import Foundation
import CoreGraphics

// MARK: - BIOTECH PHASE 106
// Biomech Studio Engine V1
//
// Safe additive module.
// Purpose:
// - Keep REVIEW focused on IA retraining.
// - Move biomechanical analysis into BIOTECH.
// - Provide session-level metrics for live/replay analysis.

public struct BiotechJointPoint: Codable, Hashable {
    public var name: String
    public var x: Double
    public var y: Double
    public var confidence: Double

    public init(name: String, x: Double, y: Double, confidence: Double) {
        self.name = name
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public struct BiotechPoseFrame: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var points: [BiotechJointPoint]

    public init(frameIndex: Int, timeSeconds: Double, points: [BiotechJointPoint]) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.points = points
    }
}

public struct BiotechBiomechFrameMetrics: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var toplineAngle: Double
    public var forelimbAngle: Double
    public var hindlimbAngle: Double
    public var symmetry: Double
    public var stability: Double
    public var risk: Double

    public init(frameIndex: Int,
                timeSeconds: Double,
                toplineAngle: Double,
                forelimbAngle: Double,
                hindlimbAngle: Double,
                symmetry: Double,
                stability: Double,
                risk: Double) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.toplineAngle = toplineAngle
        self.forelimbAngle = forelimbAngle
        self.hindlimbAngle = hindlimbAngle
        self.symmetry = symmetry
        self.stability = stability
        self.risk = risk
    }
}

public final class BiotechBiomechStudioEngineV1 {

    public init() {}

    public func analyze(frames: [BiotechPoseFrame]) -> [BiotechBiomechFrameMetrics] {
        var output: [BiotechBiomechFrameMetrics] = []

        for frame in frames {
            let prev = output.last

            let topline = angle(frame, "Wither", "Back", "Croup")
            let fore = angle(frame, "Shoulder", "Elbow", "Knee")
            let hind = angle(frame, "Hip", "Stifle", "Hock")
            let symmetry = estimateSymmetry(frame)
            let stability = estimateStability(current: frame, previousMetrics: prev)
            let risk = max(0, min(1, (1 - symmetry) * 0.55 + (1 - stability) * 0.45))

            output.append(
                BiotechBiomechFrameMetrics(
                    frameIndex: frame.frameIndex,
                    timeSeconds: frame.timeSeconds,
                    toplineAngle: topline,
                    forelimbAngle: fore,
                    hindlimbAngle: hind,
                    symmetry: symmetry,
                    stability: stability,
                    risk: risk
                )
            )
        }

        return output
    }

    private func point(_ frame: BiotechPoseFrame, _ name: String) -> CGPoint? {
        guard let p = frame.points.first(where: { $0.name.lowercased() == name.lowercased() }) else {
            return nil
        }
        return CGPoint(x: p.x, y: p.y)
    }

    public func angle(_ frame: BiotechPoseFrame, _ aName: String, _ bName: String, _ cName: String) -> Double {
        guard let a = point(frame, aName),
              let b = point(frame, bName),
              let c = point(frame, cName) else { return 0 }

        let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = ab.dx * cb.dx + ab.dy * cb.dy
        let magA = sqrt(ab.dx * ab.dx + ab.dy * ab.dy)
        let magC = sqrt(cb.dx * cb.dx + cb.dy * cb.dy)

        guard magA > 0, magC > 0 else { return 0 }

        let value = max(-1, min(1, dot / (magA * magC)))
        return acos(value) * 180.0 / .pi
    }

    public func estimateSymmetry(_ frame: BiotechPoseFrame) -> Double {
        let left = frame.points.filter {
            let n = $0.name.lowercased()
            return n.contains("left") || n.contains("near")
        }

        let right = frame.points.filter {
            let n = $0.name.lowercased()
            return n.contains("right") || n.contains("far")
        }

        guard !left.isEmpty, !right.isEmpty else {
            let avgConf = frame.points.map(\.confidence).reduce(0, +) / Double(max(1, frame.points.count))
            return max(0, min(1, avgConf))
        }

        let leftY = left.map(\.y).reduce(0, +) / Double(left.count)
        let rightY = right.map(\.y).reduce(0, +) / Double(right.count)

        return max(0, min(1, 1 - abs(leftY - rightY)))
    }

    public func estimateStability(current: BiotechPoseFrame,
                                  previousMetrics: BiotechBiomechFrameMetrics?) -> Double {
        guard let previousMetrics else { return 1 }

        let currentTopline = angle(current, "Wither", "Back", "Croup")
        let delta = abs(currentTopline - previousMetrics.toplineAngle)

        return max(0, min(1, 1 - delta / 45.0))
    }

    public func summary(metrics: [BiotechBiomechFrameMetrics]) -> String {
        guard !metrics.isEmpty else { return "NO BIOMECH DATA" }

        let avgSym = metrics.map(\.symmetry).reduce(0, +) / Double(metrics.count)
        let avgRisk = metrics.map(\.risk).reduce(0, +) / Double(metrics.count)
        let highRisk = metrics.filter { $0.risk > 0.65 }.count

        return "FRAMES \(metrics.count) | SYM \(String(format: "%.2f", avgSym)) | RISK \(String(format: "%.2f", avgRisk)) | HIGH \(highRisk)"
    }
}
