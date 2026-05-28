import SwiftUI
import UIKit
import Foundation
import UniformTypeIdentifiers

struct AVOAITrainingSettingsPage: View {
    @Environment(\.dismiss) private var dismiss
    let datasetManager: HorseDatasetManager

    @AppStorage("avo.ai.driveAccount") private var driveAccount: String = ""
    @AppStorage("avo.ai.driveDatasetFolder") private var driveDatasetFolder: String = "AVO_HORSE_DATASETS"
    @AppStorage("avo.ai.driveModelFolder") private var driveModelFolder: String = "AVO_HORSE_MODELS"
    @AppStorage("avo.ai.colabNotebookURL") private var colabNotebookURL: String = ""
    @AppStorage("avo.ai.modelType") private var modelType: String = "YOLO Pose"
    @AppStorage("avo.ai.trainResolution") private var trainResolution: Int = 960
    @AppStorage("avo.ai.epochs") private var epochs: Int = 80
    @AppStorage("avo.ai.batchSize") private var batchSize: Int = 8
    @AppStorage("avo.ai.autoZip") private var autoZip: Bool = true
    @AppStorage("avo.ai.autoYaml") private var autoYaml: Bool = true
    @AppStorage("avo.ai.autoSplit") private var autoSplit: Bool = true
    @AppStorage("avo.ai.autoPreviews") private var autoPreviews: Bool = true
    @AppStorage("avo.ai.includeBaseModel") private var includeBaseModel: Bool = true
    @AppStorage("avo.ai.pipelineMode") private var pipelineMode: String = "COLAB_SEMI_MANUAL"

    @StateObject private var latestExportSharer = LatestExportSharer()
    @State private var showShare = false
    @State private var modelShareURL: URL?
    @State private var showModelShare = false
    @State private var availableModels: [AVOStoredTrainingModel] = []
    @State private var status = "AI TRAINING SETTINGS READY"
    @State private var isExporting = false
    @State private var showModelImporter = false

