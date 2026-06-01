import Foundation

// MARK: - REVIEW PHASE 115
// AUTO CORRECT DATA ADAPTER
//
// Helper functions for converting existing REVIEW point data to the
// ReviewCorrectionPointInput format used by the learning engine.
//
// These helpers are string/double based so they do not depend on one exact
// project annotation type.

public enum ReviewAutoCorrectDataAdapter {

    public static func makeInput(
        jointName: String,
        x: Double,
        y: Double,
        confidence: Double
    ) -> ReviewCorrectionPointInput {
        ReviewCorrectionPointInput(
            jointName: jointName,
            x: x,
            y: y,
            confidence: confidence
        )
    }

    public static func applyResultsToDictionaryPoints(
        points: [String: ReviewCorrectionPointInput],
        results: [ReviewAutoCorrectionResult]
    ) -> [String: ReviewCorrectionPointInput] {
        var output = points

        for result in results {
            output[result.jointName] = ReviewCorrectionPointInput(
                jointName: result.jointName,
                x: result.correctedX,
                y: result.correctedY,
                confidence: max(points[result.jointName]?.confidence ?? 0, result.confidence)
            )
        }

        return output
    }

    public static func resultsSummary(_ results: [ReviewAutoCorrectionResult]) -> String {
        let applied = results.filter {
            abs($0.appliedDeltaX) > 0.00001 || abs($0.appliedDeltaY) > 0.00001
        }

        let avgConfidence = results.isEmpty ? 0 : results.map(\.confidence).reduce(0, +) / Double(results.count)

        return "AUTO CORREGIR | applied \(applied.count)/\(results.count) | confidence \(String(format: "%.2f", avgConfidence))"
    }
}
