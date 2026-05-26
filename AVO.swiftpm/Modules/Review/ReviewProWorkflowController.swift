import Foundation
import SwiftUI
import UIKit
import PDFKit

// MARK: - REVIEW PRO PHASE 103
// WORKFLOW CONTROLLER
//
// Complete orchestration layer:
// Video -> Pose Timeline -> Temporal AutoPose -> Biomech -> Export
//
// This is additive and designed to be called from existing SwiftUI pages.

@MainActor
public final class ReviewProWorkflowController: ObservableObject {

    @Published public private(set) var status: String = "REVIEW WORKFLOW READY"
    @Published public private(set) var loadedVideoName: String = "NO VIDEO"
    @Published public private(set) var currentFrameImage: UIImage?
    @Published public private(set) var currentFrameIndex: Int = 0
    @Published public private(set) var totalFrames: Int = 0
    @Published public private(set) var currentPose: ReviewProPoseFrame?
    @Published public private(set) var stablePoseTimeline: [ReviewProPoseFrame] = []
    @Published public private(set) var biomechReports: [ReviewProBiomechFrameReport] = []
    @Published public private(set) var currentBiomechReport: ReviewProBiomechFrameReport?
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var lastError: String?

    public let videoEngine = ReviewProCompleteVideoEngine()
    public let temporalEngine = ReviewProTemporalAutoPoseComplete()
    public let biomechEngine = ReviewProBiomechCompleteEngine()
    public let exportEngine = ReviewProExportReportEngine()

    private var rawPoseTimeline: [Int: ReviewProPoseFrame] = [:]

    public init() {}

    public func loadVideo(url: URL, preferredFPS: Double? = nil) {
        do {
            try videoEngine.load(url: url, preferredFPS: preferredFPS)
            loadedVideoName = url.lastPathComponent
            totalFrames = videoEngine.assetInfo?.totalFrames ?? 0
            currentFrameIndex = 0
            currentFrameImage = try? videoEngine.scrub(to: 0)
            rawPoseTimeline.removeAll()
            stablePoseTimeline.removeAll()
            biomechReports.removeAll()
            currentPose = nil
            currentBiomechReport = nil
            status = "VIDEO READY: \(loadedVideoName)"
            lastError = nil
        } catch {
            status = "VIDEO LOAD ERROR"
            lastError = error.localizedDescription
        }
    }

    public func scrub(to frameIndex: Int) {
        do {
            let safeIndex = max(0, min(frameIndex, max(0, totalFrames - 1)))
            currentFrameImage = try videoEngine.scrub(to: safeIndex)
            currentFrameIndex = safeIndex
            currentPose = stablePoseTimeline.first(where: { $0.frameIndex == safeIndex }) ?? rawPoseTimeline[safeIndex]
            currentBiomechReport = biomechReports.first(where: { $0.frameIndex == safeIndex })
            status = "FRAME \(safeIndex)/\(max(0, totalFrames - 1))"
            lastError = nil
        } catch {
            status = "SCRUB ERROR"
            lastError = error.localizedDescription
        }
    }

    public func saveRawPose(frameIndex: Int,
                            timeSeconds: Double,
                            points: [ReviewProPosePoint]) {
        let confidence = temporalEngine.globalConfidence(points: points)
        let pose = ReviewProPoseFrame(
            frameIndex: frameIndex,
            timeSeconds: timeSeconds,
            points: points,
            globalConfidence: confidence,
            temporalStability: 1
        )
        rawPoseTimeline[frameIndex] = pose
        currentPose = pose
        status = "POSE SAVED FRAME \(frameIndex)"
    }

    public func runTemporalAutoPose() {
        let ordered = rawPoseTimeline.values.sorted { $0.frameIndex < $1.frameIndex }
        let interpolated = temporalEngine.interpolateMissingFrames(ordered)
        stablePoseTimeline = temporalEngine.process(frames: interpolated)
        currentPose = stablePoseTimeline.first(where: { $0.frameIndex == currentFrameIndex })
        status = "TEMPORAL AUTOPOSE DONE: \(stablePoseTimeline.count) FRAMES"
    }

    public func runBiomechAnalysis() {
        biomechReports = biomechEngine.analyzePoseFrames(stablePoseTimeline)
        currentBiomechReport = biomechReports.first(where: { $0.frameIndex == currentFrameIndex })
        status = "BIOMECH DONE: \(biomechReports.count) REPORTS"
    }

    public func runFullAnalysis() {
        runTemporalAutoPose()
        runBiomechAnalysis()
    }

    public func exportCSV(to folder: URL) {
        do {
            let csv = biomechEngine.exportCSV(reports: biomechReports)
            let url = folder.appendingPathComponent("review_pro_biomech_phase103.csv")
            try exportEngine.writeCSV(csv, to: url)
            lastExportURL = url
            status = "CSV EXPORTED"
            lastError = nil
        } catch {
            status = "CSV EXPORT ERROR"
            lastError = error.localizedDescription
        }
    }

    public func exportJSON(to folder: URL) {
        do {
            let url = folder.appendingPathComponent("review_pro_pose_timeline_phase103.json")
            try exportEngine.writeJSON(stablePoseTimeline, to: url)
            lastExportURL = url
            status = "JSON EXPORTED"
            lastError = nil
        } catch {
            status = "JSON EXPORT ERROR"
            lastError = error.localizedDescription
        }
    }

    public func exportPDF(to folder: URL) {
        let pdf = exportEngine.makeBiomechPDF(
            title: "REVIEW PRO BIOMECH REPORT",
            subtitle: loadedVideoName,
            reports: biomechReports
        )

        let url = folder.appendingPathComponent("review_pro_biomech_phase103.pdf")

        if pdf.write(to: url) {
            lastExportURL = url
            status = "PDF EXPORTED"
            lastError = nil
        } else {
            status = "PDF EXPORT ERROR"
            lastError = "PDFKit could not write document."
        }
    }

    public var progressText: String {
        "\(currentFrameIndex)/\(max(0, totalFrames - 1))"
    }

    public var analysisSummaryText: String {
        let avgRisk = biomechReports.isEmpty ? 0 : biomechReports.map(\.locomotionRisk).reduce(0, +) / Double(biomechReports.count)
        let avgSym = biomechReports.isEmpty ? 0 : biomechReports.map(\.symmetryScore).reduce(0, +) / Double(biomechReports.count)
        return "POSE \(stablePoseTimeline.count) | BIOMECH \(biomechReports.count) | SYM \(String(format: "%.2f", avgSym)) | RISK \(String(format: "%.2f", avgRisk))"
    }
}
