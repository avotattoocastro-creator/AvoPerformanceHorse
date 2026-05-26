import Foundation
import CoreGraphics

// MARK: - Biomechanical Temporal Tracking Engine Pro
// Single source of truth for live horse skeleton stabilization.
// This replaces simple frame-to-frame smoothing with a persistent biomechanical tracker:
// - per-joint alpha-beta/Kalman-style prediction
// - One Euro adaptive low-pass filtering
// - short occlusion hold without flicker
// - confidence hysteresis
// - anatomical chain length constraints
// - spine/body identity lock
// - limb-chain damping to prevent teleporting joints
// - gait/contact hints based on hoof motion

struct TrackedHorseJoint: Identifiable, Hashable {
    var id: HorseJoint { joint }
    let joint: HorseJoint
    let x: Double
    let y: Double
    let confidence: Double
    let velocityX: Double
    let velocityY: Double
    let ageFrames: Int
    let missedFrames: Int
    let isPredicted: Bool
    let trail: [CGPoint]
}

final class HorseAnatomyTemporalTracker {
    private struct OneEuroAxis {
        var value: Double
        var derivative: Double
        var initialized: Bool

        mutating func reset(_ newValue: Double) {
            value = newValue
            derivative = 0
            initialized = true
        }

        mutating func filter(_ raw: Double, velocityHint: Double, minCutoff: Double, beta: Double, dCutoff: Double) -> Double {
            if !initialized {
                reset(raw)
                return raw
            }
            let rawDerivative = raw - value
            let dAlpha = alpha(cutoff: dCutoff)
            derivative = derivative + (rawDerivative - derivative) * dAlpha
            let cutoff = minCutoff + beta * abs(derivative + velocityHint * 0.35)
            let a = alpha(cutoff: cutoff)
            value = value + (raw - value) * a
            return value
        }

        private func alpha(cutoff: Double) -> Double {
            // Frame-normalized One Euro approximation for 30/60 fps camera use.
            let safeCutoff = max(0.001, min(4.0, cutoff))
            let tau = 1.0 / (2.0 * Double.pi * safeCutoff)
            let te = 1.0 / 60.0
            return max(0.04, min(0.85, 1.0 / (1.0 + tau / te)))
        }
    }

    private struct JointFilter2D {
        var xFilter: OneEuroAxis
        var yFilter: OneEuroAxis

        init(x: Double, y: Double) {
            xFilter = OneEuroAxis(value: x, derivative: 0, initialized: true)
            yFilter = OneEuroAxis(value: y, derivative: 0, initialized: true)
        }

        mutating func filter(x: Double, y: Double, vx: Double, vy: Double, minCutoff: Double, beta: Double) -> CGPoint {
            let fx = xFilter.filter(x, velocityHint: vx, minCutoff: minCutoff, beta: beta, dCutoff: 1.15)
            let fy = yFilter.filter(y, velocityHint: vy, minCutoff: minCutoff, beta: beta, dCutoff: 1.15)
            return CGPoint(x: fx, y: fy)
        }
    }

    private struct TrackState {
        var joint: HorseJoint
        var x: Double
        var y: Double
        var filteredX: Double
        var filteredY: Double
        var velocityX: Double
        var velocityY: Double
        var accelerationX: Double
        var accelerationY: Double
        var confidence: Double
        var ageFrames: Int
        var missedFrames: Int
        var rejectedFrames: Int
        var stableFrames: Int
        var trail: [CGPoint]
        var filter: JointFilter2D
    }

    private struct LimbChain {
        let joints: [HorseJoint]
        let stiffness: Double
    }

    private var tracks: [HorseJoint: TrackState] = [:]
    private var learnedLengths: [String: Double] = [:]
    private var lastBodyCenter: CGPoint?
    private var lastBodyScale: Double = 0.22
    private var stableFrameCount: Int = 0
    private var gaitPhaseHint: String = "GAIT --"

