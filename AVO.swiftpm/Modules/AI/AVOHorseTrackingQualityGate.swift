
import Foundation
import CoreGraphics

struct AVOHorseTrackingGateResult {
    let score: Double
    let status: String
    let shouldSaveTrainingFrame: Bool
    let reason: String
}

final class AVOHorseTrackingQualityGate {
    func evaluate(
        joints: [TrackedHorseJoint],
        horseBox: CGRect,
        trackingQuality: Double,
        poseConfidence: Double
    ) -> AVOHorseTrackingGateResult {
        let jointCountScore = min(1.0, Double(joints.count) / Double(max(1, HorseJoint.allCases.count)))

        let map = Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, $0) })

        var anatomyChecks = 0
        var anatomyPass = 0

        func pass(_ condition: Bool) {
            anatomyChecks += 1
            if condition { anatomyPass += 1 }
        }

        pass(map[.nose] != nil || map[.poll] != nil)
        pass(map[.withers] != nil)
        pass(map[.croup] != nil || map[.tailBase] != nil)
        pass(map[.leftShoulder] != nil || map[.rightShoulder] != nil)
        pass(map[.leftHip] != nil || map[.rightHip] != nil)
        pass((map[.leftHoof] != nil || map[.rightHoof] != nil) && (map[.leftHindHoof] != nil || map[.rightHindHoof] != nil))

        let anatomyScore = anatomyChecks == 0 ? 0 : Double(anatomyPass) / Double(anatomyChecks)

        let boxArea = horseBox.width * horseBox.height
        let boxScore: Double
        if boxArea < 0.05 || boxArea > 0.80 {
            boxScore = 0.25
        } else if boxArea < 0.10 {
            boxScore = 0.55
        } else {
            boxScore = 1.0
        }

        let confidenceScore = max(0, min(1, poseConfidence))
        let total = max(0, min(1,
            trackingQuality * 0.34 +
            jointCountScore * 0.24 +
            anatomyScore * 0.24 +
            confidenceScore * 0.10 +
            boxScore * 0.08
        ))

        let shouldSave = total >= 0.62 && joints.count >= 10 && anatomyScore >= 0.50

        let status: String
        let reason: String

        if total >= 0.78 {
            status = "TRACKING ELITE"
            reason = "lateral clean / full anatomy"
        } else if total >= 0.62 {
            status = "TRACKING GOOD"
            reason = "usable training frame"
        } else if joints.count < 8 {
            status = "TRACKING PARTIAL"
            reason = "not enough joints"
        } else {
            status = "TRACKING WEAK"
            reason = "improve side view / distance"
        }

        return AVOHorseTrackingGateResult(
            score: total,
            status: status,
            shouldSaveTrainingFrame: shouldSave,
            reason: reason
        )
    }
}
