import Foundation
import SwiftUI
import UIKit
import AVFoundation

// MARK: - BIOTECH PHASE 124
// BIOTECH COMPLETE SYSTEM
//
// Closes BIOTECH as one full capture station:
// - camera ownership
// - selected horse/session
// - REC CLIENT
// - REC BIOTECH
// - DATA -> REVIEW
// - storage
// - manifest
// - state panel

public enum BiotechCompleteCaptureMode: String, Codable, CaseIterable, Hashable {
    case idle
    case live
    case recClient
    case recBiotech
    case dataToReview
    case fullCapture
}

public struct BiotechCompleteSystemManifest: Codable, Hashable {
    public var phase: String
    public var horseName: String
    public var sessionId: String
    public var mode: BiotechCompleteCaptureMode
    public var createdAt: Date
    public var clientFrames: Int
    public var biotechFrames: Int
    public var dataFrames: Int
    public var dataDropped: Int
    public var cameraOwner: String
    public var storageStatus: String
    public var notes: [String]
}

@MainActor
public final class BiotechCompleteSystemController: ObservableObject {

    public static let shared = BiotechCompleteSystemController()

    @Published public private(set) var mode: BiotechCompleteCaptureMode = .idle
    @Published public private(set) var status: String = "BIOTECH COMPLETE READY"
    @Published public private(set) var selectedHorse: String = "SIN_CABALLO"
    @Published public private(set) var lastManifestURL: URL?
    @Published public private(set) var lastError: String?

    public let pipeline = BiotechToReviewSessionPipeline.shared
    public let storage = AVOStorageEngine.shared
    public let dataBridge = BiotechDataToReviewBridge.shared
    public let horseRecorder = BiotechHorseSessionRecorder.shared
    public let cameraOwnership = AVOCameraOwnershipCoordinator.shared

    private init() {}

    public func prepare(horseName: String, rootFolder: URL? = nil) {
        selectedHorse = clean(horseName.isEmpty ? "SIN_CABALLO" : horseName)
        horseRecorder.setSelectedHorse(selectedHorse)
        cameraOwnership.forceReleaseAll()
        cameraOwnership.claim(.biotech)

        do {
            _ = try storage.ensureSession(horseName: selectedHorse, rootFolder: rootFolder)
            _ = try horseRecorder.ensureSession(rootFolder: rootFolder)
            pipeline.prepare(horseName: selectedHorse, rootFolder: rootFolder)
            mode = .live
            status = "BIOTECH LIVE · \(selectedHorse)"
            lastError = nil
        } catch {
            status = "BIOTECH PREPARE ERROR"
            lastError = error.localizedDescription
        }
    }

    public func startClientREC(size: CGSize = CGSize(width: 1920, height: 1080),
                               fps: Int = 60,
                               rootFolder: URL? = nil) {
        prepare(horseName: selectedHorse, rootFolder: rootFolder)
        pipeline.startClientRecording(horseName: selectedHorse, size: size, fps: fps, rootFolder: rootFolder)
        mode = .recClient
        status = "REC CLIENT ON"
    }

    public func startBiotechREC(size: CGSize = CGSize(width: 1920, height: 1080),
                                fps: Int = 60,
                                rootFolder: URL? = nil) {
        prepare(horseName: selectedHorse, rootFolder: rootFolder)
        pipeline.startBiotechRecording(horseName: selectedHorse, size: size, fps: fps, rootFolder: rootFolder)
        mode = .recBiotech
        status = "REC BIOTECH ON"
    }

    public func startFullCapture(size: CGSize = CGSize(width: 1920, height: 1080),
                                 videoFPS: Int = 60,
                                 dataFPS: Int = 120,
                                 rootFolder: URL? = nil) {
        prepare(horseName: selectedHorse, rootFolder: rootFolder)
        pipeline.startClientRecording(horseName: selectedHorse, size: size, fps: videoFPS, rootFolder: rootFolder)
        pipeline.startBiotechRecording(horseName: selectedHorse, size: size, fps: videoFPS, rootFolder: rootFolder)
        pipeline.toggleDataToReview(horseName: selectedHorse, requestedFPS: dataFPS, rootFolder: rootFolder)
        mode = .fullCapture
        status = "FULL CAPTURE ON"
    }

