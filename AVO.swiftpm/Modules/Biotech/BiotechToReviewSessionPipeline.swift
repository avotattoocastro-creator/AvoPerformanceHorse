import Foundation
import SwiftUI
import UIKit

// MARK: - AVO PHASE 122
// REC -> VIDEO -> DATA -> REVIEW PIPELINE
//
// Coordinates BIOTECH recording and REVIEW training intake.

@MainActor
public final class BiotechToReviewSessionPipeline: ObservableObject {

    public static let shared = BiotechToReviewSessionPipeline()

    @Published public private(set) var status: String = "PIPELINE READY"
    @Published public private(set) var clientWriter = BiotechSessionVideoWriter()
    @Published public private(set) var biotechWriter = BiotechSessionVideoWriter()
    @Published public private(set) var lastManifestURL: URL?
    @Published public private(set) var exportedReviewFrames: Int = 0

    private let storage = AVOStorageEngine.shared
    private let dataBridge = BiotechDataToReviewBridge.shared
    private let horseRecorder = BiotechHorseSessionRecorder.shared

    private init() {}

    public func prepare(horseName: String, rootFolder: URL? = nil) {
        do {
            horseRecorder.setSelectedHorse(horseName)
            _ = try storage.ensureSession(horseName: horseName, rootFolder: rootFolder)
            _ = try horseRecorder.ensureSession(rootFolder: rootFolder)
            status = "PIPELINE READY FOR \(horseName)"
        } catch {
            status = "PIPELINE PREPARE ERROR: \(error.localizedDescription)"
        }
    }

    public func startClientRecording(horseName: String,
                                     size: CGSize,
                                     fps: Int = 60,
                                     rootFolder: URL? = nil) {
        do {
            prepare(horseName: horseName, rootFolder: rootFolder)
            let url = try storage.makeFileURL(
                area: .recClient,
                horseName: horseName,
                prefix: "REC_CLIENT",
                ext: "mp4",
                rootFolder: rootFolder
            )
            clientWriter.start(url: url, size: size, fps: fps)
            status = "REC CLIENT STARTED"
        } catch {
            status = "REC CLIENT ERROR: \(error.localizedDescription)"
        }
    }

    public func startBiotechRecording(horseName: String,
                                      size: CGSize,
                                      fps: Int = 60,
                                      rootFolder: URL? = nil) {
        do {
            prepare(horseName: horseName, rootFolder: rootFolder)
            let url = try storage.makeFileURL(
                area: .recBiotech,
                horseName: horseName,
                prefix: "REC_BIOTECH",
                ext: "mp4",
                rootFolder: rootFolder
            )
            biotechWriter.start(url: url, size: size, fps: fps)
            status = "REC BIOTECH STARTED"
        } catch {
            status = "REC BIOTECH ERROR: \(error.localizedDescription)"
        }
    }

    public func appendFrameToActiveRecordings(_ image: UIImage) {
        if clientWriter.isRecording {
            clientWriter.append(image: image)
        }
        if biotechWriter.isRecording {
            biotechWriter.append(image: image)
        }
    }

    public func stopAllRecordings() {
        clientWriter.stop()
        biotechWriter.stop()
        status = "ALL RECORDINGS STOPPED"
    }

    public func toggleDataToReview(horseName: String,
                                   requestedFPS: Int = 120,
                                   rootFolder: URL? = nil) {
        prepare(horseName: horseName, rootFolder: rootFolder)

        if dataBridge.isDataOn {
            exportBufferedFramesToReview(horseName: horseName, rootFolder: rootFolder)
            exportDataManifestToSession(horseName: horseName, rootFolder: rootFolder)
            dataBridge.setDataOn(false, requestedFPS: requestedFPS)
            status = "DATA STREAM OFF -> REVIEW SAVED"
        } else {
            dataBridge.keepUIImageInMemory = true
            dataBridge.clearBuffer()
            dataBridge.setDataOn(true, requestedFPS: requestedFPS)
            status = "DATA STREAM ON -> REVIEW"
        }
    }

    public func exportDataManifestToSession(horseName: String,
                                            rootFolder: URL? = nil) {
        do {
            let csv = dataBridge.exportManifestCSV()
            let url = try storage.writeText(
                csv,
                area: .recData,
                horseName: horseName,
                fileName: "data_to_review_manifest.csv",
                rootFolder: rootFolder
            )
            lastManifestURL = url
            status = "DATA MANIFEST SAVED"
        } catch {
            status = "DATA MANIFEST ERROR: \(error.localizedDescription)"
        }
    }

    public func exportBufferedFramesToReview(horseName: String,
                                             rootFolder: URL? = nil) {
        do {
            var count = 0
            for sample in dataBridge.buffer {
                if let image = sample.image {
                    _ = try storage.saveImage(
                        image,
                        area: .reviewFrames,
                        horseName: horseName,
                        prefix: "review_frame_\(sample.packet.frameIndex)",
                        rootFolder: rootFolder
                    )
                    count += 1
                }
            }

            let json = try dataBridge.exportManifestJSONData()
            let manifestFolder = try storage.folder(for: .manifests, horseName: horseName, rootFolder: rootFolder)
            let url = manifestFolder.appendingPathComponent("review_training_frames_manifest.json")
            try json.write(to: url)

            exportedReviewFrames = count
            lastManifestURL = url
            status = "REVIEW FRAMES EXPORTED \(count)"
        } catch {
            status = "REVIEW EXPORT ERROR: \(error.localizedDescription)"
        }
    }
}

@MainActor
public struct BiotechPipelineStatusPanel: View {

    @ObservedObject private var pipeline = BiotechToReviewSessionPipeline.shared
    @ObservedObject private var dataBridge = BiotechDataToReviewBridge.shared
    @ObservedObject private var storage = AVOStorageEngine.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("REC → VIDEO → DATA → REVIEW")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            Text(pipeline.status)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            HStack(spacing: 12) {
                Text(dataBridge.isDataOn ? "DATA ON \(dataBridge.capturedCount)" : "DATA OFF")
                Text("CLIENT \(pipeline.clientWriter.writtenFrames)")
                Text("BIOTECH \(pipeline.biotechWriter.writtenFrames)")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.green)

            Text(storage.status)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(10)
        .background(Color.black.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }
}
