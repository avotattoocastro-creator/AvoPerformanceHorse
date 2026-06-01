import Foundation
import CoreGraphics
import SwiftUI

// MARK: - BIOMECH PHASE 125
// SCIENCE COMPLETE ENGINE
//
// Complete scientific layer:
// - joint angle curves
// - stride/gait phase candidates
// - symmetry
// - lameness risk
// - temporal stability
// - analytics manifest
//
// Input should come from normalized pose frames / BIOTECH pose frames.

public enum BiomechGaitPhase: String, Codable, CaseIterable, Hashable {
    case unknown
    case stance
    case swing
    case suspension
    case transition
}

public struct BiomechSciencePoint: Codable, Hashable {
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

public struct BiomechScienceFrame: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var points: [BiomechSciencePoint]

    public init(frameIndex: Int, timeSeconds: Double, points: [BiomechSciencePoint]) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.points = points
    }
}

public struct BiomechJointAngles: Codable, Hashable {
    public var topline: Double
    public var forelimb: Double
    public var hindlimb: Double
    public var neck: Double
    public var pelvis: Double

    public init(topline: Double = 0,
                forelimb: Double = 0,
                hindlimb: Double = 0,
                neck: Double = 0,
                pelvis: Double = 0) {
        self.topline = topline
        self.forelimb = forelimb
        self.hindlimb = hindlimb
        self.neck = neck
        self.pelvis = pelvis
    }
}

public struct BiomechScienceMetrics: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var angles: BiomechJointAngles
    public var symmetry: Double
    public var temporalStability: Double
    public var strideCandidate: Double
    public var gaitPhase: BiomechGaitPhase
    public var lamenessRisk: Double
    public var confidence: Double
    public var notes: [String]

    public init(frameIndex: Int,
                timeSeconds: Double,
                angles: BiomechJointAngles,
                symmetry: Double,
                temporalStability: Double,
                strideCandidate: Double,
                gaitPhase: BiomechGaitPhase,
                lamenessRisk: Double,
                confidence: Double,
                notes: [String]) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.angles = angles
        self.symmetry = symmetry
        self.temporalStability = temporalStability
        self.strideCandidate = strideCandidate
        self.gaitPhase = gaitPhase
        self.lamenessRisk = lamenessRisk
        self.confidence = confidence
        self.notes = notes
    }
}

public struct BiomechScienceSessionReport: Codable, Hashable {
    public var phase: String
    public var horseName: String
    public var createdAt: Date
    public var frameCount: Int
    public var averageSymmetry: Double
    public var averageLamenessRisk: Double
    public var averageTemporalStability: Double
    public var highRiskFrames: [Int]
    public var gaitPhaseCounts: [String: Int]
    public var metrics: [BiomechScienceMetrics]
}

public final class BiomechScienceCompleteEngine {

    public init() {}

    public func analyze(frames: [BiomechScienceFrame],
                        horseName: String = "SIN_CABALLO") -> BiomechScienceSessionReport {
        let sorted = frames.sorted { $0.frameIndex < $1.frameIndex }
        var output: [BiomechScienceMetrics] = []

        for frame in sorted {
            let previous = output.last
            let angles = computeAngles(frame)
            let symmetry = computeSymmetry(frame)
            let confidence = computeConfidence(frame)
            let stability = computeTemporalStability(frame: frame, previous: previous)
            let stride = computeStrideCandidate(frame: frame, previous: previous)
            let phase = classifyGaitPhase(stride: stride, stability: stability, symmetry: symmetry)
            let risk = computeRisk(symmetry: symmetry, stability: stability, confidence: confidence, stride: stride)

            var notes: [String] = []
            if risk > 0.65 { notes.append("HIGH_LAMENESS_RISK") }
            if stability < 0.45 { notes.append("LOW_TEMPORAL_STABILITY") }
            if confidence < 0.40 { notes.append("LOW_POINT_CONFIDENCE") }

            output.append(
                BiomechScienceMetrics(
                    frameIndex: frame.frameIndex,
                    timeSeconds: frame.timeSeconds,
                    angles: angles,
                    symmetry: symmetry,
                    temporalStability: stability,
                    strideCandidate: stride,
                    gaitPhase: phase,
                    lamenessRisk: risk,
                    confidence: confidence,
                    notes: notes
                )
            )
        }

        return buildReport(metrics: output, horseName: horseName)
    }

    public func computeAngles(_ frame: BiomechScienceFrame) -> BiomechJointAngles {
        BiomechJointAngles(
            topline: angle(frame, "Wither", "Back", "Croup"),
            forelimb: angle(frame, "Shoulder", "Elbow", "Knee"),
            hindlimb: angle(frame, "Hip", "Stifle", "Hock"),
            neck: angle(frame, "Nose", "Neck", "Wither"),
            pelvis: angle(frame, "Hip", "Croup", "Tail")
        )
    }

    public func angle(_ frame: BiomechScienceFrame,
                      _ a: String,
                      _ b: String,
                      _ c: String) -> Double {
        guard let pa = point(frame, a),
              let pb = point(frame, b),
              let pc = point(frame, c) else { return 0 }

        let ab = CGVector(dx: pa.x - pb.x, dy: pa.y - pb.y)
        let cb = CGVector(dx: pc.x - pb.x, dy: pc.y - pb.y)
        let dot = ab.dx * cb.dx + ab.dy * cb.dy
        let ma = sqrt(ab.dx * ab.dx + ab.dy * ab.dy)
        let mc = sqrt(cb.dx * cb.dx + cb.dy * cb.dy)

        guard ma > 0, mc > 0 else { return 0 }
        let cosValue = max(-1, min(1, dot / (ma * mc)))
        return acos(cosValue) * 180.0 / .pi
    }

