import Foundation
import SwiftUI
import UIKit

// MARK: - BIOTECH PHASE 121
// HORSE SESSION RECORDING STORAGE

public enum BiotechRecordingKind: String, Codable, CaseIterable, Hashable {
    case client = "CLIENT"
    case biotech = "BIOTECH"
    case data = "DATA"
}

public struct BiotechSessionRecordingInfo: Codable, Hashable {
    public var horseName: String
    public var sessionId: String
    public var rootPath: String
    public var clientFolder: String
    public var biotechFolder: String
    public var dataFolder: String
    public var createdAt: Date
}

public final class BiotechHorseSessionRecorder: ObservableObject {

    public static let shared = BiotechHorseSessionRecorder()

    @Published public var selectedHorseName: String = "SIN_CABALLO"
    @Published public private(set) var currentSession: BiotechSessionRecordingInfo?
    @Published public private(set) var status: String = "SESSION READY"
    @Published public private(set) var lastSavedURL: URL?

    private init() {}

    public func setSelectedHorse(_ name: String) {
        selectedHorseName = sanitize(name.isEmpty ? "SIN_CABALLO" : name)
        status = "HORSE SELECTED: \(selectedHorseName)"
    }

    public func ensureSession(rootFolder: URL? = nil) throws -> BiotechSessionRecordingInfo {
        if let currentSession { return currentSession }

        if AVOMasterSessionCore.shared.activeHorseName == "SIN_CABALLO" {
            AVOMasterSessionCore.shared.setActiveHorse(name: selectedHorseName)
        }
        let manifest = try AVOMasterSessionCore.shared.ensureSession()
        let client = try AVOMasterSessionCore.shared.folder(for: .clientRec)
        let biotech = try AVOMasterSessionCore.shared.folder(for: .biotechRec)
        let data = try AVOMasterSessionCore.shared.folder(for: .dataRec)

        let info = BiotechSessionRecordingInfo(
            horseName: selectedHorseName,
            sessionId: manifest.sessionId,
            rootPath: manifest.sessionRoot,
            clientFolder: client.path,
            biotechFolder: biotech.path,
            dataFolder: data.path,
            createdAt: manifest.createdAt
        )

        currentSession = info
        try writeManifest(info)
        status = "MASTER SESSION \(manifest.sessionId) READY"
        return info
    }

    public func folderURL(for kind: BiotechRecordingKind, rootFolder: URL? = nil) throws -> URL {
        let session = try ensureSession(rootFolder: rootFolder)
        switch kind {
        case .client: return URL(fileURLWithPath: session.clientFolder, isDirectory: true)
        case .biotech: return URL(fileURLWithPath: session.biotechFolder, isDirectory: true)
        case .data: return URL(fileURLWithPath: session.dataFolder, isDirectory: true)
        }
    }

    public func makeRecordingURL(kind: BiotechRecordingKind,
                                 fileExtension: String,
                                 rootFolder: URL? = nil) throws -> URL {
        let folder = try folderURL(for: kind, rootFolder: rootFolder)
        let filename = "\(kind.rawValue)_\(selectedHorseName)_\(compactTimestamp()).\(fileExtension)"
        let url = folder.appendingPathComponent(sanitizeFileName(filename))
        lastSavedURL = url
        status = "SAVE TARGET: \(kind.rawValue)"
        return url
    }

    public func writeDataManifest(_ text: String,
                                  rootFolder: URL? = nil,
                                  fileName: String = "data_stream_manifest.csv") throws -> URL {
        let folder = try folderURL(for: .data, rootFolder: rootFolder)
        let url = folder.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        lastSavedURL = url
        status = "DATA MANIFEST SAVED"
        return url
    }

    public func closeSession() {
        status = "SESSION CLOSED"
        currentSession = nil
        AVOMasterSessionCore.shared.closeSession()
    }

    private func writeManifest(_ info: BiotechSessionRecordingInfo) throws {
        let url = URL(fileURLWithPath: info.rootPath, isDirectory: true)
            .appendingPathComponent("session_manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(info).write(to: url)
    }

    private func defaultHorseRoot() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ??
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    private func compactTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
    }

    private func sanitizeFileName(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}

@MainActor
public struct BiotechSelectedHorseHeaderBadge: View {
    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hare.fill")
            VStack(alignment: .leading, spacing: 1) {
                Text("CABALLO SELECCIONADO")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Text(recorder.selectedHorseName)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.28), lineWidth: 1))
    }
}
