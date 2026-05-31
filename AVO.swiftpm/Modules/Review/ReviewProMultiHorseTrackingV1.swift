import Foundation
import CoreGraphics

// PHASE 105
// Multi horse temporal tracking base

public struct ReviewProTrackedHorse: Codable, Hashable, Identifiable {
    public var id: UUID
    public var label: String
    public var lastCenterX: Double
    public var lastCenterY: Double
    public var lastFrame: Int
    public var confidence: Double

    public init(label: String,
                lastCenterX: Double,
                lastCenterY: Double,
                lastFrame: Int,
                confidence: Double) {
        self.id = UUID()
        self.label = label
        self.lastCenterX = lastCenterX
        self.lastCenterY = lastCenterY
        self.lastFrame = lastFrame
        self.confidence = confidence
    }
}

public final class ReviewProMultiHorseTrackingV1 {

    public private(set) var horses: [ReviewProTrackedHorse] = []

    public init() {}

    public func update(centerX: Double,
                       centerY: Double,
                       frame: Int,
                       confidence: Double) -> ReviewProTrackedHorse {

        if let idx = horses.firstIndex(where: {
            abs($0.lastCenterX - centerX) < 0.12 &&
            abs($0.lastCenterY - centerY) < 0.12
        }) {
            horses[idx].lastCenterX = centerX
            horses[idx].lastCenterY = centerY
            horses[idx].lastFrame = frame
            horses[idx].confidence = confidence
            return horses[idx]
        }

        let horse = ReviewProTrackedHorse(
            label: "HORSE_\(horses.count + 1)",
            lastCenterX: centerX,
            lastCenterY: centerY,
            lastFrame: frame,
            confidence: confidence
        )

        horses.append(horse)
        return horse
    }
}
