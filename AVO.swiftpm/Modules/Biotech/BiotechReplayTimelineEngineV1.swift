import Foundation

// MARK: - BIOTECH PHASE 106
// Replay Timeline Engine V1
//
// Biotech-specific temporal replay/timeline state.
// REVIEW keeps dataset/training timeline; BIOTECH gets locomotion timeline.

public enum BiotechReplayMode: String, Codable, CaseIterable {
    case live
    case replay
    case slowMotion
    case compare
}

public struct BiotechReplayMarker: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var frameIndex: Int
    public var timeSeconds: Double
    public var label: String
    public var severity: Double

    public init(frameIndex: Int,
                timeSeconds: Double,
                label: String,
                severity: Double) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.label = label
        self.severity = severity
    }
}

public final class BiotechReplayTimelineEngineV1: ObservableObject {

    @Published public var mode: BiotechReplayMode = .live
    @Published public var currentFrame: Int = 0
    @Published public var totalFrames: Int = 0
    @Published public var playbackRate: Double = 1.0
    @Published public var markers: [BiotechReplayMarker] = []

    public init() {}

    public func configure(totalFrames: Int) {
        self.totalFrames = max(0, totalFrames)
        self.currentFrame = 0
        self.markers.removeAll()
    }

    public func scrub(to frame: Int) {
        currentFrame = max(0, min(frame, max(0, totalFrames - 1)))
    }

    public func addRiskMarkers(from metrics: [BiotechBiomechFrameMetrics],
                               threshold: Double = 0.65) {
        markers = metrics
            .filter { $0.risk >= threshold }
            .map {
                BiotechReplayMarker(
                    frameIndex: $0.frameIndex,
                    timeSeconds: $0.timeSeconds,
                    label: "HIGH RISK",
                    severity: $0.risk
                )
            }
    }

    public var progress: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(currentFrame) / Double(max(1, totalFrames - 1))
    }
}
