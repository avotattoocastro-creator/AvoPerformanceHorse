import Foundation

// MARK: - AVO PHASE 108 FIXED
// REVIEW CONNECTOR
//
// REVIEW = IA retraining / dataset / quality.
// Compile-safe Swift 6 correction:
// no MainActor-isolated static .shared reference in nonisolated default argument.

@MainActor
public final class AVOReviewConnector: ObservableObject {

    @Published public private(set) var status: String = "REVIEW CONNECTOR READY"

    private let bus: AVOSystemDataBus

    public init(bus: AVOSystemDataBus? = nil) {
        self.bus = bus ?? AVOSystemDataBus.shared
    }

    public func beginReviewSession(videoName: String = "") {
        bus.setArea(.review)
        bus.setMode(.reviewDataset)
        if !videoName.isEmpty {
            bus.updateVideo(name: videoName)
        }
        status = "REVIEW SESSION STARTED"
    }

    public func publishReviewFrame(frameIndex: Int,
                                   timeSeconds: Double,
                                   keypoints: [AVONormalizedKeypoint],
                                   modelName: String? = nil,
                                   qualityScore: Double) {
        let frame = AVONormalizedPoseFrame(
            frameIndex: frameIndex,
            timeSeconds: timeSeconds,
            keypoints: keypoints,
            originArea: .review,
            modelName: modelName,
            qualityScore: qualityScore
        )

        bus.publishPoseFrame(frame)
        status = "REVIEW FRAME \(frameIndex) PUBLISHED"
    }

    public func markReadyForRetraining() -> String {
        let frames = bus.normalizedPoseTimeline.filter { $0.originArea == .review }
        let avgQuality = frames.isEmpty ? 0 : frames.map(\.qualityScore).reduce(0, +) / Double(frames.count)
        let weakFrames = frames.filter { $0.qualityScore < 0.55 }.count

        return "RETRAINING PACKAGE | FRAMES \(frames.count) | AVG QUALITY \(String(format: "%.2f", avgQuality)) | WEAK \(weakFrames)"
    }
}
