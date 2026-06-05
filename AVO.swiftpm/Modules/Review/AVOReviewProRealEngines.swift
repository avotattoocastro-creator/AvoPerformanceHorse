import SwiftUI
import UIKit
import AVFoundation
import CoreGraphics

// MARK: - AVO Review Pro Real Engines
// No simulated measurements: these helpers only compute from real images, real video frames, or user/model annotations.

struct AVOReviewFrameSample: Identifiable, Hashable {
    let id = UUID()
    let timeSeconds: Double
    let image: UIImage
}

struct AVOReviewVideoClipInfo: Hashable {
    var urlName: String = "--"
    var duration: Double = 0
    var naturalSize: CGSize = .zero
    var nominalFPS: Double = 0
    var frameCount: Int = 0

    var summary: String {
        let seconds = duration.isFinite ? duration : 0
        return "\(urlName) · \(String(format: "%.2fs", seconds)) · \(Int(naturalSize.width))x\(Int(naturalSize.height)) · \(String(format: "%.1f", nominalFPS)) FPS"
    }
}

struct AVOReviewTemporalTrackSample: Identifiable, Hashable {
    var id: String { frameId }
    var frameId: String
    var timeSeconds: Double
    var pointCount: Int
    var averageConfidence: Double
    var continuity: Double
    var occlusionFilled: Int
}

final class AVOReviewVideoFrameExtractor: ObservableObject {
    @Published var status: String = "VIDEO ENGINE REAL READY"
    @Published var frames: [AVOReviewFrameSample] = []
    @Published var isExtracting: Bool = false
    @Published var clipInfo: AVOReviewVideoClipInfo = AVOReviewVideoClipInfo()
    @Published var selectedIndex: Int = 0
    @Published var selectedTime: Double = 0
    @Published var cacheStatus: String = "CACHE VACÍA"
    @Published var temporalTrack: [AVOReviewTemporalTrackSample] = []
    @Published var trackingStatus: String = "TRACKING TEMPORAL WAIT"

    private var frameCache: [Int: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "avo.review.video.cache.queue")

    var selectedFrame: AVOReviewFrameSample? {
        guard frames.indices.contains(selectedIndex) else { return nil }
        return frames[selectedIndex]
    }

    func reset() {
        frames = []
        frameCache.removeAll()
        temporalTrack = []
        selectedIndex = 0
        selectedTime = 0
        clipInfo = AVOReviewVideoClipInfo()
        status = "VIDEO ENGINE REAL READY"
        cacheStatus = "CACHE VACÍA"
        trackingStatus = "TRACKING TEMPORAL WAIT"
    }

    func seekFrame(index: Int) {
        guard !frames.isEmpty else { return }
        let clamped = max(0, min(index, frames.count - 1))
        selectedIndex = clamped
        selectedTime = frames[clamped].timeSeconds
    }

    func extractFrames(from url: URL, maxFrames: Int = 240, fps: Double = 12.0) {
        guard !isExtracting else { return }
        isExtracting = true
        status = "ABRIENDO MP4 REAL"
        frames = []
        frameCache.removeAll()
        temporalTrack = []
        selectedIndex = 0
        selectedTime = 0
        cacheStatus = "CACHE PREPARANDO"

        let accessGranted = url.startAccessingSecurityScopedResource()
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                if accessGranted { url.stopAccessingSecurityScopedResource() }
            }

