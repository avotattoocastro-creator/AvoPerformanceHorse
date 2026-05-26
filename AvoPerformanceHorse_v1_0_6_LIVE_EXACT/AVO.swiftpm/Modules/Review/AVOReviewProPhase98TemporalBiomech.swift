import Foundation
import CoreGraphics
import SwiftUI

// MARK: - REVIEW PRO PHASE 98 - Temporal AutoPose + Biomech Add-on
// Additive module: extends the current temporal logic with a reusable track buffer and biomech time-series.

struct AVOPhase98TrackedJoint: Hashable, Identifiable {
    var id: String { joint.rawValue }
    var joint: HorseJoint
    var x: Double
    var y: Double
    var confidence: Double
    var ageFrames: Int
    var source: String
}

struct AVOPhase98TemporalFrame: Identifiable, Hashable {
    var id: String
    var frameIndex: Int
    var timeSeconds: Double
    var joints: [AVOPhase98TrackedJoint]
    var continuityScore: Double
    var filledOcclusions: Int
    var averageConfidence: Double
}

struct AVOPhase98BiomechSample: Identifiable, Hashable {
    var id: String { frameId }
    var frameId: String
    var timeSeconds: Double
    var dorsalAngle: Double?
    var pelvisAngle: Double?
    var leftForeAngle: Double?
    var rightForeAngle: Double?
    var leftHindAngle: Double?
    var rightHindAngle: Double?
    var foreSymmetry: Double?
    var hindSymmetry: Double?
    var dynamicRisk: Double

    var compactText: String {
        let risk = Int(dynamicRisk * 100)
        let fore = foreSymmetry.map { "F\(Int($0 * 100))%" } ?? "F--"
        let hind = hindSymmetry.map { "H\(Int($0 * 100))%" } ?? "H--"
        return "\(fore) · \(hind) · RISK \(risk)%"
    }
}

final class AVOPhase98TemporalAutoPoseEngine: ObservableObject {
    @Published private(set) var status: String = "PHASE98 TEMPORAL AUTOPOSE READY"
    @Published private(set) var frames: [AVOPhase98TemporalFrame] = []
    @Published private(set) var biomechSeries: [AVOPhase98BiomechSample] = []
    @Published private(set) var lastContinuity: Double = 0
    @Published private(set) var lastOcclusionFill: Int = 0

    private var previous: [HorseJoint: AVOPhase98TrackedJoint] = [:]
    private let maxOcclusionAge = 4

    func reset() {
        previous.removeAll()
        frames.removeAll()
        biomechSeries.removeAll()
        lastContinuity = 0
        lastOcclusionFill = 0
        status = "PHASE98 TEMPORAL AUTOPOSE RESET"
    }

    func push(frameIndex: Int, timeSeconds: Double, annotations: [EditableHorseAnnotation]) -> AVOPhase98TemporalFrame {
        let detected = Dictionary(uniqueKeysWithValues: annotations.map { ($0.joint, $0) })
        var output: [AVOPhase98TrackedJoint] = []
        var stable = 0
        var compared = 0
        var filled = 0

        for joint in HorseJoint.allCases {
            if let ann = detected[joint] {
                var x = ann.x
                var y = ann.y
                var confidence = ann.confidence
                if let old = previous[joint] {
                    compared += 1
                    let jump = hypot(ann.x - old.x, ann.y - old.y)
                    if jump < 0.075 { stable += 1 }
                    if jump > 0.20 && ann.confidence < 0.70 {
                        x = old.x * 0.76 + ann.x * 0.24
                        y = old.y * 0.76 + ann.y * 0.24
                        confidence = min(confidence, old.confidence) * 0.88
                    }
                }
                let tracked = AVOPhase98TrackedJoint(joint: joint, x: x, y: y, confidence: confidence, ageFrames: 0, source: ann.isManual ? "manual" : "model")
                previous[joint] = tracked
                output.append(tracked)
            } else if let old = previous[joint], old.ageFrames < maxOcclusionAge {
                let tracked = AVOPhase98TrackedJoint(joint: joint,
                                                     x: old.x,
                                                     y: old.y,
                                                     confidence: max(0.03, old.confidence * 0.58),
                                                     ageFrames: old.ageFrames + 1,
                                                     source: "temporal-fill")
                previous[joint] = tracked
                output.append(tracked)
                filled += 1
            }
        }

        let avg = output.isEmpty ? 0 : output.map { $0.confidence }.reduce(0, +) / Double(output.count)
        let continuity = compared == 0 ? avg : min(1.0, (Double(stable) / Double(max(compared, 1))) * 0.62 + avg * 0.38)
        let frame = AVOPhase98TemporalFrame(id: "phase98-frame-\(frameIndex)", frameIndex: frameIndex, timeSeconds: timeSeconds, joints: output, continuityScore: continuity, filledOcclusions: filled, averageConfidence: avg)
        frames.append(frame)
        if frames.count > 1500 { frames.removeFirst(frames.count - 1500) }

        let biomech = makeBiomechSample(from: frame)
        biomechSeries.append(biomech)
        if biomechSeries.count > 1500 { biomechSeries.removeFirst(biomechSeries.count - 1500) }

        lastContinuity = continuity
        lastOcclusionFill = filled
        status = "TEMPORAL AUTOPOSE · \(output.count) trainingModels · fill \(filled) · C\(Int(continuity * 100))%"
        return frame
    }

    private func makeBiomechSample(from frame: AVOPhase98TemporalFrame) -> AVOPhase98BiomechSample {
        let annotations = frame.joints.map {
            EditableHorseAnnotation(joint: $0.joint,
                                    x: $0.x,
                                    y: $0.y,
                                    confidence: $0.confidence,
                                    isPredicted: $0.source != "manual",
                                    isManual: $0.source == "manual")
        }
        let result = AVOAdvancedBiomechEngine.analyze(points: annotations)
        let risk = result.asymmetryRisk ?? dynamicRiskFallback(result)
        return AVOPhase98BiomechSample(frameId: frame.id,
                                       timeSeconds: frame.timeSeconds,
                                       dorsalAngle: result.dorsalAngle,
                                       pelvisAngle: result.pelvisAngle,
                                       leftForeAngle: result.leftForeAngle,
                                       rightForeAngle: result.rightForeAngle,
                                       leftHindAngle: result.leftHindAngle,
                                       rightHindAngle: result.rightHindAngle,
                                       foreSymmetry: result.foreSymmetry,
                                       hindSymmetry: result.hindSymmetry,
                                       dynamicRisk: risk)
    }

    private func dynamicRiskFallback(_ result: AVOAdvancedBiomechResult) -> Double {
        let visiblePenalty = max(0.0, 1.0 - Double(result.visiblePoints) / Double(max(HorseJoint.allCases.count, 1)))
        return min(1.0, visiblePenalty * 0.65)
    }
}
