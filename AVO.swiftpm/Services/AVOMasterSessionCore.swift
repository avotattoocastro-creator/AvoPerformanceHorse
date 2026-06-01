import Foundation
import SwiftUI
import UIKit

// MARK: - AVO MASTER SESSION CORE
// Single source of truth for horse folder + active session.
// All REC CLIENT / REC BIOMECH / REC DATA / REVIEW / HARDWARE / LIDAR / REPORT files must go through this core.

public enum AVOMasterSessionArea: String, Codable, CaseIterable, Hashable {
    case clientRec = "ClientRec"
    case biotechRec = "BiotechRec"
    case dataRec = "DataRec"
    case snaps = "Snaps"
    case review = "Review"
    case hardware = "Hardware"
    case lidar = "Lidar"
    case reports = "Reports"
    case ai = "AI"
    case manifests = "Manifests"
    case exports = "Exports"
    case analytics = "Analytics"
}

public struct AVOMasterSessionManifest: Codable, Hashable {
    public var version: String
    public var horseName: String
    public var horseId: String
    public var horseFolderName: String
    public var sessionId: String
    public var sessionRoot: String
    public var createdAt: Date
    public var updatedAt: Date
    public var areas: [String: String]
    public var notes: [String]
}

public final class AVOMasterSessionCore: ObservableObject {
    public static let shared = AVOMasterSessionCore()

    @Published public private(set) var activeHorseName: String = "SIN_CABALLO"
    @Published public private(set) var activeHorseId: UUID?
    @Published public private(set) var activeHorseFolderName: String = "SIN_CABALLO"
    @Published public private(set) var activeHorseFolderURL: URL?
    @Published public private(set) var activeSessionId: String = ""
    @Published public private(set) var activeSessionURL: URL?
    @Published public private(set) var status: String = "MASTER SESSION READY"
    @Published public private(set) var lastURL: URL?

    private let lastHorseNameKey = "AVOMasterActiveHorseNameV1"
    private let lastHorseIdKey = "AVOMasterActiveHorseIdV1"
    private let lastHorseFolderKey = "AVOMasterActiveHorseFolderV1"

    private init() {
        activeHorseName = UserDefaults.standard.string(forKey: lastHorseNameKey) ?? "SIN_CABALLO"
        if let idText = UserDefaults.standard.string(forKey: lastHorseIdKey) { activeHorseId = UUID(uuidString: idText) }
        activeHorseFolderName = UserDefaults.standard.string(forKey: lastHorseFolderKey) ?? sanitizeHorseFolderName(activeHorseName)
    }

    public func setActiveHorse(name: String, id: UUID? = nil, stableRoot: URL? = nil, stableFolderName: String? = nil) {
        let cleanName = sanitizeVisibleName(name)
        activeHorseName = cleanName.isEmpty ? "SIN_CABALLO" : cleanName
        activeHorseId = id

        let folderName: String
        if let stableFolderName, !stableFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            folderName = stableFolderName
        } else if let id {
            folderName = sanitizeHorseFolderName(activeHorseName) + "_" + id.uuidString
        } else {
            folderName = sanitizeHorseFolderName(activeHorseName)
        }
        activeHorseFolderName = folderName

