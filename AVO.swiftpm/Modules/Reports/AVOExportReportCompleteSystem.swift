import Foundation
import SwiftUI
import UIKit

// MARK: - EXPORT PHASE 129
// REPORT / EXPORT COMPLETE SYSTEM
//
// Closes the output layer:
// One professional session package containing:
// - session manifests
// - REVIEW dataset manifest
// - BIOTECH manifest
// - BIOMECH science report
// - HARDWARE telemetry
// - LIDAR/depth report
// - COREML training package
// - human-readable summary TXT/CSV
//
// This is the system that makes the app commercially usable for client delivery.

public enum AVOExportPackageType: String, Codable, CaseIterable, Hashable {
    case clientReport
    case trainingPackage
    case clinicalPackage
    case fullSessionArchive
}

public struct AVOCompleteExportManifest: Codable, Hashable {
    public var phase: String
    public var packageType: AVOExportPackageType
    public var horseName: String
    public var sessionId: String
    public var createdAt: Date
    public var files: [String]
    public var reviewFrames: Int
    public var hardwarePackets: Int
    public var dataFrames: Int
    public var scienceFrames: Int
    public var modelCount: Int
    public var warnings: [String]
    public var status: String
}

@MainActor
public final class AVOExportReportCompleteSystem: ObservableObject {

    public static let shared = AVOExportReportCompleteSystem()

    @Published public private(set) var status: String = "EXPORT REPORT READY"
    @Published public private(set) var lastManifest: AVOCompleteExportManifest?
    @Published public private(set) var lastExportFolder: URL?
    @Published public private(set) var lastError: String?

    private let storage = AVOStorageEngine.shared

    private init() {}