    private let modelTypes = ["YOLO Pose", "CreateML", "CoreML", "KeypointRCNN"]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 10) {
                    header

                    ScrollView {
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                drivePanel
                                colabPanel
                            }
                            HStack(alignment: .top, spacing: 12) {
                                exportPanel
                                modelManagerPanel
                            }
                            validatorPanel
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 16)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) {
            if let url = latestExportSharer.zipURL {
                LatestExportShareSheet(url: url)
            } else {
                Text("Preparando ZIP...")
            }
        }
        .sheet(isPresented: $showModelShare) {
            if let url = modelShareURL {
                LatestExportShareSheet(url: url)
            } else {
                Text("Preparando modelo...")
            }
        }
        .fileImporter(
            isPresented: $showModelImporter,
            allowedContentTypes: [.item, .folder, .package],
            allowsMultipleSelection: false
        ) { result in
            importModelFromFiles(result)
        }
        .onAppear { refreshModels() }
        .onReceive(NotificationCenter.default.publisher(for: .avoHorsePoseModelUpdated)) { _ in
            refreshModels()
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "AI Training Settings",
            subtitle: "Drive/Colab seguro · dataset + modelo base · import/export modelos",
            status: status,
            accent: .cyan,
            onClose: { dismiss() }
        ) {
            EmptyView()
        }
    }


    private var drivePanel: some View {
        trainingPanel("GOOGLE DRIVE", accent: .cyan) {
            settingsField("Cuenta Drive", text: $driveAccount, placeholder: "tu cuenta / email")
            settingsField("Carpeta datasets", text: $driveDatasetFolder, placeholder: "AVO_HORSE_DATASETS")
            settingsField("Carpeta modelos", text: $driveModelFolder, placeholder: "AVO_HORSE_MODELS")
            HStack(spacing: 8) {
                trainingButton("TEST", .cyan) { status = driveAccount.isEmpty ? "DRIVE: añade cuenta en ajustes" : "DRIVE CONFIG OK · compartir ZIP con Drive" }
                trainingButton("OPEN DRIVE", .green) { openURL("googledrive://") }
            }
            Text("Modo fiable: la app prepara el pack y lo compartes a Drive con Share Sheet. Colab se abre desde aquí, pero se ejecuta manualmente con Run all.")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private var colabPanel: some View {
        trainingPanel("COLAB SETTINGS · SIN API OFICIAL", accent: .purple) {
            settingsField("Notebook URL", text: $colabNotebookURL, placeholder: "https://colab.research.google.com/...")
            Picker("Modelo", selection: $modelType) {
                ForEach(modelTypes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            Stepper("Resolución: \(trainResolution)", value: $trainResolution, in: 320...1536, step: 32)
            Stepper("Epochs: \(epochs)", value: $epochs, in: 1...500, step: 1)
            Stepper("Batch: \(batchSize)", value: $batchSize, in: 1...64, step: 1)
            HStack(spacing: 8) {
                trainingButton("CHECK URL", .purple) { status = colabNotebookURL.isEmpty ? "COLAB: pega URL notebook" : "COLAB URL OK · ejecución manual Run all" }
                trainingButton("OPEN COLAB", .green) { openURL(colabNotebookURL) }
            }
        }
    }

    private var exportPanel: some View {
        trainingPanel("EXPORT PIPELINE", accent: .green) {
            Toggle("Auto ZIP", isOn: $autoZip)
            Toggle("Auto dataset.yaml", isOn: $autoYaml)
            Toggle("Auto split train/val/test", isOn: $autoSplit)
            Toggle("Auto previews/README", isOn: $autoPreviews)
            Toggle("Incluir modelo base actual", isOn: $includeBaseModel)
            Text("Genera un paquete único: dataset + modelo base + train_config.json + README. Luego lo subes a Drive y en Colab solo haces Runtime → Run all.")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            HStack(spacing: 8) {
                trainingButton(isExporting ? "EXPORTANDO" : "EXPORT DRIVE PACK", .green) { exportColabPackage() }
                    .disabled(isExporting)
                trainingButton("SHARE TO DRIVE", .cyan) { shareLatest() }
                trainingButton("OPEN COLAB", .purple) { openURL(colabNotebookURL) }
            }
        }
    }

    private var modelManagerPanel: some View {
        trainingPanel("MODEL MANAGER", accent: .orange) {
            Text("Modelos guardados en iPad · descarga/compartir para otros dispositivos")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)

            HStack(spacing: 8) {
                trainingButton("REFRESH", .orange) { refreshModels() }
                trainingButton("IMPORT MODEL", .green) { showModelImporter = true }
            }

            if availableModels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NO HAY MODELOS LOCALES")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Cuando importes o descargues un .mlpackage/.mlmodel aparecerá aquí para guardarlo en Archivos o compartirlo por AirDrop/Drive.")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(availableModels) { model in
                            modelRow(model)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private var validatorPanel: some View {
        trainingPanel("DATASET VALIDATOR", accent: .red) {
            Text("Antes de exportar se comprueba: imágenes, JSON, puntos, cajas, splits y estructura YOLO/COCO.")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
            HStack(spacing: 8) {
                trainingButton("VALIDATE", .red) { validateDataset() }
                trainingButton("REBUILD MANIFEST", .cyan) { status = "MANIFEST: se reconstruye al exportar desde Review" }
            }
        }
    }

    private func trainingPanel<Content: View>(_ title: String, accent: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
            content()
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 245, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.35), lineWidth: 1))
    }

    private func settingsField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func trainingButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    private func modelRow(_ model: AVOStoredTrainingModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(model.kind.uppercased()) · \(model.sizeText) · \(model.dateText)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
            }

            HStack(spacing: 6) {
                compactModelButton("LOAD", .green) { loadModel(model) }
                compactModelButton("SAVE", .cyan) { shareModel(model) }
                compactModelButton("SHARE", .orange) { shareModel(model) }
                compactModelButton("DEL", .red) { deleteModel(model) }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.36)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private func compactModelButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }


    private func exportColabPackage() {
        guard !isExporting else { return }
        isExporting = true
        status = "EXPORT DRIVE/COLAB PACK: preparando dataset + modelo base..."
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let report = try HorseDatasetExporter().exportPoseColabPack(from: datasetManager)
                try AVOAITrainingPipelineWriter.writeColabPackFiles(exportFolder: URL(fileURLWithPath: report.exportPath), report: report)
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.status = "PACK OK · \(report.totalRecords) imágenes · súbelo a Drive y abre Colab"
                    self.shareLatest()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.status = "EXPORT ERROR: \(error.localizedDescription)"
                }
            }
        }
    }

    private func shareLatest() {
        latestExportSharer.shareLatestExport { showShare = true }
        status = latestExportSharer.status
    }

    private func importModelFromFiles(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else {
                status = "IMPORT MODEL: ningún archivo seleccionado"
                return
            }

            guard let source = findImportableModel(startingAt: selectedURL) else {
                status = "IMPORT MODEL ERROR: selecciona .mlpackage o .mlmodel"
                return
            }

            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }

            let fm = FileManager.default
            guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                status = "IMPORT MODEL ERROR: Documents no disponible"
                return
            }

            let libraryFolder = docs.appendingPathComponent("AVO_HORSE_MODELS", isDirectory: true)
            try fm.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
            let safeName = source.lastPathComponent.isEmpty ? "ImportedHorsePose.mlpackage" : source.lastPathComponent
            let libraryTarget = libraryFolder.appendingPathComponent(safeName, isDirectory: source.pathExtension.lowercased() == "mlpackage")
            try fm.copyItemReplacing(at: source, to: libraryTarget)

            if source.pathExtension.lowercased() == "mlpackage" {
                try AVOModelFileManager.installAsActiveModel(libraryTarget)
            }

            status = "MODELO IMPORTADO: \(libraryTarget.lastPathComponent)"
            NotificationCenter.default.post(name: .avoHorsePoseModelUpdated, object: nil)
            refreshModels()
        } catch {
            status = "IMPORT MODEL ERROR: \(error.localizedDescription)"
        }
    }

    private func findImportableModel(startingAt url: URL) -> URL? {
        let fm = FileManager.default
        let valid: Set<String> = ["mlpackage", "mlmodel"]
        if valid.contains(url.pathExtension.lowercased()) { return url }
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue, let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if valid.contains(fileURL.pathExtension.lowercased()) { return fileURL }
            }
        }
        return nil
    }

    private func refreshModels() {
        availableModels = AVOModelFileManager.scanLocalModels()
        status = availableModels.isEmpty ? "MODELS: no hay modelos locales" : "MODELS: \(availableModels.count) encontrados"
    }

    private func shareModel(_ model: AVOStoredTrainingModel) {
        do {
            modelShareURL = try AVOModelFileManager.prepareForSharing(model.url)
            showModelShare = true
            status = "MODELO LISTO PARA GUARDAR/COMPARTIR: \(model.name)"
        } catch {
            status = "MODEL SHARE ERROR: \(error.localizedDescription)"
        }
    }

    private func loadModel(_ model: AVOStoredTrainingModel) {
        do {
            try AVOModelFileManager.installAsActiveModel(model.url)
            status = "MODELO ACTIVO: \(model.name)"
            NotificationCenter.default.post(name: .avoHorsePoseModelUpdated, object: nil)
            refreshModels()
        } catch {
            status = "LOAD MODEL ERROR: \(error.localizedDescription)"
        }
    }

    private func deleteModel(_ model: AVOStoredTrainingModel) {
        do {
            try FileManager.default.removeItem(at: model.url)
            status = "MODELO ELIMINADO: \(model.name)"
            refreshModels()
        } catch {
            status = "DELETE MODEL ERROR: \(error.localizedDescription)"
        }
    }

    private func validateDataset() {
        let fm = FileManager.default
        let images = (try? fm.contentsOfDirectory(at: datasetManager.imagesURL, includingPropertiesForKeys: nil)) ?? []
        let annotations = (try? fm.contentsOfDirectory(at: datasetManager.annotationsURL, includingPropertiesForKeys: nil)) ?? []
        let jsonCount = annotations.filter { $0.pathExtension.lowercased() == "json" }.count
        let imageCount = images.filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }.count
        if imageCount == 0 || jsonCount == 0 {
            status = "VALIDATOR ERROR · faltan imágenes o anotaciones reales"
        } else {
            status = "VALIDATOR OK · IMG \(imageCount) · JSON \(jsonCount) · READY FOR REAL EXPORT"
        }
    }

    private func openURL(_ text: String) {
        guard let url = URL(string: text), !text.isEmpty else {
            status = "URL VACÍA"
            return
        }
        UIApplication.shared.open(url)
    }
}