        let root = stableRoot ?? defaultStableRoot()
        activeHorseFolderURL = root.appendingPathComponent("Horses", isDirectory: true).appendingPathComponent(folderName, isDirectory: true)
        createHorseBaseFolders()
        persistActiveHorse()
        status = "ACTIVE HORSE · \(activeHorseName)"
    }

    public func ensureSession(sessionId requestedSessionId: String? = nil) throws -> AVOMasterSessionManifest {
        if activeHorseFolderURL == nil { setActiveHorse(name: activeHorseName, id: activeHorseId) }
        guard let horseFolder = activeHorseFolderURL else {
            throw NSError(domain: "AVOMasterSessionCore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active horse folder"])
        }

        if let activeSessionURL, !activeSessionId.isEmpty, FileManager.default.fileExists(atPath: activeSessionURL.path) {
            return try writeManifest(sessionURL: activeSessionURL, sessionId: activeSessionId)
        }

        let sessionId = requestedSessionId ?? "SESSION_" + timestamp()
        let sessionURL = horseFolder.appendingPathComponent("Sessions", isDirectory: true).appendingPathComponent(sessionId, isDirectory: true)
        try createSessionFolders(sessionURL)
        activeSessionId = sessionId
        activeSessionURL = sessionURL
        status = "SESSION ACTIVE · \(sessionId)"
        return try writeManifest(sessionURL: sessionURL, sessionId: sessionId)
    }

    public func startNewSession() throws -> AVOMasterSessionManifest {
        activeSessionId = ""
        activeSessionURL = nil
        return try ensureSession()
    }

    public func closeSession() {
        activeSessionId = ""
        activeSessionURL = nil
        status = "SESSION CLOSED"
    }

    public func folder(for area: AVOMasterSessionArea) throws -> URL {
        _ = try ensureSession()
        guard let sessionURL = activeSessionURL else {
            throw NSError(domain: "AVOMasterSessionCore", code: -2, userInfo: [NSLocalizedDescriptionKey: "No active session"])
        }
        let folder = sessionURL.appendingPathComponent(area.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        lastURL = folder
        return folder
    }

    public func makeFileURL(area: AVOMasterSessionArea, prefix: String, ext: String) throws -> URL {
        let folder = try self.folder(for: area)
        let safePrefix = sanitizeFileName(prefix)
        let url = folder.appendingPathComponent("\(safePrefix)_\(timestamp()).\(ext)")
        lastURL = url
        return url
    }

    public func writeText(_ text: String, area: AVOMasterSessionArea, fileName: String) throws -> URL {
        let folder = try self.folder(for: area)
        let url = folder.appendingPathComponent(sanitizeFileName(fileName))
        try text.write(to: url, atomically: true, encoding: .utf8)
        lastURL = url
        touchManifest()
        return url
    }

    public func writeData(_ data: Data, area: AVOMasterSessionArea, fileName: String) throws -> URL {
        let folder = try self.folder(for: area)
        let url = folder.appendingPathComponent(sanitizeFileName(fileName))
        try data.write(to: url, options: [.atomic])
        lastURL = url
        touchManifest()
        return url
    }

    public func saveImage(_ image: UIImage, area: AVOMasterSessionArea, prefix: String, compression: CGFloat = 0.86) throws -> URL {
        guard let data = image.jpegData(compressionQuality: compression) else {
            throw NSError(domain: "AVOMasterSessionCore", code: -3, userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed"])
        }
        let url = try makeFileURL(area: area, prefix: prefix, ext: "jpg")
        try data.write(to: url, options: [.atomic])
        lastURL = url
        touchManifest()
        return url
    }

    public func sessionPathText() -> String {
        activeSessionURL?.path ?? "NO SESSION"
    }

    private func createHorseBaseFolders() {
        guard let horse = activeHorseFolderURL else { return }
        let folders = [
            horse,
            horse.appendingPathComponent("HorseFile", isDirectory: true),
            horse.appendingPathComponent("Sessions", isDirectory: true),
            horse.appendingPathComponent("VetRecords", isDirectory: true),
            horse.appendingPathComponent("AITraining", isDirectory: true),
            horse.appendingPathComponent("Media", isDirectory: true),
            horse.appendingPathComponent("Reports", isDirectory: true),
            horse.appendingPathComponent("Calibration", isDirectory: true),
            horse.appendingPathComponent("GaitAnalysis", isDirectory: true),
            horse.appendingPathComponent("LamenessMonitor", isDirectory: true),
            horse.appendingPathComponent("RehabPlans", isDirectory: true),
            horse.appendingPathComponent("LoadMonitor", isDirectory: true)
        ]
        for folder in folders { try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    }

    private func createSessionFolders(_ sessionURL: URL) throws {
        try FileManager.default.createDirectory(at: sessionURL, withIntermediateDirectories: true)
        for area in AVOMasterSessionArea.allCases {
            try FileManager.default.createDirectory(at: sessionURL.appendingPathComponent(area.rawValue, isDirectory: true), withIntermediateDirectories: true)
        }
    }

    private func writeManifest(sessionURL: URL, sessionId: String) throws -> AVOMasterSessionManifest {
        var areas: [String: String] = [:]
        for area in AVOMasterSessionArea.allCases {
            areas[area.rawValue] = sessionURL.appendingPathComponent(area.rawValue, isDirectory: true).path
        }
        let manifest = AVOMasterSessionManifest(
            version: "MASTER_SESSION_CORE_V1",
            horseName: activeHorseName,
            horseId: activeHorseId?.uuidString ?? "",
            horseFolderName: activeHorseFolderName,
            sessionId: sessionId,
            sessionRoot: sessionURL.path,
            createdAt: Date(),
            updatedAt: Date(),
            areas: areas,
            notes: [
                "All app data is stored under the active horse folder.",
                "REC CLIENT / REC BIOMECH / REC DATA / REVIEW / HARDWARE / LIDAR / REPORTS are session scoped."
            ]
        )
        let data = try encoder().encode(manifest)
        try data.write(to: sessionURL.appendingPathComponent("session_manifest.json"), options: [.atomic])
        try data.write(to: sessionURL.appendingPathComponent("Manifests", isDirectory: true).appendingPathComponent("master_session_manifest.json"), options: [.atomic])
        lastURL = sessionURL
        return manifest
    }

    private func touchManifest() {
        guard let url = activeSessionURL, !activeSessionId.isEmpty else { return }
        _ = try? writeManifest(sessionURL: url, sessionId: activeSessionId)
    }

    private func persistActiveHorse() {
        UserDefaults.standard.set(activeHorseName, forKey: lastHorseNameKey)
        UserDefaults.standard.set(activeHorseId?.uuidString, forKey: lastHorseIdKey)
        UserDefaults.standard.set(activeHorseFolderName, forKey: lastHorseFolderKey)
    }

    private func defaultStableRoot() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("AVO_Horse_App", isDirectory: true)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss_SSS"
        return formatter.string(from: Date())
    }

    private func sanitizeVisibleName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.uppercased().contains("NO HORSE") || trimmed.uppercased() == "SIN_CABALLO" { return "SIN_CABALLO" }
        return trimmed
    }

    private func sanitizeHorseFolderName(_ value: String) -> String {
        let base = sanitizeVisibleName(value).replacingOccurrences(of: " ", with: "_")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let clean = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return clean.isEmpty ? "SIN_CABALLO" : clean
    }

    private func sanitizeFileName(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

@MainActor
public struct AVOMasterSessionStatusStrip: View {
    @ObservedObject private var core = AVOMasterSessionCore.shared
    public init() {}
    public var body: some View {
        HStack(spacing: 10) {
            Text("HORSE")
                .foregroundStyle(.cyan)
            Text(core.activeHorseName)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("SESSION")
                .foregroundStyle(.orange)
            Text(core.activeSessionId.isEmpty ? "NO SESSION" : core.activeSessionId)
                .foregroundStyle(.green)
                .lineLimit(1)
            Spacer()
        }
        .font(.system(size: 10, weight: .black, design: .monospaced))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cyan.opacity(0.28), lineWidth: 1))
    }
}
