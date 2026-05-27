import SwiftUI
import UniformTypeIdentifiers

struct ModelImporterView: View {
    @Binding var modelStatus: String
    var onImported: () -> Void
    
    @State private var showImporter = false
    
    var body: some View {
        VStack(spacing: 10) {
            Text("IA MODEL MANAGER")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            
            Text(modelStatus)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
                .multilineTextAlignment(.center)
            
            Button("ACTUALIZAR IA") {
                showImporter = true
            }
            .buttonStyle(ReviewButtonStyle(color: .cyan))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.65)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item, .folder, .package],
            allowsMultipleSelection: false
        ) { result in
            importModel(result)
        }
    }
    
    private func importModel(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else {
                modelStatus = "NO FILE SELECTED"
                return
            }
            
            let fm = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            let modelsFolder = docs.appendingPathComponent("Models", isDirectory: true)
            let destination = modelsFolder.appendingPathComponent("AVOHorsePose.mlpackage", isDirectory: true)
            
            try fm.createDirectory(at: modelsFolder, withIntermediateDirectories: true)
            
            let source = try resolveMLPackage(from: selectedURL)
            
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            
            let accessed = source.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    source.stopAccessingSecurityScopedResource()
                }
            }
            
            try fm.copyItem(at: source, to: destination)
            
            modelStatus = "MODEL COPIED · RESTART PREVIEW"
            NotificationCenter.default.post(name: .avoHorsePoseModelUpdated, object: nil)
            onImported()
            
        } catch {
            modelStatus = "IMPORT ERROR: \(error.localizedDescription)"
        }
    }
    
    private func resolveMLPackage(from url: URL) throws -> URL {
        let fm = FileManager.default
        
        if url.pathExtension.lowercased() == "mlpackage" {
            return url
        }
        
        var current = url
        for _ in 0..<6 {
            if current.pathExtension.lowercased() == "mlpackage" {
                return current
            }
            current.deleteLastPathComponent()
        }
        
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "mlpackage" {
                    return fileURL
                }
            }
        }
        
        throw NSError(
            domain: "AVOHorsePoseImporter",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "No se encontró ningún .mlpackage válido"]
        )
    }
}

extension Notification.Name {
    static let avoHorsePoseModelUpdated = Notification.Name("avoHorsePoseModelUpdated")
}