            let asset = AVAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)
            guard duration.isFinite, duration > 0 else {
                DispatchQueue.main.async {
                    self.status = "VIDEO NO VÁLIDO"
                    self.cacheStatus = "CACHE ERROR"
                    self.isExtracting = false
                }
                return
            }

            let track = asset.tracks(withMediaType: .video).first
            let natural = track?.naturalSize.applying(track?.preferredTransform ?? .identity) ?? .zero
            let size = CGSize(width: abs(natural.width), height: abs(natural.height))
            let nominal = Double(track?.nominalFrameRate ?? 0)
            let targetFPS = min(max(fps, 1.0), max(nominal > 0 ? nominal : fps, 1.0))
            let step = max(1.0 / targetFPS, 0.025)

            var times: [NSValue] = []
            var t = 0.0
            while t <= duration, times.count < maxFrames {
                times.append(NSValue(time: CMTime(seconds: t, preferredTimescale: 600)))
                t += step
            }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: min(step * 0.35, 0.03), preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: min(step * 0.35, 0.03), preferredTimescale: 600)
            generator.maximumSize = CGSize(width: 1600, height: 1600)

            var collected: [AVOReviewFrameSample] = []
            let appendQueue = DispatchQueue(label: "avo.review.video.append.queue")
            let group = DispatchGroup()

            for (index, value) in times.enumerated() {
                group.enter()
                generator.generateCGImagesAsynchronously(forTimes: [value]) { requested, cg, actual, _, _ in
                    if let cg {
                        let time = CMTimeGetSeconds(actual.isValid ? actual : requested)
                        let image = UIImage(cgImage: cg)
                        appendQueue.sync {
                            collected.append(AVOReviewFrameSample(timeSeconds: time, image: image))
                        }
                        self.cacheQueue.sync {
                            self.frameCache[index] = image
                        }
                    }
                    group.leave()
                }
            }

            group.wait()
            let sorted = collected.sorted { $0.timeSeconds < $1.timeSeconds }

            DispatchQueue.main.async {
                self.frames = sorted
                for (i, f) in sorted.enumerated() { self.frameCache[i] = f.image }
                self.clipInfo = AVOReviewVideoClipInfo(urlName: url.lastPathComponent,
                                                       duration: duration,
                                                       naturalSize: size,
                                                       nominalFPS: nominal,
                                                       frameCount: sorted.count)
                self.selectedIndex = 0
                self.selectedTime = sorted.first?.timeSeconds ?? 0
                self.status = "MP4 REAL · \(sorted.count) FRAMES · SCRUB READY"
                self.cacheStatus = "CACHE VIDEO: \(sorted.count) FRAMES"
                self.trackingStatus = sorted.isEmpty ? "SIN FRAMES" : "TRACKING TEMPORAL PREPARADO"
                self.isExtracting = false
            }
        }
    }

    func buildTemporalTrack(annotationsByFrameId: [String: [EditableHorseAnnotation]]) {
        guard !frames.isEmpty else {
            trackingStatus = "IMPORTA MP4 PRIMERO"
            return
        }
        var previous: [CGPoint] = []
        var track: [AVOReviewTemporalTrackSample] = []
        for (index, frame) in frames.enumerated() {
            let frameId = String(format: "video_%05d", index)
            let points = annotationsByFrameId[frameId] ?? []
            let current = points.sorted { $0.joint.rawValue < $1.joint.rawValue }.map { CGPoint(x: $0.x, y: $0.y) }
            let avg = points.isEmpty ? 0 : points.map { $0.confidence }.reduce(0, +) / Double(points.count)
            let cont = previous.isEmpty || previous.count != current.count ? 0 : AVOReviewProIntegrator.continuityScore(previous: previous, current: current)
            track.append(AVOReviewTemporalTrackSample(frameId: frameId,
                                                      timeSeconds: frame.timeSeconds,
                                                      pointCount: points.count,
                                                      averageConfidence: avg,
                                                      continuity: cont,
                                                      occlusionFilled: points.filter { $0.isPredicted && $0.confidence < 0.50 }.count))
            if !current.isEmpty { previous = current }
        }
        temporalTrack = track
        let meanContinuity = track.isEmpty ? 0 : track.map { $0.continuity }.reduce(0, +) / Double(track.count)
        trackingStatus = "TRACK REAL · \(track.count) FRAMES · CONT \(Int(meanContinuity * 100))%"
    }
}

struct AVOBiomechTimePoint: Identifiable, Hashable {
    var id: String { frameId }
    var frameId: String
    var timeSeconds: Double
    var dorsal: Double?
    var pelvis: Double?
    var foreSymmetry: Double?
    var hindSymmetry: Double?
    var risk: Double?
}

struct AVOBiomechTimeSeriesReport: Hashable {
    var points: [AVOBiomechTimePoint]
    var meanRisk: Double?
    var maxRisk: Double?
    var strideEvents: Int

