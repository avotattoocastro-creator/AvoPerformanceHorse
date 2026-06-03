import SwiftUI

// MARK: - PHASE131
// BIOTECH SELECTED HORSE COMPACT STRIP
//
// Small, always-visible strip for the empty top-right area in BIOTECH.

@MainActor
public struct BiotechSelectedHorseCompactStrip: View {

    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared
    @ObservedObject private var complete = BiotechCompleteSystemController.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hare.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 1) {
                Text("CABALLO ACTIVO")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))

                Text(displayHorse)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Divider()
                .frame(height: 22)
                .overlay(Color.white.opacity(0.18))

            Text(complete.mode.rawValue.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.28), lineWidth: 1))
    }

    private var displayHorse: String {
        let value = recorder.selectedHorseName
        if value.isEmpty || value == "SIN_CABALLO" {
            return "SIN CABALLO SELECCIONADO"
        }
        return value
    }
}