    public func toggleData(requestedFPS: Int = 120, rootFolder: URL? = nil) {
        prepare(horseName: selectedHorse, rootFolder: rootFolder)
        pipeline.toggleDataToReview(horseName: selectedHorse, requestedFPS: requestedFPS, rootFolder: rootFolder)
        mode = dataBridge.isDataOn ? .dataToReview : .live
        status = dataBridge.isDataOn ? "DATA -> REVIEW ON" : "DATA -> REVIEW OFF"
    }

    public func appendRenderedFrame(_ image: UIImage) {
        pipeline.appendFrameToActiveRecordings(image)
        dataBridge.acceptFrame(
            image: image,
            source: "biotech-rendered-frame",
            timeSeconds: CACurrentMediaTime(),
            width: Int(image.size.width),
            height: Int(image.size.height),
            qualityTag: "rendered"
        )
    }

    public func stopAll(rootFolder: URL? = nil) {
        // Stop only the active recordings. Do NOT close the master session here.
        // The user may record several CLIENT / BIOMECH / DATA clips inside the same training session.
        pipeline.stopAllRecordings()
        if dataBridge.isDataOn {
            dataBridge.setDataOn(false)
        }
        exportManifest(rootFolder: rootFolder)
        cameraOwnership.release(.biotech)
        mode = .live
        status = "RECORDINGS STOPPED · SESSION STILL OPEN"
    }

    public func openTrainingSession(rootFolder: URL? = nil) {
        prepare(horseName: selectedHorse, rootFolder: rootFolder)
        status = "SESSION OPEN · READY FOR MULTI REC"
    }

    public func closeTrainingSession(rootFolder: URL? = nil) {
        stopAll(rootFolder: rootFolder)
        exportManifest(rootFolder: rootFolder)
        horseRecorder.closeSession()
        storage.resetSession()
        mode = .idle
        status = "SESSION CLOSED · SAVED"
    }

    public func exportManifest(rootFolder: URL? = nil) {
        do {
            let map = try storage.ensureSession(horseName: selectedHorse, rootFolder: rootFolder)
            let manifest = BiotechCompleteSystemManifest(
                phase: "124",
                horseName: selectedHorse,
                sessionId: map.sessionId,
                mode: mode,
                createdAt: Date(),
                clientFrames: pipeline.clientWriter.writtenFrames,
                biotechFrames: pipeline.biotechWriter.writtenFrames,
                dataFrames: dataBridge.capturedCount,
                dataDropped: dataBridge.droppedCount,
                cameraOwner: cameraOwnership.owner.rawValue,
                storageStatus: storage.status,
                notes: [
                    "BIOTECH COMPLETE SYSTEM",
                    "REC CLIENT / REC BIOTECH / DATA REVIEW unified",
                    "Horse/session storage enabled"
                ]
            )

            let folder = try storage.folder(for: .manifests, horseName: selectedHorse, rootFolder: rootFolder)
            let url = folder.appendingPathComponent("biotech_complete_manifest.json")
            try storage.writeJSON(manifest, to: url)
            lastManifestURL = url
            lastError = nil
            status = "BIOTECH MANIFEST SAVED"
        } catch {
            lastError = error.localizedDescription
            status = "BIOTECH MANIFEST ERROR"
        }
    }

    public func resetForNewHorse(_ horseName: String) {
        stopAll()
        storage.resetSession()
        horseRecorder.closeSession()
        selectedHorse = clean(horseName)
        prepare(horseName: selectedHorse)
    }

    private func clean(_ value: String) -> String {
        value.replacingOccurrences(of: " ", with: "_")
    }
}

@MainActor
public struct BiotechCompleteSystemPanel: View {

    @ObservedObject private var controller = BiotechCompleteSystemController.shared
    @ObservedObject private var dataBridge = BiotechDataToReviewBridge.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BIOTECH COMPLETE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)

                Spacer()

                Text(controller.mode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
            }

            HStack {
                metric("CLIENT", "\(controller.pipeline.clientWriter.writtenFrames)")
                metric("BIOTECH", "\(controller.pipeline.biotechWriter.writtenFrames)")
                metric("DATA", "\(dataBridge.capturedCount)")
                metric("DROP", "\(dataBridge.droppedCount)")
            }

            Text(controller.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)

            if let error = controller.lastError {
                Text(error)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button("FULL CAPTURE") {
                    controller.startFullCapture()
                }
                .buttonStyle(.borderedProminent)

                Button("STOP") {
                    controller.stopAll()
                }
                .buttonStyle(.bordered)

                Button("MANIFEST") {
                    controller.exportManifest()
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))
        }
        .padding(12)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.24), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
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
