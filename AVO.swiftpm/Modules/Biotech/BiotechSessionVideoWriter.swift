import Foundation
import AVFoundation
import UIKit

// MARK: - AVO PHASE 122
// BIOTECH SESSION VIDEO WRITER
//
// Real MP4 writer for REC CLIENT / REC BIOTECH.
// Accepts rendered UIImages or camera frames converted to UIImage.

@MainActor
public final class BiotechSessionVideoWriter: ObservableObject {

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var status: String = "VIDEO WRITER READY"
    @Published public private(set) var outputURL: URL?
    @Published public private(set) var writtenFrames: Int = 0

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var fps: Int = 60
    private var videoSize: CGSize = CGSize(width: 1920, height: 1080)
    private let queue = DispatchQueue(label: "avo.biotech.session.video.writer", qos: .userInitiated)

    public init() {}

    public func start(url: URL, size: CGSize, fps: Int = 60) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            self.fps = max(1, fps)
            self.videoSize = size
            self.writtenFrames = 0
            self.outputURL = url

            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 9_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: Int(size.width),
                    kCVPixelBufferHeightKey as String: Int(size.height)
                ]
            )

            guard writer.canAdd(input) else {
                status = "VIDEO WRITER INPUT ERROR"
                return
            }

            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            self.writer = writer
            self.input = input
            self.adaptor = adaptor
            self.isRecording = true
            self.status = "REC STARTED"
        } catch {
            self.status = "REC ERROR: \(error.localizedDescription)"
            self.isRecording = false
        }
    }

    public func append(image: UIImage) {
        guard isRecording,
              let input,
              let adaptor,
              input.isReadyForMoreMediaData else { return }

        let frameNumber = writtenFrames
        let time = CMTime(value: CMTimeValue(frameNumber), timescale: CMTimeScale(fps))

        if let buffer = pixelBuffer(from: image, size: videoSize) {
            adaptor.append(buffer, withPresentationTime: time)
            writtenFrames += 1
            status = "REC \(writtenFrames) FRAMES"
        }
    }

    public func stop(completion: ((URL?) -> Void)? = nil) {
        guard isRecording else {
            completion?(outputURL)
            return
        }

        isRecording = false
        status = "STOPPING REC"

        guard let writer, let input else {
            completion?(outputURL)
            return
        }

        input.markAsFinished()
        writer.finishWriting { [weak self] in
            Task { @MainActor in
                self?.status = writer.status == .completed ? "REC SAVED" : "REC SAVE ERROR"
                completion?(self?.outputURL)
            }
        }
    }

    private func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        if let cg = image.cgImage {
            context.draw(cg, in: CGRect(origin: .zero, size: size))
        }

        return buffer
    }
}
