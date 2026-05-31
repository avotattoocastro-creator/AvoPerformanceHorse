import Foundation
import CoreGraphics

// MARK: - REVIEW PRO PHASE 102
// COMPLETE BIOMECH ENGINE
//
// Additive module.
// Purpose:
// - Calculate angles.
// - Build time-series curves.
// - Estimate stride rhythm.
// - Score symmetry and lameness risk.
// - Export analysis-ready metrics.

public struct ReviewProBiomechAngleSample: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var frameIndex: Int
    public var timeSeconds: Double
    public var name: String
    public var degrees: Double

    public init(frameIndex: Int, timeSeconds: Double, name: String, degrees: Double) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.name = name
        self.degrees = degrees
    }
}

public struct ReviewProBiomechFrameReport: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var angles: [ReviewProBiomechAngleSample]
    public var symmetryScore: Double
    public var locomotionRisk: Double
    public var notes: [String]

    public init(frameIndex: Int,
                timeSeconds: Double,
                angles: [ReviewProBiomechAngleSample],
                symmetryScore: Double,
                locomotionRisk: Double,
                notes: [String]) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.angles = angles
        self.symmetryScore = symmetryScore
        self.locomotionRisk = locomotionRisk
        self.notes = notes
    }
}

public final class ReviewProBiomechCompleteEngine {

    public init() {}

    public func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)

        let dot = ab.dx * cb.dx + ab.dy * cb.dy
        let magA = sqrt(ab.dx * ab.dx + ab.dy * ab.dy)
        let magC = sqrt(cb.dx * cb.dx + cb.dy * cb.dy)

        guard magA > 0, magC > 0 else { return 0 }

        let cosValue = max(-1, min(1, dot / (magA * magC)))
        return acos(cosValue) * 180 / .pi
    }

    public func analyzePoseFrames(_ frames: [ReviewProPoseFrame]) -> [ReviewProBiomechFrameReport] {
        frames.map { frame in
            analyzeSingleFrame(frame)
        }
    }

    public func analyzeSingleFrame(_ frame: ReviewProPoseFrame) -> ReviewProBiomechFrameReport {
        var angles: [ReviewProBiomechAngleSample] = []
        var notes: [String] = []

        func point(_ name: String) -> CGPoint? {
            guard let p = frame.points.first(where: { $0.name.lowercased() == name.lowercased() }) else { return nil }
            return CGPoint(x: p.x, y: p.y)
        }

        if let shoulder = point("Shoulder"),
           let elbow = point("Elbow"),
           let knee = point("Knee") {
            angles.append(
                ReviewProBiomechAngleSample(
                    frameIndex: frame.frameIndex,
                    timeSeconds: frame.timeSeconds,
                    name: "Forelimb Shoulder-Elbow-Knee",
                    degrees: angle(a: shoulder, b: elbow, c: knee)
                )
            )
        }

        if let hip = point("Hip"),
           let stifle = point("Stifle"),
           let hock = point("Hock") {
            angles.append(
                ReviewProBiomechAngleSample(
                    frameIndex: frame.frameIndex,
                    timeSeconds: frame.timeSeconds,
                    name: "Hindlimb Hip-Stifle-Hock",
                    degrees: angle(a: hip, b: stifle, c: hock)
                )
            )
        }

        if let wither = point("Wither"),
           let back = point("Back"),
           let croup = point("Croup") {
            angles.append(
                ReviewProBiomechAngleSample(
                    frameIndex: frame.frameIndex,
                    timeSeconds: frame.timeSeconds,
                    name: "Topline Wither-Back-Croup",
                    degrees: angle(a: wither, b: back, c: croup)
                )
            )
        }

        let recoveredCount = frame.points.filter(\.isOcclusionRecovered).count
        if recoveredCount > 0 {
            notes.append("Occlusion recovered keypoints: \(recoveredCount)")
        }

        if frame.temporalStability < 0.45 {
            notes.append("Temporal instability detected.")
        }

        let symmetry = estimateFrameSymmetry(frame)
        let risk = max(0, min(1, (1 - symmetry) * 0.65 + (1 - frame.temporalStability) * 0.35))

        if risk > 0.65 {
            notes.append("High locomotion risk candidate.")
        } else if risk > 0.40 {
            notes.append("Moderate locomotion risk candidate.")
        }

        return ReviewProBiomechFrameReport(
            frameIndex: frame.frameIndex,
            timeSeconds: frame.timeSeconds,
            angles: angles,
            symmetryScore: symmetry,
            locomotionRisk: risk,
            notes: notes
        )
    }

    public func estimateFrameSymmetry(_ frame: ReviewProPoseFrame) -> Double {

        let left = frame.points.filter {
            let n = $0.name.lowercased()
            return n.contains("left") || n.contains("near")
        }

        let right = frame.points.filter {
            let n = $0.name.lowercased()
            return n.contains("right") || n.contains("far")
        }

        guard !left.isEmpty, !right.isEmpty else {
            return frame.globalConfidence
        }

        let leftAvgY = left.map(\.y).reduce(0, +) / Double(left.count)
        let rightAvgY = right.map(\.y).reduce(0, +) / Double(right.count)

        let diff = abs(leftAvgY - rightAvgY)
        return max(0, min(1, 1 - diff))
    }

    public func curve(named name: String,
                      from reports: [ReviewProBiomechFrameReport]) -> [(time: Double, value: Double)] {
        reports.compactMap { report in
            guard let angle = report.angles.first(where: { $0.name == name }) else { return nil }
            return (report.timeSeconds, angle.degrees)
        }
    }

    public func exportCSV(reports: [ReviewProBiomechFrameReport]) -> String {
        var rows = ["frame,time,angle_name,degrees,symmetry,risk,notes"]

        for report in reports {
            if report.angles.isEmpty {
                rows.append("\(report.frameIndex),\(report.timeSeconds),,,\(report.symmetryScore),\(report.locomotionRisk),\"\(report.notes.joined(separator: " | "))\"")
            } else {
                for angle in report.angles {
                    rows.append("\(report.frameIndex),\(report.timeSeconds),\"\(angle.name)\",\(angle.degrees),\(report.symmetryScore),\(report.locomotionRisk),\"\(report.notes.joined(separator: " | "))\"")
                }
            }
        }

        return rows.joined(separator: "\n")
    }
}
