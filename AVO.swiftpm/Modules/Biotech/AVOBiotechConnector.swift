import Foundation

// MARK: - AVO PHASE 108 FIXED
// BIOTECH CONNECTOR
//
// BIOTECH = biomechanical analysis.
// Compile-safe Swift 6 correction:
// no MainActor-isolated static .shared reference in nonisolated default argument.

@MainActor
public final class AVOBiotechConnector: ObservableObject {

    @Published public private(set) var status: String = "BIOTECH CONNECTOR READY"

    private let bus: AVOSystemDataBus
    private let engine = BiotechBiomechStudioEngineV1()

    public init(bus: AVOSystemDataBus? = nil) {
        self.bus = bus ?? AVOSystemDataBus.shared
    }

    public func beginBiotechSession(videoName: String = "") {
        bus.setArea(.biotech)
        bus.setMode(.biotechLive)
        if !videoName.isEmpty {
            bus.updateVideo(name: videoName)
        }
        status = "BIOTECH SESSION STARTED"
    }

    public func runBiomechFromBus() {
        let frames = bus.normalizedPoseTimeline.map { normalized -> BiotechPoseFrame in
            BiotechPoseFrame(
                frameIndex: normalized.frameIndex,
                timeSeconds: normalized.timeSeconds,
                points: normalized.keypoints.map {
                    BiotechJointPoint(
                        name: $0.name,
                        x: $0.x,
                        y: $0.y,
                        confidence: $0.confidence
                    )
                }
            )
        }

        let metrics = engine.analyze(frames: frames)

        for metric in metrics {
            bus.publishBiotechMetric(
                AVOBiotechMetricSnapshot(
                    frameIndex: metric.frameIndex,
                    timeSeconds: metric.timeSeconds,
                    symmetry: metric.symmetry,
                    risk: metric.risk,
                    stability: metric.stability,
                    notes: metric.risk > 0.65 ? ["HIGH_RISK"] : []
                )
            )
        }

        status = "BIOTECH METRICS \(metrics.count) GENERATED"
    }

    public func summary() -> String {
        let metrics = bus.biotechMetrics
        guard !metrics.isEmpty else { return "NO BIOTECH METRICS" }

        let avgSym = metrics.map(\.symmetry).reduce(0, +) / Double(metrics.count)
        let avgRisk = metrics.map(\.risk).reduce(0, +) / Double(metrics.count)

        return "BIOTECH | FRAMES \(metrics.count) | SYM \(String(format: "%.2f", avgSym)) | RISK \(String(format: "%.2f", avgRisk))"
    }
}
