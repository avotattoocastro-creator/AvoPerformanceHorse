import Foundation
import Vision
import CoreML
import AVFoundation
import CoreGraphics

struct HorseDetectorResult {
    let boundingBox: CGRect
    let confidence: Float
    let label: String
    let source: String
}

final class HorseDetectorCoreML {
    private var visionModel: VNCoreMLModel?
    private(set) var statusText: String = "HORSE DETECTOR LOADING"
    private let acceptedLabels = ["horse", "caballo", "equine", "pony", "foal", "mare", "stallion"]
    private let minimumConfidence: Float = 0.35

    init() {
        loadModel()
    }

    var isReady: Bool {
        visionModel != nil
    }

    func reload() {
        loadModel()
    }

    private func loadModel() {
        let bundles = Bundle.allBundles + Bundle.allFrameworks
        let candidates = bundles.flatMap { bundle in
            [
                bundle.url(forResource: "HorseDetector", withExtension: "mlmodelc"),
                bundle.url(forResource: "HorseDetector", withExtension: "mlmodel")
            ]
        }

        guard let url = candidates.compactMap({ $0 }).first else {
            visionModel = nil
            statusText = "HORSE DETECTOR MISSING"
            return
        }

        do {
            let compiledURL: URL
            if url.pathExtension == "mlmodel" {
                compiledURL = try MLModel.compileModel(at: url)
            } else {
                compiledURL = url
            }

            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let mlModel = try MLModel(contentsOf: compiledURL, configuration: configuration)
            visionModel = try VNCoreMLModel(for: mlModel)
            statusText = "HORSE DETECTOR READY"
        } catch {
            visionModel = nil
            statusText = "HORSE DETECTOR ERROR"
        }
    }

    func detectHorse(in sampleBuffer: CMSampleBuffer) -> HorseDetectorResult? {
        guard let visionModel else {
            statusText = "HORSE DETECTOR MISSING"
            return nil
        }

        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .right,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            statusText = "HORSE DETECTOR INFERENCE ERROR"
            return nil
        }

        if let objects = request.results as? [VNRecognizedObjectObservation] {
            return bestHorseObject(objects)
        }

        if let classifications = request.results as? [VNClassificationObservation],
           let best = classifications.first {
            let label = best.identifier.lowercased()
            let isHorse = acceptedLabels.contains { label.contains($0) }
            if isHorse && best.confidence >= minimumConfidence {
                return HorseDetectorResult(
                    boundingBox: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
                    confidence: best.confidence,
                    label: best.identifier,
                    source: "CoreML classification"
                )
            }
        }

        return nil
    }

    private func bestHorseObject(_ objects: [VNRecognizedObjectObservation]) -> HorseDetectorResult? {
        var bestMatch: HorseDetectorResult?
        var bestAny: HorseDetectorResult?

        for object in objects {
            guard let label = object.labels.first else { continue }
            let name = label.identifier.lowercased()
            let result = HorseDetectorResult(
                boundingBox: object.boundingBox,
                confidence: label.confidence,
                label: label.identifier,
                source: "CoreML object"
            )

            if bestAny == nil || result.confidence > bestAny!.confidence {
                bestAny = result
            }

            let isHorse = acceptedLabels.contains { name.contains($0) }
            if isHorse && label.confidence >= minimumConfidence {
                if bestMatch == nil || result.confidence > bestMatch!.confidence {
                    bestMatch = result
                }
            }
        }

        if let bestMatch {
            statusText = "HORSE DETECTOR LOCK"
            return bestMatch
        }

        if let bestAny {
            statusText = "MODEL SAW: \(bestAny.label.uppercased())"
        } else {
            statusText = "NO OBJECTS"
        }

        return nil
    }
}
