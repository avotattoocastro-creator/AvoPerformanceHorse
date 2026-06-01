import Foundation
import UIKit

// MARK: - Phase 8: Dataset exporter for real horse training
// Converts manually reviewed stable annotations into formats used by real training pipelines.
// Detector: YOLO bbox.
// Pose: YOLOv8-pose style labels and COCO keypoints JSON.
// No synthetic points are generated here. Missing points are exported as visibility 0.

struct HorseDatasetExportReport: Codable, Hashable {
    let createdAt: TimeInterval
    let datasetName: String
    let sourcePath: String
    let exportPath: String
    let totalRecords: Int
    let detectorPositive: Int
    let detectorNegative: Int
    let poseRecords: Int
    let skippedNoImage: Int
    let trainCount: Int
    let valCount: Int
    let testCount: Int
    let notes: [String]
}

final class HorseDatasetExporter {
    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    func exportAll(from manager: HorseDatasetManager) throws -> HorseDatasetExportReport {
        try manager.prepareDataset(name: "AVOStableHorseDataset")
        let records = loadReviewedRecords(from: manager)
        let root = manager.activeDatasetURL.appendingPathComponent("exports", isDirectory: true)
        let stamp = Self.timestampFolderName()
        let exportURL = root.appendingPathComponent("export_\(stamp)", isDirectory: true)

        let yoloDetectorURL = exportURL.appendingPathComponent("yolo_detector", isDirectory: true)
        let yoloPoseURL = exportURL.appendingPathComponent("yolo_pose", isDirectory: true)
        let cocoURL = exportURL.appendingPathComponent("coco", isDirectory: true)

        try prepareYOLOFolders(yoloDetectorURL)
        try prepareYOLOFolders(yoloPoseURL)
        try fm.createDirectory(at: cocoURL, withIntermediateDirectories: true)

        var skippedNoImage = 0
        var detectorPositive = 0
        var detectorNegative = 0
        var poseRecords = 0
        var splitCounts: [String: Int] = ["train": 0, "val": 0, "test": 0]
        var cocoImages: [[String: Any]] = []
        var cocoAnnotations: [[String: Any]] = []
        var annotationId = 1
        var imageId = 1

        for (index, record) in records.enumerated() {
            let split = normalizedSplit(record.split, fallbackIndex: index)
            splitCounts[split, default: 0] += 1

            let sourceImage = manager.imagesURL.appendingPathComponent(record.imageFile)
            guard fm.fileExists(atPath: sourceImage.path), let imageInfo = imageInfo(url: sourceImage) else {
                skippedNoImage += 1
                continue
            }

            let detImageURL = yoloDetectorURL.appendingPathComponent("images/\(split)/\(record.imageFile)")
            let poseImageURL = yoloPoseURL.appendingPathComponent("images/\(split)/\(record.imageFile)")
            try copyReplacing(sourceImage, to: detImageURL)
            try copyReplacing(sourceImage, to: poseImageURL)

            let detLabelFile = record.imageFile.replacingExtension(with: "txt")
            let detLabelURL = yoloDetectorURL.appendingPathComponent("labels/\(split)/\(detLabelFile)")
            let poseLabelURL = yoloPoseURL.appendingPathComponent("labels/\(split)/\(detLabelFile)")

            if record.horseVisible, let box = record.horseBox {
                detectorPositive += 1
                let yoloBox = yoloBBox(box: box, width: imageInfo.width, height: imageInfo.height)
                try "0 \(yoloBox)\n".write(to: detLabelURL, atomically: true, encoding: .utf8)

                if !record.keypoints.isEmpty {
                    poseRecords += 1
                    let poseLine = makeYOLOPoseLine(record: record, imageWidth: imageInfo.width, imageHeight: imageInfo.height)
                    try poseLine.write(to: poseLabelURL, atomically: true, encoding: .utf8)
                } else {
                    try "".write(to: poseLabelURL, atomically: true, encoding: .utf8)
                }

                cocoImages.append([
                    "id": imageId,
                    "file_name": record.imageFile,
                    "width": imageInfo.width,
                    "height": imageInfo.height
                ])
                cocoAnnotations.append(makeCOCOAnnotation(record: record, annotationId: annotationId, imageId: imageId, width: imageInfo.width, height: imageInfo.height))
                annotationId += 1
                imageId += 1
            } else {
                detectorNegative += 1
                try "".write(to: detLabelURL, atomically: true, encoding: .utf8)
                try "".write(to: poseLabelURL, atomically: true, encoding: .utf8)
            }
        }

        try writeDetectorYaml(to: yoloDetectorURL)
        try writePoseYaml(to: yoloPoseURL)
        try writeCOCO(images: cocoImages, annotations: cocoAnnotations, to: cocoURL)
        try writeTrainingNotes(to: exportURL)

        let report = HorseDatasetExportReport(
            createdAt: Date().timeIntervalSince1970,
            datasetName: manager.datasetName,
            sourcePath: manager.activeDatasetURL.path,
            exportPath: exportURL.path,
            totalRecords: records.count,
            detectorPositive: detectorPositive,
            detectorNegative: detectorNegative,
            poseRecords: poseRecords,
            skippedNoImage: skippedNoImage,
            trainCount: splitCounts["train", default: 0],
            valCount: splitCounts["val", default: 0],
            testCount: splitCounts["test", default: 0],
            notes: [
                "YOLO detector labels: class cx cy w h normalized.",
                "YOLO pose labels: class cx cy w h + \(HorseJoint.allCases.count) keypoints x y visibility.",
                "COCO keypoints visibility: 0 missing, 2 labelled/visible.",
                "No synthetic anatomy exported. Review labels before training."
            ]
        )

        let reportData = try encoder.encode(report)
        try reportData.write(to: exportURL.appendingPathComponent("export_report.json"), options: .atomic)
        return report
    }