    // Tuned for iPad live camera. These values favor stable live drawing over instant jumps.
    var maxMissedFrames: Int = 54
    var maxTrailPoints: Int = 32
    var minInputConfidence: Double = 0.14
    var confidenceDecayPerMiss: Double = 0.955
    var velocityBlend: Double = 0.22
    var accelerationBlend: Double = 0.10
    var predictionWeight: Double = 0.64
    var softJumpFactor: Double = 0.36
    var hardJumpFactor: Double = 0.88
    var occlusionConfidenceFloor: Double = 0.055

    private let spineChain = LimbChain(joints: [.poll, .neckBase, .withers, .back, .croup, .tailBase], stiffness: 0.24)
    private let limbChains: [LimbChain] = [
        LimbChain(joints: [.withers, .leftShoulder, .leftElbow, .leftCarpus, .leftFetlock, .leftHoof], stiffness: 0.18),
        LimbChain(joints: [.withers, .rightShoulder, .rightElbow, .rightCarpus, .rightFetlock, .rightHoof], stiffness: 0.18),
        LimbChain(joints: [.croup, .leftHip, .leftStifle, .leftHock, .leftHindFetlock, .leftHindHoof], stiffness: 0.18),
        LimbChain(joints: [.croup, .rightHip, .rightStifle, .rightHock, .rightHindFetlock, .rightHindHoof], stiffness: 0.18)
    ]

    func reset() {
        tracks.removeAll()
        learnedLengths.removeAll()
        lastBodyCenter = nil
        lastBodyScale = 0.22
        stableFrameCount = 0
        gaitPhaseHint = "GAIT --"
    }

    func update(with detections: [HorseKeypoint]) -> [TrackedHorseJoint] {
        let valid = detections.filter { $0.confidence >= minInputConfidence }
        updateBodyReference(from: valid)
        learnAnatomicalLengths(from: valid)
        let observedJoints = Set(valid.map { $0.joint })

        for point in valid {
            if var state = tracks[point.joint] {
                updateExistingTrack(&state, with: point)
                tracks[point.joint] = state
            } else {
                tracks[point.joint] = makeNewTrack(from: point)
            }
        }

        for joint in HorseJoint.allCases where !observedJoints.contains(joint) {
            guard var state = tracks[joint] else { continue }
            holdOccludedTrack(&state)
            if state.missedFrames > maxMissedFrames || state.confidence < occlusionConfidenceFloor {
                tracks.removeValue(forKey: joint)
            } else {
                tracks[joint] = state
            }
        }

        applyBiomechanicalConstraints()
        updateGaitPhaseHint()
        return trackedJoints()
    }

    func trackedJoints() -> [TrackedHorseJoint] {
        HorseJoint.allCases.compactMap { joint in
            guard let state = tracks[joint] else { return nil }
            return TrackedHorseJoint(
                joint: state.joint,
                x: state.filteredX,
                y: state.filteredY,
                confidence: state.confidence,
                velocityX: state.velocityX,
                velocityY: state.velocityY,
                ageFrames: state.ageFrames,
                missedFrames: state.missedFrames,
                isPredicted: state.missedFrames > 0 || state.rejectedFrames > 0,
                trail: state.trail
            )
        }
    }

    func stableHorseKeypoints() -> [HorseKeypoint] {
        trackedJoints().map {
            HorseKeypoint(joint: $0.joint, x: $0.x, y: $0.y, confidence: $0.confidence)
        }
    }

    func trackingQuality() -> Double {
        let active = trackedJoints()
        guard !active.isEmpty else { return 0 }
        let visibleScore = Double(active.count) / Double(max(1, HorseJoint.allCases.count))
        let confidenceScore = active.map { $0.confidence }.reduce(0, +) / Double(active.count)
        let predictedPenalty = Double(active.filter { $0.isPredicted }.count) / Double(max(1, active.count))
        let continuity = Double(active.filter { $0.ageFrames > 12 }.count) / Double(max(1, active.count))
        let stabilityBonus = min(0.20, Double(stableFrameCount) / 260.0)
        return clamp01(visibleScore * 0.34 + confidenceScore * 0.50 + continuity * 0.20 - predictedPenalty * 0.16 + stabilityBonus)
    }

