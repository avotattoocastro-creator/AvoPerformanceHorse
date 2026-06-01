import SwiftUI
import Foundation
import UIKit
import AVKit
import UniformTypeIdentifiers

// MARK: - AVO BIOMECH ANALYSIS ENGINE PRO
// Analysis is NOT a second video editor.
// VIDEO page = commercial trimming/export.
// ANALYSIS page = session source loader + biomech analysis + sensors/LiDAR/dataset bridge.
// This file deliberately reuses CameraManager, SensorHub, AVOHardwareReceiver and AVOMasterSessionCore.

struct AVOBiomechAnalysisSnapshot: Codable, Hashable {
    var createdAt: Date
    var horseName: String
    var activeSessionId: String
    var sourceMode: String
    var sourceVideoPath: String
    var gait: String
    var asymmetry: String
    var frontSymmetry: String
    var hindSymmetry: String
    var lamenessRisk: String
    var stride: String
    var headNod: String
    var hipHike: String
    var pushOff: String
    var biomechScore: String
    var vetRisk: String
    var heartRate: String
    var speed: String
    var cadence: String
    var rssi: String
    var battery: String
    var lidarDistance: String
    var lidarQuality: String
    var imuPitch: Double
    var imuRoll: Double
    var imuImpact: Double
    var quality: Double
    var fatigue: Double
    var risk: Double
    var suspicion: String
    var recommendation: String
}

enum AVOAnalysisSourceMode: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case liveCamera = "LIVE CAMERA"
    case sessionVideo = "SESSION VIDEO"
    case lastBiomech = "LAST BIOMECH"
    case lastClient = "LAST CLIENT"
    case importedVideo = "IMPORTED VIDEO"
    case raspberryLive = "RASPBERRY LIVE"
}

struct AVOAnalysisVideoCandidate: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: URL
    let type: String
    let sessionId: String
    let modifiedAt: Date
}

@MainActor
final class AVOBiomechAnalysisEngineProStore: ObservableObject {
    @Published var status: String = "ANALYSIS ENGINE READY"
    @Published var showSkeleton = true
    @Published var showLiDAR = true
    @Published var showSensors = true
    @Published var showSymmetry = true
    @Published var showStride = true
    @Published var showImpact = true
    @Published var showVetAI = true
    @Published var showClientClean = false
    @Published var playbackPosition: Double = 0
    @Published var reportURL: URL?
    @Published var colabManifestURL: URL?
    @Published var compareMode = false
    @Published var sourceMode: AVOAnalysisSourceMode = .sessionVideo
    @Published var availableVideos: [AVOAnalysisVideoCandidate] = []
    @Published var selectedVideoURL: URL?
    @Published var selectedVideoTitle: String = "NO VIDEO LOADED"
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var lastSnapshot: AVOBiomechAnalysisSnapshot?
    @Published var replayLiDARSamples: [AVOLiDARDepthSample] = []
    @Published var replayLiDARFrames: [AVORecordedLiDARFrame] = []
    @Published var replayLiDARStatus: String = "NO REPLAY LiDAR"
    @Published var replaySkeletonFrames: [[TrackedHorseJoint]] = []
    @Published var replaySkeletonStatus: String = "NO REPLAY SKELETON"

    var isVideoReplayMode: Bool {
        sourceMode != .liveCamera && sourceMode != .raspberryLive && selectedVideoURL != nil
    }

    private let videoExtensions = ["mov", "mp4", "m4v", "MOV", "MP4", "M4V"]

    func bootstrap(camera: CameraManager) {
        refreshVideoLibrary(camera: camera)
        if selectedVideoURL == nil {
            if let url = latestVideo(type: "BIOMECH")?.url {
                selectVideo(url, title: latestVideo(type: "BIOMECH")?.title ?? url.lastPathComponent, mode: .lastBiomech)
            } else if let url = latestVideo(type: "CLIENT")?.url {
                selectVideo(url, title: latestVideo(type: "CLIENT")?.title ?? url.lastPathComponent, mode: .lastClient)
            } else if let url = camera.lastBiomechVideoURL {
                selectVideo(url, title: url.lastPathComponent, mode: .sessionVideo)
            } else {
                sourceMode = .liveCamera
                status = "LIVE CAMERA · NO SESSION VIDEO FOUND"
            }
        }
    }

