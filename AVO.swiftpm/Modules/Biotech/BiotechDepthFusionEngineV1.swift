import Foundation
import CoreGraphics

// MARK: - BIOTECH PHASE 106
// Depth Fusion Engine V1
//
// Safe additive RGB + Depth helper for BIOTECH.
// Intended to connect later to ARKit sceneDepth.

public struct BiotechDepthPoint: Codable, Hashable {
    public var x: Double
    public var y: Double
    public var depthMeters: Double
    public var confidence: Double

    public init(x: Double, y: Double, depthMeters: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.depthMeters = depthMeters
        self.confidence = confidence
    }
}

public struct BiotechDepthFusionReport: Codable, Hashable {
    public var estimatedHorseDistance: Double
    public var foregroundRatio: Double
    public var bodyDepthSpread: Double
    public var usableDepthConfidence: Double

    public init(estimatedHorseDistance: Double,
                foregroundRatio: Double,
                bodyDepthSpread: Double,
                usableDepthConfidence: Double) {
        self.estimatedHorseDistance = estimatedHorseDistance
        self.foregroundRatio = foregroundRatio
        self.bodyDepthSpread = bodyDepthSpread
        self.usableDepthConfidence = usableDepthConfidence
    }
}

public final class BiotechDepthFusionEngineV1 {

    public init() {}

    public func analyze(points: [BiotechDepthPoint],
                        foregroundMaxDistance: Double = 6.0) -> BiotechDepthFusionReport {
        guard !points.isEmpty else {
            return BiotechDepthFusionReport(
                estimatedHorseDistance: 0,
                foregroundRatio: 0,
                bodyDepthSpread: 0,
                usableDepthConfidence: 0
            )
        }

        let usable = points.filter { $0.confidence > 0.35 && $0.depthMeters > 0.15 }
        guard !usable.isEmpty else {
            return BiotechDepthFusionReport(
                estimatedHorseDistance: 0,
                foregroundRatio: 0,
                bodyDepthSpread: 0,
                usableDepthConfidence: 0
            )
        }

        let foreground = usable.filter { $0.depthMeters <= foregroundMaxDistance }
        let avg = foreground.map(\.depthMeters).reduce(0, +) / Double(max(1, foreground.count))
        let minDepth = foreground.map(\.depthMeters).min() ?? 0
        let maxDepth = foreground.map(\.depthMeters).max() ?? 0

        return BiotechDepthFusionReport(
            estimatedHorseDistance: avg,
            foregroundRatio: Double(foreground.count) / Double(usable.count),
            bodyDepthSpread: max(0, maxDepth - minDepth),
            usableDepthConfidence: usable.map(\.confidence).reduce(0, +) / Double(usable.count)
        )
    }

    public func depthAwarePose(frame: BiotechPoseFrame,
                               depthPoints: [BiotechDepthPoint],
                               radius: Double = 0.035) -> [(point: BiotechJointPoint, depth: Double?)] {
        frame.points.map { joint in
            let nearby = depthPoints.filter {
                abs($0.x - joint.x) <= radius && abs($0.y - joint.y) <= radius
            }

            let depth = nearby.isEmpty ? nil : nearby.map(\.depthMeters).reduce(0, +) / Double(nearby.count)
            return (joint, depth)
        }
    }
}
