import Foundation
import SwiftUI
import CoreML

// MARK: - COREML PHASE 126
// TRAINING ECOSYSTEM COMPLETE SYSTEM
//
// Closes the ML lifecycle:
// REVIEW dataset -> training package -> model import -> benchmark -> compare -> deploy.
// This does not train heavy models on iPad. It prepares/export datasets and manages models.

public enum AVOModelRole: String, Codable, CaseIterable, Hashable {
    case activeAutoPose
    case candidate
    case fallback
    case archived
}

public struct AVOModelRegistryEntry: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var modelName: String
    public var fileName: String
    public var role: AVOModelRole
    public var importedAt: Date
    public var averageLatencyMS: Double
    public var averageQualityScore: Double
    public var failureCount: Int
    public var notes: [String]

    public init(modelName: String,
                fileName: String,
                role: AVOModelRole = .candidate,
                importedAt: Date = Date(),
                averageLatencyMS: Double = 0,
                averageQualityScore: Double = 0,
                failureCount: Int = 0,
                notes: [String] = []) {
        self.modelName = modelName
        self.fileName = fileName
        self.role = role
        self.importedAt = importedAt
        self.averageLatencyMS = averageLatencyMS
        self.averageQualityScore = averageQualityScore
        self.failureCount = failureCount
        self.notes = notes
    }
}

public struct AVOTrainingPackageManifest: Codable, Hashable {
    public var phase: String
    public var createdAt: Date
    public var horseName: String
    public var packageId: String
    public var reviewFrames: Int
    public var correctionSamples: Int
    public var averageQuality: Double
    public var files: [String]
    public var recommendedAction: String
}

public struct AVOModelComparisonReport: Codable, Hashable {
    public var createdAt: Date
    public var activeModel: String?
    public var candidates: [AVOModelRegistryEntry]
    public var recommendedModel: String?
    public var reason: String
}

@MainActor
public final class AVOCoreMLTrainingEcosystem: ObservableObject {

    public static let shared = AVOCoreMLTrainingEcosystem()

    @Published public private(set) var status: String = "COREML ECOSYSTEM READY"
    @Published public private(set) var registry: [AVOModelRegistryEntry] = []
    @Published public private(set) var lastTrainingPackageURL: URL?
    @Published public private(set) var lastComparison: AVOModelComparisonReport?
    @Published public private(set) var activeModelName: String?

    private let storage = AVOStorageEngine.shared
    private let review = ReviewCompleteSystemController.shared

    private init() {}

    public func registerModel(fileURL: URL, role: AVOModelRole = .candidate) {
        let name = fileURL.deletingPathExtension().lastPathComponent

        if registry.contains(where: { $0.fileName == fileURL.lastPathComponent }) {
            status = "MODEL ALREADY REGISTERED"
            return
        }

        let entry = AVOModelRegistryEntry(
            modelName: name,
            fileName: fileURL.lastPathComponent,
            role: role,
            notes: ["imported"]
        )

        registry.append(entry)
        if role == .activeAutoPose {
            activeModelName = name
        }

        status = "MODEL REGISTERED: \(name)"
    }

    public func setActiveModel(_ modelName: String) {
        for idx in registry.indices {
            if registry[idx].modelName == modelName {
                registry[idx].role = .activeAutoPose
                activeModelName = modelName
            } else if registry[idx].role == .activeAutoPose {
                registry[idx].role = .fallback
            }
        }
        status = "ACTIVE MODEL: \(modelName)"
    }

    public func recordBenchmark(modelName: String,
                                latencyMS: Double,
                                qualityScore: Double,
                                failed: Bool = false) {
        guard let idx = registry.firstIndex(where: { $0.modelName == modelName }) else {
            status = "BENCHMARK MODEL NOT FOUND"
            return
        }

        let old = registry[idx]
        let mergedLatency = old.averageLatencyMS == 0 ? latencyMS : (old.averageLatencyMS * 0.75 + latencyMS * 0.25)
        let mergedQuality = old.averageQualityScore == 0 ? qualityScore : (old.averageQualityScore * 0.75 + qualityScore * 0.25)

        registry[idx].averageLatencyMS = mergedLatency
        registry[idx].averageQualityScore = mergedQuality
        if failed { registry[idx].failureCount += 1 }

        status = "BENCHMARK UPDATED: \(modelName)"
    }

    public func compareModels() -> AVOModelComparisonReport {
        let candidates = registry.sorted {
            let aScore = modelScore($0)
            let bScore = modelScore($1)
            return aScore > bScore
        }

        let best = candidates.first
        let active = registry.first(where: { $0.role == .activeAutoPose })?.modelName

        let reason: String
        if let best {
            reason = "Best score quality/latency/failures: \(String(format: "%.3f", modelScore(best)))"
        } else {
            reason = "No models registered."
        }

        let report = AVOModelComparisonReport(
            createdAt: Date(),
            activeModel: active,
            candidates: candidates,
            recommendedModel: best?.modelName,
            reason: reason
        )

        lastComparison = report
        status = "MODEL COMPARE DONE"
        return report
    }

