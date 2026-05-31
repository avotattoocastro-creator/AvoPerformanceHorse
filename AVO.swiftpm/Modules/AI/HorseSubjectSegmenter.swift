import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct HorseSegmentationResult: Hashable {
    let maskURL: URL?
    let subjectBox: CGRect?
    let coverage: Double
    let cleanedImage: UIImage?
}

final class HorseSubjectSegmenter: ObservableObject {
    @Published var status: String = "SEGMENT READY"
    private let ciContext = CIContext()

    func segmentSubject(in image: UIImage, frameId: String, datasetManager: HorseDatasetManager) -> HorseSegmentationResult? {
        guard let cgImage = image.fixedUp().cgImage else {
            status = "SEGMENT: IMAGE ERROR"
            return nil
        }

        if #available(iOS 17.0, *) {
            do {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                try handler.perform([request])

                guard let observation = request.results?.first else {
                    status = "SEGMENT: SIN SUJETO"
                    return nil
                }

                let maskBuffer = try observation.generateScaledMaskForImage(
                    forInstances: observation.allInstances,
                    from: handler
                )

                let maskCI = CIImage(cvPixelBuffer: maskBuffer)
                let originalCI = CIImage(cgImage: cgImage)
                let maskImage = UIImage(ciImage: maskCI)

                let subjectBox = Self.boundingBox(from: maskBuffer)
                let coverage = subjectBox.map { Double($0.width * $0.height) } ?? 0.0
                let cleaned = createCleanedImage(original: originalCI, mask: maskCI)
                let maskURL = saveMask(maskImage, frameId: frameId, datasetManager: datasetManager)

                status = subjectBox == nil ? "SEGMENT: MÁSCARA SIN CAJA" : "SEGMENT: OK · ÁREA \(Int(coverage * 100))%"
                return HorseSegmentationResult(maskURL: maskURL, subjectBox: subjectBox, coverage: coverage, cleanedImage: cleaned)
            } catch {
                status = "SEGMENT ERROR: \(error.localizedDescription)"
                return nil
            }
        } else {
            status = "SEGMENT: REQUIERE iPadOS 17+"
            return nil
        }
    }

    private func createCleanedImage(original: CIImage, mask: CIImage) -> UIImage? {
        let transparent = CIImage(color: .clear).cropped(to: original.extent)
        let filter = CIFilter.blendWithMask()
        filter.inputImage = original
        filter.backgroundImage = transparent
        filter.maskImage = mask
        guard let output = filter.outputImage,
              let cg = ciContext.createCGImage(output, from: original.extent) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up)
    }

    private func saveMask(_ image: UIImage, frameId: String, datasetManager: HorseDatasetManager) -> URL? {
        let masksURL = datasetManager.rootURL.appendingPathComponent("masks", isDirectory: true)
        try? FileManager.default.createDirectory(at: masksURL, withIntermediateDirectories: true)
        let url = masksURL.appendingPathComponent("\(frameId)_mask.png")
        guard let data = image.pngData() else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
    }

    static func boundingBox(from pixelBuffer: CVPixelBuffer) -> CGRect? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else { return nil }

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var count = 0

        let threshold: UInt8 = 18
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        if format == kCVPixelFormatType_OneComponent8 {
            let trainingModelr = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                let row = trainingModelr.advanced(by: y * bytesPerRow)
                for x in 0..<width {
                    if row[x] > threshold {
                        minX = min(minX, x); minY = min(minY, y)
                        maxX = max(maxX, x); maxY = max(maxY, y)
                        count += 1
                    }
                }
            }
        } else {
            let trainingModelr = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                let row = trainingModelr.advanced(by: y * bytesPerRow)
                for x in 0..<width {
                    if row[x] > threshold {
                        minX = min(minX, x); minY = min(minY, y)
                        maxX = max(maxX, x); maxY = max(maxY, y)
                        count += 1
                    }
                }
            }
        }

        guard count > 80, maxX > minX, maxY > minY else { return nil }

        let padX = Double(maxX - minX) * 0.04
        let padY = Double(maxY - minY) * 0.05
        let x = max(0.0, Double(minX) / Double(width) - padX / Double(width))
        let y = max(0.0, Double(minY) / Double(height) - padY / Double(height))
        let w = min(1.0 - x, Double(maxX - minX) / Double(width) + (padX * 2.0) / Double(width))
        let h = min(1.0 - y, Double(maxY - minY) / Double(height) + (padY * 2.0) / Double(height))
        return CGRect(x: x, y: y, width: max(w, 0.02), height: max(h, 0.02))
    }
}

extension UIImage {
    func fixedUp() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
