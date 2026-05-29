import Foundation
import CoreGraphics
import SwiftUI

// MARK: - REVIEW PHASE 113
// AUTO CORRECTION LEARNING LOOP
//
// Purpose:
// AutoPose -> user manually corrects points -> app learns correction deltas.
// Later the user can press AUTO CORREGIR and apply learned corrections locally.
//
// This is NOT full ML retraining.
// This is a lightweight local adaptive corrector for REVIEW.

public struct ReviewLearnedPointCorrection: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var jointName: String
    public var predictedX: Double
    public var predictedY: Double
    public var correctedX: Double
    public var correctedY: Double
    public var deltaX: Double
    public var deltaY: Double
    public var predictedConfidence: Double
    public var horseBoxWidth: Double
    public var horseBoxHeight: Double
    public var viewTag: String
    public var modelName: String
    public var createdAt: Date

    public init(jointName: String,
                predictedX: Double,
                predictedY: Double,
                correctedX: Double,
                correctedY: Double,
                predictedConfidence: Double,
                horseBoxWidth: Double,
                horseBoxHeight: Double,
                viewTag: String = "unknown",
                modelName: String = "unknown",
                createdAt: Date = Date()) {
        self.jointName = jointName
        self.predictedX = predictedX
        self.predictedY = predictedY
        self.correctedX = correctedX
        self.correctedY = correctedY
        self.deltaX = correctedX - predictedX
        self.deltaY = correctedY - predictedY
        self.predictedConfidence = predictedConfidence
        self.horseBoxWidth = max(0.0001, horseBoxWidth)
        self.horseBoxHeight = max(0.0001, horseBoxHeight)
        self.viewTag = viewTag
        self.modelName = modelName
        self.createdAt = createdAt
    }

    public var normalizedDeltaX: Double {
        deltaX / horseBoxWidth
    }

    public var normalizedDeltaY: Double {
        deltaY / horseBoxHeight
    }

    public var movementDistance: Double {
        sqrt(deltaX * deltaX + deltaY * deltaY)
    }
}

public struct ReviewCorrectionPointInput: Codable, Hashable {
    public var jointName: String
    public var x: Double
    public var y: Double
    public var confidence: Double