    func refreshVideoLibrary(camera: CameraManager) {
        var list: [AVOAnalysisVideoCandidate] = []
        let fm = FileManager.default

        if let session = AVOMasterSessionCore.shared.activeSessionURL {
            list.append(contentsOf: scanVideos(root: session.appendingPathComponent(AVOMasterSessionArea.biotechRec.rawValue, isDirectory: true), type: "BIOMECH", sessionId: AVOMasterSessionCore.shared.activeSessionId))
            list.append(contentsOf: scanVideos(root: session.appendingPathComponent(AVOMasterSessionArea.clientRec.rawValue, isDirectory: true), type: "CLIENT", sessionId: AVOMasterSessionCore.shared.activeSessionId))
            list.append(contentsOf: scanVideos(root: session.appendingPathComponent(AVOMasterSessionArea.analytics.rawValue, isDirectory: true), type: "IMPORT", sessionId: AVOMasterSessionCore.shared.activeSessionId))
        }

        if let horse = AVOMasterSessionCore.shared.activeHorseFolderURL {
            let sessionsRoot = horse.appendingPathComponent("Sessions", isDirectory: true)
            if let sessions = try? fm.contentsOfDirectory(at: sessionsRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for session in sessions where session.hasDirectoryPath {
                    let sid = session.lastPathComponent
                    list.append(contentsOf: scanVideos(root: session.appendingPathComponent(AVOMasterSessionArea.biotechRec.rawValue, isDirectory: true), type: "BIOMECH", sessionId: sid))
                    list.append(contentsOf: scanVideos(root: session.appendingPathComponent(AVOMasterSessionArea.clientRec.rawValue, isDirectory: true), type: "CLIENT", sessionId: sid))
                    list.append(contentsOf: scanVideos(root: session.appendingPathComponent(AVOMasterSessionArea.analytics.rawValue, isDirectory: true), type: "IMPORT", sessionId: sid))
                }
            }
        }

        if let camURL = camera.lastBiomechVideoURL, fm.fileExists(atPath: camURL.path) {
            let d = modifiedDate(camURL)
            list.append(AVOAnalysisVideoCandidate(title: "CAMERA LAST · " + camURL.lastPathComponent, url: camURL, type: "CAMERA", sessionId: AVOMasterSessionCore.shared.activeSessionId, modifiedAt: d))
        }

        var seen = Set<String>()
        availableVideos = list
            .filter { candidate in
                let key = candidate.url.path
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }

        status = "VIDEO LIBRARY · \(availableVideos.count) FILES"
    }

    func selectLatestBiomech() {
        guard let item = latestVideo(type: "BIOMECH") ?? latestVideo(type: "CAMERA") else {
            sourceMode = .liveCamera
            status = "NO BIOMECH VIDEO · LIVE CAMERA"
            return
        }
        selectVideo(item.url, title: item.title, mode: .lastBiomech)
    }

    func selectLatestClient() {
        guard let item = latestVideo(type: "CLIENT") else {
            status = "NO CLIENT VIDEO FOUND"
            return
        }
        selectVideo(item.url, title: item.title, mode: .lastClient)
    }

    func selectSessionVideo() {
        guard let item = availableVideos.first else {
            sourceMode = .liveCamera
            status = "NO SESSION VIDEO FOUND"
            return
        }
        selectVideo(item.url, title: item.title, mode: .sessionVideo)
    }

    func selectCandidate(_ item: AVOAnalysisVideoCandidate) {
        selectVideo(item.url, title: item.title, mode: .sessionVideo)
    }

    func useLiveCamera() {
        pause()
        player = nil
        selectedVideoURL = nil
        selectedVideoTitle = "LIVE CAMERA"
        replayLiDARSamples = []
        replayLiDARFrames = []
        replayLiDARStatus = "LIVE LiDAR FROM CAMERA"
        replaySkeletonFrames = []
        replaySkeletonStatus = "LIVE SKELETON FROM CAMERA"
        sourceMode = .liveCamera
        status = "LIVE CAMERA SOURCE"
    }

    func useRaspberryLive() {
        pause()
        player = nil
        selectedVideoURL = nil
        selectedVideoTitle = "RASPBERRY LIVE STREAM"
        replayLiDARSamples = []
        replayLiDARFrames = []
        replayLiDARStatus = "LIVE LiDAR FROM RASPBERRY/CAMERA"
        replaySkeletonFrames = []
        replaySkeletonStatus = "LIVE/RASPBERRY SKELETON"
        sourceMode = .raspberryLive
        status = "RASPBERRY LIVE · UDP/WS TELEMETRY"
    }

