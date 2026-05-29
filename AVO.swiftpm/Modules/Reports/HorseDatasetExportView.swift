import SwiftUI

// MARK: - Phase 8 UI
// One-tap export of reviewed frames into YOLO/COCO training folders.

struct HorseDatasetExportView: View {
    let datasetManager: HorseDatasetManager
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var report: HorseDatasetExportReport?
    @State private var errorText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FASE 8 · EXPORTADOR YOLO / COCO")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
                        Text("Convierte las anotaciones revisadas en dataset entrenable real")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    Spacer()
                    Button("CERRAR") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        exportRow("Origen", datasetManager.activeDatasetURL.path)
                        exportRow("Salida", datasetManager.activeDatasetURL.appendingPathComponent("exports").path)
                        exportRow("Formatos", "YOLO detector · YOLO pose · COCO keypoints")
                        exportRow("Regla", "No exporta anatomía sintética; puntos perdidos = visibilidad 0")
                    }
                    .padding(8)
                }
                .groupBoxStyle(DarkExportBoxStyle())

                Button {
                    runExport()
                } label: {
                    HStack {
                        Spacer()
                        Text(isExporting ? "EXPORTANDO..." : "EXPORTAR DATASET REAL")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                        Spacer()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.28)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.8), lineWidth: 1))
                }
                .disabled(isExporting)

                if let report {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            exportRow("Total", "\(report.totalRecords)")
                            exportRow("Detector +", "\(report.detectorPositive)")
                            exportRow("Negativos", "\(report.detectorNegative)")
                            exportRow("Pose", "\(report.poseRecords)")
                            exportRow("Saltados", "\(report.skippedNoImage)")
                            exportRow("Split", "train \(report.trainCount) · val \(report.valCount) · test \(report.testCount)")
                            exportRow("Export", report.exportPath)
                        }
                        .padding(8)
                    }
                    .groupBoxStyle(DarkExportBoxStyle())
                }

                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("Después de exportar: copia la carpeta al Mac/PC, entrena YOLO detector y YOLO pose, exporta a CoreML y vuelve a meter HorseDetector.mlmodelc + HorsePose.mlmodelc en la app.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))

                Spacer()
            }
            .padding(22)
        }
    }

    private func runExport() {
        isExporting = true
        errorText = ""
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try HorseDatasetExporter().exportAll(from: datasetManager)
                DispatchQueue.main.async {
                    self.report = result
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorText = "EXPORT ERROR: \(error.localizedDescription)"
                    self.isExporting = false
                }
            }
        }
    }

    private func exportRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.green)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.82))
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct DarkExportBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1))
    }
}