    public func buildCompletePackage(horseName: String,
                                     packageType: AVOExportPackageType = .fullSessionArchive,
                                     rootFolder: URL? = nil) {
        do {
            let map = try storage.ensureSession(horseName: horseName, rootFolder: rootFolder)
            let exportFolder = URL(fileURLWithPath: map.sessionRoot, isDirectory: true)
                .appendingPathComponent("EXPORT_PACKAGE", isDirectory: true)

            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)

            var files: [String] = []
            var warnings: [String] = []

            // Summaries from existing systems
            let review = ReviewCompleteSystemController.shared
            let hardware = AVOHardwareTelemetryHub.shared
            let science = BiomechScienceSystemController.shared
            let coreml = AVOCoreMLTrainingEcosystem.shared
            let dataBridge = BiotechDataToReviewBridge.shared
            let lidar = AVOLidarFusionCompleteSystem.shared

            let summary = buildHumanSummary(
                horseName: horseName,
                sessionId: map.sessionId,
                reviewFrames: review.frameRecords.count,
                hardwarePackets: hardware.packets.count,
                dataFrames: dataBridge.capturedCount,
                scienceFrames: science.lastReport?.frameCount ?? 0,
                modelCount: coreml.registry.count,
                lidarFrames: lidar.depthFrames.count
            )

            let summaryURL = exportFolder.appendingPathComponent("AVO_SESSION_SUMMARY.txt")
            try summary.write(to: summaryURL, atomically: true, encoding: .utf8)
            files.append(summaryURL.lastPathComponent)

            // Export REVIEW manifest
            let reviewManifestURL = exportFolder.appendingPathComponent("review_complete_manifest.json")
            try storage.writeJSON(review.buildManifest(), to: reviewManifestURL)
            files.append(reviewManifestURL.lastPathComponent)

            // Export hardware telemetry
            let hardwareCSVURL = exportFolder.appendingPathComponent("hardware_telemetry.csv")
            try hardware.exportCSV().write(to: hardwareCSVURL, atomically: true, encoding: .utf8)
            files.append(hardwareCSVURL.lastPathComponent)

            let hardwareSummaryURL = exportFolder.appendingPathComponent("hardware_summary.json")
            try storage.writeJSON(hardware.buildSummary(), to: hardwareSummaryURL)
            files.append(hardwareSummaryURL.lastPathComponent)

            // Export science if present
            if let scienceReport = science.lastReport {
                let scienceURL = exportFolder.appendingPathComponent("biomech_science_report.json")
                try storage.writeJSON(scienceReport, to: scienceURL)
                files.append(scienceURL.lastPathComponent)

                let scienceCSVURL = exportFolder.appendingPathComponent("biomech_science_curves.csv")
                try science.exportCSV(report: scienceReport).write(to: scienceCSVURL, atomically: true, encoding: .utf8)
                files.append(scienceCSVURL.lastPathComponent)
            } else {
                warnings.append("NO_BIOMECH_SCIENCE_REPORT")
            }

            // Export data bridge manifest
            let dataCSVURL = exportFolder.appendingPathComponent("data_to_review_manifest.csv")
            try dataBridge.exportManifestCSV().write(to: dataCSVURL, atomically: true, encoding: .utf8)
            files.append(dataCSVURL.lastPathComponent)

            // Export CoreML registry
            let modelRegistryURL = exportFolder.appendingPathComponent("coreml_model_registry.json")
            try storage.writeJSON(coreml.registry, to: modelRegistryURL)
            files.append(modelRegistryURL.lastPathComponent)

            // Export Lidar frames
            let lidarURL = exportFolder.appendingPathComponent("lidar_depth_fusion.json")
            try storage.writeJSON(lidar.depthFrames, to: lidarURL)
            files.append(lidarURL.lastPathComponent)

            if review.frameRecords.isEmpty { warnings.append("NO_REVIEW_FRAMES") }
            if hardware.packets.isEmpty { warnings.append("NO_HARDWARE_PACKETS") }
            if dataBridge.capturedCount == 0 { warnings.append("NO_DATA_FRAMES") }

            let manifest = AVOCompleteExportManifest(
                phase: "129",
                packageType: packageType,
                horseName: horseName,
                sessionId: map.sessionId,
                createdAt: Date(),
                files: files,
                reviewFrames: review.frameRecords.count,
                hardwarePackets: hardware.packets.count,
                dataFrames: dataBridge.capturedCount,
                scienceFrames: science.lastReport?.frameCount ?? 0,
                modelCount: coreml.registry.count,
                warnings: warnings,
                status: warnings.isEmpty ? "COMPLETE" : "COMPLETE_WITH_WARNINGS"
            )

            let manifestURL = exportFolder.appendingPathComponent("AVO_COMPLETE_EXPORT_MANIFEST.json")
            try storage.writeJSON(manifest, to: manifestURL)
            files.append(manifestURL.lastPathComponent)

            lastManifest = manifest
            lastExportFolder = exportFolder
            lastError = nil
            status = "EXPORT COMPLETE · \(files.count) FILES"
        } catch {
            lastError = error.localizedDescription
            status = "EXPORT ERROR"
        }
    }

    public func buildClientReport(horseName: String) {
        buildCompletePackage(horseName: horseName, packageType: .clientReport)
    }

    public func buildTrainingPackage(horseName: String) {
        AVOCoreMLTrainingEcosystem.shared.buildTrainingPackage(horseName: horseName)
        buildCompletePackage(horseName: horseName, packageType: .trainingPackage)
    }

    private func buildHumanSummary(horseName: String,
                                   sessionId: String,
                                   reviewFrames: Int,
                                   hardwarePackets: Int,
                                   dataFrames: Int,
                                   scienceFrames: Int,
                                   modelCount: Int,
                                   lidarFrames: Int) -> String {
        """
        AVO PERFORMANCE HORSE — SESSION SUMMARY

        Horse: \(horseName)
        Session: \(sessionId)
        Created: \(Date())

        REVIEW
        - Frames: \(reviewFrames)

        BIOTECH / DATA
        - Data frames: \(dataFrames)

        HARDWARE
        - Telemetry packets: \(hardwarePackets)

        BIOMECH SCIENCE
        - Science frames: \(scienceFrames)

        LIDAR / DEPTH
        - Depth frames: \(lidarFrames)

        COREML
        - Registered models: \(modelCount)

        Notes:
        This export package is generated by AVO Export Report Complete System PHASE129.
        """
    }
}

@MainActor
public struct AVOExportReportCompletePanel: View {

    @ObservedObject private var exportSystem = AVOExportReportCompleteSystem.shared
    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXPORT REPORT COMPLETE")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            HStack {
                metric("FILES", "\(exportSystem.lastManifest?.files.count ?? 0)")
                metric("WARN", "\(exportSystem.lastManifest?.warnings.count ?? 0)")
                metric("TYPE", exportSystem.lastManifest?.packageType.rawValue.uppercased() ?? "--")
            }

            Text(exportSystem.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)

            if let error = exportSystem.lastError {
                Text(error)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            HStack {
                Button("CLIENT REPORT") {
                    exportSystem.buildClientReport(horseName: recorder.selectedHorseName)
                }
                .buttonStyle(.borderedProminent)

                Button("TRAINING") {
                    exportSystem.buildTrainingPackage(horseName: recorder.selectedHorseName)
                }
                .buttonStyle(.bordered)

                Button("FULL") {
                    exportSystem.buildCompletePackage(horseName: recorder.selectedHorseName)
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))
        }
        .padding(12)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