    func importExternalVideo(_ url: URL, camera: CameraManager) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            _ = try AVOMasterSessionCore.shared.ensureSession()
            let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
            let target = try AVOMasterSessionCore.shared.makeFileURL(area: .analytics, prefix: "analysis_import_" + url.deletingPathExtension().lastPathComponent, ext: ext)
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            try FileManager.default.copyItem(at: url, to: target)
            refreshVideoLibrary(camera: camera)
            selectVideo(target, title: "IMPORTED · " + target.lastPathComponent, mode: .importedVideo)
            status = "IMPORTED VIDEO READY"
        } catch {
            status = "IMPORT ERROR · \(error.localizedDescription)"
        }
    }

    func selectVideo(_ url: URL, title: String, mode: AVOAnalysisSourceMode) {
        pause()
        selectedVideoURL = url
        selectedVideoTitle = title
        sourceMode = mode
        player = AVPlayer(url: url)
        player?.actionAtItemEnd = .pause
        playbackPosition = 0
        loadReplayLiDAR(for: url)
        loadReplaySkeleton(for: url)
        status = "VIDEO LOADED · \(url.lastPathComponent)"
    }

    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        status = "PLAYING · \(selectedVideoTitle)"
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        playbackPosition = 0
    }

    func seekToSlider() {
        guard let item = player?.currentItem else { return }
        let seconds = CMTimeGetSeconds(item.duration)
        guard seconds.isFinite, seconds > 0 else { return }
        let target = CMTime(seconds: seconds * playbackPosition, preferredTimescale: 600)
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }


    func replayJointsForCurrentTime() -> [TrackedHorseJoint] {
        guard !replaySkeletonFrames.isEmpty else { return [] }
        let idx = max(0, min(replaySkeletonFrames.count - 1, Int(playbackPosition * Double(max(1, replaySkeletonFrames.count - 1)))))
        return replaySkeletonFrames[idx]
    }

    private func loadReplaySkeleton(for videoURL: URL) {
        replaySkeletonFrames = []
        replaySkeletonStatus = "SEARCHING REPLAY SKELETON"
        guard let sessionRoot = sessionRootURL(for: videoURL) else {
            replaySkeletonStatus = "NO SESSION ROOT FOR SKELETON"
            return
        }
        let fm = FileManager.default
        let decoder = JSONDecoder()

        // 1) Native scientific BIOMECH recording: BiotechRec/skeleton_track.json
        let nativeCandidates = [
            sessionRoot.appendingPathComponent(AVOMasterSessionArea.biotechRec.rawValue, isDirectory: true).appendingPathComponent("skeleton_track.json"),
            sessionRoot.appendingPathComponent("skeleton_track.json")
        ]

        for url in nativeCandidates where fm.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let frames = try? decoder.decode([AVORecordedSkeletonFrame].self, from: data) {
                let converted = frames.map { frame in
                    frame.joints.map { joint in
                        TrackedHorseJoint(
                            joint: joint.joint,
                            x: joint.x,
                            y: joint.y,
                            confidence: joint.confidence,
                            velocityX: joint.velocityX,
                            velocityY: joint.velocityY,
                            ageFrames: frame.frameIndex,
                            missedFrames: 0,
                            isPredicted: joint.isPredicted,
                            trail: []
                        )
                    }
                }.filter { !$0.isEmpty }
                replaySkeletonFrames = converted
                replaySkeletonStatus = converted.isEmpty ? "SKELETON TRACK EMPTY" : "REAL REC SKELETON · \(converted.count) FRAMES"
                return
            }
        }

        // 2) Fallback: REVIEW annotations/dataset, used for older sessions.
        let reviewRoot = sessionRoot.appendingPathComponent(AVOMasterSessionArea.review.rawValue, isDirectory: true)
        var annotationFiles: [URL] = []

        if let enumerator = fm.enumerator(at: reviewRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "json" && url.deletingLastPathComponent().lastPathComponent.lowercased().contains("annotation") {
                    annotationFiles.append(url)
                }
            }
        }

        annotationFiles.sort { $0.lastPathComponent < $1.lastPathComponent }
        var frames: [[TrackedHorseJoint]] = []

        for file in annotationFiles.prefix(1800) {
            guard let data = try? Data(contentsOf: file) else { continue }
            if let record = try? decoder.decode(HorseDatasetFrameRecord.self, from: data) {
                let joints = record.keypoints.map { ann in
                    TrackedHorseJoint(joint: ann.joint, x: ann.x, y: ann.y, confidence: ann.confidence, velocityX: 0, velocityY: 0, ageFrames: 1, missedFrames: 0, isPredicted: ann.isPredicted, trail: [])
                }
                if !joints.isEmpty { frames.append(joints) }
            } else if let array = try? decoder.decode([HorseDatasetAnnotation].self, from: data) {
                let joints = array.map { ann in
                    TrackedHorseJoint(joint: ann.joint, x: ann.x, y: ann.y, confidence: ann.confidence, velocityX: 0, velocityY: 0, ageFrames: 1, missedFrames: 0, isPredicted: ann.isPredicted, trail: [])
                }
                if !joints.isEmpty { frames.append(joints) }
            }
        }

        replaySkeletonFrames = frames
        if frames.isEmpty {
            replaySkeletonStatus = "NO REAL SKELETON TRACK IN SESSION"
        } else {
            replaySkeletonStatus = "REVIEW SKELETON · \(frames.count) FRAMES"
        }
    }

    private func sessionRootURL(for fileURL: URL) -> URL? {
        var url = fileURL.deletingLastPathComponent()
        for _ in 0..<12 {
            let name = url.lastPathComponent.uppercased()
            if name.hasPrefix("SESSION_") { return url }
            if url.lastPathComponent == "Sessions" { return nil }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { return nil }
            url = parent
        }
        return nil
    }

    func buildSnapshot(camera: CameraManager, sensors: SensorHub, hardware: AVOHardwareReceiver, stableStore: AVOStableStore) -> AVOBiomechAnalysisSnapshot {
        let session = AVOMasterSessionCore.shared.activeSessionId.isEmpty ? "NO SESSION" : AVOMasterSessionCore.shared.activeSessionId
        let suspicion = camera.biomechAISuspicionText == "SUSPICION --" ? camera.lamenessRiskText : camera.biomechAISuspicionText
        let recommendation: String
        if camera.risk > 0.70 {
            recommendation = "STOP / VET CHECK RECOMMENDED"
        } else if camera.fatigue > 0.65 {
            recommendation = "REDUCE INTENSITY / MONITOR FATIGUE"
        } else if camera.quality < 0.45 {
            recommendation = "LOW TRACKING QUALITY / REPEAT PASS"
        } else {
            recommendation = "TRAINING QUALITY ACCEPTABLE"
        }
        let snap = AVOBiomechAnalysisSnapshot(
            createdAt: Date(),
            horseName: stableStore.selectedHorseName,
            activeSessionId: session,
            sourceMode: sourceMode.rawValue,
            sourceVideoPath: selectedVideoURL?.path ?? "",
            gait: camera.gait,
            asymmetry: camera.asymmetry,
            frontSymmetry: camera.frontSymmetryText,
            hindSymmetry: camera.hindSymmetryText,
            lamenessRisk: camera.lamenessRiskText,
            stride: camera.strideText,
            headNod: camera.headNodText,
            hipHike: camera.hipHikeText,
            pushOff: camera.pushOffText,
            biomechScore: camera.biomechScore,
            vetRisk: camera.vetRiskLevelText,
            heartRate: sensors.pulseStatus,
            speed: sensors.speedStatus,
            cadence: sensors.cadenceStatus,
            rssi: hardware.rssi,
            battery: hardware.remoteBattery,
            lidarDistance: camera.lidarDistanceText,
            lidarQuality: camera.lidarQualityText,
            imuPitch: sensors.imuPitch,
            imuRoll: sensors.imuRoll,
            imuImpact: sensors.imuImpact,
            quality: camera.quality,
            fatigue: camera.fatigue,
            risk: camera.risk,
            suspicion: suspicion,
            recommendation: recommendation
        )
        lastSnapshot = snap
        return snap
    }

    func saveAnalysisJSON(camera: CameraManager, sensors: SensorHub, hardware: AVOHardwareReceiver, stableStore: AVOStableStore) {
        let snap = buildSnapshot(camera: camera, sensors: sensors, hardware: hardware, stableStore: stableStore)
        do {
            let data = try JSONEncoder.avoAnalysis.encode(snap)
            let url = try AVOMasterSessionCore.shared.writeData(data, area: .analytics, fileName: "biomech_analysis_\(safeTimestamp()).json")
            reportURL = url
            status = "ANALYSIS SAVED · \(url.lastPathComponent)"
        } catch {
            status = "SAVE ERROR · \(error.localizedDescription)"
        }
    }

    func exportVetReport(camera: CameraManager, sensors: SensorHub, hardware: AVOHardwareReceiver, stableStore: AVOStableStore) {
        let snap = buildSnapshot(camera: camera, sensors: sensors, hardware: hardware, stableStore: stableStore)
        let text = """
        AVO HORSE EDITION · BIOMECH ANALYSIS REPORT
        Created: \(snap.createdAt)
        Horse: \(snap.horseName)
        Session: \(snap.activeSessionId)
        Source: \(snap.sourceMode)
        Video: \(snap.sourceVideoPath)

        GAIT: \(snap.gait)
        BIOMECH SCORE: \(snap.biomechScore)
        ASYMMETRY: \(snap.asymmetry)
        FRONT: \(snap.frontSymmetry)
        HIND: \(snap.hindSymmetry)
        STRIDE: \(snap.stride)
        HEAD NOD: \(snap.headNod)
        HIP HIKE: \(snap.hipHike)
        PUSH OFF: \(snap.pushOff)

        VET RISK: \(snap.vetRisk)
        LAMENESS RISK: \(snap.lamenessRisk)
        AI SUSPICION: \(snap.suspicion)
        RECOMMENDATION: \(snap.recommendation)

        TELEMETRY
        HR: \(snap.heartRate)
        SPEED: \(snap.speed)
        CADENCE: \(snap.cadence)
        RSSI: \(snap.rssi)
        BATTERY: \(snap.battery)
        LiDAR: \(snap.lidarDistance) · \(snap.lidarQuality)
        IMU: pitch \(String(format: "%.2f", snap.imuPitch)) / roll \(String(format: "%.2f", snap.imuRoll)) / impact \(String(format: "%.2f", snap.imuImpact))
        QUALITY: \(Int(snap.quality * 100))%
        FATIGUE: \(Int(snap.fatigue * 100))%
        RISK: \(Int(snap.risk * 100))%
        """
        do {
            let url = try AVOMasterSessionCore.shared.writeText(text, area: .reports, fileName: "biomech_vet_report_\(safeTimestamp()).txt")
            reportURL = url
            status = "REPORT EXPORTED · \(url.lastPathComponent)"
        } catch {
            status = "REPORT ERROR · \(error.localizedDescription)"
        }
    }

    func exportColabManifest(camera: CameraManager, sensors: SensorHub, hardware: AVOHardwareReceiver, stableStore: AVOStableStore) {
        let snap = buildSnapshot(camera: camera, sensors: sensors, hardware: hardware, stableStore: stableStore)
        let manifest: [String: String] = [
            "type": "AVO_COLAB_PACK_POINTER",
            "horse": snap.horseName,
            "session": snap.activeSessionId,
            "source_mode": snap.sourceMode,
            "clean_video": selectedVideoURL?.path ?? camera.lastBiomechVideoURL?.path ?? "",
            "dataset_status": camera.datasetStatusText,
            "dataset_count": camera.datasetCountText,
            "review_folder": (try? AVOMasterSessionCore.shared.folder(for: .review).path) ?? "",
            "data_folder": (try? AVOMasterSessionCore.shared.folder(for: .dataRec).path) ?? "",
            "lidar_folder": (try? AVOMasterSessionCore.shared.folder(for: .lidar).path) ?? "",
            "sensor_folder": (try? AVOMasterSessionCore.shared.folder(for: .hardware).path) ?? ""
        ]
        do {
            let data = try JSONEncoder.avoAnalysis.encode(manifest)
            let url = try AVOMasterSessionCore.shared.writeData(data, area: .exports, fileName: "colab_pack_manifest_\(safeTimestamp()).json")
            colabManifestURL = url
            status = "COLAB MANIFEST READY · \(url.lastPathComponent)"
        } catch {
            status = "COLAB ERROR · \(error.localizedDescription)"
        }
    }

    private func loadReplayLiDAR(for videoURL: URL) {
        replayLiDARSamples = []
        replayLiDARFrames = []
        replayLiDARStatus = "NO RECORDED LiDAR FOR VIDEO"

        let fm = FileManager.default
        guard let sessionRoot = sessionRootURL(for: videoURL) else {
            replayLiDARStatus = "NO SESSION ROOT FOR LiDAR"
            return
        }

        // 1) Native scientific LiDAR track created by REC BIOMECH.
        let nativeCandidates = [
            sessionRoot.appendingPathComponent(AVOMasterSessionArea.lidar.rawValue, isDirectory: true).appendingPathComponent("lidar_track.json"),
            sessionRoot.appendingPathComponent("lidar_track.json")
        ]

        for url in nativeCandidates where fm.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let frames = try? JSONDecoder.avoAnalysis.decode([AVORecordedLiDARFrame].self, from: data) {
                replayLiDARFrames = frames
                replayLiDARSamples = frames.map {
                    AVOLiDARDepthSample(time: $0.videoTime,
                                         distanceMeters: $0.distanceMeters,
                                         quality: $0.quality,
                                         width: $0.width,
                                         height: $0.height,
                                         source: $0.source)
                }
                replayLiDARStatus = frames.isEmpty ? "LiDAR TRACK EMPTY" : "REAL REC LiDAR · \(frames.count) FRAMES"
                return
            }
        }

        // 2) Fallback for older sessions.
        let candidates = [
            sessionRoot.appendingPathComponent(AVOMasterSessionArea.lidar.rawValue, isDirectory: true).appendingPathComponent("depth_lidar.json"),
            sessionRoot.appendingPathComponent("depth_lidar.json"),
            sessionRoot.appendingPathComponent(AVOMasterSessionArea.lidar.rawValue, isDirectory: true).appendingPathComponent("lidar_depth.json"),
            sessionRoot.appendingPathComponent(AVOMasterSessionArea.lidar.rawValue, isDirectory: true).appendingPathComponent("lidar_samples.json")
        ]

        for url in candidates where fm.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let samples = try? JSONDecoder.avo.decode([AVOLiDARDepthSample].self, from: data) {
                replayLiDARSamples = samples
                replayLiDARStatus = "LEGACY LiDAR · \(samples.count) SAMPLES"
                return
            }
        }
    }

    func replayLiDARPointsForCurrentTime() -> [AVOLiDARPoint2D] {
        let duration = player?.currentItem.flatMap { item -> Double? in
            let d = CMTimeGetSeconds(item.duration)
            return d.isFinite && d > 0 ? d : nil
        } ?? 1.0
        let rawCurrent = player.map { CMTimeGetSeconds($0.currentTime()) }
        let current = (rawCurrent != nil && rawCurrent!.isFinite) ? rawCurrent! : (duration * playbackPosition)

        if !replayLiDARFrames.isEmpty {
            let target = replayLiDARFrames.min { abs($0.videoTime - current) < abs($1.videoTime - current) } ?? replayLiDARFrames[0]
            return target.points2D
        }

        guard !replayLiDARSamples.isEmpty else { return [] }
        let target = replayLiDARSamples.min { abs($0.time - current) < abs($1.time - current) } ?? replayLiDARSamples[0]
        let q = max(0.12, min(1.0, target.quality))
        let z = max(0.25, min(8.0, target.distanceMeters))

        // Legacy scalar LiDAR fallback. Native sessions use recorded point clouds above.
        var trainingModels: [AVOLiDARPoint2D] = []
        for row in 0..<5 {
            for col in 0..<20 {
                let x = 0.08 + Double(col) * 0.044
                let y = 0.09 + Double(row) * 0.030
                let wave = sin(Double(col) * 0.55 + current * 1.7 + Double(row)) * 0.035
                trainingModels.append(AVOLiDARPoint2D(x: x, y: y + wave, z: z, confidence: q))
            }
        }
        return trainingModels
    }

    private func latestVideo(type: String) -> AVOAnalysisVideoCandidate? {
        availableVideos.first { $0.type == type }
    }

    private func scanVideos(root: URL, type: String, sessionId: String) -> [AVOAnalysisVideoCandidate] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        return files.filter { videoExtensions.contains($0.pathExtension) }.map { url in
            AVOAnalysisVideoCandidate(title: "\(type) · \(sessionId) · \(url.lastPathComponent)", url: url, type: type, sessionId: sessionId, modifiedAt: modifiedDate(url))
        }
    }

    private func modifiedDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func safeTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}