    public init(jointName: String, x: Double, y: Double, confidence: Double) {
        self.jointName = jointName
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public struct ReviewAutoCorrectionResult: Codable, Hashable {
    public var jointName: String
    public var originalX: Double
    public var originalY: Double
    public var correctedX: Double
    public var correctedY: Double
    public var appliedDeltaX: Double
    public var appliedDeltaY: Double
    public var learnedSamplesUsed: Int
    public var confidence: Double

    public init(jointName: String,
                originalX: Double,
                originalY: Double,
                correctedX: Double,
                correctedY: Double,
                appliedDeltaX: Double,
                appliedDeltaY: Double,
                learnedSamplesUsed: Int,
                confidence: Double) {
        self.jointName = jointName
        self.originalX = originalX
        self.originalY = originalY
        self.correctedX = correctedX
        self.correctedY = correctedY
        self.appliedDeltaX = appliedDeltaX
        self.appliedDeltaY = appliedDeltaY
        self.learnedSamplesUsed = learnedSamplesUsed
        self.confidence = confidence
    }
}

public struct ReviewCorrectionLearningStats: Codable, Hashable {
    public var totalSamples: Int
    public var samplesByJoint: [String: Int]
    public var averageErrorByJoint: [String: Double]
    public var mostCorrectedJoints: [String]

    public init(totalSamples: Int,
                samplesByJoint: [String: Int],
                averageErrorByJoint: [String: Double],
                mostCorrectedJoints: [String]) {
        self.totalSamples = totalSamples
        self.samplesByJoint = samplesByJoint
        self.averageErrorByJoint = averageErrorByJoint
        self.mostCorrectedJoints = mostCorrectedJoints
    }
}

@MainActor
public final class ReviewAutoCorrectionLearningEngine: ObservableObject {

    @Published public private(set) var corrections: [ReviewLearnedPointCorrection] = []
    @Published public private(set) var status: String = "AUTO CORRECTION LEARNING READY"
    @Published public private(set) var lastStats = ReviewCorrectionLearningStats(
        totalSamples: 0,
        samplesByJoint: [:],
        averageErrorByJoint: [:],
        mostCorrectedJoints: []
    )

    public var minimumSamplesPerJoint: Int = 2
    public var maxAppliedNormalizedDelta: Double = 0.08
    public var lowConfidenceBoost: Double = 1.20
    public var highConfidenceDamping: Double = 0.55

    public init() {}

    public func learn(predicted: [ReviewCorrectionPointInput],
                      corrected: [ReviewCorrectionPointInput],
                      horseBoxWidth: Double,
                      horseBoxHeight: Double,
                      viewTag: String = "unknown",
                      modelName: String = "unknown",
                      ignoreMovementBelow: Double = 0.001) {
        var learnedCount = 0

        for predictedPoint in predicted {
            guard let correctedPoint = corrected.first(where: { $0.jointName == predictedPoint.jointName }) else {
                continue
            }

            let dx = correctedPoint.x - predictedPoint.x
            let dy = correctedPoint.y - predictedPoint.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < ignoreMovementBelow {
                continue
            }

            corrections.append(
                ReviewLearnedPointCorrection(
                    jointName: predictedPoint.jointName,
                    predictedX: predictedPoint.x,
                    predictedY: predictedPoint.y,
                    correctedX: correctedPoint.x,
                    correctedY: correctedPoint.y,
                    predictedConfidence: predictedPoint.confidence,
                    horseBoxWidth: horseBoxWidth,
                    horseBoxHeight: horseBoxHeight,
                    viewTag: viewTag,
                    modelName: modelName
                )
            )

            learnedCount += 1
        }

        rebuildStats()
        status = "LEARNED \(learnedCount) CORRECTIONS | TOTAL \(corrections.count)"
    }

    public func autoCorrect(points: [ReviewCorrectionPointInput],
                            horseBoxWidth: Double,
                            horseBoxHeight: Double,
                            viewTag: String = "unknown") -> [ReviewAutoCorrectionResult] {
        let width = max(0.0001, horseBoxWidth)
        let height = max(0.0001, horseBoxHeight)

        return points.map { point in
            let candidates = corrections.filter {
                $0.jointName == point.jointName &&
                ($0.viewTag == viewTag || $0.viewTag == "unknown" || viewTag == "unknown")
            }

            guard candidates.count >= minimumSamplesPerJoint else {
                return ReviewAutoCorrectionResult(
                    jointName: point.jointName,
                    originalX: point.x,
                    originalY: point.y,
                    correctedX: point.x,
                    correctedY: point.y,
                    appliedDeltaX: 0,
                    appliedDeltaY: 0,
                    learnedSamplesUsed: candidates.count,
                    confidence: 0
                )
            }

            let avgNormDX = candidates.map(\.normalizedDeltaX).reduce(0, +) / Double(candidates.count)
            let avgNormDY = candidates.map(\.normalizedDeltaY).reduce(0, +) / Double(candidates.count)

            let clampedNormDX = clamp(avgNormDX, -maxAppliedNormalizedDelta, maxAppliedNormalizedDelta)
            let clampedNormDY = clamp(avgNormDY, -maxAppliedNormalizedDelta, maxAppliedNormalizedDelta)

            let confidenceFactor: Double
            if point.confidence < 0.45 {
                confidenceFactor = lowConfidenceBoost
            } else if point.confidence > 0.80 {
                confidenceFactor = highConfidenceDamping
            } else {
                confidenceFactor = 1.0
            }

            let dx = clampedNormDX * width * confidenceFactor
            let dy = clampedNormDY * height * confidenceFactor

            let correctedX = clamp(point.x + dx, 0, 1)
            let correctedY = clamp(point.y + dy, 0, 1)

            let learnedConfidence = min(1.0, Double(candidates.count) / 12.0)

            return ReviewAutoCorrectionResult(
                jointName: point.jointName,
                originalX: point.x,
                originalY: point.y,
                correctedX: correctedX,
                correctedY: correctedY,
                appliedDeltaX: correctedX - point.x,
                appliedDeltaY: correctedY - point.y,
                learnedSamplesUsed: candidates.count,
                confidence: learnedConfidence
            )
        }
    }

    public func clearLearning() {
        corrections.removeAll()
        rebuildStats()
        status = "LOCAL CORRECTION MEMORY CLEARED"
    }

    public func exportLearningJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(corrections)
    }

    public func importLearningJSONData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        corrections = try decoder.decode([ReviewLearnedPointCorrection].self, from: data)
        rebuildStats()
        status = "IMPORTED \(corrections.count) LEARNED CORRECTIONS"
    }

    public func exportTrainingCorrectionCSV() -> String {
        var rows = [
            "joint,predicted_x,predicted_y,corrected_x,corrected_y,delta_x,delta_y,confidence,box_w,box_h,view_tag,model,created_at"
        ]

        let formatter = ISO8601DateFormatter()

        for c in corrections {
            rows.append([
                c.jointName,
                String(c.predictedX),
                String(c.predictedY),
                String(c.correctedX),
                String(c.correctedY),
                String(c.deltaX),
                String(c.deltaY),
                String(c.predictedConfidence),
                String(c.horseBoxWidth),
                String(c.horseBoxHeight),
                c.viewTag,
                c.modelName,
                formatter.string(from: c.createdAt)
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    private func rebuildStats() {
        let grouped = Dictionary(grouping: corrections, by: { $0.jointName })
        var counts: [String: Int] = [:]
        var avgErrors: [String: Double] = [:]

        for (joint, samples) in grouped {
            counts[joint] = samples.count
            avgErrors[joint] = samples.map(\.movementDistance).reduce(0, +) / Double(max(1, samples.count))
        }

        let mostCorrected = counts
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key }

        lastStats = ReviewCorrectionLearningStats(
            totalSamples: corrections.count,
            samplesByJoint: counts,
            averageErrorByJoint: avgErrors,
            mostCorrectedJoints: Array(mostCorrected)
        )
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        max(minValue, min(maxValue, value))
    }
}
