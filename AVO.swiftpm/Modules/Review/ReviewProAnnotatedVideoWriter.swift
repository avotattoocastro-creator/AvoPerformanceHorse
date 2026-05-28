import Foundation
import AVFoundation
import UIKit

// MARK: - REVIEW PRO PHASE 104
// ANNOTATED VIDEO WRITER
//
// Writes an annotated MP4 from frame images.
// Designed to work with ReviewProAnnotatedVideoExportEngine.renderAnnotatedFrame.

public final class ReviewProAnnotatedVideoWriter {

    public init() {}

    public func writeMP4(images: [UIImage],
                         outputURL: URL,
                         fps: Int = 30,
                         size: CGSize? = nil,
                         completion: @escaping (Result<URL, Error>) -> Void) {

        guard let first = images.first else {
            completion(.failure(NSError(domain: "ReviewProAnnotatedVideoWriter", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No frames to export."
            ])))
            return
        }

        let videoSize = size ?? first.size

        do {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(videoSize.width),
                AVVideoHeightKey: Int(videoSize.height)
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: Int(videoSize.width),
                    kCVPixelBufferHeightKey as String: Int(videoSize.height)
                ]
            )

            guard writer.canAdd(input) else {
                completion(.failure(NSError(domain: "ReviewProAnnotatedVideoWriter", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot add video input."
                ])))
                return
            }

            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            let queue = DispatchQueue(label: "review.pro.annotated.video.writer")
            let renderer = ReviewProAnnotatedVideoExportEngine()

            input.requestMediaDataWhenReady(on: queue) {
                var frame = 0

                while frame < images.count {
                    if input.isReadyForMoreMediaData {
                        autoreleasepool {
                            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))
                            if let buffer = renderer.makePixelBuffer(from: images[frame], size: videoSize) {
                                adaptor.append(buffer, withPresentationTime: time)
                            }
                            frame += 1
                        }
                    } else {
                        Thread.sleep(forTimeInterval: 0.002)
                    }
                }

                input.markAsFinished()
                writer.finishWriting {
                    if writer.status == .completed {
                        completion(.success(outputURL))
                    } else {
                        completion(.failure(writer.error ?? NSError(domain: "ReviewProAnnotatedVideoWriter", code: -3, userInfo: [
                            NSLocalizedDescriptionKey: "Unknown video writer error."
                        ])))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
