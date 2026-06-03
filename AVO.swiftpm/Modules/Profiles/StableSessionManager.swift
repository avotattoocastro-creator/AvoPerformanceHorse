import Foundation
import SwiftUI

@MainActor
final class StableSessionManager: ObservableObject {
    static let shared = StableSessionManager()

    @Published var activeHorse: StableHorseProfile?
    @Published var currentSessionFolder: URL?
    @Published var isRecording = false

    private init() {}

    func setActiveHorse(_ horse: StableHorseProfile) {
        activeHorse = horse
    }

    func startBiomechRecording(rootFolder: URL) {
        guard let horse = activeHorse else {
            print("No active horse")
            return
        }

        do {
            AVOMasterSessionCore.shared.setActiveHorse(name: horse.name, id: horse.id, stableRoot: rootFolder)
            let manifest = try AVOMasterSessionCore.shared.startNewSession()
            let folder = URL(fileURLWithPath: manifest.sessionRoot, isDirectory: true)
            _ = try AVOMasterSessionCore.shared.folder(for: .snaps)
            _ = try AVOMasterSessionCore.shared.folder(for: .biotechRec)
            _ = try AVOMasterSessionCore.shared.folder(for: .dataRec)
            currentSessionFolder = folder
            isRecording = true
            print("MASTER SESSION STARTED:", folder.path)
        } catch {
            print("SESSION ERROR:", error)
        }
    }

    func stopBiomechRecording() {
        isRecording = false
        print("SESSION STOPPED")
    }

    func saveSnapshot(imageData: Data) {
        guard let folder = currentSessionFolder else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH-mm-ss-SSS"
        let name = formatter.string(from: Date())
        let snapFolder = (try? AVOMasterSessionCore.shared.folder(for: .snaps)) ?? folder.appendingPathComponent("Snaps", isDirectory: true)
        let url = snapFolder.appendingPathComponent("snap_\(name).jpg")
        do { try imageData.write(to: url, options: [.atomic]) } catch { print("SNAP ERROR:", error) }
    }

    func saveBiomechFrame(_ dictionary: [String: Double]) {
        appendFrame(dictionary, fileName: "biomechanics.json")
    }

    func saveSensorFrame(_ dictionary: [String: Double]) {
        appendFrame(dictionary, fileName: "sensors.json")
    }

    func saveLiDARDepthFrame(_ sample: AVOLiDARDepthSample) {
        guard let folder = currentSessionFolder else { return }
        let url = folder.appendingPathComponent("depth_lidar.json")
        var array: [AVOLiDARDepthSample] = []
        if let data = try? Data(contentsOf: url),
           let old = try? JSONDecoder.avo.decode([AVOLiDARDepthSample].self, from: data) {
            array = old
        }
        array.append(sample)
        do {
            let data = try JSONEncoder.avo.encode(array)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("LIDAR SAVE ERROR:", error)
        }
    }

    private func appendFrame(_ dictionary: [String: Double], fileName: String) {
        guard let folder = currentSessionFolder else { return }
        let url = folder.appendingPathComponent(fileName)
        var array: [[String: Double]] = []
        if let data = try? Data(contentsOf: url),
           let old = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] {
            array = old
        }
        array.append(dictionary)
        do {
            let data = try JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted])
            try data.write(to: url, options: [.atomic])
        } catch {
            print("FRAME SAVE ERROR:", error)
        }
    }
}
