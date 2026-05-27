import SwiftUI
import CoreGraphics
import Foundation


@MainActor
final class AVOStableSkeletonRenderCache: ObservableObject {
    @Published var joints: [TrackedHorseJoint] = []

    private var holdFrames: [HorseJoint: Int] = [:]
    private var visualVelocity: [HorseJoint: CGVector] = [:]
    private var stableConfidence: [HorseJoint: Double] = [:]

    // Final V1 tuning: the temporal tracker already stabilizes the data source;
    // this render cache is the last visual anti-flicker guard before drawing.
    private let maxRenderHoldFrames = 54
    private let normalBlend: Double = 0.24
    private let predictedBlend: Double = 0.10
    private let maxVisualJump: Double = 0.155
    private let hardVisualJump: Double = 0.260
    private let confidenceFloor: Double = 0.045

    func ingest(_ incoming: [TrackedHorseJoint]) {
        if incoming.isEmpty {
            holdExistingFrame()
            return
        }

        var current = Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, $0) })
        let incomingMap = Dictionary(uniqueKeysWithValues: incoming.map { ($0.joint, $0) })

        for point in incoming {
            if let old = current[point.joint] {
                let distance = hypot(point.x - old.x, point.y - old.y)
                let oldConfidence = stableConfidence[point.joint] ?? old.confidence

                // Never let one bad detection visually teleport a joint. Hold/predict instead.
                if shouldRejectVisualJump(distance: distance, oldConfidence: oldConfidence, newConfidence: point.confidence, isPredicted: point.isPredicted) {
                    let missed = min(maxRenderHoldFrames, (holdFrames[point.joint] ?? 0) + 1)
                    holdFrames[point.joint] = missed
                    current[point.joint] = held(old, joint: point.joint, missed: missed, reasonPrediction: true)
                    continue
                }

                current[point.joint] = blended(old: old, new: point, distance: distance)
            } else {
                current[point.joint] = point
                visualVelocity[point.joint] = CGVector(dx: 0, dy: 0)
                stableConfidence[point.joint] = point.confidence
            }
            holdFrames[point.joint] = 0
        }

        for old in joints where incomingMap[old.joint] == nil {
            let missed = (holdFrames[old.joint] ?? 0) + 1
            holdFrames[old.joint] = missed
            if missed <= maxRenderHoldFrames {
                current[old.joint] = held(old, joint: old.joint, missed: missed, reasonPrediction: true)
            } else {
                current.removeValue(forKey: old.joint)
                visualVelocity.removeValue(forKey: old.joint)
                stableConfidence.removeValue(forKey: old.joint)
            }
        }

        let ordered = HorseJoint.allCases.compactMap { current[$0] }.filter { $0.confidence >= confidenceFloor }
        joints = applyRenderBoneContinuity(ordered)
    }

    private func holdExistingFrame() {
        var current = Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, $0) })
        for old in joints {
            let missed = (holdFrames[old.joint] ?? 0) + 1
            holdFrames[old.joint] = missed
            if missed <= maxRenderHoldFrames {
                current[old.joint] = held(old, joint: old.joint, missed: missed, reasonPrediction: true)
            } else {
                current.removeValue(forKey: old.joint)
                visualVelocity.removeValue(forKey: old.joint)
                stableConfidence.removeValue(forKey: old.joint)
            }
        }
        let ordered = HorseJoint.allCases.compactMap { current[$0] }.filter { $0.confidence >= confidenceFloor }
        joints = applyRenderBoneContinuity(ordered)
    }

    private func shouldRejectVisualJump(distance: Double, oldConfidence: Double, newConfidence: Double, isPredicted: Bool) -> Bool {
        if distance > hardVisualJump { return true }
        if isPredicted && distance > maxVisualJump * 0.72 { return true }
        if oldConfidence > 0.38 && newConfidence < 0.32 && distance > maxVisualJump * 0.62 { return true }
        return distance > maxVisualJump && newConfidence < 0.78
    }

    private func blended(old: TrackedHorseJoint, new: TrackedHorseJoint, distance: Double) -> TrackedHorseJoint {
        let adaptiveBoost = min(0.12, distance * 0.35)
        let b = new.isPredicted ? predictedBlend : min(0.38, normalBlend + adaptiveBoost)
        let x = old.x + (new.x - old.x) * b
        let y = old.y + (new.y - old.y) * b

        let rawVX = x - old.x
        let rawVY = y - old.y
        let previousV = visualVelocity[new.joint] ?? CGVector(dx: old.velocityX, dy: old.velocityY)
        let vx = Double(previousV.dx) + (rawVX - Double(previousV.dx)) * 0.18
        let vy = Double(previousV.dy) + (rawVY - Double(previousV.dy)) * 0.18
        visualVelocity[new.joint] = CGVector(dx: vx, dy: vy)

        let conf = max(new.confidence, old.confidence * 0.965)
        stableConfidence[new.joint] = conf

        return TrackedHorseJoint(
            joint: new.joint,
            x: clamp01(x),
            y: clamp01(y),
            confidence: conf,
            velocityX: vx,
            velocityY: vy,
            ageFrames: max(old.ageFrames + 1, new.ageFrames),
            missedFrames: new.missedFrames,
            isPredicted: new.isPredicted,
            trail: mergeTrail(old: old.trail, new: new.trail, point: CGPoint(x: x, y: y))
        )
    }

    private func held(_ old: TrackedHorseJoint, joint: HorseJoint, missed: Int, reasonPrediction: Bool) -> TrackedHorseJoint {
        let v = visualVelocity[joint] ?? CGVector(dx: old.velocityX, dy: old.velocityY)
        let damping = max(0.10, 0.62 - Double(min(missed, 18)) * 0.026)
        let predictedX = old.x + Double(v.dx) * damping
        let predictedY = old.y + Double(v.dy) * damping
        visualVelocity[joint] = CGVector(dx: Double(v.dx) * 0.64, dy: Double(v.dy) * 0.64)

        let decay = max(0.16, pow(0.972, Double(missed)))
        let conf = old.confidence * decay
        stableConfidence[joint] = conf

        return TrackedHorseJoint(
            joint: old.joint,
            x: clamp01(predictedX),
            y: clamp01(predictedY),
            confidence: conf,
            velocityX: Double(v.dx) * 0.64,
            velocityY: Double(v.dy) * 0.64,
            ageFrames: old.ageFrames + 1,
            missedFrames: missed,
            isPredicted: reasonPrediction,
            trail: old.trail
        )
    }

    private func applyRenderBoneContinuity(_ input: [TrackedHorseJoint]) -> [TrackedHorseJoint] {
        // Lightweight render-side continuity: if one endpoint is predicted and another is stable,
        // nudge predicted distal joints toward the last known bone relationship without changing model data.
        var map = Dictionary(uniqueKeysWithValues: input.map { ($0.joint, $0) })
        for edge in HorseJoint.skeletonEdges {
            guard let a = map[edge.from], var b = map[edge.to] else { continue }
            guard b.isPredicted || b.confidence < 0.25 else { continue }
            let dx = b.x - a.x
            let dy = b.y - a.y
            let dist = max(0.0001, hypot(dx, dy))
            let maxLen = 0.34
            if dist > maxLen {
                let tx = a.x + dx / dist * maxLen
                let ty = a.y + dy / dist * maxLen
                b = TrackedHorseJoint(
                    joint: b.joint,
                    x: b.x + (tx - b.x) * 0.20,
                    y: b.y + (ty - b.y) * 0.20,
                    confidence: b.confidence,
                    velocityX: b.velocityX * 0.80,
                    velocityY: b.velocityY * 0.80,
                    ageFrames: b.ageFrames,
                    missedFrames: b.missedFrames,
                    isPredicted: b.isPredicted,
                    trail: b.trail
                )
                map[edge.to] = b
            }
        }
        return HorseJoint.allCases.compactMap { map[$0] }
    }

    private func mergeTrail(old: [CGPoint], new: [CGPoint], point: CGPoint) -> [CGPoint] {
        var trail = new.isEmpty ? old : new
        if let last = trail.last {
            if hypot(Double(last.x - point.x), Double(last.y - point.y)) > 0.002 {
                trail.append(point)
            }
        } else {
            trail.append(point)
        }
        if trail.count > 28 { trail.removeFirst(trail.count - 28) }
        return trail
    }

    private func clamp01(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}

