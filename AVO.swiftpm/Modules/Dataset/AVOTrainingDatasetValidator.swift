import Foundation

// MARK: - COREML PHASE 126
// TRAINING DATASET VALIDATOR
//
// Validates if REVIEW dataset is ready for external retraining.

public struct AVOTrainingReadinessReport: Codable, Hashable {
    public var ready: Bool
    public var score: Double
    public var frameCount: Int
    public var correctedFrames: Int
    public var correctionSamples: Int
    public var warnings: [String]
    public var recommendations: [String]
}

@MainActor
public final class AVOTrainingDatasetValidator: ObservableObject {

    @Published public private(set) var lastReport: AVOTrainingReadinessReport?

    public init() {}

    public func validate() -> AVOTrainingReadinessReport {
        return validate(review: ReviewCompleteSystemController.shared)
    }

    public func validate(review: ReviewCompleteSystemController) -> AVOTrainingReadinessReport {
        let frames = review.frameRecords.count
        let corrected = review.correctedCount
        let samples = review.correctionLearning.lastStats.totalSamples
        let avgQuality = review.averageQuality

        var warnings: [String] = []
        var recommendations: [String] = []

        if frames < 50 {
            warnings.append("LOW_FRAME_COUNT")
            recommendations.append("Capture/import at least 50 useful frames.")
        }

        if corrected < 15 {
            warnings.append("LOW_CORRECTED_FRAMES")
            recommendations.append("Correct more AutoPose frames manually.")
        }

        if samples < 60 {
            warnings.append("LOW_CORRECTION_SAMPLES")
            recommendations.append("Save more keypoint corrections before retraining.")
        }

        if avgQuality < 0.55 {
            warnings.append("LOW_DATASET_QUALITY")
            recommendations.append("Run QA and remove weak/outlier frames.")
        }

        let frameScore = min(1, Double(frames) / 120.0) * 0.25
        let correctedScore = min(1, Double(corrected) / 40.0) * 0.30
        let sampleScore = min(1, Double(samples) / 180.0) * 0.30
        let qualityScore = min(1, avgQuality) * 0.15
        let total = frameScore + correctedScore + sampleScore + qualityScore

        let report = AVOTrainingReadinessReport(
            ready: total >= 0.70 && warnings.count <= 1,
            score: total,
            frameCount: frames,
            correctedFrames: corrected,
            correctionSamples: samples,
            warnings: warnings,
            recommendations: recommendations
        )

        lastReport = report
        return report
    }
}