    var summary: String {
        if points.isEmpty { return "SERIE BIOMECH VACÍA" }
        let riskText = meanRisk.map { "RIESGO MEDIO \(Int($0 * 100))%" } ?? "RIESGO --"
        return "\(points.count) FRAMES · \(riskText) · EVENTOS \(strideEvents)"
    }
}

struct AVOReviewBiomechTimeSeriesEngine {
    static func analyze(frames: [AVOReviewFrameSample], annotationsByFrameId: [String: [EditableHorseAnnotation]]) -> AVOBiomechTimeSeriesReport {
        var out: [AVOBiomechTimePoint] = []
        for (index, frame) in frames.enumerated() {
            let frameId = String(format: "video_%05d", index)
            let result = AVOAdvancedBiomechEngine.analyze(points: annotationsByFrameId[frameId] ?? [])
            out.append(AVOBiomechTimePoint(frameId: frameId,
                                           timeSeconds: frame.timeSeconds,
                                           dorsal: result.dorsalAngle,
                                           pelvis: result.pelvisAngle,
                                           foreSymmetry: result.foreSymmetry,
                                           hindSymmetry: result.hindSymmetry,
                                           risk: result.asymmetryRisk))
        }
        let risks = out.compactMap { $0.risk }
        let mean = risks.isEmpty ? nil : risks.reduce(0, +) / Double(risks.count)
        let maxRisk = risks.max()
        let strideEvents = detectStrideEvents(out)
        return AVOBiomechTimeSeriesReport(points: out, meanRisk: mean, maxRisk: maxRisk, strideEvents: strideEvents)
    }

    private static func detectStrideEvents(_ series: [AVOBiomechTimePoint]) -> Int {
        let values = series.compactMap { $0.foreSymmetry }
        guard values.count > 4 else { return 0 }
        var events = 0
        for i in 1..<(values.count - 1) {
            if values[i] < values[i - 1], values[i] < values[i + 1], values[i] < 0.82 { events += 1 }
        }
        return events
    }
}

struct AVOReviewQualityPointReport: Identifiable, Hashable {
    var id: HorseJoint { joint }
    var joint: HorseJoint
    var averageConfidence: Double
    var missingRatio: Double
    var outlierRatio: Double
    var quality: Double
}

struct AVOReviewAIQualityReport: Hashable {
    var globalScore: Double
    var pointReports: [AVOReviewQualityPointReport]
    var rejectedFrameIds: [String]
    var warnings: [String]

    var summary: String {
        "QUALITY IA \(Int(globalScore * 100))% · REJECT \(rejectedFrameIds.count) · WARN \(warnings.count)"
    }
}

struct AVOReviewAIQualityEngine {
    static func analyze(annotationsByFrameId: [String: [EditableHorseAnnotation]]) -> AVOReviewAIQualityReport {
        let frameIds = annotationsByFrameId.keys.sorted()
        var pointReports: [AVOReviewQualityPointReport] = []
        var warnings: [String] = []
        var rejected: [String] = []

        for joint in HorseJoint.allCases {
            let values = frameIds.map { annotationsByFrameId[$0]?.first(where: { $0.joint == joint }) }
            let present = values.compactMap { $0 }
            let missing = frameIds.isEmpty ? 1.0 : 1.0 - Double(present.count) / Double(frameIds.count)
            let avg = present.isEmpty ? 0 : present.map { $0.confidence }.reduce(0, +) / Double(present.count)
            let outliers = outlierRatio(points: present)
            let quality = max(0, min(1, avg * 0.60 + (1.0 - missing) * 0.25 + (1.0 - outliers) * 0.15))
            if quality < 0.45 { warnings.append("\(joint.rawValue): baja calidad") }
            pointReports.append(AVOReviewQualityPointReport(joint: joint,
                                                            averageConfidence: avg,
                                                            missingRatio: missing,
                                                            outlierRatio: outliers,
                                                            quality: quality))
        }

        for id in frameIds {
            let trainingModels = annotationsByFrameId[id] ?? []
            let avg = trainingModels.isEmpty ? 0 : trainingModels.map { $0.confidence }.reduce(0, +) / Double(trainingModels.count)
            if trainingModels.count < max(6, HorseJoint.allCases.count / 4) || avg < 0.30 { rejected.append(id) }
        }

        let global = pointReports.isEmpty ? 0 : pointReports.map { $0.quality }.reduce(0, +) / Double(pointReports.count)
        return AVOReviewAIQualityReport(globalScore: global,
                                        pointReports: pointReports.sorted { $0.quality < $1.quality },
                                        rejectedFrameIds: rejected,
                                        warnings: warnings)
    }