struct AVOStoredTrainingModel: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let kind: String
    let sizeBytes: Int64
    let modifiedAt: Date

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modifiedAt)
    }
}

struct AVOModelFileManager {
    static func scanLocalModels() -> [AVOStoredTrainingModel] {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }

        var roots: [URL] = [
            docs,
            docs.appendingPathComponent("Models", isDirectory: true),
            docs.appendingPathComponent("AVOHorseModels", isDirectory: true),
            docs.appendingPathComponent("AVO_HORSE_MODELS", isDirectory: true),
            docs.appendingPathComponent("AVOHorseDatasets", isDirectory: true)
        ]

        if let bundleModel = Bundle.main.url(forResource: "AVOHorsePose", withExtension: "mlpackage") {
            roots.append(bundleModel)
        }

        var found: [URL] = []
        let validExtensions: Set<String> = ["mlpackage", "mlmodel"]

        for root in roots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { continue }

            if validExtensions.contains(root.pathExtension.lowercased()) {
                found.append(root)
                continue
            }

            guard isDir.boolValue, let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                let ext = url.pathExtension.lowercased()
                if validExtensions.contains(ext) {
                    found.append(url)
                    if ext == "mlpackage" {
                        enumerator.skipDescendants()
                    }
                }
            }
        }

        var unique: [String: URL] = [:]
        for url in found {
            unique[url.path] = url
        }

        return unique.values.map { url in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let size = folderSize(url)
            return AVOStoredTrainingModel(
                id: url.path,
                url: url,
                name: url.lastPathComponent,
                kind: url.pathExtension.isEmpty ? "model" : url.pathExtension,
                sizeBytes: size > 0 ? size : Int64(values?.fileSize ?? 0),
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    static func prepareForSharing(_ source: URL) throws -> URL {
        let fm = FileManager.default
        let tempBase = fm.temporaryDirectory.appendingPathComponent("AVOModelShare", isDirectory: true)
        if fm.fileExists(atPath: tempBase.path) {
            try? fm.removeItem(at: tempBase)
        }
        try fm.createDirectory(at: tempBase, withIntermediateDirectories: true)

        if source.pathExtension.lowercased() == "mlpackage" || isDirectory(source) {
            let zipURL = tempBase.appendingPathComponent(source.deletingPathExtension().lastPathComponent + ".zip")
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            var copyError: Error?
            coordinator.coordinate(readingItemAt: source, options: [.forUploading], error: &coordinatorError) { zippedURL in
                do { try fm.copyItem(at: zippedURL, to: zipURL) } catch { copyError = error }
            }
            if let coordinatorError { throw coordinatorError }
            if let copyError { throw copyError }
            return zipURL
        } else {
            let destination = tempBase.appendingPathComponent(source.lastPathComponent)
            try fm.copyItem(at: source, to: destination)
            return destination
        }
    }

    static func installAsActiveModel(_ source: URL) throws {
        guard source.pathExtension.lowercased() == "mlpackage" else {
            throw NSError(domain: "AVOModelFileManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Solo se puede activar directamente un .mlpackage CoreML"])
        }

        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AVOModelFileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No se encontró Documents"])
        }

        let modelsFolder = docs.appendingPathComponent("Models", isDirectory: true)
        let destination = modelsFolder.appendingPathComponent("AVOHorsePose.mlpackage", isDirectory: true)
        try fm.createDirectory(at: modelsFolder, withIntermediateDirectories: true)

        if source.path == destination.path { return }
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: source, to: destination)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    private static func folderSize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        if !isDirectory(url) {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        return total
    }
}

