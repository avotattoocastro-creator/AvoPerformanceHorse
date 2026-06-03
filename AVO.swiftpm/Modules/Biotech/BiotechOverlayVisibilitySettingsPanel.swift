import SwiftUI

// MARK: - PHASE134
// BIOTECH VISIBILITY SETTINGS
//
// Use this inside the existing BIOTECH/Hub settings page.
// It controls the forced PHASE133 overlay.

@MainActor
public struct BiotechOverlayVisibilitySettingsPanel: View {

    @AppStorage("biotech_show_phase133_rec_panel") private var showRecPanel: Bool = false
    @AppStorage("biotech_show_selected_horse_header") private var showHorseHeader: Bool = true

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BIOTECH VISUAL")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            Toggle("Mostrar panel REC BIOTECH", isOn: $showRecPanel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))

            Toggle("Mostrar caballo activo", isOn: $showHorseHeader)
                .font(.system(size: 12, weight: .bold, design: .monospaced))

            Text("Estos ajustes ocultan o muestran el panel nuevo igual que el panel anterior.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(12)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }
}
