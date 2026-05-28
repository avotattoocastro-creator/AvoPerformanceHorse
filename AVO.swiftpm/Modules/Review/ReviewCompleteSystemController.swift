import Foundation
import SwiftUI
import UIKit
import AVFoundation

// MARK: - REVIEW PHASE 123
// REVIEW COMPLETE SYSTEM
//
// One complete REVIEW system:
// - MP4/video session import
// - timeline/cache/thumbnails
// - AutoPose temporal track
// - manual correction learning
// - dataset QA
// - CoreML/Colab export package
// - storage into AVOStorageEngine

public enum ReviewCompleteSystemMode: String, Codable, CaseIterable {
    case idle
    case imageReview
    case videoReview
    case temporalAutoPose
    case correctionLearning
    case datasetQA
    case exportReady
}

public struct ReviewCompleteFrameRecord: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var imageFileName: String?
    public var thumbnailFileName: String?
    public var hasManualCorrection: Bool
    public var hasAutoPose: Bool
    public var qualityScore: Double
    public var notes: [String]

    public init(frameIndex: Int,
                timeSeconds: Double,
                imageFileName: String? = nil,
                thumbnailFileName: String? = nil,
                hasManualCorrection: Bool = false,
                hasAutoPose: Bool = false,
                qualityScore: Double = 0,
                notes: [String] = []) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.hasManualCorrection = hasManualCorrection
        self.hasAutoPose = hasAutoPose
        self.qualityScore = qualityScore
        self.notes = notes
    }
}

public struct ReviewCompleteDatasetManifest: Codable, Hashable {
    public var project: String
    public var phase: String
    public var horseName: String
    public var sessionId: String
    public var createdAt: Date
    public var mode: ReviewCompleteSystemMode
    public var totalFrames: Int
    public var correctedFrames: Int
    public var autoposeFrames: Int
    public var averageQuality: Double
    public var frames: [ReviewCompleteFrameRecord]
    public var correctionSamples: Int
    public var exportReady: Bool

    public init(horseName: String,
                sessionId: String,
                mode: ReviewCompleteSystemMode,
                frames: [ReviewCompleteFrameRecord],
                correctionSamples: Int) {
        self.project = "AVO REVIEW COMPLETE SYSTEM"
        self.phase = "123"
        self.horseName = horseName
        self.sessionId = sessionId
        self.createdAt = Date()
        self.mode = mode
        self.totalFrames = frames.count
        self.correctedFrames = frames.filter(\.hasManualCorrection).count
        self.autoposeFrames = frames.filter(\.hasAutoPose).count
        self.averageQuality = frames.isEmpty ? 0 : frames.map(\.qualityScore).reduce(0, +) / Double(frames.count)
        self.frames = frames
        self.correctionSamples = correctionSamples
        self.exportReady = !frames.isEmpty && correctedFrames > 0
    }
}

@MainActor
public final class ReviewCompleteSystemController: ObservableObject {

    public static let shared = ReviewCompleteSystemController()

    @Published public private(set) var mode: ReviewCompleteSystemMode = .idle
    @Published public private(set) var status: String = "REVIEW COMPLETE READY"
    @Published public private(set) var horseName: String = "SIN_CABALLO"
    @Published public private(set) var videoName: String = ""
    @Published public private(set) var frameRecords: [ReviewCompleteFrameRecord] = []
    @Published public private(set) var currentFrameIndex: Int = 0
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var lastManifest: ReviewCompleteDatasetManifest?

    public let correctionLearning = ReviewAutoCorrectionLearningEngine()
    public let storage = AVOStorageEngine.shared

    private init() {}

    public func startReviewSession(horseName: String, mode: ReviewCompleteSystemMode = .imageReview) {
        self.horseName = clean(horseName.isEmpty ? "SIN_CABALLO" : horseName)
        self.mode = mode

        do {
            _ = try storage.ensureSession(horseName: self.horseName)
            status = "REVIEW SESSION READY · \(self.horseName)"
        } catch {
            status = "REVIEW STORAGE ERROR: \(error.localizedDescription)"
        }
    }

    public func importVideoSession(url: URL, estimatedFPS: Double = 30) {
        videoName = url.lastPathComponent
        mode = .videoReview

        let asset = AVAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        let safeDuration = duration.isFinite && duration > 0 ? duration : 0
        let total = max(1, Int((safeDuration * estimatedFPS).rounded(.down)))

        frameRecords = (0..<total).map {
            ReviewCompleteFrameRecord(
                frameIndex: $0,
                timeSeconds: Double($0) / max(1, estimatedFPS),
                hasManualCorrection: false,
                hasAutoPose: false,
                qualityScore: 0,
                notes: ["video-import"]
            )
        }

        status = "VIDEO IMPORTED · \(total) FRAMES"
    }

