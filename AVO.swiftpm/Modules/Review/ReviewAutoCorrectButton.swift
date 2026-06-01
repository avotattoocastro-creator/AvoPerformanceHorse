
import SwiftUI

// MARK: - REVIEW PHASE 114
// AUTO CORRECT BUTTON
//
// Functional button for REVIEW workflow.
// Connects directly to ReviewAutoCorrectionLearningEngine.

public struct ReviewAutoCorrectButton: View {

    public var title: String = "AUTO CORREGIR"

    @ObservedObject public var learningEngine: ReviewAutoCorrectionLearningEngine

    public var currentPoints: [ReviewCorrectionPointInput]
    public var horseBoxWidth: Double
    public var horseBoxHeight: Double
    public var viewTag: String = "unknown"

    public var onApply: ([ReviewAutoCorrectionResult]) -> Void

    @State private var lastAppliedCount: Int = 0

    public init(
        title: String = "AUTO CORREGIR",
        learningEngine: ReviewAutoCorrectionLearningEngine,
        currentPoints: [ReviewCorrectionPointInput],
        horseBoxWidth: Double,
        horseBoxHeight: Double,
        viewTag: String = "unknown",
        onApply: @escaping ([ReviewAutoCorrectionResult]) -> Void
    ) {
        self.title = title
        self.learningEngine = learningEngine
        self.currentPoints = currentPoints
        self.horseBoxWidth = horseBoxWidth
        self.horseBoxHeight = horseBoxHeight
        self.viewTag = viewTag
        self.onApply = onApply
    }

    public var body: some View {
        Button {
            let results = learningEngine.autoCorrect(
                points: currentPoints,
                horseBoxWidth: horseBoxWidth,
                horseBoxHeight: horseBoxHeight,
                viewTag: viewTag
            )

            lastAppliedCount = results.filter {
                abs($0.appliedDeltaX) > 0.00001 ||
                abs($0.appliedDeltaY) > 0.00001
            }.count

            onApply(results)

        } label: {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))

                    Text(lastAppliedCount > 0 ?
                         "Correcciones aplicadas: \(lastAppliedCount)" :
                         "Usa memoria aprendida local")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text("\(learningEngine.lastStats.totalSamples)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.25),
                        Color.blue.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
