import Foundation
import AVFoundation
import UIKit

// MARK: - BIOTECH PHASE 117
// CAMERA FRAME OUTPUT HOOK
//
// Optional hook for real AVCaptureVideoDataOutput.
// Add this output to the BIOTECH camera session if you want live frames
// to be forwarded into BiotechDataToReviewBridge when DATA is ON.

public final class BiotechCameraFrameOutputHook: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    public static let shared = BiotechCameraFrameOutputHook()

    private let ciContext = CIContext()
    private var lastUIImageConversionTime: TimeInterval = 0

    private override init() {
        super.init()
    }

    public func makeVideoDataOutput() -> AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let queue = DispatchQueue(label: "biotech.data.to.review.frames", qos: .userInitiated)
        output.setSampleBufferDelegate(self, queue: queue)

        return output
    }

    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        let timeSeconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)

        // Avoid forcing UIImage conversion for every frame unless bridge asks for memory images.
        Task { @MainActor in
            let bridge = BiotechDataToReviewBridge.shared
            guard bridge.isDataOn else { return }

            if bridge.keepUIImageInMemory {
                let image = self.makeUIImage(from: buffer)
                bridge.acceptFrame(
                    image: image,
                    source: "biotech-camera-output",
                    timeSeconds: timeSeconds,
                    width: width,
                    height: height,
                    qualityTag: "camera-frame"
                )
            } else {
                bridge.acceptFrame(
                    image: nil,
                    source: "biotech-camera-output",
                    timeSeconds: timeSeconds,
                    width: width,
                    height: height,
                    qualityTag: "camera-frame-metadata"
                )
            }
        }
    }

    private func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