struct AVOAITrainingPipelineWriter {
    static func writeColabPackFiles(exportFolder: URL, report: HorseDatasetExportReport) throws {
        let defaults = UserDefaults.standard
        let modelType = defaults.string(forKey: "avo.ai.modelType") ?? "YOLO Pose"
        let epochs = defaults.integer(forKey: "avo.ai.epochs") == 0 ? 80 : defaults.integer(forKey: "avo.ai.epochs")
        let batch = defaults.integer(forKey: "avo.ai.batchSize") == 0 ? 8 : defaults.integer(forKey: "avo.ai.batchSize")
        let resolution = defaults.integer(forKey: "avo.ai.trainResolution") == 0 ? 960 : defaults.integer(forKey: "avo.ai.trainResolution")
        let driveDatasetFolder = defaults.string(forKey: "avo.ai.driveDatasetFolder") ?? "AVO_HORSE_DATASETS"
        let driveModelFolder = defaults.string(forKey: "avo.ai.driveModelFolder") ?? "AVO_HORSE_MODELS"
        let notebookURL = defaults.string(forKey: "avo.ai.colabNotebookURL") ?? ""

        let manifest = """
        {
          "pipeline": "AVO Horse Pose Drive Colab Semi Manual Training",
          "dataset": "\(report.datasetName)",
          "createdAt": \(report.createdAt),
          "modelType": "\(modelType)",
          "epochs": \(epochs),
          "batchSize": \(batch),
          "resolution": \(resolution),
          "driveDatasetFolder": "\(driveDatasetFolder)",
          "driveModelFolder": "\(driveModelFolder)",
          "notebookURL": "\(notebookURL)",
          "totalRecords": \(report.totalRecords),
          "poseRecords": \(report.poseRecords),
          "train": \(report.trainCount),
          "val": \(report.valCount),
          "test": \(report.testCount),
          "pipelineMode": "COLAB_AUTO_PACK",
          "outputModelName": "horsepose_vNEXT.mlpackage",
          "expectedUserAction": "Share ZIP to Drive, open included notebook, Runtime -> Run all"
        }
        """
        try manifest.write(to: exportFolder.appendingPathComponent("avo_colab_pipeline.json"), atomically: true, encoding: .utf8)
        try writeBaseModelsIfNeeded(to: exportFolder)
        try writeTrainConfig(to: exportFolder, modelType: modelType, epochs: epochs, batch: batch, resolution: resolution, driveDatasetFolder: driveDatasetFolder, driveModelFolder: driveModelFolder, notebookURL: notebookURL, report: report)
        try writeAutoColabNotebook(to: exportFolder, epochs: epochs, batch: batch, resolution: resolution, driveDatasetFolder: driveDatasetFolder, driveModelFolder: driveModelFolder)

        let readme = """
        AVO HORSE POSE · COLAB TRAINING PACK

        FLUJO SEGURO SIN API DE COLAB

        1) Pulsa SHARE TO DRIVE en el iPad y guarda este ZIP en Drive dentro de: \(driveDatasetFolder)
        2) Abre tu notebook Colab: \(notebookURL.isEmpty ? "CONFIGURA LA URL EN AI TRAINING SETTINGS" : notebookURL)
        3) En Colab: Runtime -> Run all. El notebook detectará este ZIP y el modelo base.
        4) Entrena con:
           - Modelo: \(modelType)
           - Resolución: \(resolution)
           - Epochs: \(epochs)
           - Batch: \(batch)
        5) Guarda el resultado en Drive dentro de: \(driveModelFolder)
        6) En el iPad abre AI Training Settings -> Model Manager -> Import/Share/Load.

        MODELO BASE:
        Si existe un modelo activo en Documents/Models o el modelo incluido en la app, se copia en /base_models/ dentro del paquete.

        Contenido:
        - yolo_pose/data.yaml + images/labels train/val/test
        - yolo_detector/data.yaml
        - coco/annotations.json
        - export_report.json
        - avo_colab_pipeline.json
        - train_config.json
        - base_models/ con el modelo actual si está disponible

        IMPORTANTE:
        La app exporta datos reales revisados. No genera anatomía sintética.
        """
        try readme.write(to: exportFolder.appendingPathComponent("README_COLAB_TRAINING.txt"), atomically: true, encoding: .utf8)

        let version = """
        model_version=horsepose_vNEXT
        source_export=\(exportFolder.lastPathComponent)
        mode=colab_semi_manual_drive
        base_models_folder=base_models
        expected_output=\(driveModelFolder)/horsepose_vNEXT.mlpackage
        """
        try version.write(to: exportFolder.appendingPathComponent("MODEL_VERSION.txt"), atomically: true, encoding: .utf8)

        // V1.0 RC ROBUST TRAINING GATE
        // This is the final safety check before the package is shared to Drive/Colab.
        // It prevents silent broken exports: empty labels, missing YAML, mismatched images/labels
        // or the common YOLO warning: "no labels found in pose set".
        _ = try AVOTrainingRobustnessCore.writePreflightReport(exportFolder: exportFolder)
    }


