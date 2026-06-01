import SwiftUI

// MARK: - REVIEW PHASE 115
// INTEGRATED REVIEW AUTOCORRECT HOST
//
// Safe integration wrapper.
// Use this around the existing REVIEW screen if direct patching the original
// heavy file is risky in Swift Playgrounds.
//
// Example:
// ReviewAutoCorrectIntegratedHost {
//     ExistingReviewPage()
// }

public struct ReviewAutoCorrectIntegratedHost<Content: View>: View {

    @StateObject private var learningEngine = ReviewAutoCorrectionLearningEngine()

    private let content: Content

    @State private var predictedPoints: [ReviewCorrectionPointInput] = []
    @State private var editablePoints: [ReviewCorrectionPointInput] = []
    @State private var horseBoxWidth: Double = 1.0
    @State private var horseBoxHeight: Double = 1.0
    @State private var lastAutoCorrectSummary: String = "AUTO CORREGIR READY"

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .reviewAutoCorrectFloatingDock(
                learningEngine: learningEngine,
                predictedPoints: predictedPoints,
                editablePoints: editablePoints,
                horseBoxWidth: horseBoxWidth,
                horseBoxHeight: horseBoxHeight,
                viewTag: "review",
                modelName: "current"
            ) { results in
                lastAutoCorrectSummary = ReviewAutoCorrectDataAdapter.resultsSummary(results)
                editablePoints = results.map {
                    ReviewCorrectionPointInput(
                        jointName: $0.jointName,
                        x: $0.correctedX,
                        y: $0.correctedY,
                        confidence: $0.confidence
                    )
                }
            }
    }

    public func updatePredictedPoints(_ points: [ReviewCorrectionPointInput]) -> Self {
        // SwiftUI value views cannot mutate state here.
        // Use ReviewAutoCorrectRuntimeBridge.shared from the real REVIEW page
        // when wiring live points in the next patch.
        self
    }
}
