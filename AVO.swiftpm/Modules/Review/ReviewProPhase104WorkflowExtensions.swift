import Foundation
import UIKit

// MARK: - REVIEW PRO PHASE 108 FIXED
// Workflow extensions for package export and charts-ready data.
//
// Compile-safe correction:
// Previous PHASE104 extension attempted to assign private(set) properties
// of ReviewProWorkflowController from an extension. Swift blocks that.
// This version returns the exported package URL instead of mutating
// private(set) controller state.

@MainActor
public extension ReviewProWorkflowController {

    @discardableResult
    func makeSessionPackage(to folder: URL) throws -> URL {
        let packageExporter = ReviewProSessionPackageExporter()
        let csv = biomechEngine.exportCSV(reports: biomechReports)

        return try packageExporter.exportPackage(
            folder: folder,
            videoName: loadedVideoName,
            poseTimeline: stablePoseTimeline,
            biomechReports: biomechReports,
            biomechCSV: csv
        )
    }

    var highRiskFrameIndexes: [Int] {
        biomechReports
            .filter { $0.locomotionRisk > 0.65 }
            .map(\.frameIndex)
    }

    var symmetryCurve: [Double] {
        biomechReports.map(\.symmetryScore)
    }

    var riskCurve: [Double] {
        biomechReports.map(\.locomotionRisk)
    }
}
