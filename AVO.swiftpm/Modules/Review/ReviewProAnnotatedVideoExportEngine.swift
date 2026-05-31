import Foundation
import AVFoundation
import UIKit
import CoreGraphics

// MARK: - REVIEW PRO PHASE 103
// ANNOTATED VIDEO EXPORT ENGINE
//
// Complete export helper for future connection:
// renders source frame + pose points into images suitable for video writing.
// This module keeps writing logic separated so it can be used by existing UI.

public final class ReviewProAnnotatedVideoExportEngine {

    public init() {}

    public func renderAnnotatedFrame(image: UIImage,
                                     pose: ReviewProPoseFrame?,
                                     size: CGSize? = nil) -> UIImage {
        let targetSize = size ?? image.size
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            image.draw(in: CGRect(origin: .zero, size: targetSize))

            guard let pose else { return }

            for point in pose.points {
                let x = CGFloat(point.x) * targetSize.width
                let y = CGFloat(point.y) * targetSize.height
                let rect = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)

                let color: UIColor = point.isOcclusionRecovered ? .orange : .cyan
                color.setFill()
                ctx.cgContext.fillEllipse(in: rect)

                UIColor.black.withAlphaComponent(0.7).setStroke()
                ctx.cgContext.strokeEllipse(in: rect)
            }
        }
    }

    public func makePixelBuffer(from image: UIImage,
                                size: CGSize) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
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

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        guard let cgImage = image.cgImage else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))

        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
