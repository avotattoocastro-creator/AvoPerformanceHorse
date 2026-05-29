
import Foundation
import CoreGraphics

struct AVOHorseBiomechAIResult {
    let risk: Double
    let alertLevel: String
    let primarySuspicion: String
    let supportPhase: String
    let headNodScore: Double
    let hipHikeScore: Double
    let frontLoadImbalance: Double
    let hindLoadImbalance: Double
    let pushOffAsymmetry: Double
    let clinicalNote: String
}

final class AVOHorseBiomechAIEngine {
    private var headHistory: [CGPoint] = []
    private var withersHistory: [CGPoint] = []
    private var croupHistory: [CGPoint] = []
    private var leftFrontHistory: [CGPoint] = []
    private var rightFrontHistory: [CGPoint] = []
    private var leftHindHistory: [CGPoint] = []
    private var rightHindHistory: [CGPoint] = []

    var maxHistory: Int = 64

    func reset() {
        headHistory.removeAll()
        withersHistory.removeAll()
        croupHistory.removeAll()
        leftFrontHistory.removeAll()
        rightFrontHistory.removeAll()
        leftHindHistory.removeAll()
        rightHindHistory.removeAll()
    }

    func update(joints: [TrackedHorseJoint], trackingQuality: Double, bodyRank: String) -> AVOHorseBiomechAIResult {
        let map = Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, $0) })

        append(map[.nose] ?? map[.poll], to: &headHistory)
        append(map[.withers], to: &withersHistory)
        append(map[.croup] ?? map[.tailBase], to: &croupHistory)
        append(map[.leftHoof] ?? map[.leftFetlock], to: &leftFrontHistory)
        append(map[.rightHoof] ?? map[.rightFetlock], to: &rightFrontHistory)
        append(map[.leftHindHoof] ?? map[.leftHindFetlock], to: &leftHindHistory)
        append(map[.rightHindHoof] ?? map[.rightHindFetlock], to: &rightHindHistory)

        let headNod = normalizedOscillation(headHistory, reference: withersHistory)
        let hipHike = normalizedOscillation(croupHistory, reference: withersHistory)

        let frontLoad = pairImbalance(leftFrontHistory, rightFrontHistory)
        let hindLoad = pairImbalance(leftHindHistory, rightHindHistory)

        let frontStride = amplitudeImbalance(leftFrontHistory, rightFrontHistory)
        let hindStride = amplitudeImbalance(leftHindHistory, rightHindHistory)
        let pushOff = max(frontStride, hindStride)

        let baseRisk = max(headNod * 0.30, hipHike * 0.30, frontLoad * 0.22, hindLoad * 0.22, pushOff * 0.26)
        let qualityPenalty = max(0, 0.55 - trackingQuality) * 0.28
        let rankPenalty: Double = bodyRank.contains("ELITE") || bodyRank.contains("GOOD") ? 0.0 : 0.12
        let risk = max(0, min(1, baseRisk + qualityPenalty + rankPenalty))

        let suspicion: String
        if frontLoad > 0.28 || headNod > 0.30 {
            suspicion = "FRONT LIMB ASYMMETRY"
        } else if hindLoad > 0.28 || hipHike > 0.30 {
            suspicion = "HIND LIMB ASYMMETRY"
        } else if pushOff > 0.28 {
            suspicion = "PUSH-OFF ASYMMETRY"
        } else {
            suspicion = "NO CLEAR ASYMMETRY"
        }

        let support = supportPhase(leftFront: leftFrontHistory, rightFront: rightFrontHistory, leftHind: leftHindHistory, rightHind: rightHindHistory)

        let level: String
        if risk >= 0.72 {
            level = "HIGH"
        } else if risk >= 0.46 {
            level = "WATCH"
        } else {
            level = "LOW"
        }

        let note: String
        if level == "HIGH" {
            note = "High asymmetry signal. Review slow motion and compare both reins before increasing workload."
        } else if level == "WATCH" {
            note = "Possible asymmetry. Repeat side-view pass with clean lateral angle."
        } else {
            note = "No strong biomechanical warning with current tracked anatomy."
        }

        return AVOHorseBiomechAIResult(
            risk: risk,
            alertLevel: level,
            primarySuspicion: suspicion,
            supportPhase: support,
            headNodScore: headNod,
            hipHikeScore: hipHike,
            frontLoadImbalance: frontLoad,
            hindLoadImbalance: hindLoad,
            pushOffAsymmetry: pushOff,
            clinicalNote: note
        )
    }

    private func append(_ joint: TrackedHorseJoint?, to history: inout [CGPoint]) {
        guard let joint, joint.confidence >= 0.18 else { return }
        history.append(CGPoint(x: joint.x, y: joint.y))
        if history.count > maxHistory {
            history.removeFirst(history.count - maxHistory)
        }
    }

    private func normalizedOscillation(_ main: [CGPoint], reference: [CGPoint]) -> Double {
        guard main.count >= 8 else { return 0 }
        let mainAmp = verticalAmplitude(main)
        let refAmp = reference.count >= 8 ? verticalAmplitude(reference) : 0.0
        return max(0, min(1, abs(mainAmp - refAmp) * 5.5))
    }

    private func pairImbalance(_ a: [CGPoint], _ b: [CGPoint]) -> Double {
        guard a.count >= 6, b.count >= 6 else { return 0 }
        let ay = verticalAmplitude(a)
        let by = verticalAmplitude(b)
        let denom = max(0.0001, max(ay, by))
        return max(0, min(1, abs(ay - by) / denom))
    }

    private func amplitudeImbalance(_ a: [CGPoint], _ b: [CGPoint]) -> Double {
        guard a.count >= 8, b.count >= 8 else { return 0 }
        let ax = horizontalAmplitude(a)
        let bx = horizontalAmplitude(b)
        let denom = max(0.0001, max(ax, bx))
        return max(0, min(1, abs(ax - bx) / denom))
    }

    private func verticalAmplitude(_ points: [CGPoint]) -> Double {
        guard let minY = points.map({ $0.y }).min(), let maxY = points.map({ $0.y }).max() else { return 0 }
        return Double(maxY - minY)
    }

    private func horizontalAmplitude(_ points: [CGPoint]) -> Double {
        guard let minX = points.map({ $0.x }).min(), let maxX = points.map({ $0.x }).max() else { return 0 }
        return Double(maxX - minX)
    }

    private func supportPhase(leftFront: [CGPoint], rightFront: [CGPoint], leftHind: [CGPoint], rightHind: [CGPoint]) -> String {
        guard let lf = leftFront.last, let rf = rightFront.last, let lh = leftHind.last, let rh = rightHind.last else {
            return "SUPPORT UNKNOWN"
        }

        let front = lf.y > rf.y ? "LF LOAD" : "RF LOAD"
        let hind = lh.y > rh.y ? "LH LOAD" : "RH LOAD"
        return front + " / " + hind
    }
}
