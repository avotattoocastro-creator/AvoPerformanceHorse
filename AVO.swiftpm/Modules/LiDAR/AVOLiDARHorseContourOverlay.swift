import SwiftUI
import CoreGraphics

// MARK: - AVO LiDAR Horse Contour Overlay
// FINALIZED HYBRID RGB + LiDAR CONTOUR PIPELINE
// Stable biomechanical contour using:
// - tracked anatomy joints
// - LiDAR depth cloud
// - persistent body fallback
// - adaptive visibility
//
// Designed for iPad Pro M4 LiDAR.

struct AVOLiDARHorseContourOverlay: View {

    @ObservedObject var camera: CameraManager

    private let maxLiDARPointsForContour = 240
    private let minPointsForContour = 4

    var body: some View {

        GeometryReader { geo in

            let contourPoints = makeContourPoints(in: geo.size)

            ZStack(alignment: .topLeading) {

                if contourPoints.count >= minPointsForContour {

                    let hull = convexHull(contourPoints)

                    Path { path in

                        guard let first = hull.first else { return }

                        path.move(to: first)

                        for p in hull.dropFirst() {
                            path.addLine(to: p)
                        }

                        path.closeSubpath()
                    }
                    .stroke(
                        Color.green.opacity(contourOpacity),
                        style: StrokeStyle(
                            lineWidth: 2.2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .shadow(color: Color.green.opacity(0.45), radius: 8)
                    .blur(radius: 0.15)

                    Path { path in

                        guard let first = hull.first else { return }

                        path.move(to: first)

                        for p in hull.dropFirst() {
                            path.addLine(to: p)
                        }

                        path.closeSubpath()
                    }
                    .fill(Color.green.opacity(0.05))

                    ForEach(Array(contourPoints.prefix(80).enumerated()), id: \.offset) { _, p in

                        Circle()
                            .fill(Color.green.opacity(0.28))
                            .frame(width: 3.2, height: 3.2)
                            .position(p)
                    }

                    VStack(alignment: .leading, spacing: 4) {

                        Text("LiDAR BODY LOCK")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.green.opacity(0.95))

                        Text("RGB + DEPTH FUSION")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.75))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.green.opacity(0.32), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .padding(10)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var contourOpacity: Double {

        if camera.lidarSupported &&
            !camera.lidarPointCloud2D.isEmpty {
            return 0.72
        }

        if camera.trackedHorseJoints.count >= 6 {
            return 0.55
        }

        return 0.25
    }

    private func makeContourPoints(in size: CGSize) -> [CGPoint] {

        let jointPoints = camera.trackedHorseJoints
            .filter {
                $0.confidence >= 0.12
            }
            .map {
                CGPoint(
                    x: size.width * CGFloat($0.x),
                    y: size.height * CGFloat($0.y)
                )
            }

        guard jointPoints.count >= 3 else {
            return []
        }

        let bodyBox = expandedBoundingBox(
            for: jointPoints,
            in: size
        )

        let lidarPoints = camera.lidarPointCloud2D
            .filter {
                $0.confidence >= 0.08 &&
                $0.z > 0.18 &&
                $0.z < 12.0
            }
            .prefix(maxLiDARPointsForContour)
            .map {
                CGPoint(
                    x: size.width * CGFloat($0.x),
                    y: size.height * CGFloat($0.y)
                )
            }
            .filter {
                bodyBox.insetBy(dx: -45, dy: -45).contains($0)
            }

        var contour = jointPoints + lidarPoints

        if contour.count < 10 {

            contour += generateFallbackBodyContour(
                from: bodyBox
            )
        }

        return removeNearDuplicates(
            contour,
            minDistance: 5.0
        )
    }

    private func generateFallbackBodyContour(from rect: CGRect) -> [CGPoint] {

        let top = rect.minY
        let bottom = rect.maxY
        let left = rect.minX
        let right = rect.maxX
        let midY = rect.midY

        return [
            CGPoint(x: left + 10, y: midY - 30),
            CGPoint(x: left + 40, y: top + 15),
            CGPoint(x: rect.midX, y: top),
            CGPoint(x: right - 25, y: top + 18),
            CGPoint(x: right, y: midY),
            CGPoint(x: right - 20, y: bottom - 12),
            CGPoint(x: rect.midX, y: bottom),
            CGPoint(x: left + 25, y: bottom - 15),
            CGPoint(x: left, y: midY + 8)
        ]
    }

    private func expandedBoundingBox(
        for points: [CGPoint],
        in size: CGSize
    ) -> CGRect {

        let xs = points.map { $0.x }
        let ys = points.map { $0.y }

        guard
            let minX = xs.min(),
            let maxX = xs.max(),
            let minY = ys.min(),
            let maxY = ys.max()
        else {
            return .zero
        }

        let paddingX: CGFloat = 65
        let paddingY: CGFloat = 55

        return CGRect(
            x: max(0, minX - paddingX),
            y: max(0, minY - paddingY),
            width: min(size.width, (maxX - minX) + paddingX * 2),
            height: min(size.height, (maxY - minY) + paddingY * 2)
        )
    }

    private func removeNearDuplicates(
        _ points: [CGPoint],
        minDistance: CGFloat
    ) -> [CGPoint] {

        var filtered: [CGPoint] = []

        for p in points {

            let exists = filtered.contains {
                hypot($0.x - p.x, $0.y - p.y) < minDistance
            }

            if !exists {
                filtered.append(p)
            }
        }

        return filtered
    }

    // MARK: - Convex Hull

    private func convexHull(_ points: [CGPoint]) -> [CGPoint] {

        guard points.count > 2 else { return points }

        let sorted = points.sorted {
            if $0.x == $1.x {
                return $0.y < $1.y
            }
            return $0.x < $1.x
        }

        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) -
            (a.y - o.y) * (b.x - o.x)
        }

        var lower: [CGPoint] = []

        for p in sorted {

            while lower.count >= 2 &&
                cross(
                    lower[lower.count - 2],
                    lower[lower.count - 1],
                    p
                ) <= 0 {

                lower.removeLast()
            }

            lower.append(p)
        }

        var upper: [CGPoint] = []

        for p in sorted.reversed() {

            while upper.count >= 2 &&
                cross(
                    upper[upper.count - 2],
                    upper[upper.count - 1],
                    p
                ) <= 0 {

                upper.removeLast()
            }

            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()

        return lower + upper
    }
}