    private static func outlierRatio(points: [EditableHorseAnnotation]) -> Double {
        guard points.count > 4 else { return 0 }
        let xs = points.map { $0.x }.sorted()
        let ys = points.map { $0.y }.sorted()
        let mx = xs[xs.count / 2]
        let my = ys[ys.count / 2]
        let out = points.filter { hypot($0.x - mx, $0.y - my) > 0.32 }.count
        return Double(out) / Double(points.count)
    }
}

struct AVOReviewBiomechResult: Hashable {
    var dorsalAngle: Double?
    var pelvisAngle: Double?
    var foreSymmetry: Double?
    var hindSymmetry: Double?
    var visiblePoints: Int

    var summary: String {
        var parts: [String] = []
        if let dorsalAngle { parts.append("DORSO \(Int(dorsalAngle))°") }
        if let pelvisAngle { parts.append("PELVIS \(Int(pelvisAngle))°") }
        if let foreSymmetry { parts.append("SIM DEL \(Int(foreSymmetry * 100))%") }
        if let hindSymmetry { parts.append("SIM TRAS \(Int(hindSymmetry * 100))%") }
        if parts.isEmpty { return "BIOMECH: faltan puntos reales" }
        return parts.joined(separator: " · ")
    }
}

struct AVOReviewBiomechEngine {
    static func analyze(points: [EditableHorseAnnotation]) -> AVOReviewBiomechResult {
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })
        let dorsal = angle(dict[.withers], dict[.croup])
        let pelvis = angle(dict[.leftHip], dict[.rightHip]) ?? angle(dict[.croup], dict[.tailBase])
        let fore = symmetry(a: dict[.leftHoof], b: dict[.rightHoof], anchor: dict[.withers])
        let hind = symmetry(a: dict[.leftHindHoof], b: dict[.rightHindHoof], anchor: dict[.croup])
        return AVOReviewBiomechResult(dorsalAngle: dorsal, pelvisAngle: pelvis, foreSymmetry: fore, hindSymmetry: hind, visiblePoints: points.count)
    }

    private static func angle(_ a: EditableHorseAnnotation?, _ b: EditableHorseAnnotation?) -> Double? {
        guard let a, let b else { return nil }
        let dx = b.x - a.x
        let dy = b.y - a.y
        return atan2(dy, dx) * 180.0 / Double.pi
    }

    private static func symmetry(a: EditableHorseAnnotation?, b: EditableHorseAnnotation?, anchor: EditableHorseAnnotation?) -> Double? {
        guard let a, let b, let anchor else { return nil }
        let da = hypot(a.x - anchor.x, a.y - anchor.y)
        let db = hypot(b.x - anchor.x, b.y - anchor.y)
        let maxD = max(da, db, 0.0001)
        return max(0.0, 1.0 - abs(da - db) / maxD)
    }
}

struct AVOReviewDatasetStats: Hashable {
    var total: Int
    var good: Int
    var review: Int
    var rejected: Int
    var annotated: Int
    var completion: Double
}

struct AVOReviewDatasetTrainerHubEngine {
    static func stats(items: [HorseDatasetReviewItem]) -> AVOReviewDatasetStats {
        let total = items.count
        let good = items.filter { DatasetQualityManager.normalizedLabel($0.record.label) == .good }.count
        let review = items.filter { DatasetQualityManager.normalizedLabel($0.record.label) == .review }.count
        let rejected = items.filter { DatasetQualityManager.normalizedLabel($0.record.label) == .rejected }.count
        let annotated = items.filter { !$0.record.keypoints.isEmpty }.count
        return AVOReviewDatasetStats(total: total, good: good, review: review, rejected: rejected, annotated: annotated, completion: total == 0 ? 0 : Double(annotated) / Double(total))
    }
}