    // MARK: - V4.2.4: Colab Auto Pack Pose Only
    // Exports only real positive horse-pose samples. This avoids YOLO Pose training on
    // empty negative TXT files and prevents "no labels found in pose set" warnings.
    func exportPoseColabPack(from manager: HorseDatasetManager) throws -> HorseDatasetExportReport {
        try manager.prepareDataset(name: "AVOStableHorseDataset")
        let allRecords = loadReviewedRecords(from: manager)
        let validPoseRecords = allRecords.filter { record in
            guard record.horseVisible, record.horseBox != nil else { return false }
            return record.keypoints.contains { !$0.isPredicted && $0.confidence > 0.01 }
        }

        guard !validPoseRecords.isEmpty else {
            throw NSError(domain: "HorseDatasetExporter", code: 424, userInfo: [NSLocalizedDescriptionKey: "No hay imágenes positivas con puntos anatómicos reales. Filtra GOOD/HORSE y marca puntos antes de exportar Colab."])
        }

        let root = manager.activeDatasetURL.appendingPathComponent("exports", isDirectory: true)
        let stamp = Self.timestampFolderName()
        let exportURL = root.appendingPathComponent("colab_auto_\(stamp)", isDirectory: true)
        let yoloDetectorURL = exportURL.appendingPathComponent("yolo_detector", isDirectory: true)
        let yoloPoseURL = exportURL.appendingPathComponent("yolo_pose", isDirectory: true)
        let cocoURL = exportURL.appendingPathComponent("coco", isDirectory: true)

        try prepareYOLOFolders(yoloDetectorURL)
        try prepareYOLOFolders(yoloPoseURL)
        try fm.createDirectory(at: cocoURL, withIntermediateDirectories: true)

        var skippedNoImage = 0
        var splitCounts: [String: Int] = ["train": 0, "val": 0, "test": 0]
        var cocoImages: [[String: Any]] = []
        var cocoAnnotations: [[String: Any]] = []
        var annotationId = 1
        var imageId = 1

        for (index, record) in validPoseRecords.enumerated() {
            let split = autoPoseSplit(index: index, total: validPoseRecords.count)
            splitCounts[split, default: 0] += 1

            let sourceImage = manager.imagesURL.appendingPathComponent(record.imageFile)
            guard fm.fileExists(atPath: sourceImage.path), let imageInfo = imageInfo(url: sourceImage), let box = record.horseBox else {
                skippedNoImage += 1
                continue
            }

            let detImageURL = yoloDetectorURL.appendingPathComponent("images/\(split)/\(record.imageFile)")
            let poseImageURL = yoloPoseURL.appendingPathComponent("images/\(split)/\(record.imageFile)")
            try copyReplacing(sourceImage, to: detImageURL)
            try copyReplacing(sourceImage, to: poseImageURL)

            let labelFile = record.imageFile.replacingExtension(with: "txt")
            let detLabelURL = yoloDetectorURL.appendingPathComponent("labels/\(split)/\(labelFile)")
            let poseLabelURL = yoloPoseURL.appendingPathComponent("labels/\(split)/\(labelFile)")

            let yoloBox = yoloBBox(box: box, width: imageInfo.width, height: imageInfo.height)
            try "0 \(yoloBox)\n".write(to: detLabelURL, atomically: true, encoding: .utf8)
            try makeYOLOPoseLine(record: record, imageWidth: imageInfo.width, imageHeight: imageInfo.height).write(to: poseLabelURL, atomically: true, encoding: .utf8)

            cocoImages.append([
                "id": imageId,
                "file_name": record.imageFile,
                "width": imageInfo.width,
                "height": imageInfo.height
            ])
            cocoAnnotations.append(makeCOCOAnnotation(record: record, annotationId: annotationId, imageId: imageId, width: imageInfo.width, height: imageInfo.height))
            annotationId += 1
            imageId += 1
        }

        try writeDetectorYaml(to: yoloDetectorURL)
        try writePoseYaml(to: yoloPoseURL)
        try writeCOCO(images: cocoImages, annotations: cocoAnnotations, to: cocoURL)
        try writeTrainingNotes(to: exportURL)

        let report = HorseDatasetExportReport(
            createdAt: Date().timeIntervalSince1970,
            datasetName: manager.datasetName,
            sourcePath: manager.activeDatasetURL.path,
            exportPath: exportURL.path,
            totalRecords: validPoseRecords.count,
            detectorPositive: validPoseRecords.count,
            detectorNegative: 0,
            poseRecords: validPoseRecords.count,
            skippedNoImage: skippedNoImage,
            trainCount: splitCounts["train", default: 0],
            valCount: splitCounts["val", default: 0],
            testCount: splitCounts["test", default: 0],
            notes: [
                "COLAB AUTO PACK: solo positivos con caballo visible y keypoints reales.",
                "No se incluyen negativos en yolo_pose para evitar entrenamientos vacíos.",
                "YAML preparado para Colab con path relativo al directorio yolo_pose."
            ]
        )

        let reportData = try encoder.encode(report)
        try reportData.write(to: exportURL.appendingPathComponent("export_report.json"), options: .atomic)
        return report
    }