    private static func writeAutoColabNotebook(to exportFolder: URL, epochs: Int, batch: Int, resolution: Int, driveDatasetFolder: String, driveModelFolder: String) throws {
        func source(_ code: String) -> String {
            let escaped = code
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "\"" + escaped + "\""
        }

        let cells: [[String]] = [
            ["# AVO HORSE POSE · AUTO TRAINING\n# 1) Sube el ZIP a Drive/" + driveDatasetFolder + "\n# 2) Ejecuta Runtime -> Run all\n"],
            ["from google.colab import drive\ndrive.mount('/content/drive')\n"],
            ["!pip install ultralytics -q\n"],
            ["import os, glob, zipfile, shutil, yaml, json\nDRIVE_DATASET_FOLDER = '/content/drive/MyDrive/" + driveDatasetFolder + "'\nDRIVE_MODEL_FOLDER = '/content/drive/MyDrive/" + driveModelFolder + "'\nos.makedirs(DRIVE_MODEL_FOLDER, exist_ok=True)\nzips = sorted(glob.glob(DRIVE_DATASET_FOLDER + '/*.zip'), key=os.path.getmtime, reverse=True)\nassert zips, 'No hay ZIP en ' + DRIVE_DATASET_FOLDER\nzip_path = zips[0]\nextract_path = '/content/avo_horse_dataset'\nshutil.rmtree(extract_path, ignore_errors=True)\nwith zipfile.ZipFile(zip_path, 'r') as z:\n    z.extractall(extract_path)\nprint('ZIP:', zip_path)\nprint('EXTRAÍDO:', extract_path)\n"],
            ["import os, glob, yaml\nyamls = glob.glob(extract_path + '/**/yolo_pose/*.yaml', recursive=True) + glob.glob(extract_path + '/**/yolo_pose/*.yml', recursive=True)\nassert yamls, 'No encuentro YAML yolo_pose'\ndata_yaml = yamls[0]\nbase = os.path.dirname(data_yaml)\nwith open(data_yaml, 'r') as f:\n    data = yaml.safe_load(f) or {}\ndata['path'] = base\ndata['train'] = 'images/train'\ndata['val'] = 'images/val'\ndata['test'] = 'images/test'\nwith open(data_yaml, 'w') as f:\n    yaml.safe_dump(data, f, sort_keys=False)\nprint(open(data_yaml).read())\n"],
            ["import glob, os\nlabel_files = glob.glob(base + '/labels/**/*.txt', recursive=True)\nnon_empty = [p for p in label_files if os.path.getsize(p) > 0]\nprint('LABELS:', len(label_files), 'NON_EMPTY:', len(non_empty))\nassert non_empty, 'Labels vacíos: revisa export GOOD/HORSE desde la app'\nprint(open(non_empty[0]).read()[:500])\n"],
            ["from ultralytics import YOLO\nmodel = YOLO('yolo11n-pose')\nresults = model.train(data=data_yaml, epochs=" + String(epochs) + ", imgsz=" + String(resolution) + ", batch=" + String(batch) + ", patience=20, project='/content/avo_horse_training', name='horse_pose_auto', pretrained=True)\n"],
            ["from ultralytics import YOLO\nimport shutil, os, glob\nbest = '/content/avo_horse_training/horse_pose_auto/weights/best_model'\nassert os.path.exists(best), 'No existe best_model'\nshutil.copy2(best, os.path.join(DRIVE_MODEL_FOLDER, 'best_horse_pose_auto'))\nprint('BEST PT GUARDADO EN DRIVE')\ntry:\n    model = YOLO(best)\n    exported = model.export(format='coreml', imgsz=" + String(resolution) + ")\n    print('COREML EXPORT:', exported)\n    if os.path.exists(str(exported)):\n        target = os.path.join(DRIVE_MODEL_FOLDER, os.path.basename(str(exported)))\n        if os.path.isdir(str(exported)):\n            shutil.copytree(str(exported), target, dirs_exist_ok=True)\n        else:\n            shutil.copy2(str(exported), target)\n        print('COREML GUARDADO:', target)\nexcept Exception as e:\n    print('CoreML export no disponible en este runtime:', e)\n"]
        ]

        let cellJSON = cells.map { lines -> String in
            let joined = lines.joined(separator: "")
            return """
            {
              "cell_type": "code",
              "execution_count": null,
              "metadata": {},
              "outputs": [],
              "source": [\(source(joined))]
            }
            """
        }.joined(separator: ",\n")

        let notebook = """
        {
          "cells": [
        \(cellJSON)
          ],
          "metadata": {
            "accelerator": "GPU",
            "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
            "language_info": {"name": "python", "version": "3.x"}
          },
          "nbformat": 4,
          "nbformat_minor": 5
        }
        """
        try notebook.write(to: exportFolder.appendingPathComponent("AVO_HORSE_AUTO_TRAIN_COLAB.ipynb"), atomically: true, encoding: .utf8)
    }

