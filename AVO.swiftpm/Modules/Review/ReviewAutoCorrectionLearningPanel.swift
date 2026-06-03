import SwiftUI

// MARK: - REVIEW PHASE 113
// AUTO CORRECTION LEARNING PANEL
//
// Compact UI panel for REVIEW.
// Keep this as a collapsible panel or small dock.

public struct ReviewAutoCorrectionLearningPanel: View {

    @ObservedObject public var engine: ReviewAutoCorrectionLearningEngine

    public init(engine: ReviewAutoCorrectionLearningEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AUTO CORRECTION LEARNING")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(engine.lastStats.totalSamples)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }

            Text(engine.status)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)

            if engine.lastStats.mostCorrectedJoints.isEmpty {
                Text("Sin memoria todavía. Usa AutoPose, corrige puntos y pulsa Guardar Corrección.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PUNTOS QUE MÁS APRENDE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))

                    ForEach(engine.lastStats.mostCorrectedJoints, id: \.self) { joint in
                        HStack {
                            Text(joint)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))

                            Spacer()

                            Text("\(engine.lastStats.samplesByJoint[joint] ?? 0)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