    private func autoPoseSplit(index: Int, total: Int) -> String {
        if total < 5 { return index == total - 1 ? "val" : "train" }
        let r = Double(index) / Double(max(total, 1))
        if r < 0.80 { return "train" }
        if r < 0.95 { return "val" }
        return "test"
    }

    private func loadReviewedRecords(from manager: HorseDatasetManager) -> [HorseDatasetFrameRecord] {
        let urls = (try? fm.contentsOfDirectory(at: manager.annotationsURL, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        let records = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> HorseDatasetFrameRecord? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(HorseDatasetFrameRecord.self, from: data)
            }
        return records.sorted { $0.createdAt < $1.createdAt }
    }

    private func prepareYOLOFolders(_ root: URL) throws {
        for sub in [
            "images/train", "images/val", "images/test",
            "labels/train", "labels/val", "labels/test"
        ] {
            try fm.createDirectory(at: root.appendingPathComponent(sub, isDirectory: true), withIntermediateDirectories: true)
        }
    }

    private func copyReplacing(_ source: URL, to destination: URL) throws {
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: source, to: destination)
    }

    private func normalizedSplit(_ split: String, fallbackIndex: Int) -> String {
        let clean = split.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean == "train" || clean == "val" || clean == "test" { return clean }
        let r = fallbackIndex % 10
        if r < 7 { return "train" }
        if r < 9 { return "val" }
        return "test"
    }

