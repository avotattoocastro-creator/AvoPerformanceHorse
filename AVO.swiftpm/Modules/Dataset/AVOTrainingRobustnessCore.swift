import Foundation

// MARK: - AVO V1.0 RC Robust Training Core
// This file is intentionally UI-free. It validates every training package before
// it is shared to Drive/Colab so the app can prove that the exported dataset is trainable.

public enum AVOTrainingGateStatus: String, Codable, Hashable {
    case pass = "PASS"
    case warning = "WARNING"
    case fail = "FAIL"
}

public struct AVOTrainingFolderCount: Codable, Hashable {
    public var train: Int
    public var val: Int
    public var test: Int
    public var total: Int { train + val + test }

    public init(train: Int = 0, val: Int = 0, test: Int = 0) {
        self.train = train
        self.val = val
        self.test = test
    }
}

public struct AVOTrainingPreflightReport: Codable, Hashable {
    public var createdAt: Date
    public var exportFolder: String
    public var status: AVOTrainingGateStatus
    public var images: AVOTrainingFolderCount
    public var labels: AVOTrainingFolderCount
    public var nonEmptyLabels: AVOTrainingFolderCount
    public var malformedLabels: [String]
    public var missingImagesForLabels: [String]
    public var missingLabelsForImages: [String]
    public var yamlFiles: [String]
    public var notes: [String]
    public var blockingErrors: [String]
    public var warnings: [String]

    public var isTrainable: Bool { status != .fail && blockingErrors.isEmpty && nonEmptyLabels.total > 0 }
}

public enum AVOTrainingRobustnessCore {

