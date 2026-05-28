import SwiftUI

// MARK: - REVIEW PHASE 115
// REAL AUTO CORRECT FLOATING DOCK
//
// This is the concrete UI integration layer for REVIEW.
// It provides:
// - AUTO CORREGIR button
// - GUARDAR CORRECCIÓN button
// - compact learning memory panel
//
// It is intentionally a ViewModifier so it can be attached to the existing
// REVIEW screen without rewriting the whole page.

public struct ReviewAutoCorrectFloatingDock: ViewModifier {

    @ObservedObject public var learningEngine: ReviewAutoCorrectionLearningEngine

    public var predictedPoints: [ReviewCorrectionPointInput]
    public var editablePoints: [ReviewCorrectionPointInput]
    public var horseBoxWidth: Double
    public var horseBoxHeight: Double
    public var viewTag: String
    public var modelName: String

    public var onApplyAutoCorrection: ([ReviewAutoCorrectionResult]) -> Void

    @State private var isExpanded: Bool = true

    public init(
        learningEngine: ReviewAutoCorrectionLearningEngine,
        predictedPoints: [ReviewCorrectionPointInput],
        editablePoints: [ReviewCorrectionPointInput],
        horseBoxWidth: Double,
        horseBoxHeight: Double,
        viewTag: String = "unknown",
        modelName: String = "unknown",
        onApplyAutoCorrection: @escaping ([ReviewAutoCorrectionResult]) -> Void
    ) {
        self.learningEngine = learningEngine
        self.predictedPoints = predictedPoints
        self.editablePoints = editablePoints
        self.horseBoxWidth = horseBoxWidth
        self.horseBoxHeight = horseBoxHeight
        self.viewTag = viewTag
        self.modelName = modelName
        self.onApplyAutoCorrection = onApplyAutoCorrection
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                        Text(isExpanded ? "OCULTAR AUTO CORRECCIÓN" : "AUTO CORRECCIÓN")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 8) {
                        ReviewAutoCorrectButton(
                            learningEngine: learningEngine,
                            currentPoints: editablePoints,
                            horseBoxWidth: horseBoxWidth,
                            horseBoxHeight: horseBoxHeight,
                            viewTag: viewTag
                        ) { results in
                            onApplyAutoCorrection(results)
                        }

                        Button {
                            learningEngine.learn(
                                predicted: predictedPoints,
                                corrected: editablePoints,
                                horseBoxWidth: horseBoxWidth,
                                horseBoxHeight: horseBoxHeight,
                                viewTag: viewTag,
                                modelName: modelName
                            )
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("GUARDAR CORRECCIÓN")
                                Spacer()
                                Text("\(predictedPoints.count)")
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
                        .disabled(predictedPoints.isEmpty || editablePoints.isEmpty)
                        .opacity((predictedPoints.isEmpty || editablePoints.isEmpty) ? 0.45 : 1.0)

                        ReviewAutoCorrectionLearningPanel(engine: learningEngine)
                            .frame(width: 320)
                    }
                    .frame(width: 340)
                    .padding(10)
                    .background(Color.black.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
            .padding(.trailing, 10)
            .padding(.bottom, 10)
        }
    }
}

public extension View {
    func reviewAutoCorrectFloatingDock(
        learningEngine: ReviewAutoCorrectionLearningEngine,
        predictedPoints: [ReviewCorrectionPointInput],
        editablePoints: [ReviewCorrectionPointInput],
        horseBoxWidth: Double,
        horseBoxHeight: Double,
        viewTag: String = "unknown",
        modelName: String = "unknown",
        onApplyAutoCorrection: @escaping ([ReviewAutoCorrectionResult]) -> Void
    ) -> some View {
        modifier(
            ReviewAutoCorrectFloatingDock(
                learningEngine: learningEngine,
                predictedPoints: predictedPoints,
                editablePoints: editablePoints,
                horseBoxWidth: horseBoxWidth,
                horseBoxHeight: horseBoxHeight,
                viewTag: viewTag,
                modelName: modelName,
                onApplyAutoCorrection: onApplyAutoCorrection
            )
        )
    }
}