    private func imageInfo(url: URL) -> (width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data), let cg = image.cgImage else { return nil }
        return (cg.width, cg.height)
    }

    private func yoloBBox(box: HorseDetection, width: Int, height: Int) -> String {
        // FIX FASE 20:
        // En el anotador iPad las cajas suelen venir ya normalizadas 0...1.
        // Antes se dividían otra vez por width/height y salían valores 0.0005.
        let iw = max(Double(width), 1)
        let ih = max(Double(height), 1)

        let x = normalizedValue(box.boxX, dimension: iw)
        let y = normalizedValue(box.boxY, dimension: ih)
        let w = normalizedSize(box.boxW, dimension: iw)
        let h = normalizedSize(box.boxH, dimension: ih)

        let cx = clamp01(x + w * 0.5)
        let cy = clamp01(y + h * 0.5)

        return String(format: "%.6f %.6f %.6f %.6f", cx, cy, w, h)
    }

    private func makeYOLOPoseLine(record: HorseDatasetFrameRecord, imageWidth: Int, imageHeight: Int) -> String {
        let bbox = yoloBBox(box: record.horseBox!, width: imageWidth, height: imageHeight)
        let byJoint = Dictionary(uniqueKeysWithValues: record.keypoints.map { ($0.joint, $0) })
        let iw = max(Double(imageWidth), 1)
        let ih = max(Double(imageHeight), 1)

        let kp = HorseJoint.allCases.map { joint -> String in
            guard let p = byJoint[joint], p.confidence > 0.01, !p.isPredicted else {
                return "0.000000 0.000000 0"
            }

            // FIX FASE 20:
            // Si p.x/p.y ya están en 0...1, se exportan tal cual.
            // Si por una importación vieja vinieran en píxeles, se normalizan una sola vez.
            let x = normalizedValue(p.x, dimension: iw)
            let y = normalizedValue(p.y, dimension: ih)

            return String(format: "%.6f %.6f 2", x, y)
        }.joined(separator: " ")
        return "0 \(bbox) \(kp)\n"
    }

    private func makeCOCOAnnotation(record: HorseDatasetFrameRecord, annotationId: Int, imageId: Int, width: Int, height: Int) -> [String: Any] {
        let box = record.horseBox!
        let byJoint = Dictionary(uniqueKeysWithValues: record.keypoints.map { ($0.joint, $0) })
        let iw = max(Double(width), 1)
        let ih = max(Double(height), 1)

        var keypoints: [Any] = []
        var numKeypoints = 0
        for joint in HorseJoint.allCases {
            if let p = byJoint[joint], p.confidence > 0.01, !p.isPredicted {
                let px = pixelValue(p.x, dimension: iw)
                let py = pixelValue(p.y, dimension: ih)
                keypoints.append(Int(round(px)))
                keypoints.append(Int(round(py)))
                keypoints.append(2)
                numKeypoints += 1
            } else {
                keypoints.append(0)
                keypoints.append(0)
                keypoints.append(0)
            }
        }

        let bx = pixelValue(box.boxX, dimension: iw)
        let by = pixelValue(box.boxY, dimension: ih)
        let bw = pixelSize(box.boxW, dimension: iw)
        let bh = pixelSize(box.boxH, dimension: ih)

        return [
            "id": annotationId,
            "image_id": imageId,
            "category_id": 1,
            "bbox": [bx, by, bw, bh],
            "area": max(bw * bh, 1),
            "iscrowd": 0,
            "num_keypoints": numKeypoints,
            "keypoints": keypoints
        ]
    }

    private func writeDetectorYaml(to root: URL) throws {
        let text = """
        path: .
        train: images/train
        val: images/val
        test: images/test
        names:
          0: horse
        
        """
        try text.write(to: root.appendingPathComponent("horse_detector.yaml"), atomically: true, encoding: .utf8)
        try text.write(to: root.appendingPathComponent("data.yaml"), atomically: true, encoding: .utf8)
    }

    private func writePoseYaml(to root: URL) throws {
        let names = HorseJoint.allCases.map { "  - \($0.rawValue)" }.joined(separator: "\n")
        let skeleton = HorseJoint.skeletonEdges.map { edge -> String in
            let a = (HorseJoint.allCases.firstIndex(of: edge.from) ?? 0) + 1
            let b = (HorseJoint.allCases.firstIndex(of: edge.to) ?? 0) + 1
            return "  - [\(a), \(b)]"
        }.joined(separator: "\n")
        let text = """
        path: .
        train: images/train
        val: images/val
        test: images/test
        names:
          0: horse
        kpt_shape: [\(HorseJoint.allCases.count), 3]
        keypoints:
        \(names)
        skeleton:
        \(skeleton)
        
        """
        try text.write(to: root.appendingPathComponent("horse_pose.yaml"), atomically: true, encoding: .utf8)
        try text.write(to: root.appendingPathComponent("data.yaml"), atomically: true, encoding: .utf8)
    }

    private func writeCOCO(images: [[String: Any]], annotations: [[String: Any]], to root: URL) throws {
        let keypoints = HorseJoint.allCases.map { $0.rawValue }
        let skeleton = HorseJoint.skeletonEdges.map { edge -> [Int] in
            let a = (HorseJoint.allCases.firstIndex(of: edge.from) ?? 0) + 1
            let b = (HorseJoint.allCases.firstIndex(of: edge.to) ?? 0) + 1
            return [a, b]
        }
        let json: [String: Any] = [
            "info": ["description": "AVO real horse anatomy dataset", "version": "1.0"],
            "images": images,
            "annotations": annotations,
            "categories": [[
                "id": 1,
                "name": "horse",
                "supercategory": "animal",
                "keypoints": keypoints,
                "skeleton": skeleton
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("horse_coco_keypoints.json"), options: .atomic)
    }

    private func writeTrainingNotes(to root: URL) throws {
        let text = """
        AVO HORSE DATASET EXPORT - FASE 8

        Carpetas generadas:
        - yolo_detector: entrenamiento de caja del caballo.
        - yolo_pose: entrenamiento de puntos anatómicos reales.
        - coco/horse_coco_keypoints.json: formato COCO keypoints.

        Regla crítica:
        - Los puntos predichos por tracking temporal NO se exportan como verdad si estaban marcados como isPredicted.
        - Si falta un punto, queda como visibilidad 0.
        - Los negativos generan TXT vacío para YOLO detector.

        Siguiente fase:
        - Entrenar modelo fuera del iPad con YOLOv8/YOLO11 o pipeline equivalente.
        - Exportar a CoreML.
        - Meter HorseDetector.mlmodelc y HorsePose.mlmodelc en el proyecto Swift.
        """
        try text.write(to: root.appendingPathComponent("README_EXPORT.txt"), atomically: true, encoding: .utf8)
    }

    private func normalizedValue(_ value: Double, dimension: Double) -> Double {
        if value.isNaN || value.isInfinite { return 0.0 }
        if value >= 0.0 && value <= 1.0 {
            return clamp01(value)
        }
        return clamp01(value / max(dimension, 1.0))
    }

    private func normalizedSize(_ value: Double, dimension: Double) -> Double {
        if value.isNaN || value.isInfinite { return 0.0 }
        if value >= 0.0 && value <= 1.0 {
            return clamp01(value)
        }
        return clamp01(value / max(dimension, 1.0))
    }

    private func pixelValue(_ value: Double, dimension: Double) -> Double {
        if value.isNaN || value.isInfinite { return 0.0 }
        if value >= 0.0 && value <= 1.0 {
            return clampPixel(value * dimension, dimension: dimension)
        }
        return clampPixel(value, dimension: dimension)
    }

    private func pixelSize(_ value: Double, dimension: Double) -> Double {
        if value.isNaN || value.isInfinite { return 0.0 }
        if value >= 0.0 && value <= 1.0 {
            return max(0.0, min(value * dimension, dimension))
        }
        return max(0.0, min(value, dimension))
    }

    private func clampPixel(_ value: Double, dimension: Double) -> Double {
        min(max(dimension, 1.0), max(0.0, value))
    }

    private func clamp01(_ v: Double) -> Double {
        min(1.0, max(0.0, v))
    }

    static func timestampFolderName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

private extension String {
    func replacingExtension(with newExtension: String) -> String {
        let url = URL(fileURLWithPath: self)
        return url.deletingPathExtension().lastPathComponent + "." + newExtension
    }
}