    func trackingStatusText() -> String {
        let count = trackedJoints().count
        let q = Int(trackingQuality() * 100.0)
        return "ADV TRACK \(count)/\(HorseJoint.allCases.count) · Q\(q)% · \(gaitPhaseHint)"
    }

    private func updateExistingTrack(_ state: inout TrackState, with point: HorseKeypoint) {
        let prediction = predictedPosition(for: state)
        let detected = CGPoint(x: point.x, y: point.y)
        let distance = hypot(Double(detected.x - prediction.x), Double(detected.y - prediction.y))
        let jumpLimit = allowedJump(for: point.joint, confidence: point.confidence)

        if isTeleport(distance: distance, limit: jumpLimit, confidence: point.confidence, state: state) {
            rejectAndHold(&state, prediction: prediction)
            return
        }

        let corrected = anatomyCorrectedPosition(joint: point.joint, detected: detected, predicted: prediction)
        let alpha = trackingAlpha(for: point.joint, confidence: point.confidence, distance: distance, age: state.ageFrames)
        let blendedX = Double(prediction.x) + (Double(corrected.x) - Double(prediction.x)) * alpha
        let blendedY = Double(prediction.y) + (Double(corrected.y) - Double(prediction.y)) * alpha

        let measuredVX = blendedX - state.x
        let measuredVY = blendedY - state.y
        let measuredAX = measuredVX - state.velocityX
        let measuredAY = measuredVY - state.velocityY
        state.accelerationX = state.accelerationX + (measuredAX - state.accelerationX) * accelerationBlend
        state.accelerationY = state.accelerationY + (measuredAY - state.accelerationY) * accelerationBlend
        state.velocityX = state.velocityX + (measuredVX - state.velocityX) * velocityBlend
        state.velocityY = state.velocityY + (measuredVY - state.velocityY) * velocityBlend
        state.x = clamp01(blendedX)
        state.y = clamp01(blendedY)

        let filterParams = oneEuroParams(for: point.joint, confidence: point.confidence, distance: distance)
        let filtered = state.filter.filter(x: state.x, y: state.y, vx: state.velocityX, vy: state.velocityY, minCutoff: filterParams.minCutoff, beta: filterParams.beta)
        state.filteredX = clamp01(Double(filtered.x))
        state.filteredY = clamp01(Double(filtered.y))
        state.confidence = max(point.confidence, state.confidence * 0.972)
        state.ageFrames += 1
        state.stableFrames += distance < jumpLimit * 0.42 ? 1 : 0
        state.missedFrames = 0
        state.rejectedFrames = max(0, state.rejectedFrames - 1)
        appendTrail(&state)
    }

    private func makeNewTrack(from point: HorseKeypoint) -> TrackState {
        let x = clamp01(point.x)
        let y = clamp01(point.y)
        return TrackState(
            joint: point.joint,
            x: x,
            y: y,
            filteredX: x,
            filteredY: y,
            velocityX: 0,
            velocityY: 0,
            accelerationX: 0,
            accelerationY: 0,
            confidence: point.confidence,
            ageFrames: 1,
            missedFrames: 0,
            rejectedFrames: 0,
            stableFrames: 1,
            trail: [CGPoint(x: CGFloat(x), y: CGFloat(y))],
            filter: JointFilter2D(x: x, y: y)
        )
    }

    private func holdOccludedTrack(_ state: inout TrackState) {
        state.missedFrames += 1
        state.ageFrames += 1
        let p = predictedPosition(for: state)
        let damping = occlusionDamping(for: state.joint, missed: state.missedFrames)
        state.x = clamp01(Double(p.x))
        state.y = clamp01(Double(p.y))
        state.velocityX *= damping
        state.velocityY *= damping
        state.accelerationX *= 0.58
        state.accelerationY *= 0.58
        let filtered = state.filter.filter(x: state.x, y: state.y, vx: state.velocityX, vy: state.velocityY, minCutoff: 0.12, beta: 0.02)
        state.filteredX = clamp01(Double(filtered.x))
        state.filteredY = clamp01(Double(filtered.y))
        state.confidence *= confidenceDecayPerMiss
        appendTrail(&state)
    }

