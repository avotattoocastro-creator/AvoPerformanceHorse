import SwiftUI

// MARK: - PHASE131
// REVIEW COMPACT SYSTEMS DOCK
//
// Keeps iPad Pro 13" usable.
// Heavy system panels are moved behind one compact button instead of occupying the editor.

@MainActor
public struct ReviewCompactSystemsDock: View {

    @State private var showSystems = false

    public init() {}

    public var body: some View {
        Button {
            showSystems = true
        } label: {
            VStack(spacing: 2) {
                Text("SYSTEMS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Text("REVIEW / ML")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.blue.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSystems) {
            ReviewSystemsSheet()
        }
    }
}

@MainActor
public struct ReviewSystemsSheet: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ReviewCompleteSystemPanel()
                    AVOCoreMLTrainingEcosystemPanel()
                    AVOModelImportRegistryPanel()
                    ReviewBiotechTrainingIntakePanel(
                        horseName: BiotechHorseSessionRecorder.shared.selectedHorseName
                    )
                    AVOExportReportCompletePanel()
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("REVIEW SYSTEMS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("CERRAR") { dismiss() }
                }
            }
        }
    }
}
