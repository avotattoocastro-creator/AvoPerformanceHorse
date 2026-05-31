import Foundation

// MARK: - REVIEW PRO PHASE 102 INTEGRATION GUIDE
//
// These modules are additive and safe.
// Recommended integration order inside the existing app:
//
// 1. Video import page:
//    let videoEngine = ReviewProCompleteVideoEngine()
//    try videoEngine.load(url: selectedURL)
//    let image = try videoEngine.scrub(to: frameIndex)
//
// 2. AutoPose temporal:
//    let temporal = ReviewProTemporalAutoPoseComplete()
//    let stableFrames = temporal.process(frames: rawPoseFrames)
//
// 3. Biomech:
//    let biomech = ReviewProBiomechCompleteEngine()
//    let reports = biomech.analyzePoseFrames(stableFrames)
//
// 4. Export:
//    let exporter = ReviewProExportReportEngine()
//    let csv = biomech.exportCSV(reports: reports)
//    try exporter.writeCSV(csv, to: destinationURL)
//
// This file intentionally has no executable app code.
// It documents how to connect the complete engines without breaking existing files.
public enum ReviewProPhase102IntegrationGuide {
    public static let phase = "102 COMPLETE"
    public static let priority = "VIDEO + TEMPORAL AUTOPOSE + BIOMECH + EXPORT"
}
