import SwiftUI
import Foundation

// MARK: - AVO LiDAR 3D Fusion Models

struct AVOLiDARPoint3D: Codable, Identifiable, Hashable {
    var id = UUID()
    var x: Double      // normalized lateral position -1...1
    var y: Double      // normalized vertical position -1...1
    var z: Double      // meters from camera
    var intensity: Double
    var age: Double
    var isHorseCandidate: Bool
}

struct AVOLiDARFusionReport: Codable, Hashable {
    var pointCount: Int
    var horseCandidateCount: Int
    var depthQuality: Double
    var stability: Double
    var bodyBoxLocked: Bool
    var source: String
}

final class AVOLiDARTemporalFusionEngine {
    private var accumulated: [AVOLiDARPoint3D] = []
    private var lastCenterDepth: Double = 0
    private var lastUpdate: TimeInterval = 0
    private let maxPoints = 5200

    func reset() {
        accumulated.removeAll()
        lastCenterDepth = 0
        lastUpdate = 0
    }

    func fuse(points2D: [AVOLiDARPoint2D], referenceDistance: Double, quality: Double, timestamp: TimeInterval) -> (points: [AVOLiDARPoint3D], report: AVOLiDARFusionReport) {
        guard !points2D.isEmpty else {
            let report = AVOLiDARFusionReport(pointCount: accumulated.count,
                                             horseCandidateCount: accumulated.filter { $0.isHorseCandidate }.count,
                                             depthQuality: quality,
                                             stability: 0,
                                             bodyBoxLocked: false,
                                             source: "NO DEPTH POINTS")
            return (accumulated, report)
        }

        let dt = lastUpdate == 0 ? 0.10 : min(0.40, max(0.03, timestamp - lastUpdate))
        lastUpdate = timestamp

        let validDepths = points2D.map { $0.z }.filter { $0.isFinite && $0 > 0.20 && $0 < 12.0 }.sorted()
        let medianDepth = validDepths.isEmpty ? referenceDistance : validDepths[validDepths.count / 2]
        let stableDepth = lastCenterDepth == 0 ? medianDepth : (lastCenterDepth * 0.82 + medianDepth * 0.18)
        lastCenterDepth = stableDepth

        var incoming: [AVOLiDARPoint3D] = []
        incoming.reserveCapacity(points2D.count)

        for p in points2D {
            let nx = (p.x - 0.5) * 2.0
            let ny = (0.5 - p.y) * 2.0
            let dz = abs(p.z - stableDepth)

            // Real-time horse candidate pre-filter.
            // It does not replace CoreML horse segmentation; it prepares a stable body cloud from LiDAR depth.
            let bodyHorizontal = abs(nx) < 0.92
            let bodyVertical = ny > -0.92 && ny < 0.82
            let depthBand = dz < max(0.65, stableDepth * 0.20)
            let candidate = bodyHorizontal && bodyVertical && depthBand && p.confidence > 0.18
            let intensity = max(0.05, min(1.0, p.confidence * (candidate ? 1.0 : 0.42)))

            incoming.append(AVOLiDARPoint3D(x: nx,
                                            y: ny,
                                            z: p.z,
                                            intensity: intensity,
                                            age: 0,
                                            isHorseCandidate: candidate))
        }

        // Age and fade older cloud. This creates a temporal fusion volume instead of a flat single frame.
        accumulated = accumulated.compactMap { old in
            var o = old
            o.age += dt
            o.intensity *= 0.965
            return (o.age < 3.8 && o.intensity > 0.06) ? o : nil
        }

        // Add a reduced but stable number of incoming points.
        let targetIncoming = min(850, incoming.count)
        let stride = max(1, incoming.count / max(1, targetIncoming))
        for (idx, p) in incoming.enumerated() where idx % stride == 0 {
            accumulated.append(p)
        }

        if accumulated.count > maxPoints {
            accumulated.removeFirst(accumulated.count - maxPoints)
        }

        let horseCount = accumulated.filter { $0.isHorseCandidate }.count
        let stability = min(1.0, Double(accumulated.count) / Double(maxPoints)) * quality
        let locked = horseCount > 550 && quality > 0.35
        let report = AVOLiDARFusionReport(pointCount: accumulated.count,
                                         horseCandidateCount: horseCount,
                                         depthQuality: quality,
                                         stability: stability,
                                         bodyBoxLocked: locked,
                                         source: "TEMPORAL DEPTH FUSION + HORSE BODY FILTER")
        return (accumulated, report)
    }
}

