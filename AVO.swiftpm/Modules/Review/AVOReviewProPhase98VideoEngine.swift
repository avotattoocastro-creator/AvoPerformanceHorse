import Foundation
import UIKit
import AVFoundation
import CoreGraphics

// MARK: - REVIEW PRO PHASE 98 - Conservative Real Video Engine Add-on
// Additive module: does not replace existing REVIEW engines.
// Purpose: provide a safer MP4 frame cache and frame-accurate scrub foundation without deleting previous files.

struct AVOPhase98VideoFrame: Identifiable, Hashable {
    let id: String
    let index: Int
    let timeSeconds: Double
    let image: UIImage
    let sourceURL: URL
}

struct AVOPhase98VideoSummary: Hashable {
    var fileName: String = "--"
    var durationSeconds: Double = 0
    var nominalFPS: Double = 0
    var naturalSize: CGSize = .zero
    var estimatedFrames: Int = 0
    var cachedFrames: Int = 0

    var hudText: String {
        let w = Int(naturalSize.width.rounded())
        let h = Int(naturalSize.height.rounded())
        return "\(fileName) · \(String(format: "%.2f", durationSeconds))s · \(w)x\(h) · \(String(format: "%.1f", nominalFPS)) fps · cache \(cachedFrames)/\(estimatedFrames)"
    }
}

final class AVOPhase98VideoCacheEngine: ObservableObject {
    @Published private(set) var status: String = "PHASE98 VIDEO CACHE READY"
    @Published private(set) var summary = AVOPhase98VideoSummary()
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var selectedIndex: Int = 0
    @Published private(set) var selectedTimeSeconds: Double = 0
    @Published private(set) var lastError: String = ""

    private var frameCache: [Int: AVOPhase98VideoFrame] = [:]
    private var sortedIndexes: [Int] = []
    private let queue = DispatchQueue(label: "avo.phase98.video.cache", qos: .userInitiated)

    var cachedFrameCount: Int { frameCache.count }

    var currentFrame: AVOPhase98VideoFrame? {
        frameCache[selectedIndex]
    }

    func reset() {
        frameCache.removeAll()
        sortedIndexes.removeAll()
        selectedIndex = 0
        selectedTimeSeconds = 0
        summary = AVOPhase98VideoSummary()
        status = "PHASE98 VIDEO CACHE READY"
        lastError = ""
        isBusy = false
    }

    func frame(at index: Int) -> AVOPhase98VideoFrame? {
        frameCache[index]
    }

    func seek(to index: Int) {
        guard !sortedIndexes.isEmpty else { return }
        let clamped = max(sortedIndexes.first ?? 0, min(index, sortedIndexes.last ?? index))
        selectedIndex = clamped
        selectedTimeSeconds = frameCache[clamped]?.timeSeconds ?? selectedTimeSeconds
    }

    func nearestFrame(to timeSeconds: Double) -> AVOPhase98VideoFrame? {
        guard !frameCache.isEmpty else { return nil }
        return frameCache.values.min { abs($0.timeSeconds - timeSeconds) < abs($1.timeSeconds - timeSeconds) }
    }

    func prepare(url: URL, targetFPS: Double = 12, maxFrames: Int = 600) {
        guard !isBusy else { return }
        reset()
        isBusy = true
        status = "OPENING MP4 REAL"

        let granted = url.startAccessingSecurityScopedResource()
        queue.async {
            defer {
                if granted { url.stopAccessingSecurityScopedResource() }
            }

            let asset = AVAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)
            guard duration.isFinite && duration > 0 else {
                DispatchQueue.main.async {
                    self.lastError = "MP4 no válido o duración cero"
                    self.status = "VIDEO ERROR"
                    self.isBusy = false
                }
                return
            }

            let track = asset.tracks(withMediaType: .video).first
            let natural = track?.naturalSize.applying(track?.preferredTransform ?? .identity) ?? .zero
            let size = CGSize(width: abs(natural.width), height: abs(natural.height))
            let nominal = Double(track?.nominalFrameRate ?? 0)
            let safeFPS = max(1.0, min(targetFPS, nominal > 0 ? nominal : targetFPS))
            let step = 1.0 / safeFPS
            let count = min(maxFrames, max(1, Int((duration / step).rounded(.down)) + 1))

            var times: [NSValue] = []
            times.reserveCapacity(count)
            for i in 0..<count {
                let t = min(duration, Double(i) * step)
                times.append(NSValue(time: CMTime(seconds: t, preferredTimescale: 600)))
            }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: min(step * 0.25, 0.025), preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: min(step * 0.25, 0.025), preferredTimescale: 600)
            generator.maximumSize = CGSize(width: 1920, height: 1080)

            var localCache: [Int: AVOPhase98VideoFrame] = [:]
            let group = DispatchGroup()
            let lock = NSLock()

            for (index, value) in times.enumerated() {
                group.enter()
                generator.generateCGImagesAsynchronously(forTimes: [value]) { requested, image, actual, result, error in
                    defer { group.leave() }
                    guard result == .succeeded, let image else { return }
                    let uiImage = UIImage(cgImage: image)
                    let actualSeconds = CMTimeGetSeconds(actual)
                    let frame = AVOPhase98VideoFrame(id: "\(url.lastPathComponent)-\(index)", index: index, timeSeconds: actualSeconds, image: uiImage, sourceURL: url)
                    lock.lock()
                    localCache[index] = frame
                    lock.unlock()
                }
            }

            group.wait()
            let indexes = localCache.keys.sorted()
            DispatchQueue.main.async {
                self.frameCache = localCache
                self.sortedIndexes = indexes
                self.selectedIndex = indexes.first ?? 0
                self.selectedTimeSeconds = self.frameCache[self.selectedIndex]?.timeSeconds ?? 0
                self.summary = AVOPhase98VideoSummary(fileName: url.lastPathComponent,
                                                       durationSeconds: duration,
                                                       nominalFPS: nominal,
                                                       naturalSize: size,
                                                       estimatedFrames: count,
                                                       cachedFrames: localCache.count)
                self.status = localCache.isEmpty ? "NO FRAMES EXTRACTED" : "VIDEO CACHE READY · \(localCache.count) FRAMES"
                self.isBusy = false
            }
        }
    }
}