    private func rejectAndHold(_ state: inout TrackState, prediction: CGPoint) {
        state.rejectedFrames += 1
        state.missedFrames = min(state.missedFrames + 1, maxMissedFrames)
        state.confidence *= 0.93
        state.x = clamp01(Double(prediction.x))
        state.y = clamp01(Double(prediction.y))
        state.velocityX *= 0.48
        state.velocityY *= 0.48
        let filtered = state.filter.filter(x: state.x, y: state.y, vx: state.velocityX, vy: state.velocityY, minCutoff: 0.10, beta: 0.01)
        state.filteredX = clamp01(Double(filtered.x))
        state.filteredY = clamp01(Double(filtered.y))
        appendTrail(&state)
    }

    private func predictedPosition(for state: TrackState) -> CGPoint {
        let px = state.x + state.velocityX * predictionWeight + state.accelerationX * 0.20
        let py = state.y + state.velocityY * predictionWeight + state.accelerationY * 0.20
        return CGPoint(x: clamp01(px), y: clamp01(py))
    }

    private func isTeleport(distance: Double, limit: Double, confidence: Double, state: TrackState) -> Bool {
        if state.ageFrames < 4 { return false }
        if confidence > 0.91 && distance < limit * 1.75 { return false }
        if state.missedFrames > 8 && confidence > 0.76 && distance < limit * 1.45 { return false }
        return distance > limit
    }

    private func trackingAlpha(for joint: HorseJoint, confidence: Double, distance: Double, age: Int) -> Double {
        let base: Double
        switch joint {
        case .withers, .back, .croup, .neckBase, .tailBase, .poll:
            base = 0.18
        case .nose:
            base = 0.24
        case .leftHoof, .rightHoof, .leftHindHoof, .rightHindHoof,
             .leftFetlock, .rightFetlock, .leftHindFetlock, .rightHindFetlock:
            base = 0.38
        default:
            base = 0.26
        }
        let startup = age < 8 ? 0.14 : 0.0
        let confidenceBoost = max(0, min(0.22, (confidence - 0.42) * 0.34))
        let motionBoost = max(0, min(0.18, distance * 1.15))
        return max(0.08, min(0.62, base + startup + confidenceBoost + motionBoost))
    }

    private func oneEuroParams(for joint: HorseJoint, confidence: Double, distance: Double) -> (minCutoff: Double, beta: Double) {
        let confidencePenalty = confidence < 0.35 ? -0.06 : 0.0
        switch joint {
        case .withers, .back, .croup, .neckBase, .tailBase:
            return (0.12 + confidencePenalty, 0.035)
        case .poll, .nose:
            return (0.16 + confidencePenalty, 0.055)
        case .leftHoof, .rightHoof, .leftHindHoof, .rightHindHoof:
            return (0.22 + min(0.10, distance), 0.12)
        case .leftFetlock, .rightFetlock, .leftHindFetlock, .rightHindFetlock:
            return (0.20 + min(0.08, distance), 0.10)
        default:
            return (0.17 + confidencePenalty, 0.070)
        }
    }

    private func allowedJump(for joint: HorseJoint, confidence: Double) -> Double {
        let body = max(0.09, min(0.46, lastBodyScale))
        let multiplier: Double
        switch joint {
        case .leftHoof, .rightHoof, .leftHindHoof, .rightHindHoof:
            multiplier = 1.40
        case .leftFetlock, .rightFetlock, .leftHindFetlock, .rightHindFetlock:
            multiplier = 1.22
        case .withers, .back, .croup, .neckBase:
            multiplier = 0.58
        case .poll, .tailBase:
            multiplier = 0.72
        default:
            multiplier = 0.92
        }
        let confidenceBoost = confidence > 0.78 ? 1.18 : 1.0
        return max(0.030, min(0.30, body * softJumpFactor * multiplier * confidenceBoost))
    }

