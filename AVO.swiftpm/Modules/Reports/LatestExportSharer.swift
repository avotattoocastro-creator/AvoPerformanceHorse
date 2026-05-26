import SwiftUI
import UIKit
import Foundation

// MARK: - AVO Latest Export Sharer
// Restores the old Review IA behaviour: EXPORTS always returns a real .zip
// ready for Colab/Drive, even after V4.2 moved datasets into session folders.

final class LatestExportSharer: ObservableObject {
    @Published var zipURL: URL?
    @Published var status: String = "READY"

    func shareExport(at exportURL: URL, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.makeZip(from: exportURL, preferredName: exportURL.lastPathComponent, completion: completion)
        }
    }

    func shareLatestExport(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let latest = self.findLatestExportFolder() else {
                DispatchQueue.main.async {
                    self.status = "NO EXPORTS FOUND"
                }
                return
            }
            self.makeZip(from: latest, preferredName: latest.lastPathComponent, completion: completion)
        }
    }

    private func findLatestExportFolder() -> URL? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }

        var candidates: [URL] = []

        // Legacy route used before consolidation.
        let legacy = docs
            .appendingPathComponent("AVOHorseDatasets", isDirectory: true)
            .appendingPathComponent("AVOStableHorseDataset", isDirectory: true)
            .appendingPathComponent("exports", isDirectory: true)
        candidates.append(contentsOf: exportFoldersInside(legacy))

        // New V4.2 route: active session / Review / Datasets / AVOStableHorseDataset / exports.
        if let enumerator = fm.enumerator(
            at: docs,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                let name = url.lastPathComponent.lowercased()
                guard name.hasPrefix("export_") else { continue }
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
                let report = url.appendingPathComponent("export_report.json")
                let colab = url.appendingPathComponent("avo_colab_pipeline.json")
                if fm.fileExists(atPath: report.path) || fm.fileExists(atPath: colab.path) {
                    candidates.append(url)
                }
            }
        }

        let unique = Array(Set(candidates))
        return unique.sorted { a, b in
            modifiedOrCreatedDate(a) > modifiedOrCreatedDate(b)
        }.first
    }

    private func exportFoldersInside(_ exportsRoot: URL) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: exportsRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return items.filter { url in
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
            return url.lastPathComponent.lowercased().hasPrefix("export_")
        }
    }

    private func modifiedOrCreatedDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        return values?.contentModificationDate ?? values?.creationDate ?? .distantPast
    }

    private func makeZip(from sourceURL: URL, preferredName: String, completion: @escaping () -> Void) {
        let fm = FileManager.default
        let safeName = preferredName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let tempZip = fm.temporaryDirectory.appendingPathComponent("AVOHorse_\(safeName).zip")

        do {
            if fm.fileExists(atPath: tempZip.path) {
                try fm.removeItem(at: tempZip)
            }
        } catch {
            DispatchQueue.main.async { self.status = "ZIP CLEAN ERROR" }
            return
        }

        if sourceURL.pathExtension.lowercased() == "zip" {
            do {
                try fm.copyItem(at: sourceURL, to: tempZip)
                DispatchQueue.main.async {
                    self.zipURL = tempZip
                    self.status = "EXPORT ZIP READY"
                    completion()
                }
            } catch {
                DispatchQueue.main.async { self.status = "ZIP COPY ERROR" }
            }
            return
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: sourceURL, options: [.forUploading], error: &coordinationError) { zippedURL in
            do {
                try fm.copyItem(at: zippedURL, to: tempZip)
                DispatchQueue.main.async {
                    self.zipURL = tempZip
                    self.status = "EXPORT ZIP READY"
                    completion()
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "ZIP COPY ERROR: \(error.localizedDescription)"
                }
            }
        }

        if let coordinationError {
            DispatchQueue.main.async {
                self.status = "EXPORT ZIP ERROR: \(coordinationError.localizedDescription)"
            }
        }
    }
}

struct LatestExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