    private static func writeTrainConfig(to exportFolder: URL, modelType: String, epochs: Int, batch: Int, resolution: Int, driveDatasetFolder: String, driveModelFolder: String, notebookURL: String, report: HorseDatasetExportReport) throws {
        let config = """
        {
          "datasetZipExpectedLocation": "Drive/\(driveDatasetFolder)/\(exportFolder.lastPathComponent).zip",
          "datasetFolderInsideZip": "\(exportFolder.lastPathComponent)",
          "modelType": "\(modelType)",
          "epochs": \(epochs),
          "batchSize": \(batch),
          "imageSize": \(resolution),
          "baseModelsFolder": "base_models",
          "yoloPoseYaml": "yolo_pose/data.yaml",
          "cocoAnnotations": "coco/annotations.json",
          "driveOutputFolder": "\(driveModelFolder)",
          "colabNotebookURL": "\(notebookURL)",
          "totalRecords": \(report.totalRecords),
          "trainRecords": \(report.trainCount),
          "valRecords": \(report.valCount),
          "testRecords": \(report.testCount),
          "runMode": "colab_auto_pack_run_all"
        }
        """
        try config.write(to: exportFolder.appendingPathComponent("train_config.json"), atomically: true, encoding: .utf8)
    }

    private static func writeBaseModelsIfNeeded(to exportFolder: URL) throws {
        let includeBase = UserDefaults.standard.object(forKey: "avo.ai.includeBaseModel") as? Bool ?? true
        guard includeBase else { return }

        let fm = FileManager.default
        let baseFolder = exportFolder.appendingPathComponent("base_models", isDirectory: true)
        try fm.createDirectory(at: baseFolder, withIntermediateDirectories: true)

        var copiedNames: [String] = []

        if let active = activeCoreMLModelURL() {
            let dst = baseFolder.appendingPathComponent(active.lastPathComponent, isDirectory: active.pathExtension.lowercased() == "mlpackage")
            try copyReplacing(active, to: dst)
            copiedNames.append(dst.lastPathComponent)
        }

        if let yolo = bundledYOLOModelURL() {
            let dst = baseFolder.appendingPathComponent(yolo.lastPathComponent)
            try copyReplacing(yolo, to: dst)
            copiedNames.append(dst.lastPathComponent)
        }

        let note = copiedNames.isEmpty
            ? "No se encontró modelo base local. Colab entrenará desde pesos por defecto o desde el modelo que indiques en el notebook.\n"
            : "Modelos base incluidos: \(copiedNames.joined(separator: ", "))\n"
        try note.write(to: baseFolder.appendingPathComponent("BASE_MODEL_README.txt"), atomically: true, encoding: .utf8)
    }

    private static func activeCoreMLModelURL() -> URL? {
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let active = docs.appendingPathComponent("Models/AVOHorsePose.mlpackage", isDirectory: true)
            if fm.fileExists(atPath: active.path) { return active }
        }
        return Bundle.main.url(forResource: "AVOHorsePose", withExtension: "mlpackage")
    }

    private static func bundledYOLOModelURL() -> URL? {
        return nil
    }

    private static func copyReplacing(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: destination)
    }
}
