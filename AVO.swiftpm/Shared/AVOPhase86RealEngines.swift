import SwiftUI
import UIKit
import AVFoundation

// MARK: - Phase 86 Real Engines
// These engines do not fabricate measurements. They only use real CoreML keypoints, manual annotations,
// previous real frame annotations and live AVCapture LiDAR depth delivered by CameraManager.

final class AVOAutoPoseV2Engine: ObservableObject {
    @Published private(set) var status: String = "AUTOPOSE V2 READY"
    @Published private(set) var lastFrameId: String = "--"
    @Published private(set) var lastPointCount: Int = 0
    @Published private(set) var occlusionFilledCount: Int = 0
    @Published private(set) var temporalQuality: Double = 0

    private var previousByJoint: [HorseJoint: EditableHorseAnnotation] = [:]
    private var previousFrameId: String?

    func reset() {
        previousByJoint.removeAll()
        previousFrameId = nil
        status = "AUTOPOSE V2 RESET"
        lastFrameId = "--"
        lastPointCount = 0
        occlusionFilledCount = 0
        temporalQuality = 0
    }

    func process(frameId: String,
                 rawPredicted: [EditableHorseAnnotation],
                 currentManual: [EditableHorseAnnotation],
                 imageBox: CGRect?) -> [EditableHorseAnnotation] {
        var predicted = Dictionary(uniqueKeysWithValues: rawPredicted.map { ($0.joint, $0) })
        let manual = Dictionary(uniqueKeysWithValues: currentManual.filter { $0.isManual }.map { ($0.joint, $0) })
        var output: [EditableHorseAnnotation] = []
        var filled = 0
        var stableCount = 0
        var comparedCount = 0

        for joint in HorseJoint.allCases {
            if var manualPoint = manual[joint] {
                manualPoint.isManual = true
                manualPoint.isPredicted = false
                output.append(manualPoint)
                previousByJoint[joint] = manualPoint
                continue
            }

            if var point = predicted.removeValue(forKey: joint) {
                if let previous = previousByJoint[joint], previousFrameId != nil {
                    comparedCount += 1
                    let jump = hypot(point.x - previous.x, point.y - previous.y)
                    // If model output jumps too far between adjacent frames and confidence is not high,
                    // blend toward previous real point instead of accepting a biomechanically impossible jump.
                    if jump > 0.18 && point.confidence < 0.78 {
                        point.x = previous.x * 0.72 + point.x * 0.28
                        point.y = previous.y * 0.72 + point.y * 0.28
                        point.confidence = min(point.confidence, previous.confidence) * 0.90
                    } else if jump < 0.075 {
                        stableCount += 1
                    }
                }
                point.isPredicted = true
                point.isManual = false
                output.append(point)
                previousByJoint[joint] = point
                continue
            }

            if var previous = previousByJoint[joint], shouldFillOcclusion(joint: joint, in: imageBox) {
                previous.confidence = max(0.05, previous.confidence * 0.48)
                previous.isPredicted = true
                previous.isManual = false
                output.append(previous)
                filled += 1
            }
        }

        previousFrameId = frameId
        lastFrameId = frameId
        lastPointCount = output.count
        occlusionFilledCount = filled
        temporalQuality = comparedCount == 0 ? averageConfidence(output) : min(1.0, (Double(stableCount) / Double(max(comparedCount, 1))) * 0.55 + averageConfidence(output) * 0.45)
        status = "AUTOPOSE V2 REAL · \(output.count) trainingModels · fill \(filled) · TQ \(Int(temporalQuality * 100))%"
        return output.sorted { $0.joint.rawValue < $1.joint.rawValue }
    }

    private func shouldFillOcclusion(joint: HorseJoint, in imageBox: CGRect?) -> Bool {
        // Fill only from prior real/model observation. No synthetic horse geometry is invented.
        guard imageBox != nil else { return true }
        return true
    }

    private func averageConfidence(_ points: [EditableHorseAnnotation]) -> Double {
        guard !points.isEmpty else { return 0 }
        return points.map { $0.confidence }.reduce(0, +) / Double(points.count)
    }
}

