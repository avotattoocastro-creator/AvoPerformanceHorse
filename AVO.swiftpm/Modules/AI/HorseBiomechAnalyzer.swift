import Foundation
import CoreGraphics

// MARK: - Phase 5: Real biomechanical analysis from real tracked joints
// No synthetic anatomy is created here. Metrics are calculated only from joints
// that come from HorsePose.mlmodelc and are stabilized by HorseAnatomyTemporalTracker.

struct HorseBiomechMetrics: Codable, Hashable {
    var timestamp: TimeInterval
    var visibleJoints: Int
    var trackingQuality: Double

    var frontSymmetryScore: Double?
    var hindSymmetryScore: Double?
    var globalSymmetryScore: Double?

    var frontLamenessSuspicion: Double?
    var hindLamenessSuspicion: Double?
    var lamenessSuspicion: Double

    var leftFrontStride: Double?
    var rightFrontStride: Double?
    var leftHindStride: Double?
    var rightHindStride: Double?

    var withersCroupBalance: Double?
    var headNodIndex: Double?
    var gaitHint: String
    var status: String
}

final class HorseBiomechAnalyzer {
    private struct JointHistory {
        var points: [CGPoint] = []
        var confidence: [Double] = []
    }

    private var history: [HorseJoint: JointHistory] = [:]
    private var lastCenter: CGPoint?
    private var lastTimestamp = Date()

    var maxHistory: Int = 42
    var minConfidence: Double = 0.20
    var minFramesForStride: Int = 8

    func reset() {
        history.removeAll()
        lastCenter = nil
        lastTimestamp = Date()
    }

    func update(joints: [TrackedHorseJoint], trackingQuality: Double) -> HorseBiomechMetrics {
        let now = Date()
        let visible = joints.filter { !$0.isPredicted && $0.confidence >= minConfidence }

        for joint in visible {
            var h = history[joint.joint] ?? JointHistory()
            h.points.append(CGPoint(x: joint.x, y: joint.y))
            h.confidence.append(joint.confidence)
            if h.points.count > maxHistory {
                h.points.removeFirst(h.points.count - maxHistory)
            }
            if h.confidence.count > maxHistory {
                h.confidence.removeFirst(h.confidence.count - maxHistory)
            }
            history[joint.joint] = h
        }

        let lfStride = strideAmplitude(.leftHoof)
        let rfStride = strideAmplitude(.rightHoof)
        let lhStride = strideAmplitude(.leftHindHoof)
        let rhStride = strideAmplitude(.rightHindHoof)

        let frontSym = symmetryScore(lfStride, rfStride)
        let hindSym = symmetryScore(lhStride, rhStride)
        let globalSym = combine(frontSym, hindSym)

        let headNod = verticalOscillation(.nose)
        let withers = latest(.withers)
        let croup = latest(.croup)
        let balance = withersCroupBalance(withers: withers, croup: croup)

        let frontSuspicion = suspicion(from: frontSym, headNod: headNod, balance: balance)
        let hindSuspicion = suspicion(from: hindSym, headNod: nil, balance: balance)
        let combinedSuspicion = max(frontSuspicion ?? 0, hindSuspicion ?? 0)

        let gait = estimateGait(joints: visible, now: now)
        let status = statusText(visibleJoints: visible.count, trackingQuality: trackingQuality, suspicion: combinedSuspicion, globalSymmetry: globalSym)

        lastTimestamp = now

        return HorseBiomechMetrics(
            timestamp: now.timeIntervalSince1970,
            visibleJoints: visible.count,
            trackingQuality: trackingQuality,
            frontSymmetryScore: frontSym,
            hindSymmetryScore: hindSym,
            globalSymmetryScore: globalSym,
            frontLamenessSuspicion: frontSuspicion,
            hindLamenessSuspicion: hindSuspicion,
            lamenessSuspicion: combinedSuspicion,
            leftFrontStride: lfStride,
            rightFrontStride: rfStride,
            leftHindStride: lhStride,
            rightHindStride: rhStride,
            withersCroupBalance: balance,
            headNodIndex: headNod,
            gaitHint: gait,
            status: status
        )
    }