    private func anatomyCorrectedPosition(joint: HorseJoint, detected: CGPoint, predicted: CGPoint) -> CGPoint {
        // Core anchors get extra inertia; distal joints remain responsive but controlled by chain constraints later.
        switch joint {
        case .withers, .back, .croup, .neckBase:
            return CGPoint(x: predicted.x + (detected.x - predicted.x) * 0.68,
                           y: predicted.y + (detected.y - predicted.y) * 0.68)
        case .poll, .tailBase:
            return CGPoint(x: predicted.x + (detected.x - predicted.x) * 0.78,
                           y: predicted.y + (detected.y - predicted.y) * 0.78)
        default:
            return detected
        }
    }

    private func applyBiomechanicalConstraints() {
        applyBodyIdentityLock()
        applyChainConstraint(spineChain)
        for chain in limbChains { applyChainConstraint(chain) }
        limitContralateralCrossing()
    }

    private func applyBodyIdentityLock() {
        let anchors: [HorseJoint] = [.neckBase, .withers, .back, .croup, .tailBase]
        let visibleAnchors = anchors.compactMap { tracks[$0] }
        guard visibleAnchors.count >= 3 else { return }
        let centerX = visibleAnchors.map { $0.filteredX }.reduce(0, +) / Double(visibleAnchors.count)
        let centerY = visibleAnchors.map { $0.filteredY }.reduce(0, +) / Double(visibleAnchors.count)
        if let oldCenter = lastBodyCenter {
            let dx = centerX - Double(oldCenter.x)
            let dy = centerY - Double(oldCenter.y)
            if hypot(dx, dy) > max(0.045, lastBodyScale * 0.26) {
                for joint in anchors {
                    guard var state = tracks[joint] else { continue }
                    state.filteredX -= dx * 0.18
                    state.filteredY -= dy * 0.18
                    state.x = state.filteredX
                    state.y = state.filteredY
                    tracks[joint] = state
                }
            }
        }
    }

    private func applyChainConstraint(_ chain: LimbChain) {
        guard chain.joints.count >= 2 else { return }
        for index in 1..<chain.joints.count {
            let parentJoint = chain.joints[index - 1]
            let childJoint = chain.joints[index]
            guard let parent = tracks[parentJoint], var child = tracks[childJoint] else { continue }
            let key = lengthKey(parentJoint, childJoint)
            let expected = learnedLengths[key] ?? defaultLength(parentJoint, childJoint)
            let dx = child.filteredX - parent.filteredX
            let dy = child.filteredY - parent.filteredY
            let dist = max(0.0001, hypot(dx, dy))
            let minAllowed = expected * 0.48
            let maxAllowed = expected * 1.78
            if dist < minAllowed || dist > maxAllowed {
                let clamped = max(minAllowed, min(maxAllowed, dist))
                let targetX = parent.filteredX + dx / dist * clamped
                let targetY = parent.filteredY + dy / dist * clamped
                let strength = chain.stiffness + (child.missedFrames > 0 ? 0.18 : 0.0) + (child.rejectedFrames > 0 ? 0.24 : 0.0)
                child.filteredX = child.filteredX + (targetX - child.filteredX) * strength
                child.filteredY = child.filteredY + (targetY - child.filteredY) * strength
                child.x = child.filteredX
                child.y = child.filteredY
                child.velocityX *= 0.74
                child.velocityY *= 0.74
                tracks[childJoint] = child
            }
        }
    }

    private func limitContralateralCrossing() {
        let pairs: [(HorseJoint, HorseJoint)] = [
            (.leftShoulder, .rightShoulder), (.leftElbow, .rightElbow), (.leftCarpus, .rightCarpus),
            (.leftFetlock, .rightFetlock), (.leftHoof, .rightHoof),
            (.leftHip, .rightHip), (.leftStifle, .rightStifle), (.leftHock, .rightHock),
            (.leftHindFetlock, .rightHindFetlock), (.leftHindHoof, .rightHindHoof)
        ]
        for (aJoint, bJoint) in pairs {
            guard var a = tracks[aJoint], var b = tracks[bJoint] else { continue }
            let minSep = max(0.006, lastBodyScale * 0.022)
            if abs(a.filteredX - b.filteredX) < minSep && abs(a.filteredY - b.filteredY) < lastBodyScale * 0.16 {
                a.filteredX -= minSep * 0.5
                b.filteredX += minSep * 0.5
                a.x = a.filteredX; b.x = b.filteredX
                tracks[aJoint] = a
                tracks[bJoint] = b
            }
        }
    }

