import Foundation
import Vision
import CoreML
import AVFoundation
import CoreGraphics
import UIKit

struct HorsePoseResult {
    let keypoints: [HorseKeypoint]
    let source: String
    let confidence: Double
}

final class HorsePoseCoreML {
    
    private var visionModel: VNCoreMLModel?
    private(set) var statusText: String = "HORSE POSE LOADING"
    private(set) var loadedModelPath: String = "NO MODEL"
    
    var isReady: Bool {
        visionModel != nil
    }
    
    private let minimumPointConfidence: Double = 0.08
    
    private let jointOrder: [HorseJoint] = [
        .nose,
        .poll,
        .neckBase,
        .withers,
        .back,
        .croup,
        .tailBase,
        .leftShoulder,
        .leftElbow,
        .leftCarpus,
        .leftFetlock,
        .leftHoof,
        .rightShoulder,
        .rightElbow,
        .rightCarpus,
        .rightFetlock,
        .rightHoof,
        .leftHip,
        .leftStifle,
        .leftHock,
        .leftHindFetlock,
        .leftHindHoof,
        .rightHip,
        .rightStifle,
        .rightHock,
        .rightHindFetlock,
        .rightHindHoof
    ]
    
    init() {
        reload()
        
        NotificationCenter.default.addObserver(
            forName: .avoHorsePoseModelUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }
    
    func reload() {
        visionModel = nil
        statusText = "HORSE POSE RELOADING"
        loadedModelPath = "NO MODEL"
        
        do {
            if let customURL = customModelURL() {
                try loadModel(from: customURL, label: "CUSTOM POSE MODEL LOADED")
                return
            }
            
            if let bundledURL = bundledModelURL() {
                try loadModel(from: bundledURL, label: "BUNDLED POSE MODEL LOADED")
                return
            }
            
            statusText = "POSE MODEL NOT FOUND IN APP"
            
        } catch {
            visionModel = nil
            statusText = "POSE LOAD ERROR: \(error.localizedDescription)"
        }
    }
    
    private func customModelURL() -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let package = docs
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("AVOHorsePose.mlpackage", isDirectory: true)
        
        if fm.fileExists(atPath: package.path) {
            return package
        }
        
        let compiled = docs
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("AVOHorsePose.mlmodelc", isDirectory: true)
        
        if fm.fileExists(atPath: compiled.path) {
            return compiled
        }
        
        return nil
    }
    
    private func bundledModelURL() -> URL? {
        if let url = Bundle.main.url(forResource: "AVOHorsePose", withExtension: "mlmodelc") {
            return url
        }
        
        if let url = Bundle.main.url(forResource: "AVOHorsePose", withExtension: "mlpackage") {
            return url
        }

        if let url = Bundle.main.url(forResource: "best", withExtension: "mlpackage") {
            return url
        }
        
        if let url = Bundle.main.url(forResource: "model", withExtension: "mlmodelc") {
            return url
        }
        
        if let url = Bundle.main.url(forResource: "model", withExtension: "mlpackage") {
            return url
        }
        
        return nil
    }
    
    private func loadModel(from url: URL, label: String) throws {
        let modelURL: URL
        
        if url.pathExtension.lowercased() == "mlpackage" || url.pathExtension.lowercased() == "mlmodel" {
            modelURL = try MLModel.compileModel(at: url)
        } else {
            modelURL = url
        }
        
        let mlModel = try MLModel(contentsOf: modelURL)
        let vnModel = try VNCoreMLModel(for: mlModel)
        
        self.visionModel = vnModel
        self.statusText = label
        self.loadedModelPath = url.path
    }
    
    func detectPose(in image: UIImage, horseBox: CGRect) -> HorsePoseResult? {
        guard let visionModel else {
            statusText = "AUTO POSE: MODELO NO CARGADO"
            return nil
        }
        
        guard let cgImage = image.fixedUp().cgImage else {
            statusText = "AUTO POSE: IMAGE ERROR"
            return nil
        }
        
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFit
        
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: .up,
            options: [:]
        )
        
        do {
            try handler.perform([request])
        } catch {
            statusText = "AUTO POSE REQUEST ERROR"
            return nil
        }
        
        guard let results = request.results else {
            statusText = "AUTO POSE: NO RESULTS"
            return nil
        }
        
        if let points = decodeVisionPose(results, roi: horseBox), !points.isEmpty {
            statusText = "AUTO POSE OK: \(points.count) POINTS"
            return HorsePoseResult(keypoints: points, source: "coreml_pose", confidence: averageConfidence(points))
        }
        
