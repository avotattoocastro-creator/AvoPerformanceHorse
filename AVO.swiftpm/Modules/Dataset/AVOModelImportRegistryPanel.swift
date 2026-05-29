import SwiftUI
import UniformTypeIdentifiers

// MARK: - COREML PHASE 126
// MODEL IMPORT / REGISTRY VIEW
//
// Safe UI for importing .mlpackage/.mlmodel files into registry.

@MainActor
public struct AVOModelImportRegistryPanel: View {

    @ObservedObject private var ecosystem = AVOCoreMLTrainingEcosystem.shared
    @State private var showImporter = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MODEL REGISTRY")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)

                Spacer()

                Button("IMPORT MODEL") {
                    showImporter = true
                }
                .buttonStyle(.borderedProminent)
            }

            if ecosystem.registry.isEmpty {
                Text("NO MODELS REGISTERED")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                ForEach(ecosystem.registry) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.modelName)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("\(entry.role.rawValue) · \(String(format: "%.1f", entry.averageLatencyMS))ms · Q \(String(format: "%.2f", entry.averageQualityScore))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))
                        }

                        Spacer()

                        Button("ACTIVE") {
                            ecosystem.setActiveModel(entry.modelName)
                        }
                        .buttonStyle(.bordered)
                        .font(.system(size: 9, weight: .bold))
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "mlpackage") ?? .data,
                UTType(filenameExtension: "mlmodel") ?? .data,
                .data
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    ecosystem.registerModel(fileURL: url, role: .candidate)
                }
            case .failure:
                break
            }
        }
    }
}
