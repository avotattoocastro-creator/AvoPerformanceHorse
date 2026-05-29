import Foundation
import AVFoundation
import CoreGraphics

// MARK: - AVO PHASE 108
// Modern AVFoundation helpers for iOS 16+
//
// Purpose:
// - New code should use these helpers to avoid deprecated warnings:
//   duration, tracks(withMediaType:), nominalFrameRate,
//   naturalSize, preferredTransform.
// - Existing legacy files are left intact unless they produced real errors.

public enum AVOModernVideoLoadError: Error {
    case noVideoTrack
    case invalidDuration
    case invalidFrameRate
}

public struct AVOModernVideoInfo: Sendable, Hashable {
    public var duration: Double
    public var fps: Double
    public var naturalSize: CGSize
    public var preferredTransform: CGAffineTransform

    public init(duration: Double,
                fps: Double,
                naturalSize: CGSize,
                preferredTransform: CGAffineTransform) {
        self.duration = duration
        self.fps = fps
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
    }
}

public enum AVOModernAVFoundationHelper {

    public static func loadVideoInfo(from url: URL) async throws -> AVOModernVideoInfo {
        let asset = AVURLAsset(url: url)
        let durationTime = try await asset.load(.duration)
        let duration = CMTimeGetSeconds(durationTime)

        guard duration.isFinite, duration > 0 else {
            throw AVOModernVideoLoadError.invalidDuration
        }

        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            throw AVOModernVideoLoadError.noVideoTrack
        }

        let fps = try await track.load(.nominalFrameRate)
        guard fps.isFinite, fps > 0 else {
            throw AVOModernVideoLoadError.invalidFrameRate
        }

        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)

        return AVOModernVideoInfo(
            duration: duration,
            fps: Double(fps),
            naturalSize: naturalSize,
            preferredTransform: transform
        )
    }
}