    private func updateBodyReference(from detections: [HorseKeypoint]) {
        let anchors: [HorseJoint] = [.withers, .back, .croup, .neckBase, .tailBase]
        let points = detections.filter { anchors.contains($0.joint) || $0.confidence > 0.58 }
        guard points.count >= 3 else { return }
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return }
        let center = CGPoint(x: CGFloat((minX + maxX) * 0.5), y: CGFloat((minY + maxY) * 0.5))
        let scale = max(0.08, min(0.55, hypot(maxX - minX, maxY - minY)))
        if let old = lastBodyCenter {
            lastBodyCenter = CGPoint(x: old.x + (center.x - old.x) * CGFloat(0.16),
                                     y: old.y + (center.y - old.y) * CGFloat(0.16))
        } else {
            lastBodyCenter = center
        }
        lastBodyScale = lastBodyScale + (scale - lastBodyScale) * 0.12
        stableFrameCount = min(800, stableFrameCount + 1)
    }

    private func learnAnatomicalLengths(from detections: [HorseKeypoint]) {
        let dict = Dictionary(uniqueKeysWithValues: detections.map { ($0.joint, $0) })
        for edge in HorseJoint.skeletonEdges {
            guard let a = dict[edge.from], let b = dict[edge.to] else { continue }
            guard a.confidence > 0.42 && b.confidence > 0.42 else { continue }
            let len = max(0.002, hypot(a.x - b.x, a.y - b.y))
            let key = lengthKey(edge.from, edge.to)
            if let old = learnedLengths[key] {
                // Very slow learning: adapts to individual horse/angle without following one bad frame.
                learnedLengths[key] = old + (len - old) * 0.025
            } else {
                learnedLengths[key] = len
            }
        }
    }

    private func updateGaitPhaseHint() {
        let hooves: [HorseJoint] = [.leftHoof, .rightHoof, .leftHindHoof, .rightHindHoof]
        let visible = hooves.compactMap { tracks[$0] }
        guard visible.count >= 2 else {
            gaitPhaseHint = "GAIT HOLD"
            return
        }
        let moving = visible.filter { hypot($0.velocityX, $0.velocityY) > 0.0045 }.count
        let planted = visible.count - moving
        if planted >= 3 { gaitPhaseHint = "CONTACT" }
        else if moving >= 3 { gaitPhaseHint = "SWING" }
        else { gaitPhaseHint = "MIXED" }
    }

    private func occlusionDamping(for joint: HorseJoint, missed: Int) -> Double {
        let base: Double
        switch joint {
        case .withers, .back, .croup, .neckBase, .tailBase:
            base = 0.70
        case .leftHoof, .rightHoof, .leftHindHoof, .rightHindHoof:
            base = 0.58
        default:
            base = 0.63
        }
        return max(0.35, base - Double(min(missed, 20)) * 0.006)
    }

    private func defaultLength(_ a: HorseJoint, _ b: HorseJoint) -> Double {
        switch (a, b) {
        case (.withers, .back), (.back, .croup): return lastBodyScale * 0.24
        case (.poll, .neckBase), (.neckBase, .withers), (.croup, .tailBase): return lastBodyScale * 0.18
        default: return lastBodyScale * 0.16
        }
    }

    private func lengthKey(_ a: HorseJoint, _ b: HorseJoint) -> String {
        "\(a.rawValue)>\(b.rawValue)"
    }

    private func appendTrail(_ state: inout TrackState) {
        let p = CGPoint(x: CGFloat(state.filteredX), y: CGFloat(state.filteredY))
        if let last = state.trail.last, hypot(Double(last.x - p.x), Double(last.y - p.y)) < 0.0013 {
            return
        }
        state.trail.append(p)
        if state.trail.count > maxTrailPoints {
            state.trail.removeFirst(state.trail.count - maxTrailPoints)
        }
    }

    private func clamp01(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}