struct AVOBiomechJointAngle: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let degrees: Double
    let quality: Double
}

struct AVOAdvancedBiomechResult: Hashable {
    var dorsalAngle: Double?
    var pelvisAngle: Double?
    var neckAngle: Double?
    var leftForeAngle: Double?
    var rightForeAngle: Double?
    var leftHindAngle: Double?
    var rightHindAngle: Double?
    var foreSymmetry: Double?
    var hindSymmetry: Double?
    var strideProxy: Double?
    var asymmetryRisk: Double?
    var visiblePoints: Int
    var angles: [AVOBiomechJointAngle]

    var summary: String {
        var parts: [String] = []
        if let dorsalAngle { parts.append("DORSO \(Int(dorsalAngle))°") }
        if let pelvisAngle { parts.append("PELVIS \(Int(pelvisAngle))°") }
        if let foreSymmetry { parts.append("SIM DEL \(Int(foreSymmetry * 100))%") }
        if let hindSymmetry { parts.append("SIM TRAS \(Int(hindSymmetry * 100))%") }
        if let asymmetryRisk { parts.append("RIESGO \(Int(asymmetryRisk * 100))%") }
        if parts.isEmpty { return "BIOMECH REAL: faltan puntos" }
        return parts.joined(separator: " · ")
    }
}

struct AVOAdvancedBiomechEngine {
    static func analyze(points: [EditableHorseAnnotation]) -> AVOAdvancedBiomechResult {
        let usable = points.filter { $0.confidence > 0.04 }
        let dict = Dictionary(uniqueKeysWithValues: usable.map { ($0.joint, $0) })
        let dorsal = lineAngle(dict[.withers], dict[.croup])
        let pelvis = lineAngle(dict[.leftHip], dict[.rightHip]) ?? lineAngle(dict[.croup], dict[.tailBase])
        let neck = lineAngle(dict[.poll], dict[.neckBase])
        let leftFore = jointAngle(dict[.leftShoulder], dict[.leftElbow], dict[.leftCarpus])
        let rightFore = jointAngle(dict[.rightShoulder], dict[.rightElbow], dict[.rightCarpus])
        let leftHind = jointAngle(dict[.leftHip], dict[.leftStifle], dict[.leftHock])
        let rightHind = jointAngle(dict[.rightHip], dict[.rightStifle], dict[.rightHock])
        let foreSym = pairSymmetry(leftFore, rightFore)
        let hindSym = pairSymmetry(leftHind, rightHind)
        let stride = strideProxy(dict)
        let risk = asymmetryRisk(fore: foreSym, hind: hindSym, lf: leftFore, rf: rightFore, lh: leftHind, rh: rightHind)

        var angles: [AVOBiomechJointAngle] = []
        append(&angles, "Cuello", neck, dict[.poll], dict[.neckBase])
        append(&angles, "Dorso", dorsal, dict[.withers], dict[.croup])
        append(&angles, "Pelvis", pelvis, dict[.leftHip], dict[.rightHip])
        appendJoint(&angles, "Del. izq", leftFore, dict[.leftShoulder], dict[.leftElbow], dict[.leftCarpus])
        appendJoint(&angles, "Del. der", rightFore, dict[.rightShoulder], dict[.rightElbow], dict[.rightCarpus])
        appendJoint(&angles, "Tras. izq", leftHind, dict[.leftHip], dict[.leftStifle], dict[.leftHock])
        appendJoint(&angles, "Tras. der", rightHind, dict[.rightHip], dict[.rightStifle], dict[.rightHock])

        return AVOAdvancedBiomechResult(dorsalAngle: dorsal,
                                        pelvisAngle: pelvis,
                                        neckAngle: neck,
                                        leftForeAngle: leftFore,
                                        rightForeAngle: rightFore,
                                        leftHindAngle: leftHind,
                                        rightHindAngle: rightHind,
                                        foreSymmetry: foreSym,
                                        hindSymmetry: hindSym,
                                        strideProxy: stride,
                                        asymmetryRisk: risk,
                                        visiblePoints: usable.count,
                                        angles: angles)
    }

