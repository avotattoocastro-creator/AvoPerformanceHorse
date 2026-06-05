import Foundation
import CoreGraphics

// MARK: - REVIEW PHASE 123
// TEMPORAL AUTOPose CLOSURE ENGINE
//
// Lightweight complete temporal pass for REVIEW training.
// It does smoothing, confidence propagation, occlusion recovery and QA notes.

public struct ReviewTemporalKeypoint: Codable, Hashable {
    public var name: String
    public var x: Double
    public var y: Double
    public var confidence: Double
    public var recovered: Bool

    public init(name: String, x: Double, y: Double, confidence: Double, recovered: Bool = false) {
        self.name = name
        self.x = x
        self.y = y
        self.confidence = confidence
        self.recovered = recovered
    }
}

public struct ReviewTemporalFrame: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var points: [ReviewTemporalKeypoint]
    public var stability: Double
    public var quality: Double

    public init(frameIndex: Int, timeSeconds: Double, points: [ReviewTemporalKeypoint], stability: Double = 1, quality: Double = 0) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.points = points
        self.stability = stability
        self.quality = quality
    }
}

public final class ReviewTemporalAutoPoseClosureEngine {

    public var smoothing: Double = 0.64
    public var lowConfidenceThreshold: Double = 0.30
    public var maxOcclusionGap: Int = 6

    public init() {}

    public func process(_ frames: [ReviewTemporalFrame]) -> [ReviewTemporalFrame] {
        guard !frames.isEmpty else { return [] }

        var output: [ReviewTemporalFrame] = []
        var lastGood: [String: (frame: Int, point: ReviewTemporalKeypoint)] = [:]

        for raw in frames.sorted(by: { $0.frameIndex < $1.frameIndex }) {
            var processed: [ReviewTemporalKeypoint] = []

            for point in raw.points {
                var p = point

                if p.confidence < lowConfidenceThreshold,
                   let previous = lastGood[p.name],
                   raw.frameIndex - previous.frame <= maxOcclusionGap {
                    p.x = previous.point.x
                    p.y = previous.point.y
                    p.confidence = previous.point.confidence * 0.68
                    p.recovered = true
                } else if let prevFrame = output.last,
                          let prevPoint = prevFrame.points.first(where: { $0.name == p.name }) {
                    p.x = prevPoint.x * (1 - smoothing) + p.x * smoothing
                    p.y = prevPoint.y * (1 - smoothing) + p.y * smoothing
                    p.confidence = max(p.confidence, prevPoint.confidence * 0.88)
                }

                if p.confidence >= lowConfidenceThreshold {
                    lastGood[p.name] = (raw.frameIndex, p)
                }

                processed.append(p)
            }

            let stability = estimateStability(previous: output.last, points: processed)
            let quality = estimateQuality(points: processed, stability: stability)

            output.append(
                ReviewTemporalFrame(
                    frameIndex: raw.frameIndex,
                    timeSeconds: raw.timeSeconds,
                    points: processed,
                    stability: stability,
                    quality: quality
                )
            )
        }

        return output
    }

    private func estimateStability(previous: ReviewTemporalFrame?, points: [ReviewTemporalKeypoint]) -> Double {
        guard let previous else { return 1 }

        var jumps: [Double] = []
        for p in points {
            guard let old = previous.points.first(where: { $0.name == p.name }) else { continue }
            let dx = p.x - old.x
            let dy = p.y - old.y
            jumps.append(sqrt(dx*dx + dy*dy))
        }

        let avg = jumps.isEmpty ? 0 : jumps.reduce(0, +) / Double(jumps.count)
        return max(0, min(1, 1 - avg / 0.12))
    }

    private func estimateQuality(points: [ReviewTemporalKeypoint], stability: Double) -> Double {
        guard !points.isEmpty else { return 0 }
        let avgConfidence = points.map(\.confidence).reduce(0, +) / Double(points.count)
        let recoveredPenalty = Double(points.filter(\.recovered).count) / Double(max(1, points.count)) * 0.25
        return max(0, min(1, avgConfidence * 0.65 + stability * 0.35 - recoveredPenalty))
    }
}
