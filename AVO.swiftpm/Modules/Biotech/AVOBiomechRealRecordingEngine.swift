
import Foundation
import CoreGraphics
import QuartzCore

// MARK: - AVO BIOMECH REAL RECORDING ENGINE
// Single backend for REC BIOMECH scientific capture.
// REC BIOMECH must not save only a .mov. It also records synchronized skeleton,
// LiDAR and replay manifests so ANALYSIS can play back real session data instead
// of generating fake/live overlays on top of a finished video.

struct AVORecordedSkeletonJoint: Codable, Hashable {
    var joint: HorseJoint
    var x: Double
    var y: Double
    var confidence: Double
    var velocityX: Double
    var velocityY: Double
    var isPredicted: Bool
}

struct AVORecordedSkeletonFrame: Codable, Hashable {
    var frameIndex: Int
    var timestamp: Double
    var videoTime: Double
    var quality: Double
    var horseBoxX: Double
    var horseBoxY: Double
    var horseBoxW: Double
    var horseBoxH: Double
    var joints: [AVORecordedSkeletonJoint]
}

struct AVORecordedLiDARFrame: Codable, Hashable {
    var frameIndex: Int
    var timestamp: Double
    var videoTime: Double
    var distanceMeters: Double
    var quality: Double
    var width: Int
    var height: Int
    var source: String
    var points2D: [AVOLiDARPoint2D]
    var fusedPoints3D: [AVOLiDARPoint3D]
}

struct AVORecordedBiomechTelemetryFrame: Codable, Hashable {
    var frameIndex: Int
    var timestamp: Double
    var videoTime: Double
    var heartRate: String
    var speed: String
    var cadence: String
    var imuPitch: Double
    var imuRoll: Double
    var imuImpact: Double
    var rssi: String
    var battery: String
}

struct AVOBiomechRealCaptureManifest: Codable, Hashable {
    var version: String
    var horseName: String
    var horseId: String
    var sessionId: String
    var videoFile: String
    var videoPath: String
    var mode: String
    var startedAt: Date
    var finishedAt: Date?
    var skeletonFile: String
    var lidarFile: String
    var telemetryFile: String
    var frameCount: Int
    var lidarFrameCount: Int
    var telemetryFrameCount: Int
    var status: String
}

final class AVOBiomechRealRecordingEngine {
    static let shared = AVOBiomechRealRecordingEngine()

    private let queue = DispatchQueue(label: "avo.biomech.real.recording.engine", qos: .utility)
    private var isActive = false
    private var startedAt = Date()
    private var startMediaTime: Double = 0
    private var videoURL: URL?
    private var sessionRoot: URL?
    private var manifestURL: URL?
    private var skeletonURL: URL?
    private var lidarURL: URL?
    private var telemetryURL: URL?
    private var skeletonFrames: [AVORecordedSkeletonFrame] = []
    private var lidarFrames: [AVORecordedLiDARFrame] = []
    private var telemetryFrames: [AVORecordedBiomechTelemetryFrame] = []
    private var lastSkeletonVideoTime: Double = -99
    private var lastTelemetryVideoTime: Double = -99
    private var lastLiDARVideoTime: Double = -99
    private var frameIndex = 0
    private var lidarIndex = 0
    private var telemetryIndex = 0
    private var modeText = "BIOMECH"

    private init() {}

