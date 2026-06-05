import Foundation
import UIKit
import SwiftUI

struct DatasetQualityReport: Codable, Hashable {
    let quality: Double
    let brightness: Double
    let blurRisk: Double
    let horseArea: Double
    let pointRatio: Double
    let recommendation: String

    var qualityPercent: Int { Int((quality * 100).rounded()) }
    var color: Color {
        if quality >= 0.75 { return .green }
        if quality >= 0.45 { return .yellow }
        return .red
    }
}

enum DatasetClass: String, CaseIterable, Identifiable {
    case all = "ALL"
    case good = "GOOD"
    case review = "REVIEW"
    case negative = "NEGATIVE"
    case rejected = "REJECTED"
    case annotated = "ANNOTATED"
    case untagged = "UNTAGGED"

    var id: String { rawValue }
}

struct DatasetStats: Hashable {
    var total: Int = 0
    var good: Int = 0
    var review: Int = 0
    var negative: Int = 0
    var rejected: Int = 0
    var annotated: Int = 0
    var untagged: Int = 0
}

final class DatasetQualityManager {
    static func normalizedLabel(_ label: String) -> DatasetClass {
        let value = label.lowercased()
        if value.contains("good") { return .good }
        if value.contains("reject") || value.contains("bad") { return .rejected }
        if value.contains("negative") || value.contains("sin_caballo") { return .negative }
        if value.contains("review") || value.contains("pending") { return .review }
        return .untagged
    }

    static func stats(for records: [HorseDatasetFrameRecord]) -> DatasetStats {
        var s = DatasetStats()
        s.total = records.count
        for r in records {
            if !r.keypoints.isEmpty { s.annotated += 1 }
            switch normalizedLabel(r.label) {
            case .good: s.good += 1
            case .review: s.review += 1
            case .negative: s.negative += 1
            case .rejected: s.rejected += 1
            case .untagged: s.untagged += 1
            default: break
            }
        }
        return s
    }

    static func filter(_ items: [HorseDatasetReviewItem], by filter: DatasetClass) -> [HorseDatasetReviewItem] {
        switch filter {
        case .all:
            return items
        case .annotated:
            return items.filter { !$0.record.keypoints.isEmpty }
        case .good, .review, .negative, .rejected, .untagged:
            return items.filter { normalizedLabel($0.record.label) == filter }
        }
    }

    static func analyze(image: UIImage?, record: HorseDatasetFrameRecord) -> DatasetQualityReport {
        let horseArea: Double
        if let box = record.horseBox {
            horseArea = max(0.0, min(1.0, box.boxW * box.boxH))
        } else {
            horseArea = 0.0
        }

        let expectedPoints = max(Double(HorseJoint.allCases.count), 1.0)
        let pointRatio = min(Double(record.keypoints.count) / expectedPoints, 1.0)

        let brightness = estimateBrightness(image: image)
        let brightnessScore = 1.0 - min(abs(brightness - 0.52) / 0.52, 1.0)

        let blurRisk = estimateBlurRisk(image: image)
        let sharpnessScore = 1.0 - blurRisk

        let areaScore: Double
        if horseArea == 0 { areaScore = record.horseVisible ? 0.25 : 0.0 }
        else if horseArea < 0.08 { areaScore = 0.25 }
        else if horseArea > 0.85 { areaScore = 0.55 }
        else { areaScore = min(horseArea / 0.32, 1.0) }

        let quality = max(0.0, min(1.0,
            0.34 * areaScore +
            0.26 * pointRatio +
            0.20 * brightnessScore +
            0.20 * sharpnessScore
        ))

        let recommendation: String
        if !record.horseVisible && record.keypoints.isEmpty {
            recommendation = "NEGATIVE / SIN CABALLO"
        } else if quality >= 0.75 && !record.keypoints.isEmpty {
            recommendation = "GOOD PARA ENTRENAR"
        } else if blurRisk > 0.65 || horseArea < 0.06 {
            recommendation = "REJECT: BLUR / LEJOS / CORTADO"
        } else {
            recommendation = "REVIEW MANUAL"
        }

        return DatasetQualityReport(
            quality: quality,
            brightness: brightness,
            blurRisk: blurRisk,
            horseArea: horseArea,
            pointRatio: pointRatio,
            recommendation: recommendation
        )
    }

    private static func estimateBrightness(image: UIImage?) -> Double {
        guard let cg = image?.cgImage else { return 0.5 }
        let width = 32
        let height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0.5 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var sum = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]) / 255.0
            let g = Double(pixels[i + 1]) / 255.0
            let b = Double(pixels[i + 2]) / 255.0
            sum += (0.2126 * r + 0.7152 * g + 0.0722 * b)
        }
        return sum / Double(width * height)
    }

    private static func estimateBlurRisk(image: UIImage?) -> Double {
        guard let cg = image?.cgImage else { return 0.35 }
        let width = 48
        let height = 48
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0.35 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        func lum(_ x: Int, _ y: Int) -> Double {
            let i = (y * width + x) * 4
            return (Double(pixels[i]) + Double(pixels[i + 1]) + Double(pixels[i + 2])) / (3.0 * 255.0)
        }
        var edge = 0.0
        var count = 0.0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let dx = abs(lum(x + 1, y) - lum(x - 1, y))
                let dy = abs(lum(x, y + 1) - lum(x, y - 1))
                edge += dx + dy
                count += 1.0
            }
        }
        let sharpness = min((edge / max(count, 1.0)) * 12.0, 1.0)
        return 1.0 - sharpness
    }
}
