import Foundation
import UIKit
import CoreGraphics

struct HorseDatasetPostProcessor {
    static func padded(_ box: CGRect, padding: CGFloat) -> CGRect {
        let px = box.width * padding
        let py = box.height * padding
        let x = max(0, box.minX - px)
        let y = max(0, box.minY - py)
        let maxX = min(1, box.maxX + px)
        let maxY = min(1, box.maxY + py)
        return CGRect(x: x, y: y, width: max(0.01, maxX - x), height: max(0.01, maxY - y))
    }

    static func crop(_ image: UIImage, normalizedBox: CGRect) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let rect = CGRect(
            x: max(0, normalizedBox.minX * w),
            y: max(0, normalizedBox.minY * h),
            width: min(w, normalizedBox.width * w),
            height: min(h, normalizedBox.height * h)
        ).integral
        guard rect.width > 4, rect.height > 4, let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    static func fitOnBlackCanvas(_ image: UIImage, size: CGSize) -> UIImage {
        let source = image.fixedUp()
        let aspect = source.size.width / max(source.size.height, 1)
        let targetAspect = size.width / max(size.height, 1)
        var drawSize: CGSize
        if aspect > targetAspect {
            drawSize = CGSize(width: size.width, height: size.width / aspect)
        } else {
            drawSize = CGSize(width: size.height * aspect, height: size.height)
        }
        let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        source.draw(in: CGRect(origin: origin, size: drawSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? source
    }

    static func reprojectToCropOnly(points: [EditableHorseAnnotation], fromCrop crop: CGRect) -> [EditableHorseAnnotation] {
        points.compactMap { p in
            let nx = (p.x - Double(crop.minX)) / Double(crop.width)
            let ny = (p.y - Double(crop.minY)) / Double(crop.height)
            guard nx >= 0, nx <= 1, ny >= 0, ny <= 1 else { return nil }
            var out = p
            out.x = nx
            out.y = ny
            return out
        }
    }

    static func reproject(points: [EditableHorseAnnotation], fromCrop crop: CGRect, intoCanvas canvasSize: CGSize, sourceCropImageSize: CGSize) -> [EditableHorseAnnotation] {
        let aspect = sourceCropImageSize.width / max(sourceCropImageSize.height, 1)
        let targetAspect = canvasSize.width / max(canvasSize.height, 1)
        var drawSize: CGSize
        if aspect > targetAspect {
            drawSize = CGSize(width: canvasSize.width, height: canvasSize.width / aspect)
        } else {
            drawSize = CGSize(width: canvasSize.height * aspect, height: canvasSize.height)
        }
        let ox = (canvasSize.width - drawSize.width) / 2
        let oy = (canvasSize.height - drawSize.height) / 2
        return points.compactMap { p in
            let cx = (p.x - Double(crop.minX)) / Double(crop.width)
            let cy = (p.y - Double(crop.minY)) / Double(crop.height)
            guard cx >= 0, cx <= 1, cy >= 0, cy <= 1 else { return nil }
            let px = CGFloat(cx) * drawSize.width + ox
            let py = CGFloat(cy) * drawSize.height + oy
            var out = p
            out.x = Double(px / max(canvasSize.width, 1))
            out.y = Double(py / max(canvasSize.height, 1))
            return out
        }
    }
}
