import Foundation
import AVFoundation
import UIKit
import ImageIO
import UniformTypeIdentifiers
import CoreLocation

// MARK: - Phase 6: Real stable dataset capture
// Saves real iPad camera frames + current detector/pose annotations.
// This is the bridge for future training of HorseDetector.mlmodelc and HorsePose.mlmodelc.
// It does not create synthetic anatomy or fake labels.

struct HorseDatasetAnnotation: Codable, Hashable {
    let joint: HorseJoint
    let x: Double
    let y: Double
    let confidence: Double
    let isPredicted: Bool
}

struct HorseDatasetFrameRecord: Codable, Hashable, Identifiable {
    var id: String { frameId }
    let frameId: String
    let createdAt: TimeInterval
    let imageFile: String
    let label: String
    let split: String
    let horseVisible: Bool
    let horseBox: HorseDetection?
    let keypoints: [HorseDatasetAnnotation]
    let trackingQuality: Double
    let gait: String
    let lameness: String
    let latitude: Double?
    let longitude: Double?
    let notes: String
}

struct HorseDatasetManifest: Codable {
    let name: String
    let createdAt: TimeInterval
    let version: Int
    let totalFrames: Int
    let positiveFrames: Int
    let negativeFrames: Int
    let anatomicalFrames: Int
    let records: [HorseDatasetFrameRecord]
}

final class HorseDatasetManager {
    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private(set) var datasetName: String = "AVOStableHorseDataset"
    private(set) var records: [HorseDatasetFrameRecord] = []

    var rootURL: URL {
        // MASTER SESSION CORE: training/review frames belong to the active horse session.
        if let reviewFolder = try? AVOMasterSessionCore.shared.folder(for: .review) {
            return reviewFolder.appendingPathComponent("Datasets", isDirectory: true)
        }
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("AVOHorseDatasets", isDirectory: true)
    }

    var activeDatasetURL: URL {
        rootURL.appendingPathComponent(datasetName, isDirectory: true)
    }

    var imagesURL: URL {
        activeDatasetURL.appendingPathComponent("images", isDirectory: true)
    }

    var annotationsURL: URL {
        activeDatasetURL.appendingPathComponent("annotations", isDirectory: true)
    }

    var manifestURL: URL {
        activeDatasetURL.appendingPathComponent("manifest.json")
    }

