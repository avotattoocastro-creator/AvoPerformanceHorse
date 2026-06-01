import Foundation
import SwiftUI
import CoreGraphics
import UIKit

// MARK: - REVIEW PRO PHASE 98 - Pencil + Quality Engine Add-on
// Additive module for Apple Pencil precision, snapping, and dataset quality scoring.

struct AVOPhase98AnnotationQuality: Hashable {
    var score: Double
    var visiblePoints: Int
    var lowConfidencePoints: [HorseJoint]
    var anatomicalWarnings: [String]
    var outlierPoints: [HorseJoint]

    var statusText: String {
        let pct = Int(score * 100)
        if score >= 0.86 { return "QUALITY PRO · \(pct)%" }
        if score >= 0.68 { return "QUALITY OK · \(pct)%" }
        return "QUALITY REVIEW · \(pct)%"
    }
}

struct AVOPhase98PencilSnapResult: Hashable {
    var point: CGPoint
    var snappedJoint: HorseJoint?
    var distance: CGFloat
    var didSnap: Bool
}

struct AVOPhase98PencilEngine {
    static func subpixelPoint(_ point: CGPoint, scale: CGFloat = UIScreen.main.scale) -> CGPoint {
        guard scale > 0 else { return point }
        return CGPoint(x: (point.x * scale).rounded() / scale,
                       y: (point.y * scale).rounded() / scale)
    }

    static func smoothStroke(_ points: [CGPoint], strength: CGFloat = 0.35) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let clamped = max(0, min(strength, 0.95))
        var output = points
        for i in 1..<(points.count - 1) {
            let prev = points[i - 1]
            let cur = points[i]
            let next = points[i + 1]
            let avg = CGPoint(x: (prev.x + cur.x + next.x) / 3.0, y: (prev.y + cur.y + next.y) / 3.0)
            output[i] = CGPoint(x: cur.x * (1 - clamped) + avg.x * clamped,
                                y: cur.y * (1 - clamped) + avg.y * clamped)
        }
        return output
    }

    static func snap(point: CGPoint, to annotations: [EditableHorseAnnotation], in canvas: CGSize, radius: CGFloat = 18) -> AVOPhase98PencilSnapResult {
        guard canvas.width > 0, canvas.height > 0 else {
            return AVOPhase98PencilSnapResult(point: point, snappedJoint: nil, distance: .greatestFiniteMagnitude, didSnap: false)
        }
        let candidates = annotations.map { ann -> (HorseJoint, CGPoint, CGFloat) in
            let p = CGPoint(x: CGFloat(ann.x) * canvas.width, y: CGFloat(ann.y) * canvas.height)
            return (ann.joint, p, hypot(p.x - point.x, p.y - point.y))
        }
        guard let best = candidates.min(by: { $0.2 < $1.2 }), best.2 <= radius else {
            return AVOPhase98PencilSnapResult(point: subpixelPoint(point), snappedJoint: nil, distance: candidates.map { $0.2 }.min() ?? .greatestFiniteMagnitude, didSnap: false)
        }
        return AVOPhase98PencilSnapResult(point: subpixelPoint(best.1), snappedJoint: best.0, distance: best.2, didSnap: true)
    }
}

struct AVOPhase98QualityEngine {
    static func evaluate(_ points: [EditableHorseAnnotation]) -> AVOPhase98AnnotationQuality {
        let visible = points.filter { $0.confidence > 0.04 }
        let low = points.filter { $0.confidence > 0.04 && $0.confidence < 0.35 }.map { $0.joint }
        let dict = Dictionary(uniqueKeysWithValues: visible.map { ($0.joint, $0) })
        var warnings: [String] = []
        var outliers: [HorseJoint] = []

        if let withers = dict[.withers], let croup = dict[.croup] {
            let distance = hypot(withers.x - croup.x, withers.y - croup.y)
            if distance < 0.06 {
                warnings.append("Cruz y grupa demasiado próximas")
                outliers.append(.withers)
                outliers.append(.croup)
            }
        } else {
            warnings.append("Faltan cruz/grupa para eje dorsal")
        }

        checkLimbChain(dict, [.leftShoulder, .leftElbow, .leftCarpus, .leftFetlock, .leftHoof], label: "delantera izquierda", warnings: &warnings, outliers: &outliers)
        checkLimbChain(dict, [.rightShoulder, .rightElbow, .rightCarpus, .rightFetlock, .rightHoof], label: "delantera derecha", warnings: &warnings, outliers: &outliers)
        checkLimbChain(dict, [.leftHip, .leftStifle, .leftHock, .leftHindFetlock, .leftHindHoof], label: "trasera izquierda", warnings: &warnings, outliers: &outliers)
        checkLimbChain(dict, [.rightHip, .rightStifle, .rightHock, .rightHindFetlock, .rightHindHoof], label: "trasera derecha", warnings: &warnings, outliers: &outliers)

        let coverage = Double(visible.count) / Double(max(HorseJoint.allCases.count, 1))
        let confidence = visible.isEmpty ? 0 : visible.map { $0.confidence }.reduce(0, +) / Double(visible.count)
        let warningPenalty = min(0.45, Double(warnings.count) * 0.075)
        let lowPenalty = min(0.25, Double(low.count) * 0.025)
        let score = max(0.0, min(1.0, coverage * 0.44 + confidence * 0.56 - warningPenalty - lowPenalty))

        return AVOPhase98AnnotationQuality(score: score,
                                           visiblePoints: visible.count,
                                           lowConfidencePoints: low,
                                           anatomicalWarnings: warnings,
                                           outlierPoints: Array(Set(outliers)))
    }

    private static func checkLimbChain(_ dict: [HorseJoint: EditableHorseAnnotation], _ joints: [HorseJoint], label: String, warnings: inout [String], outliers: inout [HorseJoint]) {
        let present = joints.compactMap { dict[$0] }
        guard present.count >= 3 else { return }
        for i in 1..<present.count {
            let a = present[i - 1]
            let b = present[i]
            let distance = hypot(a.x - b.x, a.y - b.y)
            if distance > 0.42 {
                warnings.append("Salto anatómico en \(label)")
                outliers.append(a.joint)
                outliers.append(b.joint)
            }
        }
    }
}

struct AVOPhase98QualityBadge: View {
    let quality: AVOPhase98AnnotationQuality

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(quality.statusText)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(quality.score >= 0.68 ? Color.green : Color.orange)
            Text("PTS \(quality.visiblePoints)/\(HorseJoint.allCases.count) · LOW \(quality.lowConfidencePoints.count) · WARN \(quality.anatomicalWarnings.count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}