    public func registerFrame(frameIndex: Int,
                              timeSeconds: Double,
                              image: UIImage? = nil,
                              thumbnail: UIImage? = nil,
                              hasAutoPose: Bool = false,
                              hasManualCorrection: Bool = false,
                              qualityScore: Double = 0,
                              notes: [String] = []) {
        var imageFile: String?
        var thumbFile: String?

        do {
            if let image {
                let url = try storage.saveImage(
                    image,
                    area: .reviewFrames,
                    horseName: horseName,
                    prefix: "review_frame_\(frameIndex)"
                )
                imageFile = url.lastPathComponent
            }

            if let thumbnail {
                let url = try storage.saveImage(
                    thumbnail,
                    area: .thumbnails,
                    horseName: horseName,
                    prefix: "thumb_\(frameIndex)",
                    compression: 0.72
                )
                thumbFile = url.lastPathComponent
            }
        } catch {
            status = "FRAME SAVE ERROR: \(error.localizedDescription)"
        }

        let record = ReviewCompleteFrameRecord(
            frameIndex: frameIndex,
            timeSeconds: timeSeconds,
            imageFileName: imageFile,
            thumbnailFileName: thumbFile,
            hasManualCorrection: hasManualCorrection,
            hasAutoPose: hasAutoPose,
            qualityScore: qualityScore,
            notes: notes
        )

        if let idx = frameRecords.firstIndex(where: { $0.frameIndex == frameIndex }) {
            frameRecords[idx] = merge(old: frameRecords[idx], new: record)
        } else {
            frameRecords.append(record)
            frameRecords.sort { $0.frameIndex < $1.frameIndex }
        }

        currentFrameIndex = frameIndex
        status = "FRAME \(frameIndex) REGISTERED"
    }

    public func learnCorrection(predicted: [ReviewCorrectionPointInput],
                                corrected: [ReviewCorrectionPointInput],
                                horseBoxWidth: Double,
                                horseBoxHeight: Double,
                                frameIndex: Int,
                                modelName: String = "current") {
        correctionLearning.learn(
            predicted: predicted,
            corrected: corrected,
            horseBoxWidth: horseBoxWidth,
            horseBoxHeight: horseBoxHeight,
            viewTag: "review",
            modelName: modelName
        )

        markFrame(frameIndex: frameIndex, manual: true, autopose: true, quality: nil, note: "correction-learned")
        mode = .correctionLearning
        status = "CORRECTION LEARNED · \(correctionLearning.lastStats.totalSamples)"
    }

    public func autoCorrect(points: [ReviewCorrectionPointInput],
                            horseBoxWidth: Double,
                            horseBoxHeight: Double) -> [ReviewAutoCorrectionResult] {
        let results = correctionLearning.autoCorrect(
            points: points,
            horseBoxWidth: horseBoxWidth,
            horseBoxHeight: horseBoxHeight,
            viewTag: "review"
        )
        status = ReviewAutoCorrectDataAdapter.resultsSummary(results)
        return results
    }

    public func runDatasetQA() {
        mode = .datasetQA

        var updated: [ReviewCompleteFrameRecord] = []
        for record in frameRecords {
            var r = record
            var score = record.qualityScore
            if record.hasAutoPose { score += 0.35 }
            if record.hasManualCorrection { score += 0.45 }
            if record.imageFileName != nil { score += 0.10 }
            if record.thumbnailFileName != nil { score += 0.10 }
            r.qualityScore = min(1, score)
            if r.qualityScore < 0.45 {
                r.notes.append("low-quality")
            }
            updated.append(r)
        }

        frameRecords = updated
        status = "DATASET QA DONE · AVG \(String(format: "%.2f", averageQuality))"
    }

    public func buildManifest() -> ReviewCompleteDatasetManifest {
        let sid = storage.activeSession?.sessionId ?? "NO_SESSION"
        let manifest = ReviewCompleteDatasetManifest(
            horseName: horseName,
            sessionId: sid,
            mode: mode,
            frames: frameRecords,
            correctionSamples: correctionLearning.lastStats.totalSamples
        )
        lastManifest = manifest
        return manifest
    }