    func prepareDataset(name: String? = nil) throws {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            datasetName = sanitize(name)
        }
        try fm.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: annotationsURL, withIntermediateDirectories: true)
        loadExistingManifestIfAvailable()
    }


    func importImageFolder(
        _ sourceImagesURL: URL,
        sourceManifestURL: URL? = nil,
        resetExisting: Bool = true
    ) throws -> Int {
        if resetExisting, fm.fileExists(atPath: activeDatasetURL.path) {
            try? fm.removeItem(at: activeDatasetURL)
        }

        try prepareDataset(name: "AVOStableHorseDataset")

        var sourceRecordsByImage: [String: HorseDatasetFrameRecord] = [:]
        var sourceRecordsById: [String: HorseDatasetFrameRecord] = [:]

        if let sourceManifestURL,
           let data = try? Data(contentsOf: sourceManifestURL),
           let manifest = try? JSONDecoder().decode(HorseDatasetManifest.self, from: data) {
            for r in manifest.records {
                sourceRecordsByImage[r.imageFile] = r
                sourceRecordsById[r.frameId] = r
            }
        }

        let allowed = Set(["jpg", "jpeg", "png", "heic", "heif"])
        let imageFiles = recursiveFiles(in: sourceImagesURL)
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var imported = 0
        for src in imageFiles {
            let ext = src.pathExtension.isEmpty ? "jpg" : src.pathExtension.lowercased()
            let originalName = src.lastPathComponent
            let baseId = src.deletingPathExtension().lastPathComponent
            let frameId = sanitize(baseId)
            let finalImageFile = uniqueFileName(preferred: "\(frameId).\(ext)", in: imagesURL)
            let dstImg = imagesURL.appendingPathComponent(finalImageFile)

            try fm.copyItem(at: src, to: dstImg)

            let old = sourceRecordsByImage[originalName] ?? sourceRecordsByImage[finalImageFile] ?? sourceRecordsById[baseId] ?? sourceRecordsById[frameId]
            let importedLabel: String
            let importedHorseVisible: Bool
            let importedKeypoints: [HorseDatasetAnnotation]
            let importedBox: HorseDetection?
            let importedNotes: String

            if let old, !old.keypoints.isEmpty {
                importedLabel = old.label
                importedHorseVisible = old.horseVisible
                importedKeypoints = old.keypoints
                importedBox = old.horseBox
                importedNotes = old.notes + " | imported_with_points"
            } else {
                // For selected folders of horse photos, never force them to NEGATIVE.
                // Put them in REVIEW so the user can mark GOOD/NEGATIVE/REJECT manually.
                importedLabel = "review_pending_imported"
                importedHorseVisible = true
                importedKeypoints = []
                importedBox = old?.horseBox
                importedNotes = "imported_external_folder_review_needed"
            }

            let record = HorseDatasetFrameRecord(
                frameId: frameId,
                createdAt: old?.createdAt ?? Date().timeIntervalSince1970,
                imageFile: finalImageFile,
                label: importedLabel,
                split: old?.split ?? "unassigned",
                horseVisible: importedHorseVisible,
                horseBox: importedBox,
                keypoints: importedKeypoints,
                trackingQuality: old?.trackingQuality ?? 0,
                gait: old?.gait ?? "WAIT",
                lameness: old?.lameness ?? "NO ANALYSIS",
                latitude: old?.latitude,
                longitude: old?.longitude,
                notes: importedNotes
            )

            let annotationURL = annotationsURL.appendingPathComponent("\(frameId).json")
            let data = try encoder.encode(record)
            try data.write(to: annotationURL, options: [.atomic])
            records.append(record)
            imported += 1
        }

        try writeManifest()
        return imported
    }

    private func recursiveFiles(in url: URL) -> [URL] {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { !$0.hasDirectoryPath }
    }

    private func uniqueFileName(preferred: String, in folder: URL) -> String {
        let baseURL = URL(fileURLWithPath: preferred)
        let stem = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension
        var candidate = preferred
        var index = 1
        while fm.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = ext.isEmpty ? "\(stem)_\(index)" : "\(stem)_\(index).\(ext)"
            index += 1
        }
        return candidate
    }


    func saveFrame(
        sampleBuffer: CMSampleBuffer,
        label: String,
        horseVisible: Bool,
        horseBox: CGRect?,
        horseConfidence: Double?,
        joints: [TrackedHorseJoint],
        trackingQuality: Double,
        gait: String,
        lameness: String,
        coordinate: CLLocationCoordinate2D?,
        notes: String = ""
    ) throws -> HorseDatasetFrameRecord {
        try prepareDataset()

        guard let imageData = jpegData(from: sampleBuffer, quality: 0.90) else {
            throw DatasetError.imageConversionFailed
        }

        let now = Date().timeIntervalSince1970
        let frameId = makeFrameId(label: label, timestamp: now)
        let imageFile = "\(frameId).jpg"
        let annotationFile = "\(frameId).json"

        try imageData.write(to: imagesURL.appendingPathComponent(imageFile), options: [.atomic])

        let detection: HorseDetection?
        if let box = horseBox, horseVisible {
            detection = HorseDetection(
                boxX: Double(box.minX),
                boxY: Double(box.minY),
                boxW: Double(box.width),
                boxH: Double(box.height),
                confidence: horseConfidence ?? 0,
                source: "iPadCamera+CoreML+Vision"
            )
        } else {
            detection = nil
        }

        let keypoints = joints.map {
            HorseDatasetAnnotation(
                joint: $0.joint,
                x: $0.x,
                y: $0.y,
                confidence: $0.confidence,
                isPredicted: $0.isPredicted
            )
        }

        let record = HorseDatasetFrameRecord(
            frameId: frameId,
            createdAt: now,
            imageFile: imageFile,
            label: label,
            split: "unassigned",
            horseVisible: horseVisible,
            horseBox: detection,
            keypoints: keypoints,
            trackingQuality: trackingQuality,
            gait: gait,
            lameness: lameness,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            notes: notes
        )

        let annotationData = try encoder.encode(record)
        try annotationData.write(to: annotationsURL.appendingPathComponent(annotationFile), options: [.atomic])

        records.append(record)
        try writeManifest()
        return record
    }

    func writeManifest() throws {
        try fm.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: annotationsURL, withIntermediateDirectories: true)
        let manifest = HorseDatasetManifest(
            name: datasetName,
            createdAt: Date().timeIntervalSince1970,
            version: 1,
            totalFrames: records.count,
            positiveFrames: records.filter { $0.horseVisible }.count,
            negativeFrames: records.filter { !$0.horseVisible }.count,
            anatomicalFrames: records.filter { !$0.keypoints.isEmpty }.count,
            records: records
        )
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: [.atomic])
    }

    func exportTrainingReadme() throws {
        try prepareDataset()
        let text = """
        AVO HORSE DATASET - FASE 6

        Objetivo:
        - Entrenar HorseDetector.mlmodelc para detectar caballo real.
        - Entrenar HorsePose.mlmodelc para puntos anatómicos reales.

        Estructura:
        - images/*.jpg: frames reales de la cámara del iPad.
        - annotations/*.json: bounding box + keypoints detectados o revisados.
        - manifest.json: índice global.

        Reglas:
        - No usar puntos sintéticos como verdad de entrenamiento.
        - Revisar manualmente las anotaciones antes de entrenar.
        - Marcar negativos: personas, boxes, paredes, sillas, perros, tractores, etc.
        - Capturar caballo lateral, frontal, trasero, paso, trote y galope.
        - Separar train/val/test antes de entrenar.

        Conversión futura recomendada:
        - Para detector: exportar bounding boxes a YOLO format.
        - Para pose: exportar keypoints a YOLOv8-pose / COCO-keypoints.
        - Después convertir a CoreML e incluir HorseDetector.mlmodelc y HorsePose.mlmodelc en la app.
        """
        try text.write(to: activeDatasetURL.appendingPathComponent("README_DATASET.txt"), atomically: true, encoding: String.Encoding.utf8)
    }

    private func loadExistingManifestIfAvailable() {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(HorseDatasetManifest.self, from: data) else {
            records = []
            return
        }
        records = manifest.records
    }

    private func jpegData(from sampleBuffer: CMSampleBuffer, quality: CGFloat) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        // Normaliza DATASET al mismo formato visual de la app en iPad horizontal.
        // Antes se forzaba .left y las imágenes quedaban giradas en Files/Review.
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let screen = UIScreen.main.bounds
        let screenIsLandscape = screen.width > screen.height
        let bufferIsPortrait = ciImage.extent.height > ciImage.extent.width
        if screenIsLandscape && bufferIsPortrait {
            ciImage = ciImage.oriented(.right)
        }

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func makeFrameId(label: String, timestamp: TimeInterval) -> String {
        let cleanLabel = sanitize(label.lowercased())
        let ms = Int(timestamp * 1000)
        return "\(cleanLabel)_\(ms)_\(UUID().uuidString.prefix(8))"
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.reduce("") { $0 + String($1) }
    }

    enum DatasetError: Error {
        case imageConversionFailed
    }
}
