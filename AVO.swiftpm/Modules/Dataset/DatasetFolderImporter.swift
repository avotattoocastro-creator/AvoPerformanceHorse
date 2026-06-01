import Foundation
import UniformTypeIdentifiers

final class DatasetFolderImporter {
    static func importFolder(_ selectedURL: URL, into manager: HorseDatasetManager) throws -> Int {
        let access = selectedURL.startAccessingSecurityScopedResource()
        defer { if access { selectedURL.stopAccessingSecurityScopedResource() } }

        let source = findDatasetRoot(from: selectedURL) ?? selectedURL
        guard let imageFolder = findImagesFolder(from: source) ?? (isImageFolder(source) ? source : nil) else {
            throw ImportError.noImagesFound
        }

        let manifest = findManifest(from: source, selectedURL: selectedURL)
        return try manager.importImageFolder(
            imageFolder,
            sourceManifestURL: manifest,
            resetExisting: true
        )
    }

    private static func findDatasetRoot(from url: URL) -> URL? {
        let fm = FileManager.default
        let candidates = [
            url,
            url.appendingPathComponent("AVOStableHorseDataset", isDirectory: true),
            url.appendingPathComponent("Documents/AVOHorseDatasets/AVOStableHorseDataset", isDirectory: true),
            url.appendingPathComponent("AVOHorseDatasets/AVOStableHorseDataset", isDirectory: true)
        ]

        return candidates.first { candidate in
            findImagesFolder(from: candidate) != nil ||
            fm.fileExists(atPath: candidate.appendingPathComponent("manifest.json").path)
        }
    }

    private static func findImagesFolder(from root: URL) -> URL? {
        let fm = FileManager.default
        let directNames = ["images", "Images", "IMAGES"]
        for name in directNames {
            let url = root.appendingPathComponent(name, isDirectory: true)
            if fm.fileExists(atPath: url.path) { return url }
        }

        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        for case let url as URL in enumerator {
            if url.hasDirectoryPath && url.lastPathComponent.lowercased() == "images" {
                return url
            }
        }
        return nil
    }

    private static func isImageFolder(_ url: URL) -> Bool {
        let allowed = Set(["jpg", "jpeg", "png", "heic", "heif"])
        let urls = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        return urls.contains { allowed.contains($0.pathExtension.lowercased()) }
    }

    private static func findManifest(from source: URL, selectedURL: URL) -> URL? {
        let fm = FileManager.default
        let candidates = [
            source.appendingPathComponent("manifest.json"),
            selectedURL.appendingPathComponent("manifest.json"),
            source.deletingLastPathComponent().appendingPathComponent("manifest.json")
        ]
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    enum ImportError: Error {
        case noImagesFound
    }
}
