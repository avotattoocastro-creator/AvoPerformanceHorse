import Foundation
import CoreGraphics

// MARK: - REVIEW PRO PHASE 102
// TEMPORAL AUTOPOSE COMPLETE
//
// Additive module.
// Purpose:
// - Smooth keypoints across video frames.
// - Recover short occlusions.
// - Propagate confidence.
// - Detect temporal jumps.
// - Produce stable pose frames ready for biomech analysis.

public struct ReviewProPosePoint: Codable, Hashable {
    public var name: String
    public var x: Double
    public var y: Double
    public var confidence: Double
    public var isPredicted: Bool
    public var isOcclusionRecovered: Bool

    public init(name: String,
                x: Double,
                y: Double,
                confidence: Double,
                isPredicted: Bool = false,
                isOcclusionRecovered: Bool = false) {
        self.name = name
        self.x = x
        self.y = y
        self.confidence = confidence
        self.isPredicted = isPredicted
        self.isOcclusionRecovered = isOcclusionRecovered
    }
}

public struct ReviewProPoseFrame: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var points: [ReviewProPosePoint]
    public var globalConfidence: Double
    public var temporalStability: Double

    public init(frameIndex: Int,
                timeSeconds: Double,
                points: [ReviewProPosePoint],
                globalConfidence: Double = 0,
                temporalStability: Double = 1) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.points = points
        self.globalConfidence = globalConfidence
        self.temporalStability = temporalStability
    }
}

public final class ReviewProTemporalAutoPoseComplete {

    public var smoothingAlpha: Double = 0.68
    public var maxRecoverableOcclusionFrames: Int = 8
    public var minimumUsableConfidence: Double = 0.28
    public var jumpWarningThreshold: Double = 0.18

    public init() {}

    public func process(frames: [ReviewProPoseFrame]) -> [ReviewProPoseFrame] {
        guard !frames.isEmpty else { return [] }

        var output: [ReviewProPoseFrame] = []
        var lastGoodByName: [String: (frame: Int, point: ReviewProPosePoint)] = [:]

        for frame in frames {
            let previous = output.last
            var processedPoints: [ReviewProPosePoint] = []

            for point in frame.points {
                var p = point

                if point.confidence < minimumUsableConfidence,
                   let last = lastGoodByName[point.name],
                   frame.frameIndex - last.frame <= maxRecoverableOcclusionFrames {
                    p.x = last.point.x
                    p.y = last.point.y
                    p.confidence = max(0.05, last.point.confidence * 0.72)
                    p.isPredicted = true
                    p.isOcclusionRecovered = true
                } else if let previousPoint = previous?.points.first(where: { $0.name == point.name }) {
                    p.x = previousPoint.x * (1 - smoothingAlpha) + point.x * smoothingAlpha
                    p.y = previousPoint.y * (1 - smoothingAlpha) + point.y * smoothingAlpha
                    p.confidence = max(point.confidence, previousPoint.confidence * 0.90)
                }

                if p.confidence >= minimumUsableConfidence {
                    lastGoodByName[p.name] = (frame.frameIndex, p)
                }

                processedPoints.append(p)
            }

            let stability = temporalStability(previous: previous, currentPoints: processedPoints)
            let confidence = globalConfidence(points: processedPoints)

            output.append(
                ReviewProPoseFrame(
                    frameIndex: frame.frameIndex,
                    timeSeconds: frame.timeSeconds,
                    points: processedPoints,
                    globalConfidence: confidence,
                    temporalStability: stability
                )
            )
        }

        return output
    }

    public func globalConfidence(points: [ReviewProPosePoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        let sum = points.map(\.confidence).reduce(0, +)
        return max(0, min(1, sum / Double(points.count)))
    }

    public func temporalStability(previous: ReviewProPoseFrame?,
                                  currentPoints: [ReviewProPosePoint]) -> Double {
        guard let previous else { return 1 }

        var jumps: [Double] = []

        for p in currentPoints {
            guard let old = previous.points.first(where: { $0.name == p.name }) else { continue }
            let dx = p.x - old.x
            let dy = p.y - old.y
            jumps.append(sqrt(dx*dx + dy*dy))
        }

        guard !jumps.isEmpty else { return 1 }

        let avgJump = jumps.reduce(0, +) / Double(jumps.count)
        return max(0, min(1, 1 - (avgJump / jumpWarningThreshold)))
    }

    public func interpolateMissingFrames(_ frames: [ReviewProPoseFrame]) -> [ReviewProPoseFrame] {
        guard frames.count > 1 else { return frames }

        var result: [ReviewProPoseFrame] = []

        for i in 0..<(frames.count - 1) {
            let a = frames[i]
            let b = frames[i + 1]
            result.append(a)

            let gap = b.frameIndex - a.frameIndex
            if gap > 1 {
                for step in 1..<gap {
                    let t = Double(step) / Double(gap)
                    let points = interpolatePoints(a.points, b.points, t: t)
                    result.append(
                        ReviewProPoseFrame(
                            frameIndex: a.frameIndex + step,
                            timeSeconds: a.timeSeconds + ((b.timeSeconds - a.timeSeconds) * t),
                            points: points,
                            globalConfidence: globalConfidence(points: points),
                            temporalStability: 0.75
                        )
                    )
                }
            }
        }

        if let last = frames.last {
            result.append(last)
        }

        return result
    }

    private func interpolatePoints(_ a: [ReviewProPosePoint],
                                   _ b: [ReviewProPosePoint],
                                   t: Double) -> [ReviewProPosePoint] {
        var result: [ReviewProPosePoint] = []

        for pa in a {
            guard let pb = b.first(where: { $0.name == pa.name }) else {
                result.append(pa)
                continue
            }

            result.append(
                ReviewProPosePoint(
                    name: pa.name,
                    x: pa.x + (pb.x - pa.x) * t,
                    y: pa.y + (pb.y - pa.y) * t,
                    confidence: min(pa.confidence, pb.confidence) * 0.85,
                    isPredicted: true,
                    isOcclusionRecovered: false
                )
            )
        }

        return result
    }
}
