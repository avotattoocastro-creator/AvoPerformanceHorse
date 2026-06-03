import SwiftUI

// MARK: - PHASE132
// FORCED BIOTECH TOP + REC OVERLAY
//
// This overlay is independent of the old inline REC panel.
// It guarantees visible:
// - selected horse top-right
// - REC CLIENT
// - REC BIOMECH
// - REC DATA
//
// Use as:
// .overlay(BiotechPhase132ForcedOverlay(), alignment: .topTrailing)

@MainActor
public struct BiotechPhase132ForcedOverlay: View {

    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared
    @ObservedObject private var complete = BiotechCompleteSystemController.shared
    @ObservedObject private var dataBridge = BiotechDataToReviewBridge.shared

    public init() {}

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 10) {
                selectedHorseBox
                    .padding(.top, 18)
                    .padding(.trailing, 170)

                Spacer()

                recDataPanel
                    .padding(.trailing, 32)
                    .padding(.bottom, 92)
            }
        }
        .allowsHitTesting(true)
    }

    private var selectedHorseBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "hare.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 1) {
                Text("CABALLO ACTIVO")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Text(displayHorse)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(complete.mode.rawValue.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(width: 310, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
    }

    private var recDataPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                chip("CLIENT", active: complete.mode == .recClient || complete.mode == .fullCapture)
                chip("BIOMECH", active: complete.mode == .recBiotech || complete.mode == .fullCapture)
                chip("DATA", active: dataBridge.isDataOn)
            }

            HStack(spacing: 8) {
                Button {
                    prepare()
                    complete.startClientREC()
                } label: {
                    recButtonLabel("REC CLIENT", color: .green)
                }
                .buttonStyle(.plain)

                Button {
                    prepare()
                    complete.startBiotechREC()
                } label: {
                    recButtonLabel("REC BIOMECH", color: .orange)
                }
                .buttonStyle(.plain)
            }

            Button {
                prepare()
                complete.toggleData(requestedFPS: 120)
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dataBridge.isDataOn ? Color.green : Color.white)
                        .frame(width: 9, height: 9)

                    Text(dataBridge.isDataOn ? "REC DATA ON → REVIEW" : "REC DATA OFF")
                        .font(.system(size: 11, weight: .black, design: .monospaced))

                    Spacer()

                    Text("120FPS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(dataBridge.isDataOn ? Color.green.opacity(0.24) : Color.purple.opacity(0.34))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(dataBridge.isDataOn ? Color.green.opacity(0.80) : Color.purple.opacity(0.90), lineWidth: 1))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button("FULL") {
                    prepare()
                    complete.startFullCapture()
                }
                .buttonStyle(.borderedProminent)

                Button("STOP") {
                    complete.stopAll()
                }
                .buttonStyle(.bordered)

                Button("MANIFEST") {
                    complete.exportManifest()
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))

            HStack {
                Text(displayHorse)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)

                Spacer()

                Text(dataBridge.isDataOn ? "DATA \(dataBridge.capturedCount)" : "DATA READY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(dataBridge.isDataOn ? .green : .white.opacity(0.65))
            }
        }
        .padding(12)
        .frame(width: 385)
        .background(Color.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.28), lineWidth: 1))
    }

    private func prepare() {
        let horse = displayHorse == "SIN CABALLO SELECCIONADO" ? "SIN_CABALLO" : displayHorse
        recorder.setSelectedHorse(horse)
        complete.prepare(horseName: horse)
    }

    private var displayHorse: String {
        let value = recorder.selectedHorseName
        if value.isEmpty || value == "SIN_CABALLO" || value == "SIN CABALLO" {
            return "SIN CABALLO SELECCIONADO"
        }
        return value
    }

    private func chip(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(active ? Color.black : Color.white.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(active ? Color.green : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func recButtonLabel(_ title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color.white).frame(width: 9, height: 9)
            Text(title).font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(color.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.85), lineWidth: 1))
    }
}