struct AVOFullViewHorseSkeletonOverlay: View {
    @ObservedObject var camera: CameraManager
    @StateObject private var renderCache = AVOStableSkeletonRenderCache()

    @AppStorage("avoHubShowHorseBox") private var showHorseBox = true
    @AppStorage("avoHubShowSkeleton") private var showSkeleton = true
    @AppStorage("avoHubShowJoints") private var showJoints = true
    @AppStorage("avoHubShowTrails") private var showTrails = true
    @AppStorage("avoHubShowRiderPoints") private var showRiderPoints = true
    @AppStorage("avoHubShowOverlayText") private var showOverlayText = true
    @AppStorage("avoHubShowBodyMap") private var showBodyMap = true
    @AppStorage("avoHubShowVetAlerts") private var showVetAlerts = true

    var body: some View {
        GeometryReader { geo in
            let renderedJoints = renderCache.joints
            ZStack {
                if showHorseBox {
                    horseBoxLayer(size: geo.size)
                }

                if showBodyMap {
                    bodyMapLayer(size: geo.size, joints: renderedJoints)
                }

                if showSkeleton {
                    skeletonLayer(size: geo.size, joints: renderedJoints)
                }

                if showTrails {
                    trailsLayer(size: geo.size, joints: renderedJoints)
                }

                if showJoints {
                    jointsLayer(size: geo.size, joints: renderedJoints)
                }

                if showRiderPoints {
                    riderLayer(size: geo.size)
                }

                if showOverlayText {
                    overlayTechnicalText
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 70)
                        .padding(.top, 16)
                }

                if showVetAlerts {
                    vetAlertBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 24)
                }
            }
        }
        .onAppear { renderCache.ingest(camera.trackedHorseJoints) }
        .onReceive(camera.$trackedHorseJoints) { renderCache.ingest($0) }
        .allowsHitTesting(false)
    }

    private func horseBoxLayer(size: CGSize) -> some View {
        let r = displayRect(from: camera.horseBox, in: size)
        return Rectangle()
            .stroke(boxColor.opacity(camera.hasActiveObjectLock ? 0.85 : 0.25), lineWidth: 2)
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
    }

    private func skeletonLayer(size: CGSize, joints: [TrackedHorseJoint]) -> some View {
        ZStack {
            ForEach(HorseJoint.skeletonEdges) { edge in
                let aPoint = joints.first(where: { $0.joint == edge.from })
                let bPoint = joints.first(where: { $0.joint == edge.to })

                if let a = aPoint, let b = bPoint {
                    Path { path in
                        path.move(to: screenPoint(a, in: size))
                        path.addLine(to: screenPoint(b, in: size))
                    }
                    .stroke(edgeColor(a, b), lineWidth: edgeWidth(a, b))
                    .opacity(edgeOpacity(a, b))
                }
            }
        }
    }

    private func trailsLayer(size: CGSize, joints: [TrackedHorseJoint]) -> some View {
        ZStack {
            ForEach(joints) { point in
                Circle()
                    .fill(pointColor(point).opacity(0.12))
                    .frame(width: pointSize(point) * 2.4, height: pointSize(point) * 2.4)
                    .position(screenPoint(point, in: size))
            }
        }
    }

    private func jointsLayer(size: CGSize, joints: [TrackedHorseJoint]) -> some View {
        ZStack {
            ForEach(joints) { point in
                Circle()
                    .fill(pointColor(point))
                    .frame(width: pointSize(point), height: pointSize(point))
                    .overlay(Circle().stroke(Color.black.opacity(0.65), lineWidth: 1))
                    .position(screenPoint(point, in: size))
            }
        }
    }

    private func riderLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(camera.riderPosePoints, id: \.self) { point in
                Circle()
                    .fill(Color.cyan.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .position(screenPoint(point, in: size))
            }
        }
    }

    private func bodyMapLayer(size: CGSize, joints: [TrackedHorseJoint]) -> some View {
        ZStack {
            ForEach(joints) { point in
                Circle()
                    .fill(bodyZoneColor(point).opacity(bodyZoneOpacity(point)))
                    .frame(width: bodyZoneSize(point), height: bodyZoneSize(point))
                    .position(screenPoint(point, in: size))
            }
        }
    }

    private var overlayTechnicalText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(camera.horsePoseStatus)
            Text(camera.anatomyTrackingText)
            Text(camera.anatomyTrackingQualityText)
            Text(camera.trackingGateStatusText)
            Text(camera.trackingGateReasonText)
            Text(camera.bodyOrientationText)
            Text(camera.bodyPersistenceText)
            Text(camera.bodyPhaseText)
            Text(camera.bodyHeatmapText)
            Text(camera.biomechAIStatusText)
            Text(camera.biomechAISuspicionText)
        }
        .foregroundColor(.green)
        .font(.system(size: 8, weight: .black, design: .monospaced))
        .padding(8)
        .background(Color.black.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var vetAlertBadge: some View {
        VStack(spacing: 3) {
            Text(camera.biomechAIStatusText.isEmpty ? "TRACKING" : camera.biomechAIStatusText)
                .foregroundColor(camera.risk > 0.55 ? .red : .orange)
                .font(.system(size: 11, weight: .black, design: .monospaced))

            Text(camera.biomechAISuspicionText.isEmpty ? "BIOMECH WATCH" : camera.biomechAISuspicionText)
                .foregroundColor(.cyan)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var boxColor: Color {
        if !camera.hasActiveObjectLock { return .orange }
        if camera.quality < 0.35 { return .red }
        if camera.risk > 0.45 { return .orange }
        return .green
    }

    private func displayRect(from normalized: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalized.minX * size.width,
            y: normalized.minY * size.height,
            width: normalized.width * size.width,
            height: normalized.height * size.height
        )
    }

    private func screenPoint(_ point: TrackedHorseJoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func screenPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func pointColor(_ point: TrackedHorseJoint) -> Color {
        if point.confidence < 0.35 { return .red }
        if point.confidence < 0.58 { return .orange }

        switch point.joint {
        case .withers, .croup, .back, .neckBase:
            return .green
        case .nose, .poll:
            return .cyan
        default:
            return .white
        }
    }

    private func pointSize(_ point: TrackedHorseJoint) -> CGFloat {
        let base: CGFloat = point.isPredicted ? 7 : 9
        return max(5, min(12, base * CGFloat(max(0.55, point.confidence))))
    }

    private func edgeColor(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> Color {
        let avg = (a.confidence + b.confidence) * 0.5
        if avg < 0.35 { return .red }
        if avg < 0.58 { return .orange }
        return .green
    }

    private func edgeWidth(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> CGFloat {
        let avg = CGFloat((a.confidence + b.confidence) * 0.5)
        return max(1.2, min(3.2, 1.2 + avg * 2.0))
    }

    private func edgeOpacity(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> Double {
        let avg = (a.confidence + b.confidence) * 0.5
        return max(0.25, min(0.90, avg))
    }

    private func bodyZoneColor(_ point: TrackedHorseJoint) -> Color {
        if camera.risk > 0.55 { return .red }
        if camera.fatigue > 0.50 { return .orange }
        if point.confidence < 0.45 { return .yellow }
        return .green
    }

    private func bodyZoneOpacity(_ point: TrackedHorseJoint) -> Double {
        let riskBoost = max(camera.risk, camera.fatigue)
        return min(0.28, 0.07 + riskBoost * 0.22 + (1.0 - point.confidence) * 0.12)
    }

    private func bodyZoneSize(_ point: TrackedHorseJoint) -> CGFloat {
        switch point.joint {
        case .withers, .croup, .back:
            return 58
        case .neckBase, .poll:
            return 42
        default:
            return 28
        }
    }
}
