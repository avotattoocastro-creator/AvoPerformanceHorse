import Foundation
import SwiftUI

// MARK: - REVIEW PHASE 115
// AUTOCORRECT RUNTIME BRIDGE
//
// Shared bridge so the existing REVIEW page can publish predicted/editable
// points without heavy refactor.

@MainActor
public final class ReviewAutoCorrectRuntimeBridge: ObservableObject {

    public static let shared = ReviewAutoCorrectRuntimeBridge()

    @Published public var learningEngine = ReviewAutoCorrectionLearningEngine()
    @Published public var predictedPoints: [ReviewCorrectionPointInput] = []
    @Published public var editablePoints: [ReviewCorrectionPointInput] = []
    @Published public var horseBoxWidth: Double = 1.0
    @Published public var horseBoxHeight: Double = 1.0
    @Published public var viewTag: String = "review"
    @Published public var modelName: String = "current"
    @Published public var lastSummary: String = "AUTO CORREGIR READY"

    private init() {}

    public func publishPredicted(_ points: [ReviewCorrectionPointInput],
                                 horseBoxWidth: Double,
                                 horseBoxHeight: Double,
                                 viewTag: String = "review",
                                 modelName: String = "current") {
        self.predictedPoints = points
        self.editablePoints = points
        self.horseBoxWidth = horseBoxWidth
        self.horseBoxHeight = horseBoxHeight
        self.viewTag = viewTag
        self.modelName = modelName
        self.lastSummary = "PREDICTED POINTS \(points.count)"
    }

    public func publishEditable(_ points: [ReviewCorrectionPointInput]) {
        self.editablePoints = points
        self.lastSummary = "EDITABLE POINTS \(points.count)"
    }

    public func learnCurrentCorrection() {
        learningEngine.learn(
            predicted: predictedPoints,
            corrected: editablePoints,
            horseBoxWidth: horseBoxWidth,
            horseBoxHeight: horseBoxHeight,
            viewTag: viewTag,
            modelName: modelName
        )
        lastSummary = learningEngine.status
    }

    public func autoCorrectCurrent() -> [ReviewAutoCorrectionResult] {
        let results = learningEngine.autoCorrect(
            points: editablePoints,
            horseBoxWidth: horseBoxWidth,
            horseBoxHeight: horseBoxHeight,
            viewTag: viewTag
        )

        editablePoints = results.map {
            ReviewCorrectionPointInput(
                jointName: $0.jointName,
                x: $0.correctedX,
                y: $0.correctedY,
                confidence: $0.confidence
            )
        }

        lastSummary = ReviewAutoCorrectDataAdapter.resultsSummary(results)
        return results
    }
}

@MainActor
public struct ReviewAutoCorrectBridgeDock: View {

    @ObservedObject private var bridge = ReviewAutoCorrectRuntimeBridge.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            ReviewAutoCorrectButton(
                learningEngine: bridge.learningEngine,
                currentPoints: bridge.editablePoints,
                horseBoxWidth: bridge.horseBoxWidth,
                horseBoxHeight: bridge.horseBoxHeight,
                viewTag: bridge.viewTag
            ) { results in
                bridge.editablePoints = results.map {
                    ReviewCorrectionPointInput(
                        jointName: $0.jointName,
                        x: $0.correctedX,
                        y: $0.correctedY,
                        confidence: $0.confidence
                    )
                }
                bridge.lastSummary = ReviewAutoCorrectDataAdapter.resultsSummary(results)
            }

            Button {
                bridge.learnCurrentCorrection()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("GUARDAR CORRECCIÓN")
                    Spacer()
                    Text("\(bridge.predictedPoints.count)")
                        .foregroundStyle(.cyan)
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(bridge.predictedPoints.isEmpty || bridge.editablePoints.isEmpty)
            .opacity((bridge.predictedPoints.isEmpty || bridge.editablePoints.isEmpty) ? 0.45 : 1.0)

            Text(bridge.lastSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)
        }
        .frame(width: 340)
        .padding(10)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cyan.opacity(0.24), lineWidth: 1)
        )
    }
}