struct AVOBiomechAnalysisEngineProPage: View {
    @ObservedObject var camera: CameraManager
    @ObservedObject var sensors: SensorHub
    @ObservedObject var stableStore: AVOStableStore
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings

    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = AVOBiomechAnalysisEngineProStore()
    @State private var showShare = false
    @State private var showImporter = false
    @State private var showVideoPicker = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.004, green: 0.007, blue: 0.009).ignoresSafeArea()
                VStack(spacing: 8) {
                    header.frame(height: 52)
                    HStack(spacing: 8) {
                        analysisCanvas
                            .frame(width: geo.size.width * 0.61)
                        rightInspector
                    }
                    timelinePanel.frame(height: 156)
                }
                .padding(10)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear {
            engine.bootstrap(camera: camera)
            _ = engine.buildSnapshot(camera: camera, sensors: sensors, hardware: hardware, stableStore: stableStore)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { engine.importExternalVideo(url, camera: camera) }
            case .failure(let error):
                engine.status = "IMPORT ERROR · \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showVideoPicker) { videoPickerSheet }
        .sheet(isPresented: $showShare) {
            if let url = engine.reportURL ?? engine.colabManifestURL { AVOShareSheet(items: [url]) }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: { BottomButton("CLOSE", .orange) }
            VStack(alignment: .leading, spacing: 2) {
                Text("BIOMECH ANALYSIS ENGINE PRO")
                    .foregroundColor(.white)
                    .font(.system(size: 19, weight: .black, design: .monospaced))
                Text("SOURCE VIDEO · SESSION REPLAY · LIVE RASPBERRY · LiDAR · SENSORS · REPORT · COLAB")
                    .foregroundColor(.green.opacity(0.88))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Spacer()
            Text(stableStore.selectedHorseName)
                .foregroundColor(.cyan)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(engine.status)
                .foregroundColor(engine.status.contains("ERROR") ? .red : .green)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.80))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var analysisCanvas: some View {
        VStack(spacing: 6) {
            HStack {
                Text(engine.showClientClean ? "CLEAN VIDEO / CLIENT MODE" : "BIOMECH ANALYSIS VIEW")
                    .foregroundColor(.white)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                Spacer()
                Text(engine.selectedVideoTitle)
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            ZStack(alignment: .topLeading) {
                sourceView
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.22), lineWidth: 1))

                if !engine.showClientClean {
                    if engine.showSkeleton {
                        if engine.isVideoReplayMode {
                            AVOReplaySkeletonOverlay(joints: engine.replayJointsForCurrentTime(), status: engine.replaySkeletonStatus)
                                .allowsHitTesting(false)
                        } else {
                            HorseOverlay(horseBox: camera.horseBox, riderBox: camera.riderBox, riderPosePoints: camera.riderPosePoints, horseKeypoints: camera.horseKeypoints, quality: camera.quality, fatigue: camera.fatigue, risk: camera.risk)
                                .allowsHitTesting(false)
                        }
                    }
                    if engine.showLiDAR { lidarDots }
                    if engine.showSymmetry { symmetryOverlay }
                    if engine.showSensors { liveMiniHUD.padding(12) }
                    if engine.showVetAI { vetRibbon }
                }

                playbackControls
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var sourceView: some View {
        if let player = engine.player, engine.sourceMode != .liveCamera, engine.sourceMode != .raspberryLive {
            VideoPlayer(player: player)
                .background(Color.black)
        } else if engine.sourceMode == .raspberryLive {
            ZStack {
                CameraPreview(manager: camera)
                VStack(spacing: 10) {
                    Text("RASPBERRY LIVE SOURCE")
                    Text("VIDEO STREAM PENDING · TELEMETRY ACTIVE")
                }
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.purple)
                .padding(12)
                .background(Color.black.opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        } else {
            CameraPreview(manager: camera)
        }
    }

    private var playbackControls: some View {
        VStack {
            HStack {
                sourceBadge
                Spacer()
            }
            Spacer()
            if engine.player != nil {
                HStack(spacing: 10) {
                    Button { engine.isPlaying ? engine.pause() : engine.play() } label: { BottomButton(engine.isPlaying ? "PAUSE" : "PLAY", .green) }
                    Button { engine.stop() } label: { BottomButton("STOP", .orange) }
                    Button { showVideoPicker = true } label: { BottomButton("VIDEOS", .cyan) }
                    Spacer()
                }
                .padding(10)
                .background(Color.black.opacity(0.45))
            }
        }
    }

    private var sourceBadge: some View {
        Text("SOURCE · \(engine.sourceMode.rawValue)")
            .foregroundColor(.green)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(10)
    }

    private var lidarDots: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if engine.isVideoReplayMode {
                    let replayPoints = engine.replayLiDARPointsForCurrentTime()
                    if replayPoints.isEmpty {
                        Text("LiDAR REPLAY · NO DEPTH FILE IN THIS SESSION")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.black.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .padding(12)
                    } else {
                        ForEach(replayPoints.prefix(140)) { p in
                            Circle()
                                .fill(Color.cyan.opacity(max(0.20, min(0.95, p.confidence))))
                                .frame(width: CGFloat(max(2, min(9, 10 - p.z))), height: CGFloat(max(2, min(9, 10 - p.z))))
                                .position(x: geo.size.width * CGFloat(p.x), y: geo.size.height * CGFloat(p.y))
                        }
                        Text(engine.replayLiDARStatus)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.black.opacity(0.66))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .padding(12)
                    }
                } else {
                    ForEach(camera.lidarPointCloud2D.prefix(120)) { p in
                        Circle()
                            .fill(Color.cyan.opacity(max(0.20, min(0.95, p.confidence))))
                            .frame(width: CGFloat(max(2, min(9, 10 - p.z))), height: CGFloat(max(2, min(9, 10 - p.z))))
                            .position(x: geo.size.width * CGFloat(p.x), y: geo.size.height * CGFloat(p.y))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var symmetryOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle().fill(Color.clear)
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width * 0.50, y: geo.size.height * 0.12))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.50, y: geo.size.height * 0.88))
                    path.move(to: CGPoint(x: geo.size.width * 0.18, y: geo.size.height * 0.66))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.82, y: geo.size.height * 0.66))
                }
                .stroke(Color.yellow.opacity(0.60), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                VStack(alignment: .leading, spacing: 4) {
                    Text("FRONT \(camera.frontSymmetryText)")
                    Text("HIND  \(camera.hindSymmetryText)")
                    Text("ASYM  \(camera.asymmetry)")
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(8)
                .background(Color.black.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .position(x: geo.size.width * 0.16, y: geo.size.height * 0.18)
            }
        }
        .allowsHitTesting(false)
    }

    private var liveMiniHUD: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("GAIT \(camera.gait)")
            Text("RISK \(Int(camera.risk * 100))% · FAT \(Int(camera.fatigue * 100))% · Q \(Int(camera.quality * 100))%")
            Text("HR \(sensors.pulseStatus) · SPD \(sensors.speedStatus) · CAD \(sensors.cadenceStatus)")
            Text(engine.isVideoReplayMode ? engine.replayLiDARStatus : "LiDAR \(camera.lidarDistanceText) · \(camera.lidarQualityText)")
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .foregroundColor(.green)
        .padding(9)
        .background(Color.black.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var vetRibbon: some View {
        VStack { Spacer(); HStack {
            Text("VET AI · \(camera.vetRiskLevelText) · \(camera.lamenessRiskText) · \(camera.biomechAISuspicionText)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(camera.risk > 0.65 ? .red : .green)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.black.opacity(0.74))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
        }.padding(12) }
    }

    private var rightInspector: some View {
        VStack(spacing: 8) {
            sourcePanel
            layerPanel
            metricsPanel
            actionsPanel
        }
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            panelTitle("SOURCE / SESSION VIDEO")
            Text(engine.selectedVideoTitle)
                .foregroundColor(.cyan)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            HStack(spacing: 6) {
                Button { engine.useLiveCamera() } label: { miniButton("LIVE", .green) }
                Button { engine.selectLatestBiomech() } label: { miniButton("BIOMECH", .cyan) }
                Button { engine.selectLatestClient() } label: { miniButton("CLIENT", .yellow) }
            }
            HStack(spacing: 6) {
                Button { engine.refreshVideoLibrary(camera: camera); showVideoPicker = true } label: { miniButton("SESSION", .blue) }
                Button { showImporter = true } label: { miniButton("IMPORT", .purple) }
                Button { engine.useRaspberryLive() } label: { miniButton("RASPBERRY", .orange) }
            }
        }
        .padding(10)
        .background(panelBackground)
    }

    private var layerPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            panelTitle("LAYERS / EXPORT VIEW")
            toggleRow("Clean client video", $engine.showClientClean)
            toggleRow("Skeleton IA", $engine.showSkeleton)
            toggleRow("LiDAR / depth", $engine.showLiDAR)
            toggleRow("Sensors HUD", $engine.showSensors)
            toggleRow("Symmetry guides", $engine.showSymmetry)
            toggleRow("Stride analysis", $engine.showStride)
            toggleRow("Impact / IMU", $engine.showImpact)
            toggleRow("Vet AI ribbon", $engine.showVetAI)
        }
        .padding(10)
        .background(panelBackground)
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("ANALYSIS METRICS")
            metricGrid
            Divider().background(Color.white.opacity(0.12))
            Text(engine.lastSnapshot?.recommendation ?? "BUILDING RECOMMENDATION...")
                .foregroundColor(.orange)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(panelBackground)
    }

    private var metricGrid: some View {
        VStack(spacing: 6) {
            HStack { metricBox("SCORE", camera.biomechScore, .cyan); metricBox("GAIT", camera.gait, .green) }
            HStack { metricBox("STRIDE", camera.strideText, .yellow); metricBox("LAME", camera.lamenessRiskText, .red) }
            HStack { metricBox("HEAD", camera.headNodText, .orange); metricBox("HIP", camera.hipHikeText, .purple) }
            HStack { metricBox("IMPACT", String(format: "%.2f", sensors.imuImpact), .red); metricBox("RSSI", hardware.rssi, .green) }
        }
    }

    private var actionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("ACTIONS")
            HStack { Button { engine.saveAnalysisJSON(camera: camera, sensors: sensors, hardware: hardware, stableStore: stableStore) } label: { BottomButton("SAVE ANALYSIS", .green) }; Button { engine.exportVetReport(camera: camera, sensors: sensors, hardware: hardware, stableStore: stableStore) } label: { BottomButton("VET REPORT", .cyan) } }
            HStack { Button { engine.exportColabManifest(camera: camera, sensors: sensors, hardware: hardware, stableStore: stableStore) } label: { BottomButton("COLAB BRIDGE", .purple) }; Button { showShare = true } label: { BottomButton("SHARE", .orange) } }
            HStack { Button { camera.prepareDatasetForReview(); engine.status = "REVIEW DATASET PREPARED" } label: { BottomButton("SEND REVIEW", .blue) }; Button { engine.compareMode.toggle() } label: { BottomButton(engine.compareMode ? "COMPARE ON" : "COMPARE", .yellow) } }
            Text("Analysis loads session videos. Video editor remains for commercial MP4 export.")
                .foregroundColor(.gray)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .padding(10)
        .background(panelBackground)
    }

    private var timelinePanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SYNC TIMELINE · VIDEO / SENSOR / LiDAR / IMU")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                Spacer()
                Text("MODE · \(engine.sourceMode.rawValue)")
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Slider(value: $engine.playbackPosition, in: 0...1, onEditingChanged: { editing in
                if !editing { engine.seekToSlider() }
            })
            .tint(.green)
            HStack(spacing: 8) {
                timelineChip("VIDEO", engine.selectedVideoURL?.lastPathComponent ?? camera.biomechVideoStatus, .cyan)
                timelineChip("SKELETON", engine.isVideoReplayMode ? engine.replaySkeletonStatus : camera.anatomyTrackingText, .green)
                timelineChip("LiDAR", engine.isVideoReplayMode ? engine.replayLiDARStatus : camera.lidarFusionStatus, .blue)
                timelineChip("IMU", String(format: "P %.1f R %.1f I %.1f", sensors.imuPitch, sensors.imuRoll, sensors.imuImpact), .orange)
                timelineChip("RASPBERRY", hardware.udpStatus, .purple)
            }
            if engine.compareMode { compareStrip }
        }
        .padding(10)
        .background(panelBackground)
    }

    private var compareStrip: some View {
        HStack(spacing: 8) {
            timelineChip("BEFORE", "LOAD FROM HORSE TIMELINE", .yellow)
            timelineChip("AFTER", "CURRENT SESSION", .green)
            timelineChip("DELTA", "AUTO WHEN 2 SESSIONS SELECTED", .cyan)
        }
    }

    private var videoPickerSheet: some View {
        NavigationView {
            List {
                if engine.availableVideos.isEmpty {
                    Text("No hay vídeos en la sesión/caballo activo.")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                ForEach(engine.availableVideos) { item in
                    Button {
                        engine.selectCandidate(item)
                        showVideoPicker = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .foregroundColor(.primary)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                            Text(item.url.path)
                                .foregroundColor(.secondary)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Analysis Videos")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showVideoPicker = false } } }
        }
    }

    private func miniButton(_ title: String, _ color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title)
                .foregroundColor(.white.opacity(0.86))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .toggleStyle(.switch)
        .tint(.green)
    }

    private func metricBox(_ name: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).foregroundColor(.gray).font(.system(size: 9, weight: .black, design: .monospaced))
            Text(value).foregroundColor(color).font(.system(size: 12, weight: .black, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.48))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func timelineChip(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundColor(.gray).font(.system(size: 8, weight: .black, design: .monospaced))
            Text(value).foregroundColor(color).font(.system(size: 10, weight: .black, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func panelTitle(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.green)
            .font(.system(size: 11, weight: .black, design: .monospaced))
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.68))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.18), lineWidth: 1))
    }
}


