import Foundation
import UIKit

// MARK: - REVIEW PRO PHASE 104
// SESSION PACKAGE EXPORTER
//
// Exports a structured folder with JSON/CSV placeholders and readable manifest.
// Useful for Drive/Colab/client delivery.

public struct ReviewProSessionPackageManifest: Codable, Hashable {
    public var app: String
    public var phase: String
    public var createdAt: Date
    public var videoName: String
    public var framesAnalyzed: Int
    public var poseFrames: Int
    public var biomechReports: Int
    public var files: [String]

    public init(videoName: String,
                framesAnalyzed: Int,
                poseFrames: Int,
                biomechReports: Int,
                files: [String]) {
        self.app = "AVO REVIEW PRO"
        self.phase = "104"
        self.createdAt = Date()
        self.videoName = videoName
        self.framesAnalyzed = framesAnalyzed
        self.poseFrames = poseFrames
        self.biomechReports = biomechReports
        self.files = files
    }
}

public final class ReviewProSessionPackageExporter {

    public init() {}

    public func exportPackage(folder: URL,
                              videoName: String,
                              poseTimeline: [ReviewProPoseFrame],
                              biomechReports: [ReviewProBiomechFrameReport],
                              biomechCSV: String) throws -> URL {

        let packageURL = folder.appendingPathComponent("AVO_REVIEW_PRO_SESSION_\(Int(Date().timeIntervalSince1970))", isDirectory: true)

        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        let poseURL = packageURL.appendingPathComponent("pose_timeline.json")
        let biomechURL = packageURL.appendingPathComponent("biomech_reports.json")
        let csvURL = packageURL.appendingPathComponent("biomech_curves.csv")
        let manifestURL = packageURL.appendingPathComponent("manifest.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        try encoder.encode(poseTimeline).write(to: poseURL)
        try encoder.encode(biomechReports).write(to: biomechURL)
        try biomechCSV.write(to: csvURL, atomically: true, encoding: .utf8)

        let manifest = ReviewProSessionPackageManifest(
            videoName: videoName,
            framesAnalyzed: biomechReports.count,
            poseFrames: poseTimeline.count,
            biomechReports: biomechReports.count,
            files: ["pose_timeline.json", "biomech_reports.json", "biomech_curves.csv"]
        )

        try encoder.encode(manifest).write(to: manifestURL)

        return packageURL
    }
}
