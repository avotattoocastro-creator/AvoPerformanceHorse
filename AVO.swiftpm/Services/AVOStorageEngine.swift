import Foundation
import UIKit

// MARK: - AVO PHASE 122
// CENTRAL STORAGE ENGINE
//
// One central storage layer for BIOTECH + REVIEW.
// Goal:
// BIOTECH captures -> session folders -> REVIEW training intake.

public enum AVOStorageArea: String, Codable, CaseIterable, Hashable {
    case recClient = "REC_CLIENT"
    case recBiotech = "REC_BIOTECH"
    case recData = "REC_DATA"
    case reviewFrames = "review_frames"
    case thumbnails = "thumbnails"
    case analytics = "analytics"
    case manifests = "manifests"
}

public struct AVOSessionFolderMap: Codable, Hashable {
    public var horseName: String
    public var sessionId: String
    public var sessionRoot: String
    public var recClient: String
    public var recBiotech: String
    public var recData: String
    public var reviewFrames: String
    public var thumbnails: String
    public var analytics: String
    public var manifests: String
    public var createdAt: Date
}

@MainActor
public final class AVOStorageEngine: ObservableObject {

    public static let shared = AVOStorageEngine()

    @Published public private(set) var activeSession: AVOSessionFolderMap?
    @Published public private(set) var status: String = "STORAGE READY"
    @Published public private(set) var lastURL: URL?

    private init() {}

    public func ensureSession(horseName: String,
                              rootFolder: URL? = nil,
                              sessionId: String? = nil) throws -> AVOSessionFolderMap {
        let cleanHorse = clean(horseName.isEmpty ? "SIN_CABALLO" : horseName)

        // MASTER SESSION CORE: one real session per active horse, under:
        // AVO_Horse_App/Horses/<HorseName_UUID>/Sessions/SESSION_yyyy-MM-dd_HH-mm-ss_SSS/
        if AVOMasterSessionCore.shared.activeHorseName == "SIN_CABALLO" {
            AVOMasterSessionCore.shared.setActiveHorse(name: horseName)
        }
        let master = try AVOMasterSessionCore.shared.ensureSession(sessionId: sessionId)
        let sessionRoot = URL(fileURLWithPath: master.sessionRoot, isDirectory: true)

        let recClient = try AVOMasterSessionCore.shared.folder(for: .clientRec)
        let recBiotech = try AVOMasterSessionCore.shared.folder(for: .biotechRec)
        let recData = try AVOMasterSessionCore.shared.folder(for: .dataRec)
        let reviewFrames = try AVOMasterSessionCore.shared.folder(for: .review)
        let thumbnails = sessionRoot.appendingPathComponent("Thumbnails", isDirectory: true)
        let analytics = try AVOMasterSessionCore.shared.folder(for: .analytics)
        let manifests = try AVOMasterSessionCore.shared.folder(for: .manifests)
        try FileManager.default.createDirectory(at: thumbnails, withIntermediateDirectories: true)

        let map = AVOSessionFolderMap(
            horseName: cleanHorse,
            sessionId: master.sessionId,
            sessionRoot: sessionRoot.path,
            recClient: recClient.path,
            recBiotech: recBiotech.path,
            recData: recData.path,
            reviewFrames: reviewFrames.path,
            thumbnails: thumbnails.path,
            analytics: analytics.path,
            manifests: manifests.path,
            createdAt: master.createdAt
        )

        activeSession = map
        try writeJSON(map, to: manifests.appendingPathComponent("storage_engine_manifest.json"))
        status = "MASTER SESSION READY \(master.sessionId)"
        return map
    }

    public func folder(for area: AVOStorageArea,
                       horseName: String,
                       rootFolder: URL? = nil) throws -> URL {
        let map = try ensureSession(horseName: horseName, rootFolder: rootFolder)
        switch area {
        case .recClient: return URL(fileURLWithPath: map.recClient, isDirectory: true)
        case .recBiotech: return URL(fileURLWithPath: map.recBiotech, isDirectory: true)
        case .recData: return URL(fileURLWithPath: map.recData, isDirectory: true)
        case .reviewFrames: return URL(fileURLWithPath: map.reviewFrames, isDirectory: true)
        case .thumbnails: return URL(fileURLWithPath: map.thumbnails, isDirectory: true)
        case .analytics: return URL(fileURLWithPath: map.analytics, isDirectory: true)
        case .manifests: return URL(fileURLWithPath: map.manifests, isDirectory: true)
        }
    }

    public func makeFileURL(area: AVOStorageArea,
                            horseName: String,
                            prefix: String,
                            ext: String,
                            rootFolder: URL? = nil) throws -> URL {
        let folder = try folder(for: area, horseName: horseName, rootFolder: rootFolder)
        let url = folder.appendingPathComponent("\(clean(prefix))_\(timestamp()).\(ext)")
        lastURL = url
        return url
    }

    public func saveImage(_ image: UIImage,
                          area: AVOStorageArea,
                          horseName: String,
                          prefix: String,
                          rootFolder: URL? = nil,
                          compression: CGFloat = 0.86) throws -> URL {
        let url = try makeFileURL(area: area, horseName: horseName, prefix: prefix, ext: "jpg", rootFolder: rootFolder)
        guard let data = image.jpegData(compressionQuality: compression) else {
            throw NSError(domain: "AVOStorageEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed"])
        }
        try data.write(to: url)
        lastURL = url
        status = "IMAGE SAVED \(area.rawValue)"
        return url
    }

    public func writeText(_ text: String,
                          area: AVOStorageArea,
                          horseName: String,
                          fileName: String,
                          rootFolder: URL? = nil) throws -> URL {
        let folder = try folder(for: area, horseName: horseName, rootFolder: rootFolder)
        let url = folder.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        lastURL = url
        status = "TEXT SAVED \(area.rawValue)"
        return url
    }

    public func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url)
        lastURL = url
    }

    public func resetSession() {
        activeSession = nil
        status = "STORAGE SESSION RESET"
    }

    private func defaultRoot() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ??
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return f.string(from: Date())
    }

    private func clean(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let replaced = value.replacingOccurrences(of: " ", with: "_")
        return String(replaced.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}