    public func computeSymmetry(_ frame: BiomechScienceFrame) -> Double {
        let left = frame.points.filter {
            let n = $0.name.lowercased()
            return n.contains("left") || n.contains("near")
        }

        let right = frame.points.filter {
            let n = $0.name.lowercased()
            return n.contains("right") || n.contains("far")
        }

        guard !left.isEmpty, !right.isEmpty else {
            return computeConfidence(frame)
        }

        let lx = left.map(\.x).reduce(0, +) / Double(left.count)
        let rx = right.map(\.x).reduce(0, +) / Double(right.count)
        let ly = left.map(\.y).reduce(0, +) / Double(left.count)
        let ry = right.map(\.y).reduce(0, +) / Double(right.count)

        let diff = sqrt(pow(lx - rx, 2) + pow(ly - ry, 2))
        return max(0, min(1, 1 - diff))
    }

    public func computeConfidence(_ frame: BiomechScienceFrame) -> Double {
        guard !frame.points.isEmpty else { return 0 }
        return max(0, min(1, frame.points.map(\.confidence).reduce(0, +) / Double(frame.points.count)))
    }

    public func computeTemporalStability(frame: BiomechScienceFrame,
                                         previous: BiomechScienceMetrics?) -> Double {
        guard let previous else { return 1 }

        let currentAngles = computeAngles(frame)
        let delta =
            abs(currentAngles.topline - previous.angles.topline) * 0.35 +
            abs(currentAngles.forelimb - previous.angles.forelimb) * 0.25 +
            abs(currentAngles.hindlimb - previous.angles.hindlimb) * 0.25 +
            abs(currentAngles.pelvis - previous.angles.pelvis) * 0.15

        return max(0, min(1, 1 - delta / 70.0))
    }

    public func computeStrideCandidate(frame: BiomechScienceFrame,
                                       previous: BiomechScienceMetrics?) -> Double {
        let limbPoints = frame.points.filter {
            let n = $0.name.lowercased()
            return n.contains("hoof") || n.contains("fetlock") || n.contains("knee") || n.contains("hock")
        }

        guard !limbPoints.isEmpty else { return previous?.strideCandidate ?? 0 }

        let avgY = limbPoints.map(\.y).reduce(0, +) / Double(limbPoints.count)
        return max(0, min(1, avgY))
    }

    public func classifyGaitPhase(stride: Double,
                                  stability: Double,
                                  symmetry: Double) -> BiomechGaitPhase {
        if stability < 0.35 { return .transition }
        if stride > 0.72 { return .stance }
        if stride < 0.36 { return .swing }
        if symmetry > 0.84 && stability > 0.72 { return .suspension }
        return .unknown
    }

    public func computeRisk(symmetry: Double,
                            stability: Double,
                            confidence: Double,
                            stride: Double) -> Double {
        let asymmetryRisk = 1 - symmetry
        let instabilityRisk = 1 - stability
        let confidenceRisk = 1 - confidence
        let strideRisk = abs(stride - 0.55)

        return max(0, min(1,
            asymmetryRisk * 0.40 +
            instabilityRisk * 0.28 +
            confidenceRisk * 0.17 +
            strideRisk * 0.15
        ))
    }

    public func buildReport(metrics: [BiomechScienceMetrics],
                            horseName: String) -> BiomechScienceSessionReport {
        let count = max(1, metrics.count)
        let avgSym = metrics.map(\.symmetry).reduce(0, +) / Double(count)
        let avgRisk = metrics.map(\.lamenessRisk).reduce(0, +) / Double(count)
        let avgStability = metrics.map(\.temporalStability).reduce(0, +) / Double(count)
        let highRisk = metrics.filter { $0.lamenessRisk > 0.65 }.map(\.frameIndex)

        let grouped = Dictionary(grouping: metrics, by: { $0.gaitPhase.rawValue })
        let counts = grouped.mapValues { $0.count }

        return BiomechScienceSessionReport(
            phase: "125",
            horseName: horseName,
            createdAt: Date(),
            frameCount: metrics.count,
            averageSymmetry: avgSym,
            averageLamenessRisk: avgRisk,
            averageTemporalStability: avgStability,
            highRiskFrames: highRisk,
            gaitPhaseCounts: counts,
            metrics: metrics
        )
    }

    private func point(_ frame: BiomechScienceFrame, _ name: String) -> BiomechSciencePoint? {
        frame.points.first { $0.name.lowercased() == name.lowercased() }
    }
}

public struct BiomechScienceCompletePanel: View {

    public var report: BiomechScienceSessionReport?

    public init(report: BiomechScienceSessionReport?) {
        self.report = report
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BIOMECH SCIENCE")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            if let report {
                HStack {
                    metric("FR", "\(report.frameCount)")
                    metric("SYM", String(format: "%.2f", report.averageSymmetry))
                    metric("RISK", String(format: "%.2f", report.averageLamenessRisk))
                    metric("STAB", String(format: "%.2f", report.averageTemporalStability))
                }

                Text("HIGH RISK FRAMES: \(report.highRiskFrames.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(report.highRiskFrames.isEmpty ? .green : .orange)
            } else {
                Text("NO SCIENCE REPORT")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