        statusText = "AUTO POSE: SIN PUNTOS / HORSE POSE IMAGE NO POINTS"
        return nil
    }
    
    private func decodeVisionPose(_ results: [VNObservation], roi: CGRect) -> [HorseKeypoint]? {
        for obs in results {
            if let feature = obs as? VNCoreMLFeatureValueObservation,
               let array = feature.featureValue.multiArrayValue {
                let points = decodeMultiArray(array, roi: roi)
                if !points.isEmpty {
                    return points
                }
            }
        }
        
        return nil
    }
    
    private func decodeMultiArray(_ array: MLMultiArray, roi: CGRect) -> [HorseKeypoint] {
        let shape = array.shape.map { $0.intValue }
        let flat = flatten(array)
        
        if shape.count == 3 {
            let c1 = shape[1]
            let c2 = shape[2]
            
            if c1 == 86 || c1 == 71 {
                return decodeChannelsFirst(flat, channels: c1, anchors: c2, roi: roi)
            }
            
            if c2 == 86 || c2 == 71 {
                return decodeChannelsLast(flat, anchors: c1, channels: c2, roi: roi)
            }
        }
        
        if flat.count >= 5 + jointOrder.count * 3 {
            return decodeSingleRow(flat, roi: roi)
        }
        
        return []
    }
    
    private func decodeChannelsFirst(_ flat: [Double], channels: Int, anchors: Int, roi: CGRect) -> [HorseKeypoint] {
        var bestAnchor = 0
        var bestScore = -Double.greatestFiniteMagnitude
        
        for a in 0..<anchors {
            let score = sigmoidIfNeeded(value(flat, channel: 4, anchor: a, anchors: anchors))
            if score > bestScore {
                bestScore = score
                bestAnchor = a
            }
        }
        
        var keypoints: [HorseKeypoint] = []
        
        for index in 0..<jointOrder.count {
            let base = 5 + index * 3
            guard base + 2 < channels else { continue }
            
            var x = value(flat, channel: base, anchor: bestAnchor, anchors: anchors)
            var y = value(flat, channel: base + 1, anchor: bestAnchor, anchors: anchors)
            let c = sigmoidIfNeeded(value(flat, channel: base + 2, anchor: bestAnchor, anchors: anchors))
            
            if c <= 0 { continue }
            if c < minimumPointConfidence { continue }
            
            x = normalizeCoordinate(x)
            y = normalizeCoordinate(y)
            
            guard x >= 0, x <= 1, y >= 0, y <= 1 else { continue }
            
            let mapped = mapFromModel(CGPoint(x: x, y: y), roi: roi)
            
            keypoints.append(
                HorseKeypoint(
                    joint: jointOrder[index],
                    x: Double(mapped.x),
                    y: Double(mapped.y),
                    confidence: c
                )
            )
        }
        
        return keypoints
    }
    
    private func decodeChannelsLast(_ flat: [Double], anchors: Int, channels: Int, roi: CGRect) -> [HorseKeypoint] {
        var bestAnchor = 0
        var bestScore = -Double.greatestFiniteMagnitude
        
        for a in 0..<anchors {
            let score = sigmoidIfNeeded(flat[a * channels + 4])
            if score > bestScore {
                bestScore = score
                bestAnchor = a
            }
        }
        
        let offset = bestAnchor * channels
        var keypoints: [HorseKeypoint] = []
        
        for index in 0..<jointOrder.count {
            let base = offset + 5 + index * 3
            guard base + 2 < flat.count else { continue }
            
            var x = flat[base]
            var y = flat[base + 1]
            let c = sigmoidIfNeeded(flat[base + 2])
            
            if c <= 0 { continue }
            if c < minimumPointConfidence { continue }
            
            x = normalizeCoordinate(x)
            y = normalizeCoordinate(y)
            
            guard x >= 0, x <= 1, y >= 0, y <= 1 else { continue }
            
            let mapped = mapFromModel(CGPoint(x: x, y: y), roi: roi)
            
            keypoints.append(
                HorseKeypoint(
                    joint: jointOrder[index],
                    x: Double(mapped.x),
                    y: Double(mapped.y),
                    confidence: c
                )
            )
        }
        
        return keypoints
    }
    
    private func decodeSingleRow(_ flat: [Double], roi: CGRect) -> [HorseKeypoint] {
        var keypoints: [HorseKeypoint] = []
        
        for index in 0..<jointOrder.count {
            let base = 5 + index * 3
            guard base + 2 < flat.count else { continue }
            
            var x = flat[base]
            var y = flat[base + 1]
            let c = sigmoidIfNeeded(flat[base + 2])
            
            if c <= 0 { continue }
            if c < minimumPointConfidence { continue }
            
            x = normalizeCoordinate(x)
            y = normalizeCoordinate(y)
            
            guard x >= 0, x <= 1, y >= 0, y <= 1 else { continue }
            
            let mapped = mapFromModel(CGPoint(x: x, y: y), roi: roi)
            
            keypoints.append(
                HorseKeypoint(
                    joint: jointOrder[index],
                    x: Double(mapped.x),
                    y: Double(mapped.y),
                    confidence: c
                )
            )
        }
        
        return keypoints
    }
    
    private func flatten(_ array: MLMultiArray) -> [Double] {
        let count = array.count
        var values: [Double] = []
        values.reserveCapacity(count)
        
        for i in 0..<count {
            values.append(Double(truncating: array[i]))
        }
        
        return values
    }
    
    private func value(_ flat: [Double], channel: Int, anchor: Int, anchors: Int) -> Double {
        let index = channel * anchors + anchor
        guard flat.indices.contains(index) else { return 0 }
        return flat[index]
    }
    
    private func sigmoidIfNeeded(_ v: Double) -> Double {
        if v >= 0 && v <= 1 {
            return v
        }
        return 1.0 / (1.0 + exp(-v))
    }
    
    private func normalizeCoordinate(_ v: Double) -> Double {
        if v > 2 {
            return v / 640.0
        }
        return v
    }
    
    private func mapFromModel(_ point: CGPoint, roi: CGRect) -> CGPoint {
        // YOLOv8/CoreML pose inference is executed on the full frame.
        // The coordinates returned by the model are already normalized to the full image.
        // Do NOT remap them into the old tracking ROI, otherwise the skeleton drifts/compresses.
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }
    
    private func averageConfidence(_ points: [HorseKeypoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        return points.map { $0.confidence }.reduce(0, +) / Double(points.count)
    }
}
