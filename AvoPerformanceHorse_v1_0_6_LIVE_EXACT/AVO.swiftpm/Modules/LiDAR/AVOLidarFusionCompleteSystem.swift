import Foundation
import SwiftUI
import simd

// MARK: - LIDAR PHASE 128
// COMPLETE DEPTH FUSION SYSTEM

public struct AVODepthPoint: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var x: Float
    public var y: Float
    public var z: Float
    public var confidence: Float

    public init(x: Float, y: Float, z: Float, confidence: Float = 1.0) {
        self.x = x
        self.y = y
        self.z = z
        self.confidence = confidence
    }
}

public struct AVOLidarHorseVolume: Codable, Hashable {
    public var width: Float
    public var height: Float
    public var length: Float
    public var estimatedVolume: Float
    public var estimatedMassIndex: Float

    public init(width: Float = 0,
                height: Float = 0,
                length: Float = 0,
                estimatedVolume: Float = 0,
                estimatedMassIndex: Float = 0) {
        self.width = width
        self.height = height
        self.length = length
        self.estimatedVolume = estimatedVolume
        self.estimatedMassIndex = estimatedMassIndex
    }
}

public struct AVODepthFusionFrame: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var pointCount: Int
    public var segmentedHorsePoints: Int
    public var averageDepth: Float
    public var stability: Float
    public var horseVolume: AVOLidarHorseVolume

    public init(frameIndex: Int,
                pointCount: Int,
                segmentedHorsePoints: Int,
                averageDepth: Float,
                stability: Float,
                horseVolume: AVOLidarHorseVolume) {
        self.frameIndex = frameIndex
        self.pointCount = pointCount
        self.segmentedHorsePoints = segmentedHorsePoints
        self.averageDepth = averageDepth
        self.stability = stability
        self.horseVolume = horseVolume
    }
}

@MainActor
public final class AVOLidarFusionCompleteSystem: ObservableObject {

    public static let shared = AVOLidarFusionCompleteSystem()

    @Published public private(set) var status: String = "LIDAR COMPLETE READY"
    @Published public private(set) var depthFrames: [AVODepthFusionFrame] = []
    @Published public private(set) var livePointCloud: [AVODepthPoint] = []
    @Published public private(set) var segmentationEnabled = true
    @Published public private(set) var fusionEnabled = true

    private let storage = AVOStorageEngine.shared

    private init() {}

    public func ingestDepthPoints(_ points: [AVODepthPoint],
                                  frameIndex: Int) {
        livePointCloud = points

        let segmented = segmentationEnabled ? segmentHorse(points) : points
        let volume = estimateVolume(segmented)

        let avgDepth: Float
        if segmented.isEmpty {
            avgDepth = 0
        } else {
            avgDepth = segmented.map(\.z).reduce(0,+) / Float(segmented.count)
        }

        let frame = AVODepthFusionFrame(
            frameIndex: frameIndex,
            pointCount: points.count,
            segmentedHorsePoints: segmented.count,
            averageDepth: avgDepth,
            stability: estimateStability(segmented),
            horseVolume: volume
        )

        depthFrames.append(frame)

        if depthFrames.count > 5000 {
            depthFrames.removeFirst(depthFrames.count - 5000)
        }

        status = "DEPTH FRAME \(frameIndex) · \(segmented.count) HORSE PTS"
    }

    public func segmentHorse(_ points: [AVODepthPoint]) -> [AVODepthPoint] {
        // lightweight heuristic segmentation
        points.filter {
            $0.confidence > 0.35 &&
            $0.z > 0.15 &&
            $0.z < 6.0
        }
    }

    public func estimateVolume(_ points: [AVODepthPoint]) -> AVOLidarHorseVolume {
        guard !points.isEmpty else { return AVOLidarHorseVolume() }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let zs = points.map(\.z)

        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max(),
              let minZ = zs.min(),
              let maxZ = zs.max() else {
            return AVOLidarHorseVolume()
        }

        let width = maxX - minX
        let height = maxY - minY
        let length = maxZ - minZ

        let volume = width * height * length
        let massIndex = volume * 480

        return AVOLidarHorseVolume(
            width: width,
            height: height,
            length: length,
            estimatedVolume: volume,
            estimatedMassIndex: massIndex
        )
    }

    public func estimateStability(_ points: [AVODepthPoint]) -> Float {
        guard !points.isEmpty else { return 0 }
        let avgConfidence = points.map(\.confidence).reduce(0,+) / Float(points.count)
        return min(1, max(0, avgConfidence))
    }


    public func toggleSegmentation() {
        segmentationEnabled.toggle()
        status = segmentationEnabled ? "DEPTH SEGMENTATION ON" : "DEPTH SEGMENTATION OFF"
    }

    public func toggleFusion() {
        fusionEnabled.toggle()
        status = fusionEnabled ? "DEPTH FUSION ON" : "DEPTH FUSION OFF"
    }

    public func exportDepthSession(horseName: String) {
        do {
            let url = try storage.folder(for: .analytics, horseName: horseName)
                .appendingPathComponent("lidar_depth_fusion.json")

            try storage.writeJSON(depthFrames, to: url)
            status = "DEPTH SESSION EXPORTED"
        } catch {
            status = "DEPTH EXPORT ERROR: \(error.localizedDescription)"
        }
    }
}

@MainActor
public struct AVOLidarFusionPanel: View {

    @ObservedObject private var lidar = AVOLidarFusionCompleteSystem.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("LIDAR DEPTH FUSION")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            HStack {
                metric("FRAMES", "\(lidar.depthFrames.count)")
                metric("POINTS", "\(lidar.livePointCloud.count)")
                metric("SEG", lidar.segmentationEnabled ? "ON" : "OFF")
                metric("FUSION", lidar.fusionEnabled ? "ON" : "OFF")
            }

            Text(lidar.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))

            HStack {
                Button("SEGMENT") {
                    lidar.toggleSegmentation()
                }
                .buttonStyle(.bordered)

                Button("FUSION") {
                    lidar.toggleFusion()
                }
                .buttonStyle(.bordered)

                Button("EXPORT") {
                    lidar.exportDepthSession(
                        horseName: BiotechHorseSessionRecorder.shared.selectedHorseName
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.system(size: 10, weight: .bold))
        }
        .padding(12)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
        )
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))

            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
