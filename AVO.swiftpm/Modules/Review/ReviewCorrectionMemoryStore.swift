import Foundation

// MARK: - REVIEW PHASE 113
// CORRECTION MEMORY STORE
//
// Simple file persistence helper for learned local correction memory.

public final class ReviewCorrectionMemoryStore {

    public init() {}

    public func defaultMemoryURL(folder: URL) -> URL {
        folder.appendingPathComponent("review_auto_correction_memory.json")
    }

    public func save(engine: ReviewAutoCorrectionLearningEngine, to url: URL) async throws {
        let data = try await MainActor.run {
            try engine.exportLearningJSONData()
        }
        try data.write(to: url)
    }

    public func load(engine: ReviewAutoCorrectionLearningEngine, from url: URL) async throws {
        let data = try Data(contentsOf: url)
        try await MainActor.run {
            try engine.importLearningJSONData(data)
        }
    }

    public func saveCSV(engine: ReviewAutoCorrectionLearningEngine, to url: URL) async throws {
        let csv = await MainActor.run {
            engine.exportTrainingCorrectionCSV()
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