// MARK: - PHASE 96 · AUTOPOSE TEMPORAL V2 + BIOMECH DYNAMIC CORE
// Real temporal helpers. They never invent a whole horse: they only smooth, propagate short occlusions and score continuity from real/manual/CoreML keypoints.

struct AVOAutoposeTemporalFrame: Identifiable, Hashable {
    var id: String { frameId }
    var frameId: String
    var timeSeconds: Double
    var rawPoints: [EditableHorseAnnotation]
    var smoothedPoints: [EditableHorseAnnotation]
    var propagatedOcclusions: Int
    var continuityScore: Double
    var meanConfidence: Double
}

struct AVOAutoposeTemporalReport: Hashable {
    var frames: [AVOAutoposeTemporalFrame]
    var meanContinuity: Double
    var meanConfidence: Double
    var propagatedOcclusions: Int
    var warnings: [String]

    var summary: String {
        if frames.isEmpty { return "AUTOPOSE TEMPORAL: SIN FRAMES" }
        return "AUTOPOSE TEMPORAL V2 · \(frames.count) FRAMES · CONT \(Int(meanContinuity * 100))% · CONF \(Int(meanConfidence * 100))% · OCC \(propagatedOcclusions)"
    }
}

struct AVOAutoposeTemporalV2Engine {
    static func build(frames: [AVOReviewFrameSample], annotationsByFrameId: [String: [EditableHorseAnnotation]], smoothing: Double = 0.62, maxOcclusionGap: Int = 3) -> AVOAutoposeTemporalReport {
        guard !frames.isEmpty else {
            return AVOAutoposeTemporalReport(frames: [], meanContinuity: 0, meanConfidence: 0, propagatedOcclusions: 0, warnings: ["Importa primero un MP4 real."])
        }

        let alpha = max(0.0, min(0.95, smoothing))
        var lastByJoint: [HorseJoint: EditableHorseAnnotation] = [:]
        var missingGap: [HorseJoint: Int] = [:]
        var previousSmoothed: [EditableHorseAnnotation] = []
        var temporalFrames: [AVOAutoposeTemporalFrame] = []
        var warnings: [String] = []
        var totalPropagated = 0

        for (index, frame) in frames.enumerated() {
            let frameId = String(format: "video_%05d", index)
            let raw = annotationsByFrameId[frameId] ?? []
            let rawByJoint = Dictionary(uniqueKeysWithValues: raw.map { ($0.joint, $0) })
            var out: [EditableHorseAnnotation] = []
            var propagated = 0

            for joint in HorseJoint.allCases {
                if var current = rawByJoint[joint] {
                    if let last = lastByJoint[joint] {
                        current.x = last.x * alpha + current.x * (1.0 - alpha)
                        current.y = last.y * alpha + current.y * (1.0 - alpha)
                        current.confidence = max(current.confidence, last.confidence * 0.72)
                    }
                    // PHASE112 FIX: removed invalid self-assignment current.isPredicted = current.isPredicted
                    out.append(current)
                    lastByJoint[joint] = current
                    missingGap[joint] = 0
                } else if let last = lastByJoint[joint], (missingGap[joint] ?? 0) < maxOcclusionGap {
                    var filled = last
                    let gap = (missingGap[joint] ?? 0) + 1
                    filled.confidence = max(0.05, last.confidence * pow(0.72, Double(gap)))
                    filled.isPredicted = true
                    filled.isManual = false
                    out.append(filled)
                    missingGap[joint] = gap
                    propagated += 1
                } else {
                    missingGap[joint] = (missingGap[joint] ?? 0) + 1
                }
            }

            let ordered = out.sorted { $0.joint.rawValue < $1.joint.rawValue }
            let continuity = previousSmoothed.isEmpty ? 0 : AVOReviewProIntegrator.continuityScore(previous: previousSmoothed.map { CGPoint(x: $0.x, y: $0.y) }, current: ordered.map { CGPoint(x: $0.x, y: $0.y) })
            let meanConfidence = ordered.isEmpty ? 0 : ordered.map { $0.confidence }.reduce(0, +) / Double(ordered.count)
            if !raw.isEmpty && continuity < 0.35 && !previousSmoothed.isEmpty { warnings.append("\(frameId): salto temporal alto") }

            temporalFrames.append(AVOAutoposeTemporalFrame(frameId: frameId,
                                                           timeSeconds: frame.timeSeconds,
                                                           rawPoints: raw,
                                                           smoothedPoints: ordered,
                                                           propagatedOcclusions: propagated,
                                                           continuityScore: continuity,
                                                           meanConfidence: meanConfidence))
            if !ordered.isEmpty { previousSmoothed = ordered }
            totalPropagated += propagated
        }

        let continuityValues = temporalFrames.map { $0.continuityScore }.filter { $0 > 0 }
        let meanContinuity = continuityValues.isEmpty ? 0 : continuityValues.reduce(0, +) / Double(continuityValues.count)
        let confidenceValues = temporalFrames.map { $0.meanConfidence }
        let meanConfidence = confidenceValues.isEmpty ? 0 : confidenceValues.reduce(0, +) / Double(confidenceValues.count)

        return AVOAutoposeTemporalReport(frames: temporalFrames,
                                         meanContinuity: meanContinuity,
                                         meanConfidence: meanConfidence,
                                         propagatedOcclusions: totalPropagated,
                                         warnings: warnings)
    }
}