    public static func writePreflightReport(exportFolder: URL) throws -> AVOTrainingPreflightReport {
        let report = try validateColabPoseExport(exportFolder: exportFolder)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        try data.write(to: exportFolder.appendingPathComponent("AVO_TRAINING_PREFLIGHT.json"), options: .atomic)
        try makeHumanReport(report).write(to: exportFolder.appendingPathComponent("AVO_TRAINING_PREFLIGHT.txt"), atomically: true, encoding: .utf8)
        if !report.isTrainable {
            let message = report.blockingErrors.isEmpty ? "Dataset no entrenable: no hay labels pose válidos." : report.blockingErrors.joined(separator: " · ")
            throw NSError(domain: "AVOTrainingRobustnessCore", code: 901, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return report
    }

    public static func validateColabPoseExport(exportFolder: URL) throws -> AVOTrainingPreflightReport {
        let fm = FileManager.default
        let yoloPose = exportFolder.appendingPathComponent("yolo_pose", isDirectory: true)
        var blocking: [String] = []
        var warnings: [String] = []
        var notes: [String] = []

        if !fm.fileExists(atPath: yoloPose.path) {
            blocking.append("No existe carpeta yolo_pose dentro del export.")
        }

        let yamlFiles = ["horse_pose.yaml", "data.yaml"]
            .map { yoloPose.appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0.path) }
            .map { $0.lastPathComponent }

        if yamlFiles.isEmpty {
            blocking.append("No existe horse_pose.yaml/data.yaml.")
        }

        let images = AVOTrainingFolderCount(
            train: countFiles(yoloPose.appendingPathComponent("images/train"), extensions: imageExtensions),
            val: countFiles(yoloPose.appendingPathComponent("images/val"), extensions: imageExtensions),
            test: countFiles(yoloPose.appendingPathComponent("images/test"), extensions: imageExtensions)
        )
        let labels = AVOTrainingFolderCount(
            train: countFiles(yoloPose.appendingPathComponent("labels/train"), extensions: ["txt"]),
            val: countFiles(yoloPose.appendingPathComponent("labels/val"), extensions: ["txt"]),
            test: countFiles(yoloPose.appendingPathComponent("labels/test"), extensions: ["txt"])
        )
        let nonEmpty = AVOTrainingFolderCount(
            train: countNonEmptyLabels(yoloPose.appendingPathComponent("labels/train")),
            val: countNonEmptyLabels(yoloPose.appendingPathComponent("labels/val")),
            test: countNonEmptyLabels(yoloPose.appendingPathComponent("labels/test"))
        )

        if images.total == 0 { blocking.append("No hay imágenes en yolo_pose/images.") }
        if labels.total == 0 { blocking.append("No hay labels TXT en yolo_pose/labels.") }
        if nonEmpty.total == 0 { blocking.append("Todos los labels TXT están vacíos. No entrenes: YOLO marcará 'no labels found'.") }
        if nonEmpty.train == 0 { blocking.append("No hay labels pose no vacíos en train.") }
        if nonEmpty.val == 0 { warnings.append("No hay labels pose no vacíos en val. Con pocos datos se puede entrenar, pero la métrica no será fiable.") }
        if images.total != labels.total { warnings.append("El número de imágenes y labels no coincide. Images: \(images.total), Labels: \(labels.total).") }
        if images.total < 50 { warnings.append("Dataset pequeño: \(images.total) imágenes. Sirve para validar pipeline, no para calidad clínica.") }
        if nonEmpty.total < 30 { warnings.append("Pocas muestras pose reales: \(nonEmpty.total). Recomendado mínimo 300–500 para estabilidad inicial.") }

        let malformed = malformedLabelFiles(root: yoloPose.appendingPathComponent("labels"))
        if !malformed.isEmpty { blocking.append("Hay labels YOLO pose mal formados: \(malformed.count).") }

        let pairReport = pairConsistency(yoloPose: yoloPose)
        if !pairReport.missingImagesForLabels.isEmpty { warnings.append("Hay labels sin imagen correspondiente: \(pairReport.missingImagesForLabels.count).") }
        if !pairReport.missingLabelsForImages.isEmpty { warnings.append("Hay imágenes sin label correspondiente: \(pairReport.missingLabelsForImages.count).") }

        notes.append("Preflight generado dentro de la app antes de compartir a Drive/Colab.")
        notes.append("El paquete Colab debe contener solo caballo visible + puntos anatómicos reales, sin negativos vacíos en yolo_pose.")
        notes.append("Si status es PASS, el notebook incluido debería entrenar sin corregir YAML a mano.")

        let status: AVOTrainingGateStatus
        if !blocking.isEmpty { status = .fail }
        else if !warnings.isEmpty { status = .warning }
        else { status = .pass }

        return AVOTrainingPreflightReport(
            createdAt: Date(),
            exportFolder: exportFolder.lastPathComponent,
            status: status,
            images: images,
            labels: labels,
            nonEmptyLabels: nonEmpty,
            malformedLabels: malformed,
            missingImagesForLabels: pairReport.missingImagesForLabels,
            missingLabelsForImages: pairReport.missingLabelsForImages,
            yamlFiles: yamlFiles,
            notes: notes,
            blockingErrors: blocking,
            warnings: warnings
        )
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

    private static func countFiles(_ folder: URL, extensions: Set<String>) -> Int {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return 0 }
        return urls.filter { extensions.contains($0.pathExtension.lowercased()) }.count
    }

    private static func countNonEmptyLabels(_ folder: URL) -> Int {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return urls.filter { url in
            guard url.pathExtension.lowercased() == "txt" else { return false }
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    private static func malformedLabelFiles(root: URL) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var bad: [String] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "txt" {
            let text = ((try? String(contentsOf: url, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for line in lines {
                let parts = line.split { $0 == " " || $0 == "\t" }.map(String.init)
                if parts.count < 8 || (parts.count - 5) % 3 != 0 {
                    bad.append(url.lastPathComponent)
                    break
                }
                let invalidNumber = parts.contains { Double($0) == nil }
                if invalidNumber {
                    bad.append(url.lastPathComponent)
                    break
                }
            }
        }
        return Array(Set(bad)).sorted()
    }

    private static func pairConsistency(yoloPose: URL) -> (missingImagesForLabels: [String], missingLabelsForImages: [String]) {
        let fm = FileManager.default
        var missingImages: [String] = []
        var missingLabels: [String] = []
        for split in ["train", "val", "test"] {
            let imageFolder = yoloPose.appendingPathComponent("images/\(split)")
            let labelFolder = yoloPose.appendingPathComponent("labels/\(split)")
            let imageNames = Set(((try? fm.contentsOfDirectory(at: imageFolder, includingPropertiesForKeys: nil)) ?? [])
                .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
                .map { $0.deletingPathExtension().lastPathComponent })
            let labelNames = Set(((try? fm.contentsOfDirectory(at: labelFolder, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension.lowercased() == "txt" }
                .map { $0.deletingPathExtension().lastPathComponent })
            missingImages += labelNames.subtracting(imageNames).map { "\(split)/\($0)" }
            missingLabels += imageNames.subtracting(labelNames).map { "\(split)/\($0)" }
        }
        return (missingImages.sorted(), missingLabels.sorted())
    }

    private static func makeHumanReport(_ report: AVOTrainingPreflightReport) -> String {
        let blockers = report.blockingErrors.isEmpty ? "NONE" : report.blockingErrors.map { "- \($0)" }.joined(separator: "\n")
        let warns = report.warnings.isEmpty ? "NONE" : report.warnings.map { "- \($0)" }.joined(separator: "\n")
        return """
        AVO TRAINING PREFLIGHT
        STATUS: \(report.status.rawValue)
        EXPORT: \(report.exportFolder)

        IMAGES: train \(report.images.train) · val \(report.images.val) · test \(report.images.test) · total \(report.images.total)
        LABELS: train \(report.labels.train) · val \(report.labels.val) · test \(report.labels.test) · total \(report.labels.total)
        NON EMPTY LABELS: train \(report.nonEmptyLabels.train) · val \(report.nonEmptyLabels.val) · test \(report.nonEmptyLabels.test) · total \(report.nonEmptyLabels.total)
        YAML: \(report.yamlFiles.joined(separator: ", "))

        BLOCKING ERRORS:
        \(blockers)

        WARNINGS:
        \(warns)

        RESULT:
        \(report.isTrainable ? "TRAINABLE: puedes subir a Drive y ejecutar el notebook incluido." : "NO TRAINABLE: corrige dataset antes de entrenar.")
        """
    }
}