struct AVOFusedHorsePointCloudView: View {
    var points: [AVOLiDARPoint3D]
    var report: AVOLiDARFusionReport?
    var referenceDistance: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                AVOCalibrationDepthMeshBackground()

                Canvas { context, size in
                    drawFusionBox(context: context, size: size)

                    let sorted = points.sorted { $0.z > $1.z }
                    for point in sorted {
                        let perspective = max(0.55, min(1.35, referenceDistance / max(0.30, point.z)))
                        let px = size.width * (0.50 + CGFloat(point.x) * 0.42 * CGFloat(perspective))
                        let py = size.height * (0.50 - CGFloat(point.y) * 0.40)
                        let depthDelta = abs(point.z - referenceDistance)
                        let radius = CGFloat(max(1.1, min(4.4, 4.8 - depthDelta)))
                        let alpha = max(0.10, min(0.95, point.intensity))
                        let rect = CGRect(x: px - radius * 0.5, y: py - radius * 0.5, width: radius, height: radius)

                        let color: Color
                        if point.isHorseCandidate {
                            color = depthDelta < 0.55 ? Color.cyan.opacity(alpha) : Color.blue.opacity(alpha * 0.75)
                        } else {
                            color = Color.green.opacity(alpha * 0.45)
                        }
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }

                    drawGroundPlane(context: context, size: size)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("REAL 3D TEMPORAL LiDAR FUSION")
                        .foregroundColor(.cyan)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                    Text("POINT CLOUD \(points.count) · HORSE CANDIDATES \(report?.horseCandidateCount ?? 0) · STABILITY \(Int((report?.stability ?? 0) * 100))%")
                        .foregroundColor(.green)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .padding(12)

                HStack(spacing: 10) {
                    capsule("DEPTH", "\(String(format: "%.2f", referenceDistance)) m", .cyan)
                    capsule("BODY LOCK", (report?.bodyBoxLocked ?? false) ? "LOCKED" : "SEARCH", (report?.bodyBoxLocked ?? false) ? .green : .orange)
                    capsule("FUSION", "ACTIVE", .green)
                    capsule("COREML", "READY SLOT", .purple)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    private func drawFusionBox(context: GraphicsContext, size: CGSize) {
        var box = Path()
        let front = CGRect(x: size.width * 0.13, y: size.height * 0.18, width: size.width * 0.72, height: size.height * 0.62)
        let back = front.offsetBy(dx: size.width * 0.08, dy: -size.height * 0.09)
        box.addRoundedRect(in: front, cornerSize: CGSize(width: 8, height: 8))
        box.addRoundedRect(in: back, cornerSize: CGSize(width: 8, height: 8))
        box.move(to: front.origin); box.addLine(to: back.origin)
        box.move(to: CGPoint(x: front.maxX, y: front.minY)); box.addLine(to: CGPoint(x: back.maxX, y: back.minY))
        box.move(to: CGPoint(x: front.minX, y: front.maxY)); box.addLine(to: CGPoint(x: back.minX, y: back.maxY))
        box.move(to: CGPoint(x: front.maxX, y: front.maxY)); box.addLine(to: CGPoint(x: back.maxX, y: back.maxY))
        context.stroke(box, with: .color(Color.cyan.opacity(0.23)), lineWidth: 1)
    }

    private func drawGroundPlane(context: GraphicsContext, size: CGSize) {
        var plane = Path()
        plane.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.78))
        plane.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.66))
        context.stroke(plane, with: .color(Color.green.opacity(0.26)), lineWidth: 1)
    }

    private func capsule(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 8, weight: .black, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.58))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
