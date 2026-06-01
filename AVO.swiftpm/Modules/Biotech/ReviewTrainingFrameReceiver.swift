import Foundation

// MARK: - BIOTECH PHASE 117
// REVIEW TRAINING RECEIVER
//
// REVIEW can read this bridge to know if BIOTECH has captured frames
// for training.

@MainActor
public final class ReviewTrainingFrameReceiver: ObservableObject {

    @Published public private(set) var status: String = "REVIEW TRAINING RECEIVER READY"
    @Published public private(set) var lastImportedCount: Int = 0

    private let bridge: BiotechDataToReviewBridge

    public init(bridge: BiotechDataToReviewBridge? = nil) {
        self.bridge = bridge ?? BiotechDataToReviewBridge.shared
    }

    public func availableFrames() -> [BiotechTrainingImageSample] {
        bridge.buffer
    }

    public func importAvailableFrames() -> [BiotechTrainingImageSample] {
        let frames = bridge.buffer
        lastImportedCount = frames.count
        status = "IMPORTED \(frames.count) BIOTECH FRAMES FOR REVIEW"
        return frames
    }

    public func exportAvailableManifestCSV() -> String {
        bridge.exportManifestCSV()
    }

    public func exportAvailableManifestJSONData() throws -> Data {
        try bridge.exportManifestJSONData()
    }
}