    public func deployRecommendedModel() {
        let report = compareModels()
        guard let recommended = report.recommendedModel else {
            status = "NO MODEL TO DEPLOY"
            return
        }

        setActiveModel(recommended)
        status = "DEPLOYED MODEL: \(recommended)"
    }

    public func buildTrainingPackage(horseName: String) {
        do {
            let manifestFolder = try storage.folder(for: .manifests, horseName: horseName)
            let analyticsFolder = try storage.folder(for: .analytics, horseName: horseName)
            let packageURL = manifestFolder.appendingPathComponent("coreml_training_package_phase126.json")

            let reviewManifest = review.buildManifest()
            let correctionsJSON = try review.correctionLearning.exportLearningJSONData()
            let correctionsCSV = review.correctionLearning.exportTrainingCorrectionCSV()

            let correctionsJSONURL = analyticsFolder.appendingPathComponent("coreml_corrections.json")
            try correctionsJSON.write(to: correctionsJSONURL)

            let correctionsCSVURL = analyticsFolder.appendingPathComponent("coreml_corrections.csv")
            try correctionsCSV.write(to: correctionsCSVURL, atomically: true, encoding: .utf8)

            let manifest = AVOTrainingPackageManifest(
                phase: "126",
                createdAt: Date(),
                horseName: horseName,
                packageId: "TRAINING_\(Int(Date().timeIntervalSince1970))",
                reviewFrames: reviewManifest.totalFrames,
                correctionSamples: reviewManifest.correctionSamples,
                averageQuality: reviewManifest.averageQuality,
                files: [
                    "review_complete_manifest.json",
                    "coreml_corrections.json",
                    "coreml_corrections.csv"
                ],
                recommendedAction: reviewManifest.exportReady ? "READY_FOR_COLAB_RETRAINING" : "NEEDS_MORE_CORRECTED_FRAMES"
            )

            try storage.writeJSON(manifest, to: packageURL)
            lastTrainingPackageURL = packageURL
            status = "TRAINING PACKAGE BUILT"
        } catch {
            status = "TRAINING PACKAGE ERROR: \(error.localizedDescription)"
        }
    }

    public func exportModelRegistry(horseName: String) {
        do {
            let folder = try storage.folder(for: .manifests, horseName: horseName)
            let url = folder.appendingPathComponent("coreml_model_registry.json")
            try storage.writeJSON(registry, to: url)
            status = "MODEL REGISTRY EXPORTED"
        } catch {
            status = "REGISTRY EXPORT ERROR: \(error.localizedDescription)"
        }
    }

    public func resetBenchmarks() {
        for idx in registry.indices {
            registry[idx].averageLatencyMS = 0
            registry[idx].averageQualityScore = 0
            registry[idx].failureCount = 0
        }
        status = "BENCHMARKS RESET"
    }

    private func modelScore(_ entry: AVOModelRegistryEntry) -> Double {
        let quality = entry.averageQualityScore
        let latencyPenalty = entry.averageLatencyMS <= 0 ? 0.15 : min(0.35, entry.averageLatencyMS / 250.0)
        let failurePenalty = min(0.40, Double(entry.failureCount) * 0.08)
        let activeBonus = entry.role == .activeAutoPose ? 0.03 : 0
        return max(0, quality - latencyPenalty - failurePenalty + activeBonus)
    }
}

@MainActor
public struct AVOCoreMLTrainingEcosystemPanel: View {

    @ObservedObject private var ecosystem = AVOCoreMLTrainingEcosystem.shared
    @ObservedObject private var horseSession = BiotechHorseSessionRecorder.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COREML TRAINING ECOSYSTEM")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            HStack {
                metric("MODELS", "\(ecosystem.registry.count)")
                metric("ACTIVE", ecosystem.activeModelName ?? "--")
                metric("PACKAGE", ecosystem.lastTrainingPackageURL == nil ? "NO" : "YES")
            }

            Text(ecosystem.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)

            HStack {
                Button("BUILD PACKAGE") {
                    ecosystem.buildTrainingPackage(horseName: horseSession.selectedHorseName)
                }
                .buttonStyle(.borderedProminent)

                Button("COMPARE") {
                    _ = ecosystem.compareModels()
                }
                .buttonStyle(.bordered)

                Button("DEPLOY") {
                    ecosystem.deployRecommendedModel()
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))
        }
        .padding(12)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
