import Foundation
import SwiftUI
import UIKit

// MARK: - AVO PHASE 107
// SYSTEM DATA BUS
//
// Central safe bridge between app areas.
// Direction:
// REVIEW  = IA retraining, dataset quality, model comparison.
// BIOTECH = biomechanical analysis, live/replay, clinical export.
// HUB     = enable/disable features.
// EXPORT  = packages for Colab/Drive/client reports.

public enum AVOAppArea: String, Codable, CaseIterable, Hashable {
    case launch
    case dashboard
    case review
    case biotech
    case hardware
    case hub
    case export
    case settings
}

public enum AVOPipelineMode: String, Codable, CaseIterable, Hashable {
    case idle
    case reviewDataset
    case reviewVideoTraining
    case biotechLive
    case biotechReplay
    case exportPackage
}

public struct AVONormalizedKeypoint: Codable, Hashable, Identifiable {
    public var id: String { name }
    public var name: String
    public var x: Double
    public var y: Double
    public var z: Double?
    public var confidence: Double
    public var source: String

    public init(name: String,
                x: Double,
                y: Double,
                z: Double? = nil,
                confidence: Double,
                source: String = "unknown") {
        self.name = name
        self.x = x
        self.y = y
        self.z = z
        self.confidence = confidence
        self.source = source
    }
}

public struct AVONormalizedPoseFrame: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var keypoints: [AVONormalizedKeypoint]
    public var originArea: AVOAppArea
    public var modelName: String?
    public var qualityScore: Double

    public init(frameIndex: Int,
                timeSeconds: Double,
                keypoints: [AVONormalizedKeypoint],
                originArea: AVOAppArea,
                modelName: String? = nil,
                qualityScore: Double = 0) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.keypoints = keypoints
        self.originArea = originArea
        self.modelName = modelName
        self.qualityScore = qualityScore
    }
}

public struct AVOBiotechMetricSnapshot: Codable, Hashable {
    public var frameIndex: Int
    public var timeSeconds: Double
    public var symmetry: Double
    public var risk: Double
    public var stability: Double
    public var notes: [String]

    public init(frameIndex: Int,
                timeSeconds: Double,
                symmetry: Double,
                risk: Double,
                stability: Double,
                notes: [String] = []) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.symmetry = symmetry
        self.risk = risk
        self.stability = stability
        self.notes = notes
    }
}

@MainActor
public final class AVOSystemDataBus: ObservableObject {

    public static let shared = AVOSystemDataBus()

    @Published public var activeArea: AVOAppArea = .launch
    @Published public var pipelineMode: AVOPipelineMode = .idle
    @Published public var currentVideoName: String = ""
    @Published public var currentFrameIndex: Int = 0
    @Published public var normalizedPoseTimeline: [AVONormalizedPoseFrame] = []
    @Published public var biotechMetrics: [AVOBiotechMetricSnapshot] = []
    @Published public var lastSystemMessage: String = "AVO SYSTEM BUS READY"
    @Published public var lastUpdatedAt: Date = Date()

    private init() {}

    public func setArea(_ area: AVOAppArea) {
        activeArea = area
        touch("AREA -> \(area.rawValue.uppercased())")
    }

    public func setMode(_ mode: AVOPipelineMode) {
        pipelineMode = mode
        touch("MODE -> \(mode.rawValue)")
    }

    public func updateVideo(name: String) {
        currentVideoName = name
        touch("VIDEO -> \(name)")
    }

    public func publishPoseFrame(_ frame: AVONormalizedPoseFrame) {
        if let idx = normalizedPoseTimeline.firstIndex(where: { $0.frameIndex == frame.frameIndex }) {
            normalizedPoseTimeline[idx] = frame
        } else {
            normalizedPoseTimeline.append(frame)
            normalizedPoseTimeline.sort { $0.frameIndex < $1.frameIndex }
        }

        currentFrameIndex = frame.frameIndex
        touch("POSE FRAME \(frame.frameIndex)")
    }

    public func publishBiotechMetric(_ metric: AVOBiotechMetricSnapshot) {
        if let idx = biotechMetrics.firstIndex(where: { $0.frameIndex == metric.frameIndex }) {
            biotechMetrics[idx] = metric
        } else {
            biotechMetrics.append(metric)
            biotechMetrics.sort { $0.frameIndex < $1.frameIndex }
        }

        currentFrameIndex = metric.frameIndex
        touch("BIOTECH METRIC \(metric.frameIndex)")
    }

    public func clearSession() {
        normalizedPoseTimeline.removeAll()
        biotechMetrics.removeAll()
        currentFrameIndex = 0
        currentVideoName = ""
        pipelineMode = .idle
        touch("SESSION CLEARED")
    }

    public func exportStateJSONData() throws -> Data {
        let snapshot = AVOSystemDataBusSnapshot(
            activeArea: activeArea,
            pipelineMode: pipelineMode,
            currentVideoName: currentVideoName,
            currentFrameIndex: currentFrameIndex,
            poseFrames: normalizedPoseTimeline.count,
            biotechMetricFrames: biotechMetrics.count,
            lastSystemMessage: lastSystemMessage,
            lastUpdatedAt: lastUpdatedAt
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func touch(_ message: String) {
        lastSystemMessage = message
        lastUpdatedAt = Date()
    }
}

public struct AVOSystemDataBusSnapshot: Codable, Hashable {
    public var activeArea: AVOAppArea
    public var pipelineMode: AVOPipelineMode
    public var currentVideoName: String
    public var currentFrameIndex: Int
    public var poseFrames: Int
    public var biotechMetricFrames: Int
    public var lastSystemMessage: String
    public var lastUpdatedAt: Date
}