struct AVODynamicBiomechReport: Hashable {
    var temporal: AVOAutoposeTemporalReport
    var biomech: AVOBiomechTimeSeriesReport
    var lamenessRisk: Double?
    var strideRegularity: Double?
    var dorsalRange: Double?
    var pelvisRange: Double?

    var summary: String {
        let risk = lamenessRisk.map { "RIESGO DIN \(Int($0 * 100))%" } ?? "RIESGO DIN --"
        let regularity = strideRegularity.map { "REG \(Int($0 * 100))%" } ?? "REG --"
        return "BIOMECH DINÁMICO · \(risk) · \(regularity) · \(biomech.summary)"
    }
}

struct AVODynamicBiomechEngine {
    static func analyze(frames: [AVOReviewFrameSample], annotationsByFrameId: [String: [EditableHorseAnnotation]]) -> AVODynamicBiomechReport {
        let temporal = AVOAutoposeTemporalV2Engine.build(frames: frames, annotationsByFrameId: annotationsByFrameId)
        var smoothedByFrame: [String: [EditableHorseAnnotation]] = [:]
        for frame in temporal.frames { smoothedByFrame[frame.frameId] = frame.smoothedPoints }
        let series = AVOReviewBiomechTimeSeriesEngine.analyze(frames: frames, annotationsByFrameId: smoothedByFrame)
        let risk = dynamicRisk(series.points)
        let regularity = strideRegularity(series.points)
        let dorsalRange = range(series.points.compactMap { $0.dorsal })
        let pelvisRange = range(series.points.compactMap { $0.pelvis })
        return AVODynamicBiomechReport(temporal: temporal, biomech: series, lamenessRisk: risk, strideRegularity: regularity, dorsalRange: dorsalRange, pelvisRange: pelvisRange)
    }

    private static func dynamicRisk(_ points: [AVOBiomechTimePoint]) -> Double? {
        let risks = points.compactMap { $0.risk }
        guard !risks.isEmpty else { return nil }
        let mean = risks.reduce(0, +) / Double(risks.count)
        let spikes = Double(risks.filter { $0 > 0.38 }.count) / Double(risks.count)
        return max(0.0, min(1.0, mean * 0.72 + spikes * 0.28))
    }

    private static func strideRegularity(_ points: [AVOBiomechTimePoint]) -> Double? {
        let values = points.compactMap { $0.foreSymmetry }
        guard values.count > 5 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return max(0.0, min(1.0, 1.0 - sqrt(variance) * 3.0))
    }

    private static func range(_ values: [Double]) -> Double? {
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }
        return maxValue - minValue
    }
}