    func begin(videoURL: URL, mode: AVOBiomechRecordingMode) {
        queue.async {
            self.isActive = true
            self.startedAt = Date()
            self.startMediaTime = CACurrentMediaTime()
            self.videoURL = videoURL
            self.modeText = mode.rawValue
            self.skeletonFrames.removeAll(keepingCapacity: true)
            self.lidarFrames.removeAll(keepingCapacity: true)
            self.telemetryFrames.removeAll(keepingCapacity: true)
            self.lastSkeletonVideoTime = -99
            self.lastTelemetryVideoTime = -99
            self.lastLiDARVideoTime = -99
            self.frameIndex = 0
            self.lidarIndex = 0
            self.telemetryIndex = 0

            let root = self.resolveSessionRoot(from: videoURL)
            self.sessionRoot = root
            let biotechFolder = root.appendingPathComponent(AVOMasterSessionArea.biotechRec.rawValue, isDirectory: true)
            let lidarFolder = root.appendingPathComponent(AVOMasterSessionArea.lidar.rawValue, isDirectory: true)
            let hardwareFolder = root.appendingPathComponent(AVOMasterSessionArea.hardware.rawValue, isDirectory: true)
            let manifestFolder = root.appendingPathComponent(AVOMasterSessionArea.manifests.rawValue, isDirectory: true)
            try? FileManager.default.createDirectory(at: biotechFolder, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: lidarFolder, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: hardwareFolder, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: manifestFolder, withIntermediateDirectories: true)

            self.skeletonURL = biotechFolder.appendingPathComponent("skeleton_track.json")
            self.lidarURL = lidarFolder.appendingPathComponent("lidar_track.json")
            self.telemetryURL = hardwareFolder.appendingPathComponent("telemetry_track.json")
            self.manifestURL = manifestFolder.appendingPathComponent("biomech_real_capture_manifest.json")
            self.writeManifest(status: "RECORDING", finishedAt: nil)
        }
    }

    func recordSkeleton(frameCounter: Int,
                        joints: [TrackedHorseJoint],
                        quality: Double,
                        horseBox: CGRect,
                        mediaTime: Double = CACurrentMediaTime()) {
        queue.async {
            guard self.isActive else { return }
            let videoTime = max(0, mediaTime - self.startMediaTime)

            // Scientific replay does not need all 50/60 UI frames. 20-25 Hz skeleton is stable,
            // lighter for iPad and enough for gait analysis with interpolation.
            if videoTime - self.lastSkeletonVideoTime < 0.040 { return }
            self.lastSkeletonVideoTime = videoTime
            self.frameIndex += 1

            let recorded = joints.map {
                AVORecordedSkeletonJoint(joint: $0.joint,
                                         x: $0.x,
                                         y: $0.y,
                                         confidence: $0.confidence,
                                         velocityX: $0.velocityX,
                                         velocityY: $0.velocityY,
                                         isPredicted: $0.isPredicted)
            }

            let frame = AVORecordedSkeletonFrame(frameIndex: self.frameIndex,
                                                 timestamp: Date().timeIntervalSince1970,
                                                 videoTime: videoTime,
                                                 quality: quality,
                                                 horseBoxX: horseBox.origin.x,
                                                 horseBoxY: horseBox.origin.y,
                                                 horseBoxW: horseBox.size.width,
                                                 horseBoxH: horseBox.size.height,
                                                 joints: recorded)
            self.skeletonFrames.append(frame)
            if self.skeletonFrames.count % 45 == 0 { self.flushSkeleton() }
        }
    }

    func recordLiDAR(sample: AVOLiDARDepthSample,
                     points2D: [AVOLiDARPoint2D],
                     fusedPoints3D: [AVOLiDARPoint3D],
                     mediaTime: Double = CACurrentMediaTime()) {
        queue.async {
            guard self.isActive else { return }
            let videoTime = max(0, mediaTime - self.startMediaTime)
            if videoTime - self.lastLiDARVideoTime < 0.10 { return }
            self.lastLiDARVideoTime = videoTime
            self.lidarIndex += 1

            // Keep replay files usable on iPad: decimate very dense point clouds.
            let safe2D = Array(points2D.prefix(900))
            let safe3D = Array(fusedPoints3D.prefix(900))
            let frame = AVORecordedLiDARFrame(frameIndex: self.lidarIndex,
                                              timestamp: sample.time,
                                              videoTime: videoTime,
                                              distanceMeters: sample.distanceMeters,
                                              quality: sample.quality,
                                              width: sample.width,
                                              height: sample.height,
                                              source: sample.source,
                                              points2D: safe2D,
                                              fusedPoints3D: safe3D)
            self.lidarFrames.append(frame)
            if self.lidarFrames.count % 25 == 0 { self.flushLiDAR() }
        }
    }

