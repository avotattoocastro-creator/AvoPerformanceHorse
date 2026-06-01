import SwiftUI

struct BiomechOverlay: View {
    
    @ObservedObject var camera: CameraManager
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                let rect = displayRect(from: camera.horseBox, in: geo.size)
                let pointMap = Dictionary(uniqueKeysWithValues: camera.trackedHorseJoints.map { ($0.joint, $0) })
                
                Rectangle()
                    .stroke(borderColor, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .opacity(camera.hasActiveObjectLock ? 1.0 : 0.0)
                
                ForEach(camera.trackedHorseJoints) { joint in
                    if joint.trail.count >= 2 {
                        Path { path in
                            let first = screenPoint(joint.trail[0], in: geo.size)
                            path.move(to: first)
                            for p in joint.trail.dropFirst() {
                                path.addLine(to: screenPoint(p, in: geo.size))
                            }
                        }
                        .stroke(Color.white.opacity(joint.isPredicted ? 0.18 : 0.28), lineWidth: 1.2)
                    }
                }
                
                ForEach(HorseJoint.skeletonEdges) { edge in
                    if let a = pointMap[edge.from], let b = pointMap[edge.to] {
                        Path { path in
                            path.move(to: screenPoint(a, in: geo.size))
                            path.addLine(to: screenPoint(b, in: geo.size))
                        }
                        .stroke(edgeColor(a, b), lineWidth: edgeWidth(a, b))
                        .opacity(edgeOpacity(a, b))
                    }
                }
                
                ForEach(camera.trackedHorseJoints) { point in
                    ZStack {
                        Circle()
                            .fill(pointColor(point))
                            .frame(width: pointSize(point), height: pointSize(point))
                        Circle()
                            .stroke(Color.black.opacity(0.88), lineWidth: 1.5)
                            .frame(width: pointSize(point), height: pointSize(point))
                        if point.isPredicted {
                            Circle()
                                .stroke(Color.yellow.opacity(0.9), lineWidth: 1.2)
                                .frame(width: pointSize(point) + 8, height: pointSize(point) + 8)
                        }
                    }
                    .position(screenPoint(point, in: geo.size))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(camera.trackingText)
                    Text(camera.confidenceText)
                    Text(camera.coreMLStatus)
                    Text("LABEL: \(camera.horseDetectionLabel)")
                    Text(camera.horsePoseStatus)
                    Text(camera.anatomyTrackingText)
                    Text(camera.anatomyTrackingQualityText)
                    Text("TRACKED JOINTS: \(camera.trackedHorseJoints.count)")
                    Divider().background(Color.green.opacity(0.45))
                    Text(camera.biomechStatusText)
                    Text(camera.frontSymmetryText)
                    Text(camera.hindSymmetryText)
                    Text(camera.lamenessRiskText)
                    Text(camera.strideText)
                    Text(camera.headNodText)
                    Divider().background(Color.cyan.opacity(0.45))
                    Text(camera.datasetModeText)
                    Text(camera.datasetCountText)
                    Text(camera.datasetStatusText)
                    Text("GAIT: \(camera.gait)  LAME: \(camera.lameness)")
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(statusColor)
                .padding(8)
                .background(Color.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(8)
            }
        }
        .allowsHitTesting(false)
    }
    
    private var borderColor: Color {
        if camera.lameness == "HIGH REVIEW" { return .red }
        if camera.lameness == "POSSIBLE" { return .orange }
        return camera.hasActiveObjectLock ? .green : .yellow
    }

    private var statusColor: Color {
        if camera.lameness == "HIGH REVIEW" { return .red }
        if camera.lameness == "POSSIBLE" { return .orange }
        return .green
    }
    
    private func pointColor(_ point: TrackedHorseJoint) -> Color {
        if point.isPredicted { return .yellow }
        return point.confidence >= 0.55 ? .green : .orange
    }
    
    private func pointSize(_ point: TrackedHorseJoint) -> CGFloat {
        point.confidence >= 0.55 ? 10 : 8
    }
    
    private func edgeColor(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> Color {
        (a.isPredicted || b.isPredicted) ? .yellow : .cyan
    }
    
    private func edgeWidth(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> CGFloat {
        (a.isPredicted || b.isPredicted) ? 2 : 3
    }
    
    private func edgeOpacity(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> Double {
        max(0.18, min(0.95, (a.confidence + b.confidence) / 2.0))
    }
    
    private func screenPoint(_ point: TrackedHorseJoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * size.width,
            y: CGFloat(1.0 - point.y) * size.height
        )
    }
    
    private func screenPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1.0 - point.y) * size.height
        )
    }
    
    private func displayRect(from visionBox: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: visionBox.minX * size.width,
            y: (1.0 - visionBox.maxY) * size.height,
            width: visionBox.width * size.width,
            height: visionBox.height * size.height
        )
    }
}