struct AVOReplaySkeletonOverlay: View {
    let joints: [TrackedHorseJoint]
    let status: String

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if joints.isEmpty {
                    Text(status)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(9)
                        .background(Color.black.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(12)
                } else {
                    let pointMap = Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, $0) })
                    ForEach(HorseJoint.skeletonEdges) { edge in
                        if let a = pointMap[edge.from], let b = pointMap[edge.to] {
                            Path { path in
                                path.move(to: screenPoint(a, in: geo.size))
                                path.addLine(to: screenPoint(b, in: geo.size))
                            }
                            .stroke(Color.cyan.opacity(edgeOpacity(a, b)), lineWidth: edgeWidth(a, b))
                        }
                    }
                    ForEach(joints) { point in
                        ZStack {
                            Circle()
                                .fill(point.isPredicted ? Color.yellow : Color.green)
                                .frame(width: pointSize(point), height: pointSize(point))
                            Circle()
                                .stroke(Color.black.opacity(0.85), lineWidth: 1.2)
                                .frame(width: pointSize(point), height: pointSize(point))
                        }
                        .position(screenPoint(point, in: geo.size))
                    }
                    Text(status)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Color.black.opacity(0.68))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .padding(12)
                }
            }
        }
    }

    private func screenPoint(_ point: TrackedHorseJoint, in size: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(1.0 - point.y) * size.height)
    }

    private func pointSize(_ point: TrackedHorseJoint) -> CGFloat {
        point.confidence >= 0.55 ? 10 : 8
    }

    private func edgeWidth(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> CGFloat {
        (a.isPredicted || b.isPredicted) ? 2 : 3
    }

    private func edgeOpacity(_ a: TrackedHorseJoint, _ b: TrackedHorseJoint) -> Double {
        max(0.20, min(0.95, (a.confidence + b.confidence) / 2.0))
    }
}

