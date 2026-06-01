import Foundation
import CoreGraphics

// MARK: - AVO REVIEW PRO MODULES
// Lightweight real data structures used by Review Pro. No simulated measurements.

struct AVOReviewProFeatureState: Codable, Hashable {
    var autoPoseV2: Bool = true
    var datasetTimeline: Bool = true
    var autoSave: Bool = true
    var overlayIA: Bool = true
    var overlayHuman: Bool = true
    var overlaySkeleton: Bool = true
    var overlayConfidenceHeatmap: Bool = false
    var batchReview: Bool = false
    var videoTracking: Bool = false
    var datasetTrainerHub: Bool = true
    var advancedHorseAnatomy: Bool = false
    var lidarFusion: Bool = false
    var hudHidden: Bool = false
}

struct AVOAutoposeV2FrameState: Codable, Hashable {
    var frameId: String
    var timestamp: TimeInterval
    var pointCount: Int
    var averageConfidence: Double
    var continuityScore: Double
    var smoothed: Bool
    var saved: Bool
}

struct AVODatasetTrainerHubSummary: Codable, Hashable {
    var totalImages: Int
    var good: Int
    var review: Int
    var rejected: Int
    var annotated: Int
    var hasBaseModel: Bool
    var canExportYOLOPose: Bool
    var canExportCOCO: Bool
    var canExportCoreML: Bool
    var canExportCreateML: Bool
}

struct AVOAdvancedHorseAnatomyReport: Codable, Hashable {
    var dorsalLineReady: Bool
    var pelvisReady: Bool
    var neckTrackingReady: Bool
    var jointAnglesReady: Bool
    var strideLengthReady: Bool
    var symmetryReady: Bool
    var notes: String
}

final class AVOReviewProIntegrator {
    static func qualityName(blur: Double, visibility: Double, boxArea: Double, confidence: Double) -> String {
        if blur > 0.72 && visibility > 0.65 && boxArea > 0.12 && confidence > 0.70 { return "GOOD PARA ENTRENAR" }
        if blur < 0.35 || visibility < 0.35 || boxArea < 0.06 { return "REVIEW / POSIBLE BASURA" }
        return "REVIEW"
    }

    static func continuityScore(previous: [CGPoint], current: [CGPoint]) -> Double {
        guard !previous.isEmpty, previous.count == current.count else { return 0.0 }
        let distances = zip(previous, current).map { hypot($0.x - $1.x, $0.y - $1.y) }
        let mean = distances.reduce(0, +) / Double(max(distances.count, 1))
        return max(0.0, min(1.0, 1.0 - mean * 5.0))
    }
}