    public func exportCompletePackage() {
        do {
            runDatasetQA()
            let manifest = buildManifest()

            let manifestFolder = try storage.folder(for: .manifests, horseName: horseName)
            let manifestURL = manifestFolder.appendingPathComponent("review_complete_manifest.json")
            try storage.writeJSON(manifest, to: manifestURL)

            let correctionsURL = manifestFolder.appendingPathComponent("review_corrections.json")
            try correctionLearning.exportLearningJSONData().write(to: correctionsURL)

            let correctionsCSV = correctionLearning.exportTrainingCorrectionCSV()
            _ = try storage.writeText(
                correctionsCSV,
                area: .analytics,
                horseName: horseName,
                fileName: "review_corrections.csv"
            )

            lastExportURL = manifestURL
            mode = .exportReady
            status = "REVIEW PACKAGE EXPORTED"
        } catch {
            status = "REVIEW EXPORT ERROR: \(error.localizedDescription)"
        }
    }

    public func importBiotechDataFrames() {
        let receiver = ReviewTrainingFrameReceiver()
        let frames = receiver.importAvailableFrames()

        for sample in frames {
            registerFrame(
                frameIndex: sample.packet.frameIndex,
                timeSeconds: sample.packet.timeSeconds,
                image: sample.image,
                thumbnail: sample.image,
                hasAutoPose: false,
                hasManualCorrection: false,
                qualityScore: 0.15,
                notes: ["biotech-data", sample.packet.source]
            )
        }

        status = "BIOTECH DATA IMPORTED · \(frames.count)"
    }

    public var averageQuality: Double {
        frameRecords.isEmpty ? 0 : frameRecords.map(\.qualityScore).reduce(0, +) / Double(frameRecords.count)
    }

    public var correctedCount: Int {
        frameRecords.filter(\.hasManualCorrection).count
    }

    public var autoPoseCount: Int {
        frameRecords.filter(\.hasAutoPose).count
    }

    private func markFrame(frameIndex: Int,
                           manual: Bool?,
                           autopose: Bool?,
                           quality: Double?,
                           note: String) {
        guard let idx = frameRecords.firstIndex(where: { $0.frameIndex == frameIndex }) else {
            frameRecords.append(
                ReviewCompleteFrameRecord(
                    frameIndex: frameIndex,
                    timeSeconds: 0,
                    hasManualCorrection: manual ?? false,
                    hasAutoPose: autopose ?? false,
                    qualityScore: quality ?? 0,
                    notes: [note]
                )
            )
            return
        }

        if let manual { frameRecords[idx].hasManualCorrection = manual }
        if let autopose { frameRecords[idx].hasAutoPose = autopose }
        if let quality { frameRecords[idx].qualityScore = quality }
        frameRecords[idx].notes.append(note)
    }

    private func merge(old: ReviewCompleteFrameRecord,
                       new: ReviewCompleteFrameRecord) -> ReviewCompleteFrameRecord {
        ReviewCompleteFrameRecord(
            frameIndex: old.frameIndex,
            timeSeconds: new.timeSeconds,
            imageFileName: new.imageFileName ?? old.imageFileName,
            thumbnailFileName: new.thumbnailFileName ?? old.thumbnailFileName,
            hasManualCorrection: old.hasManualCorrection || new.hasManualCorrection,
            hasAutoPose: old.hasAutoPose || new.hasAutoPose,
            qualityScore: max(old.qualityScore, new.qualityScore),
            notes: Array(Set(old.notes + new.notes)).sorted()
        )
    }

    private func clean(_ value: String) -> String {
        value.replacingOccurrences(of: " ", with: "_")
    }
}

@MainActor
public struct ReviewCompleteSystemPanel: View {

    @ObservedObject private var controller = ReviewCompleteSystemController.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REVIEW COMPLETE SYSTEM")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            HStack {
                metric("FRAMES", "\(controller.frameRecords.count)")
                metric("AUTO", "\(controller.autoPoseCount)")
                metric("CORR", "\(controller.correctedCount)")
                metric("QA", String(format: "%.2f", controller.averageQuality))
            }

            Text(controller.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)

            HStack {
                Button("IMPORT BIOTECH DATA") {
                    controller.importBiotechDataFrames()
                }
                .buttonStyle(.bordered)

                Button("QA") {
                    controller.runDatasetQA()
                }
                .buttonStyle(.bordered)

                Button("EXPORT REVIEW") {
                    controller.exportCompletePackage()
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.system(size: 11, weight: .bold))
        }
        .padding(12)
        .background(Color.black.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