    func recordTelemetry(heartRate: String,
                         speed: String,
                         cadence: String,
                         imuPitch: Double,
                         imuRoll: Double,
                         imuImpact: Double,
                         rssi: String,
                         battery: String,
                         mediaTime: Double = CACurrentMediaTime()) {
        queue.async {
            guard self.isActive else { return }
            let videoTime = max(0, mediaTime - self.startMediaTime)
            if videoTime - self.lastTelemetryVideoTime < 0.20 { return }
            self.lastTelemetryVideoTime = videoTime
            self.telemetryIndex += 1
            let frame = AVORecordedBiomechTelemetryFrame(frameIndex: self.telemetryIndex,
                                                         timestamp: Date().timeIntervalSince1970,
                                                         videoTime: videoTime,
                                                         heartRate: heartRate,
                                                         speed: speed,
                                                         cadence: cadence,
                                                         imuPitch: imuPitch,
                                                         imuRoll: imuRoll,
                                                         imuImpact: imuImpact,
                                                         rssi: rssi,
                                                         battery: battery)
            self.telemetryFrames.append(frame)
            if self.telemetryFrames.count % 25 == 0 { self.flushTelemetry() }
        }
    }

    func finish(videoURL: URL? = nil) {
        queue.async {
            guard self.isActive else { return }
            if let videoURL { self.videoURL = videoURL }
            self.flushSkeleton()
            self.flushLiDAR()
            self.flushTelemetry()
            self.writeManifest(status: "FINISHED", finishedAt: Date())
            self.isActive = false
        }
    }

    func cancel() {
        queue.async {
            self.flushSkeleton()
            self.flushLiDAR()
            self.flushTelemetry()
            self.writeManifest(status: "CANCELLED", finishedAt: Date())
            self.isActive = false
        }
    }

    private func flushSkeleton() {
        guard let url = skeletonURL else { return }
        do {
            let data = try JSONEncoder.avoAnalysis.encode(skeletonFrames)
            try data.write(to: url, options: Data.WritingOptions.atomic)
        } catch {}
    }

    private func flushLiDAR() {
        guard let url = lidarURL else { return }
        do {
            let data = try JSONEncoder.avoAnalysis.encode(lidarFrames)
            try data.write(to: url, options: Data.WritingOptions.atomic)
        } catch {}
    }

    private func flushTelemetry() {
        guard let url = telemetryURL else { return }
        do {
            let data = try JSONEncoder.avoAnalysis.encode(telemetryFrames)
            try data.write(to: url, options: Data.WritingOptions.atomic)
        } catch {}
    }

    private func writeManifest(status: String, finishedAt: Date?) {
        guard let url = manifestURL, let videoURL = videoURL else { return }
        let manifest = AVOBiomechRealCaptureManifest(version: "1.0",
                                                     horseName: AVOMasterSessionCore.shared.activeHorseName,
                                                     horseId: AVOMasterSessionCore.shared.activeHorseId?.uuidString ?? "",
                                                     sessionId: AVOMasterSessionCore.shared.activeSessionId,
                                                     videoFile: videoURL.lastPathComponent,
                                                     videoPath: videoURL.path,
                                                     mode: modeText,
                                                     startedAt: startedAt,
                                                     finishedAt: finishedAt,
                                                     skeletonFile: skeletonURL?.path ?? "",
                                                     lidarFile: lidarURL?.path ?? "",
                                                     telemetryFile: telemetryURL?.path ?? "",
                                                     frameCount: skeletonFrames.count,
                                                     lidarFrameCount: lidarFrames.count,
                                                     telemetryFrameCount: telemetryFrames.count,
                                                     status: status)
        do {
            let data = try JSONEncoder.avoAnalysis.encode(manifest)
            try data.write(to: url, options: Data.WritingOptions.atomic)
        } catch {}
    }

    private func resolveSessionRoot(from videoURL: URL) -> URL {
        var url = videoURL.deletingLastPathComponent()
        for _ in 0..<10 {
            if url.lastPathComponent.uppercased().hasPrefix("SESSION_") { return url }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return AVOMasterSessionCore.shared.activeSessionURL ?? videoURL.deletingLastPathComponent()
    }
}


extension JSONEncoder {
    static var avoAnalysis: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var avoAnalysis: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
