import Foundation
import AVFoundation
import UIKit
import CoreGraphics

// MARK: - REVIEW PRO PHASE 102
// COMPLETE VIDEO ENGINE
//
// Additive module.
// Purpose:
// - Load MP4/MOV assets.
// - Build a real frame timeline.
// - Extract exact frames using AVAssetImageGenerator.
// - Provide async prefetch/cache.
// - Support scrub frame-by-frame.
// - Export normalized frame metadata for tracking/biomech engines.

public struct ReviewProVideoFrameInfo: Codable, Hashable, Identifiable {
    public var id: Int { frameIndex }
    public var frameIndex: Int
    public var timeSeconds: Double
    public var timestampLabel: String
    public var isCached: Bool
    public var width: Int
    public var height: Int

    public init(frameIndex: Int,
                timeSeconds: Double,
                isCached: Bool = false,
                width: Int = 0,
                height: Int = 0) {
        self.frameIndex = frameIndex
        self.timeSeconds = timeSeconds
        self.timestampLabel = String(format: "%.3fs", timeSeconds)
        self.isCached = isCached
        self.width = width
        self.height = height
    }
}

public struct ReviewProVideoAssetInfo: Codable, Hashable {
    public var urlPath: String
    public var duration: Double
    public var nominalFPS: Double
    public var totalFrames: Int
    public var naturalWidth: Int
    public var naturalHeight: Int

    public init(urlPath: String,
                duration: Double,
                nominalFPS: Double,
                totalFrames: Int,
                naturalWidth: Int,
                naturalHeight: Int) {
        self.urlPath = urlPath
        self.duration = duration
        self.nominalFPS = nominalFPS
        self.totalFrames = totalFrames
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
    }
}

public enum ReviewProVideoEngineError: Error, LocalizedError {
    case noVideoTrack
    case invalidDuration
    case invalidFrameRate
    case frameOutOfRange
    case imageExtractionFailed

    public var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "No video track found in selected asset."
        case .invalidDuration: return "Invalid video duration."
        case .invalidFrameRate: return "Invalid video frame rate."
        case .frameOutOfRange: return "Requested frame index is out of range."
        case .imageExtractionFailed: return "Could not extract requested frame."
        }
    }
}

public final class ReviewProCompleteVideoEngine: ObservableObject {

    @Published public private(set) var status: String = "VIDEO ENGINE READY"
    @Published public private(set) var assetInfo: ReviewProVideoAssetInfo?
    @Published public private(set) var timeline: [ReviewProVideoFrameInfo] = []
    @Published public private(set) var currentFrameIndex: Int = 0
    @Published public private(set) var cachedFrameCount: Int = 0

    private var asset: AVAsset?
    private var imageGenerator: AVAssetImageGenerator?
    private var imageCache: [Int: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "review.pro.video.cache.queue", qos: .userInitiated)

    public init() {}

    public func load(url: URL, preferredFPS: Double? = nil) throws {
        status = "LOADING VIDEO"

        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw ReviewProVideoEngineError.noVideoTrack
        }

        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else {
            throw ReviewProVideoEngineError.invalidDuration
        }

        let trackFPS = Double(track.nominalFrameRate)
        let fps = preferredFPS ?? trackFPS
        guard fps.isFinite, fps > 0 else {
            throw ReviewProVideoEngineError.invalidFrameRate
        }

        let natural = track.naturalSize.applying(track.preferredTransform)
        let width = Int(abs(natural.width))
        let height = Int(abs(natural.height))
        let total = max(1, Int((duration * fps).rounded(.down)))

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1920, height: 1920)

        self.asset = asset
        self.imageGenerator = generator
        self.imageCache.removeAll()
        self.cachedFrameCount = 0
        self.currentFrameIndex = 0

        self.assetInfo = ReviewProVideoAssetInfo(
            urlPath: url.path,
            duration: duration,
            nominalFPS: fps,
            totalFrames: total,
            naturalWidth: width,
            naturalHeight: height
        )

        self.timeline = (0..<total).map { index in
            ReviewProVideoFrameInfo(
                frameIndex: index,
                timeSeconds: Double(index) / fps,
                isCached: false,
                width: width,
                height: height
            )
        }

        status = "VIDEO LOADED \(total) FRAMES"
    }

    public func timeForFrame(_ frameIndex: Int) throws -> CMTime {
        guard let info = assetInfo else { throw ReviewProVideoEngineError.invalidDuration }
        guard frameIndex >= 0 && frameIndex < info.totalFrames else {
            throw ReviewProVideoEngineError.frameOutOfRange
        }
        return CMTime(seconds: Double(frameIndex) / info.nominalFPS, preferredTimescale: 600)
    }

    public func extractFrame(_ frameIndex: Int) throws -> UIImage {
        if let cached = imageCache[frameIndex] {
            return cached
        }

        guard let generator = imageGenerator else {
            throw ReviewProVideoEngineError.imageExtractionFailed
        }

        let time = try timeForFrame(frameIndex)
        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
        let image = UIImage(cgImage: cgImage)

        imageCache[frameIndex] = image
        cachedFrameCount = imageCache.count
        markCached(frameIndex)

        return image
    }

    public func scrub(to frameIndex: Int) throws -> UIImage {
        let image = try extractFrame(frameIndex)
        currentFrameIndex = frameIndex
        prefetchAround(frameIndex: frameIndex)
        trimCache(around: frameIndex)
        return image
    }

    public func prefetchAround(frameIndex: Int, radius: Int = 24) {
        guard let info = assetInfo else { return }

        let start = max(0, frameIndex - radius)
        let end = min(info.totalFrames - 1, frameIndex + radius)

        cacheQueue.async { [weak self] in
            guard let self else { return }

            for idx in start...end {
                if self.imageCache[idx] != nil { continue }
                _ = try? self.extractFrame(idx)
            }
        }
    }

    public func trimCache(around frameIndex: Int, keepRadius: Int = 180) {
        let keysToRemove = imageCache.keys.filter { abs($0 - frameIndex) > keepRadius }
        for key in keysToRemove {
            imageCache.removeValue(forKey: key)
        }
        cachedFrameCount = imageCache.count
    }

    public func clearCache() {
        imageCache.removeAll()
        cachedFrameCount = 0
        for i in timeline.indices {
            timeline[i].isCached = false
        }
    }

    private func markCached(_ frameIndex: Int) {
        guard let idx = timeline.firstIndex(where: { $0.frameIndex == frameIndex }) else { return }
        timeline[idx].isCached = true
    }
}