    private static func lineAngle(_ a: EditableHorseAnnotation?, _ b: EditableHorseAnnotation?) -> Double? {
        guard let a, let b else { return nil }
        return atan2(b.y - a.y, b.x - a.x) * 180.0 / Double.pi
    }

    private static func jointAngle(_ a: EditableHorseAnnotation?, _ b: EditableHorseAnnotation?, _ c: EditableHorseAnnotation?) -> Double? {
        guard let a, let b, let c else { return nil }
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let m1 = max(0.000001, hypot(v1.dx, v1.dy))
        let m2 = max(0.000001, hypot(v2.dx, v2.dy))
        let cosine = max(-1.0, min(1.0, dot / (m1 * m2)))
        return acos(cosine) * 180.0 / Double.pi
    }

    private static func pairSymmetry(_ a: Double?, _ b: Double?) -> Double? {
        guard let a, let b else { return nil }
        let denom = max(abs(a), abs(b), 1.0)
        return max(0.0, min(1.0, 1.0 - abs(a - b) / denom))
    }

    private static func strideProxy(_ d: [HorseJoint: EditableHorseAnnotation]) -> Double? {
        guard let lf = d[.leftHoof] ?? d[.rightHoof], let lh = d[.leftHindHoof] ?? d[.rightHindHoof] else { return nil }
        return hypot(lf.x - lh.x, lf.y - lh.y)
    }

    private static func asymmetryRisk(fore: Double?, hind: Double?, lf: Double?, rf: Double?, lh: Double?, rh: Double?) -> Double? {
        var risks: [Double] = []
        if let fore { risks.append(1.0 - fore) }
        if let hind { risks.append(1.0 - hind) }
        if let lf, let rf { risks.append(min(1.0, abs(lf - rf) / 45.0)) }
        if let lh, let rh { risks.append(min(1.0, abs(lh - rh) / 45.0)) }
        guard !risks.isEmpty else { return nil }
        return risks.reduce(0, +) / Double(risks.count)
    }

    private static func append(_ out: inout [AVOBiomechJointAngle], _ name: String, _ value: Double?, _ a: EditableHorseAnnotation?, _ b: EditableHorseAnnotation?) {
        guard let value else { return }
        let q = ((a?.confidence ?? 0) + (b?.confidence ?? 0)) / 2.0
        out.append(AVOBiomechJointAngle(name: name, degrees: value, quality: q))
    }

    private static func appendJoint(_ out: inout [AVOBiomechJointAngle], _ name: String, _ value: Double?, _ a: EditableHorseAnnotation?, _ b: EditableHorseAnnotation?, _ c: EditableHorseAnnotation?) {
        guard let value else { return }
        let q = ((a?.confidence ?? 0) + (b?.confidence ?? 0) + (c?.confidence ?? 0)) / 3.0
        out.append(AVOBiomechJointAngle(name: name, degrees: value, quality: q))
    }
}

struct AVOLiveLiDARFusionCard: View {
    @ObservedObject var camera: CameraManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                metric("LiDAR", camera.lidarSupported ? "ON" : "OFF", camera.lidarSupported ? .green : .orange)
                metric("DIST", camera.lidarDistanceText, .cyan)
                metric("QUALITY", camera.lidarQualityText.replacingOccurrences(of: "DEPTH Q ", with: ""), camera.lidarQuality > 0.7 ? .green : .yellow)
                metric("POINTS", "\(camera.lidarPointCloud2D.count)", .white)
            }
            if let report = camera.lidarFusionReport {
                Text("FUSION: \(camera.lidarFusionStatus) · BODY BOX \(report.bodyBoxLocked ? "LOCK" : "SEARCH") · 3D POINTS \(camera.lidarFusedPointCloud3D.count)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(report.bodyBoxLocked ? .green : .orange)
            } else {
                Text("Esperando depth real del iPad Pro. No se generan mediciones simuladas.")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }

    private func metric(_ k: String, _ v: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.gray)
            Text(v).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
    }
}