    private func latest(_ joint: HorseJoint) -> CGPoint? {
        history[joint]?.points.last
    }

    private func strideAmplitude(_ joint: HorseJoint) -> Double? {
        guard let h = history[joint], h.points.count >= minFramesForStride else { return nil }
        let xs = h.points.map { Double($0.x) }
        let ys = h.points.map { Double($0.y) }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        let horizontal = maxX - minX
        let vertical = maxY - minY
        return sqrt(horizontal * horizontal + vertical * vertical)
    }

    private func verticalOscillation(_ joint: HorseJoint) -> Double? {
        guard let h = history[joint], h.points.count >= minFramesForStride else { return nil }
        let ys = h.points.map { Double($0.y) }
        guard let minY = ys.min(), let maxY = ys.max() else { return nil }
        return maxY - minY
    }

    private func symmetryScore(_ a: Double?, _ b: Double?) -> Double? {
        guard let a, let b, max(a, b) > 0.001 else { return nil }
        let diff = abs(a - b) / max(a, b)
        return max(0.0, min(1.0, 1.0 - diff))
    }

    private func combine(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (.some(x), .some(y)): return (x + y) / 2.0
        case let (.some(x), .none): return x
        case let (.none, .some(y)): return y
        default: return nil
        }
    }

    private func withersCroupBalance(withers: CGPoint?, croup: CGPoint?) -> Double? {
        guard let withers, let croup else { return nil }
        return Double(withers.y - croup.y)
    }

    private func suspicion(from symmetry: Double?, headNod: Double?, balance: Double?) -> Double? {
        guard let symmetry else { return nil }
        var value = max(0, min(1, (0.82 - symmetry) / 0.32))
        if let headNod, headNod > 0.045 {
            value += min(0.22, (headNod - 0.045) * 2.4)
        }
        if let balance, abs(balance) > 0.055 {
            value += min(0.18, (abs(balance) - 0.055) * 2.0)
        }
        return max(0, min(1, value))
    }

    private func estimateGait(joints: [TrackedHorseJoint], now: Date) -> String {
        let hooves: [HorseJoint] = [.leftHoof, .rightHoof, .leftHindHoof, .rightHindHoof]
        let amplitudes = hooves.compactMap { strideAmplitude($0) }
        let avgAmp = amplitudes.isEmpty ? 0 : amplitudes.reduce(0, +) / Double(amplitudes.count)

        let center = averageCenter(joints)
        defer { lastCenter = center }

        guard let prev = lastCenter else {
            return avgAmp < 0.006 ? "STATIC" : "MOVING"
        }

        let dx = Double(center.x - prev.x)
        let dy = Double(center.y - prev.y)
        let bodyMotion = sqrt(dx * dx + dy * dy)

        if avgAmp < 0.006 && bodyMotion < 0.002 { return "STATIC" }
        if avgAmp < 0.025 { return "WALK" }
        if avgAmp < 0.055 { return "TROT" }
        return "GALLOP"
    }

    private func averageCenter(_ joints: [TrackedHorseJoint]) -> CGPoint {
        guard !joints.isEmpty else { return lastCenter ?? .zero }
        let sx = joints.map { $0.x }.reduce(0, +) / Double(joints.count)
        let sy = joints.map { $0.y }.reduce(0, +) / Double(joints.count)
        return CGPoint(x: sx, y: sy)
    }

    private func statusText(visibleJoints: Int, trackingQuality: Double, suspicion: Double, globalSymmetry: Double?) -> String {
        if visibleJoints < 8 || trackingQuality < 0.22 { return "BIOMECH WAIT: NEED MORE JOINTS" }
        if suspicion >= 0.70 { return "HIGH ASYMMETRY - REVIEW VIDEO" }
        if suspicion >= 0.42 { return "POSSIBLE ASYMMETRY" }
        if let globalSymmetry, globalSymmetry >= 0.86 { return "SYMMETRY OK" }
        return "BIOMECH ANALYSING"
    }
}
