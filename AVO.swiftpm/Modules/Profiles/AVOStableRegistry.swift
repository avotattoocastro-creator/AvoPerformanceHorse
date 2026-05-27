import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - AVO Stable Registry Models

struct StableHorseListItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var birthDate: Date
    var sex: StableHorseSex
    var breed: String
    var competitionMode: String
    var lastSessionDate: Date?
    var lastVetRecordDate: Date?
    var alertSummary: String
    var folderName: String

    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }
}

struct StableHorseProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var birthDate: Date
    var sex: StableHorseSex
    var breed: String
    var competitionMode: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    // Advanced editable horse file fields. Optional for backward compatibility with old saved profiles.
    var ownerName: String? = nil
    var trainerName: String? = nil
    var primaryVetName: String? = nil
    var chipNumber: String? = nil
    var nfcHorseID: String? = nil
    var stableID: String? = nil
    var riderID: String? = nil
    var clinicalNotes: String? = nil
    var sportNotes: String? = nil
    var photoRelativePath: String? = nil

    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }
}

enum StableHorseSex: String, Codable, CaseIterable, Identifiable {
    case stallion = "Semental"
    case mare = "Yegua"
    case gelding = "Castrado"
    case unknown = "Sin definir"
    var id: String { rawValue }
}

enum StableInjurySeverity: String, Codable, CaseIterable, Identifiable {
    case mild = "Leve"
    case moderate = "Moderada"
    case severe = "Grave"
    case critical = "Crítica"
    var id: String { rawValue }
}

struct StableSessionListItem: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var title: String
    var durationSeconds: Double
    var samplesCount: Int
    var avgQuality: Double
    var avgRisk: Double
    var avgFatigue: Double
    var videoRelativePath: String?
    var sessionRelativePath: String
    var sensorsRelativePath: String?
    var aiSummaryRelativePath: String?
}

struct StableVetRecordListItem: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var title: String
    var diagnosis: String
    var injuryZone: String
    var severity: StableInjurySeverity
    var recordRelativePath: String
    var imagesFolderRelativePath: String
}

struct StableVetRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var vetName: String
    var title: String
    var diagnosis: String
    var injuryZone: String
    var severity: StableInjurySeverity
    var treatment: String
    var observations: String
    var imageRelativePaths: [String]
    var linkedSessionIDs: [UUID]
}

struct StableAITrainingManifest: Codable, Hashable {
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var linkedSessionIDs: [UUID]
    var linkedVetRecordIDs: [UUID]
    var objective: String
    var notes: String
}


struct StableAIRiskZone: Identifiable, Codable, Hashable {
    var id = UUID()
    var zone: String
    var score: Double
    var reason: String
}

struct StableAIRecommendation: Identifiable, Codable, Hashable {
    var id = UUID()
    var priority: String
    var text: String
}

struct StableAIAnalysisReport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var sessionsAnalyzed: Int
    var vetRecordsAnalyzed: Int
    var globalRisk: Double
    var mainRiskZone: String
    var summary: String
    var riskZones: [StableAIRiskZone]
    var recommendations: [StableAIRecommendation]
    var timeline: [String]
}


struct StablePerformanceDashboardReport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var sessionsCount: Int
    var vetRecordsCount: Int
    var averageQuality: Double
    var averageRisk: Double
    var averageFatigue: Double
    var lastSessionDate: Date?
    var lastVetRecordDate: Date?
    var clinicalStatus: String
    var mainAlert: String
    var recommendation: String
}


struct StableProfessionalReportExport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var reportType: String
    var includePerformance: Bool
    var includeSessions: Bool
    var includeVeterinary: Bool
    var includeTimeline: Bool
    var includeAI: Bool
    var includeMedicalImages: Bool
    var title: String
    var executiveSummary: String
    var horseBlock: [String]
    var performanceBlock: [String]
    var sessionsBlock: [String]
    var veterinaryBlock: [String]
    var aiBlock: [String]
    var timelineBlock: [String]
    var recommendations: [String]
}


struct StableGaitCycleReport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var sessionsAnalyzed: Int
    var gaitType: String
    var cyclesDetected: Int
    var cadence: Double
    var estimatedStrideMeters: Double
    var symmetryScore: Double
    var regularityScore: Double
    var irregularityRisk: Double
    var summary: String
    var recommendations: [String]
}

struct StableLamenessReport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var sessionsAnalyzed: Int
    var vetRecordsAnalyzed: Int
    var baselineQuality: Double
    var currentQuality: Double
    var lamenessRisk: Double
    var alertLevel: String
    var suspectedZone: String
    var reasons: [String]
    var recommendations: [String]
}

struct StableRehabPhase: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var week: Int
    var title: String
    var workload: String
    var maxImpact: Double
    var maxFatigue: Double
    var maxAsymmetry: Double
    var objective: String
}

struct StableRehabPlanReport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var injuryFocus: String
    var alertLevel: String
    var currentRisk: Double
    var baselineQuality: Double
    var phases: [StableRehabPhase]
    var stopRules: [String]
    var veterinaryClearanceRequired: Bool
    var summary: String
}

struct StableLoadMonitorReport: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var sessionsAnalyzed: Int
    var dailyLoad: Double
    var weeklyLoad: Double
    var fatigueAccumulated: Double
    var impactAccumulated: Double
    var overloadRisk: Double
    var recommendedRestHours: Int
    var alertLevel: String
    var summary: String
    var recommendations: [String]
}

struct StableAppSettings: Codable, Hashable {
    var rootFolderPath: String
    var lastUpdated: Date
    var version: String
}

// MARK: - Folder Picker

struct AVOFolderPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - Store

final class AVOStableStore: ObservableObject {
    @Published var rootFolderURL: URL?
    @Published var horsesIndex: [StableHorseListItem] = []
    @Published var selectedHorseID: UUID?
    @Published var selectedHorseProfile: StableHorseProfile?
    @Published var selectedSessions: [StableSessionListItem] = []
    @Published var selectedVetRecords: [StableVetRecordListItem] = []
    @Published var status: String = "STABLE READY"
    @Published var latestAIReport: StableAIAnalysisReport?

    private let bookmarkKey = "AVOStableRootFolderBookmarkV1"
    private let selectedHorseIDKey = "AVOUnifiedSelectedStableHorseIDV1"
    private let fallbackFolderName = "AVO_Horse_App"

    init() {
        loadRootFolder()
    }

    var selectedHorseName: String {
        selectedHorseProfile?.name ?? horsesIndex.first(where: { $0.id == selectedHorseID })?.name ?? "NO HORSE"
    }

    func setRootFolder(_ url: URL) {
        rootFolderURL?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        rootFolderURL = url
        do {
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            status = "BOOKMARK ERROR"
        }
        createBaseFolders()
        saveAppSettings()
        loadIndex()
    }

    func loadRootFolder() {
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                _ = url.startAccessingSecurityScopedResource()
                rootFolderURL = url
                createBaseFolders()
                loadIndex()
                status = stale ? "FOLDER BOOKMARK STALE" : "FOLDER LOADED"
                return
            }
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fallback = docs.appendingPathComponent(fallbackFolderName)
        rootFolderURL = fallback
        createBaseFolders()
        loadIndex()
    }

    func createBaseFolders() {
        guard let root = rootFolderURL else { return }
        let folders = [
            root,
            root.appendingPathComponent("Horses"),
            root.appendingPathComponent("GlobalSettings"),
            root.appendingPathComponent("Exports"),
            root.appendingPathComponent("AITrainingGlobal"),
            root.appendingPathComponent("FutureCloudSync"),
            root.appendingPathComponent("CommercialClinicMode")
        ]
        for folder in folders {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    func loadIndex() {
        guard let url = indexURL() else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                horsesIndex = try JSONDecoder.avo.decode([StableHorseListItem].self, from: Data(contentsOf: url))
            } else {
                horsesIndex = []
                saveIndex()
            }
            if selectedHorseID == nil, let saved = UserDefaults.standard.string(forKey: selectedHorseIDKey), let uuid = UUID(uuidString: saved), horsesIndex.contains(where: { $0.id == uuid }) {
                selectedHorseID = uuid
            }
            if selectedHorseID == nil { selectedHorseID = horsesIndex.first?.id }
            if let id = selectedHorseID { loadHorse(id: id) }
            status = "INDEX \(horsesIndex.count) HORSES"
        } catch {
            status = "INDEX LOAD ERROR"
        }
    }

    func saveIndex() {
        guard let url = indexURL() else { return }
        do {
            try JSONEncoder.avo.encode(horsesIndex).write(to: url, options: [.atomic])
        } catch {
            status = "INDEX SAVE ERROR"
        }
    }

    func createHorse(name: String, birthDate: Date, sex: StableHorseSex, breed: String, competitionMode: String, notes: String) {
        let id = UUID()
        let safe = Self.safeFolderName(name.isEmpty ? "Horse" : name) + "_" + id.uuidString
        let profile = StableHorseProfile(id: id, name: name.isEmpty ? "NEW HORSE" : name, birthDate: birthDate, sex: sex, breed: breed, competitionMode: competitionMode, notes: notes, createdAt: Date(), updatedAt: Date())
        let item = StableHorseListItem(id: id, name: profile.name, birthDate: birthDate, sex: sex, breed: breed, competitionMode: competitionMode, lastSessionDate: nil, lastVetRecordDate: nil, alertSummary: "OK", folderName: safe)
        horsesIndex.insert(item, at: 0)
        createHorseFolders(folderName: safe)
        saveProfile(profile, folderName: safe)
        saveIndex()
        selectedHorseID = id
        loadHorse(id: id)
        status = "HORSE CREATED"
    }

    func loadHorse(id: UUID) {
        guard let item = horsesIndex.first(where: { $0.id == id }), let folder = horseFolder(item) else { return }
        selectedHorseID = id
        UserDefaults.standard.set(id.uuidString, forKey: selectedHorseIDKey)
        do {
            let profileURL = folder.appendingPathComponent("profile.json")
            if FileManager.default.fileExists(atPath: profileURL.path) {
                selectedHorseProfile = try JSONDecoder.avo.decode(StableHorseProfile.self, from: Data(contentsOf: profileURL))
            }
            let savedSessions = loadCodable([StableSessionListItem].self, from: folder.appendingPathComponent("sessions_index.json")) ?? []
            selectedSessions = rebuildSessionIndexFromFolders(horseFolder: folder, saved: savedSessions)
            saveCodable(selectedSessions, to: folder.appendingPathComponent("sessions_index.json"))
            selectedVetRecords = loadCodable([StableVetRecordListItem].self, from: folder.appendingPathComponent("vet_index.json")) ?? []
            status = "HORSE LOADED · SESSIONS \(selectedSessions.count)"
        } catch {
            status = "HORSE LOAD ERROR"
        }
    }

    private func rebuildSessionIndexFromFolders(horseFolder: URL, saved: [StableSessionListItem]) -> [StableSessionListItem] {
        let fm = FileManager.default
        let sessionsRoot = horseFolder.appendingPathComponent("Sessions", isDirectory: true)
        let savedByPath = Dictionary(uniqueKeysWithValues: saved.map { ($0.sessionRelativePath, $0) })

        guard let folders = try? fm.contentsOfDirectory(at: sessionsRoot, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return saved.sorted { $0.date > $1.date }
        }

        var rebuilt: [StableSessionListItem] = []
        for folder in folders where folder.hasDirectoryPath {
            let folderName = folder.lastPathComponent
            let relativeSessionPath = "Sessions/\(folderName)/session_manifest.json"
            let old = savedByPath[relativeSessionPath]

            let values = try? folder.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let created = values?.creationDate ?? values?.contentModificationDate ?? dateFromSessionFolderName(folderName) ?? Date()

            let reviewImages = countFiles(in: folder.appendingPathComponent("Review/Datasets/AVOStableHorseDataset/images"), extensions: ["jpg", "jpeg", "png", "heic"])
            let dataFrames = countFiles(in: folder.appendingPathComponent("DataRec"), extensions: ["json", "jpg", "jpeg", "png"])
            let clientVideos = countFiles(in: folder.appendingPathComponent("ClientRec"), extensions: ["mov", "mp4"])
            let biotechVideos = countFiles(in: folder.appendingPathComponent("BiotechRec"), extensions: ["mov", "mp4"])
            let sampleCount = max(reviewImages + dataFrames, old?.samplesCount ?? 0)

            let title: String
            if biotechVideos > 0 && clientVideos > 0 { title = "Client + Biomech Session" }
            else if biotechVideos > 0 { title = "Biomech Video Session" }
            else if clientVideos > 0 { title = "Client Video Session" }
            else if reviewImages > 0 { title = "Dataset Review Session" }
            else { title = old?.title ?? "Biomech Session" }

            rebuilt.append(StableSessionListItem(
                id: old?.id ?? UUID(),
                date: old?.date ?? created,
                title: title,
                durationSeconds: old?.durationSeconds ?? 0,
                samplesCount: sampleCount,
                avgQuality: old?.avgQuality ?? 0,
                avgRisk: old?.avgRisk ?? 0,
                avgFatigue: old?.avgFatigue ?? 0,
                videoRelativePath: firstVideoRelativePath(sessionFolder: folder, folderName: folderName) ?? old?.videoRelativePath,
                sessionRelativePath: relativeSessionPath,
                sensorsRelativePath: fm.fileExists(atPath: folder.appendingPathComponent("Hardware/sensors.json").path) ? "Sessions/\(folderName)/Hardware/sensors.json" : old?.sensorsRelativePath,
                aiSummaryRelativePath: fm.fileExists(atPath: folder.appendingPathComponent("AI/ai_summary.json").path) ? "Sessions/\(folderName)/AI/ai_summary.json" : old?.aiSummaryRelativePath
            ))
        }

        if rebuilt.isEmpty { return saved.sorted { $0.date > $1.date } }
        return rebuilt.sorted { $0.date > $1.date }
    }

    private func countFiles(in folder: URL, extensions allowed: Set<String>) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return 0 }
        return files.filter { !$0.hasDirectoryPath && allowed.contains($0.pathExtension.lowercased()) }.count
    }

    private func firstVideoRelativePath(sessionFolder: URL, folderName: String) -> String? {
        let fm = FileManager.default
        for area in ["BiotechRec", "ClientRec"] {
            let f = sessionFolder.appendingPathComponent(area)
            if let files = try? fm.contentsOfDirectory(at: f, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]),
               let first = files.filter({ ["mov", "mp4"].contains($0.pathExtension.lowercased()) }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
                return "Sessions/\(folderName)/\(area)/\(first.lastPathComponent)"
            }
        }
        return nil
    }

    private func dateFromSessionFolderName(_ name: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in ["'SESSION_'yyyy-MM-dd_HH-mm-ss", "yyyyMMdd_HHmmss", "yyyy-MM-dd_HH-mm-ss"] {
            f.dateFormat = format
            if let d = f.date(from: name) { return d }
        }
        return nil
    }

    func updateSelectedHorse(profile: StableHorseProfile) {
        guard let idx = horsesIndex.firstIndex(where: { $0.id == profile.id }) else { return }
        var updated = profile
        updated.updatedAt = Date()
        selectedHorseProfile = updated
        horsesIndex[idx].name = updated.name
        horsesIndex[idx].birthDate = updated.birthDate
        horsesIndex[idx].sex = updated.sex
        horsesIndex[idx].breed = updated.breed
        horsesIndex[idx].competitionMode = updated.competitionMode
        saveProfile(updated, folderName: horsesIndex[idx].folderName)
        saveIndex()
        status = "HORSE UPDATED"
    }

    func saveLiveSession(samples: [SessionSample], horseNameFallback: String, riderName: String, lidarSamples: [AVOLiDARDepthSample] = []) {
        if selectedHorseID == nil {
            createHorse(name: horseNameFallback == "NO HORSE" ? "AVO HORSE" : horseNameFallback, birthDate: Date(), sex: .unknown, breed: "", competitionMode: "", notes: "Auto-created from live session")
        }
        guard let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE FOLDER"; return }
        let data = samples.isEmpty ? [] : samples
        let id = UUID()
        let now = Date()
        let folderName = Self.sessionFolderName(now)
        let sessionFolder = folder.appendingPathComponent("Sessions").appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true)

        let sessionURL = sessionFolder.appendingPathComponent("session.json")
        let sensorsURL = sessionFolder.appendingPathComponent("sensors.json")
        let aiURL = sessionFolder.appendingPathComponent("ai_summary.json")
        let lidarURL = sessionFolder.appendingPathComponent("depth_lidar.json")

        let avgQ = data.map { $0.quality }.average
        let avgR = data.map { $0.risk }.average
        let avgF = data.map { $0.fatigue }.average
        let manifest: [String: String] = [
            "horse": item.name,
            "rider": riderName,
            "createdAt": ISO8601DateFormatter().string(from: now),
            "purpose": "Biomechanics + sensor session for future AI injury correlation"
        ]

        do {
            try JSONEncoder.avo.encode(data).write(to: sessionURL, options: [.atomic])
            try JSONEncoder.avo.encode(data).write(to: sensorsURL, options: [.atomic])
            try JSONEncoder.avo.encode(manifest).write(to: aiURL, options: [.atomic])
            try JSONEncoder.avo.encode(lidarSamples).write(to: lidarURL, options: [.atomic])
            let listItem = StableSessionListItem(id: id, date: now, title: "Biomech Session", durationSeconds: Double(data.count) * 0.5, samplesCount: data.count, avgQuality: avgQ, avgRisk: avgR, avgFatigue: avgF, videoRelativePath: nil, sessionRelativePath: "Sessions/\(folderName)/session.json", sensorsRelativePath: "Sessions/\(folderName)/sensors.json", aiSummaryRelativePath: "Sessions/\(folderName)/ai_summary.json")
            selectedSessions.insert(listItem, at: 0)
            saveCodable(selectedSessions, to: folder.appendingPathComponent("sessions_index.json"))
            updateIndexAfterSession(date: now)
            status = lidarSamples.isEmpty ? "AVO SESSION SAVED" : "AVO SESSION + LIDAR SAVED"
        } catch {
            status = "SESSION SAVE ERROR"
        }
    }

    func createVetRecord(title: String, vetName: String, diagnosis: String, injuryZone: String, severity: StableInjurySeverity, treatment: String, observations: String) {
        guard let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE SELECTED"; return }
        let id = UUID()
        let now = Date()
        let folderName = Self.sessionFolderName(now)
        let vetFolder = folder.appendingPathComponent("VetRecords").appendingPathComponent(folderName)
        let imagesFolder = vetFolder.appendingPathComponent("Images")
        try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)

        let record = StableVetRecord(id: id, date: now, vetName: vetName, title: title, diagnosis: diagnosis, injuryZone: injuryZone, severity: severity, treatment: treatment, observations: observations, imageRelativePaths: [], linkedSessionIDs: selectedSessions.prefix(5).map { $0.id })
        let recordURL = vetFolder.appendingPathComponent("vet_record.json")
        do {
            try JSONEncoder.avo.encode(record).write(to: recordURL, options: [.atomic])
            let list = StableVetRecordListItem(id: id, date: now, title: title, diagnosis: diagnosis, injuryZone: injuryZone, severity: severity, recordRelativePath: "VetRecords/\(folderName)/vet_record.json", imagesFolderRelativePath: "VetRecords/\(folderName)/Images")
            selectedVetRecords.insert(list, at: 0)
            saveCodable(selectedVetRecords, to: folder.appendingPathComponent("vet_index.json"))
            updateIndexAfterVet(date: now, alert: diagnosis)
            status = "VET RECORD SAVED"
        } catch {
            status = "VET SAVE ERROR"
        }
    }


    func runBiomechAIAnalysis() {
        guard let profile = selectedHorseProfile, let item = selectedItem(), let folder = horseFolder(item) else {
            status = "NO HORSE SELECTED"
            return
        }

        var riskSamples: [Double] = []
        var qualitySamples: [Double] = []
        var fatigueSamples: [Double] = []
        var gaitFlags: [String] = []

        for session in selectedSessions {
            let url = folder.appendingPathComponent(session.sessionRelativePath)
            if let samples = loadCodable([SessionSample].self, from: url) {
                riskSamples.append(contentsOf: samples.map { $0.risk })
                qualitySamples.append(contentsOf: samples.map { $0.quality })
                fatigueSamples.append(contentsOf: samples.map { $0.fatigue })
                gaitFlags.append(contentsOf: samples.map { $0.gait })
            } else {
                riskSamples.append(session.avgRisk)
                qualitySamples.append(session.avgQuality)
                fatigueSamples.append(session.avgFatigue)
            }
        }

        let avgRisk = riskSamples.average
        let avgQuality = qualitySamples.average
        let avgFatigue = fatigueSamples.average
        let severeVet = selectedVetRecords.filter { $0.severity == .severe || $0.severity == .critical }.count
        let vetBoost = min(0.35, Double(severeVet) * 0.12 + Double(selectedVetRecords.count) * 0.03)
        let qualityPenalty = max(0, 0.55 - avgQuality) * 0.35
        let fatigueBoost = avgFatigue * 0.25
        let global = min(1.0, max(0.0, avgRisk * 0.45 + fatigueBoost + vetBoost + qualityPenalty))

        let zones = selectedVetRecords.map { $0.injuryZone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Zona sin definir" : $0.injuryZone }
        let mainZone = zones.first ?? inferRiskZoneFromGait(gaitFlags: gaitFlags)

        var riskZones: [StableAIRiskZone] = []
        if selectedVetRecords.isEmpty {
            riskZones.append(StableAIRiskZone(zone: mainZone, score: global, reason: "Riesgo estimado por biomecánica, calidad de tracking y fatiga."))
        } else {
            for record in selectedVetRecords.prefix(6) {
                let sev: Double
                switch record.severity {
                case .mild: sev = 0.25
                case .moderate: sev = 0.50
                case .severe: sev = 0.75
                case .critical: sev = 0.95
                }
                let score = min(1.0, max(global, sev * 0.75 + avgRisk * 0.25))
                riskZones.append(StableAIRiskZone(zone: record.injuryZone.isEmpty ? "Zona sin definir" : record.injuryZone, score: score, reason: record.diagnosis.isEmpty ? "Historial veterinario vinculado a sesiones biomecánicas." : record.diagnosis))
            }
        }

        let summary: String
        if global >= 0.75 {
            summary = "RIESGO ALTO: revisar historial veterinario, impacto, fatiga y simetría antes de aumentar carga."
        } else if global >= 0.45 {
            summary = "RIESGO MEDIO: se recomienda comparar con sesiones anteriores y controlar evolución."
        } else {
            summary = "RIESGO BAJO: no se detectan señales fuertes con los datos disponibles."
        }

        var recommendations: [StableAIRecommendation] = []
        recommendations.append(StableAIRecommendation(priority: global >= 0.75 ? "ALTA" : "MEDIA", text: "Comparar la próxima sesión con esta línea base y revisar cambios de simetría, impacto y fatiga."))
        if !selectedVetRecords.isEmpty {
            recommendations.append(StableAIRecommendation(priority: "ALTA", text: "Cruzar el diagnóstico veterinario con las 3-5 sesiones anteriores a la lesión."))
        }
        if avgQuality < 0.45 {
            recommendations.append(StableAIRecommendation(priority: "MEDIA", text: "Mejorar encuadre de cámara antes de tomar decisiones clínicas con IA."))
        }
        if avgFatigue > 0.60 {
            recommendations.append(StableAIRecommendation(priority: "MEDIA", text: "Reducir carga o repetir medición tras descanso si la fatiga aparece elevada."))
        }

        var timeline: [String] = []
        for s in selectedSessions.prefix(8) {
            timeline.append("SESSION | \(Self.shortDate(s.date)) | risk \(Int(s.avgRisk * 100))% | samples \(s.samplesCount)")
        }
        for v in selectedVetRecords.prefix(8) {
            timeline.append("VET | \(Self.shortDate(v.date)) | \(v.injuryZone) | \(v.severity.rawValue)")
        }
        timeline.sort()

        let report = StableAIAnalysisReport(
            id: UUID(),
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: Date(),
            sessionsAnalyzed: selectedSessions.count,
            vetRecordsAnalyzed: selectedVetRecords.count,
            globalRisk: global,
            mainRiskZone: mainZone,
            summary: summary,
            riskZones: riskZones,
            recommendations: recommendations,
            timeline: timeline
        )

        let aiFolder = folder.appendingPathComponent("AITraining")
        try? FileManager.default.createDirectory(at: aiFolder, withIntermediateDirectories: true)
        do {
            try JSONEncoder.avo.encode(report).write(to: aiFolder.appendingPathComponent("ai_analysis_report.json"), options: [.atomic])
            try JSONEncoder.avo.encode(report.riskZones).write(to: aiFolder.appendingPathComponent("ai_risk_timeline.json"), options: [.atomic])
            try JSONEncoder.avo.encode(report.recommendations).write(to: aiFolder.appendingPathComponent("ai_recommendations.json"), options: [.atomic])
            latestAIReport = report
            status = "AI ANALYSIS READY"
        } catch {
            status = "AI ANALYSIS ERROR"
        }
    }

    private func inferRiskZoneFromGait(gaitFlags: [String]) -> String {
        let joined = gaitFlags.joined(separator: " ").lowercased()
        if joined.contains("left") || joined.contains("izq") { return "Lado izquierdo" }
        if joined.contains("right") || joined.contains("der") { return "Lado derecho" }
        if joined.contains("hind") || joined.contains("posterior") { return "Posterior" }
        if joined.contains("front") || joined.contains("anterior") { return "Anterior" }
        return "Biomecánica general"
    }


    func exportPerformanceDashboardReport() {
        guard let profile = selectedHorseProfile, let item = selectedItem(), let folder = horseFolder(item) else {
            status = "NO HORSE SELECTED"
            return
        }

        let avgQuality = selectedSessions.map { $0.avgQuality }.average
        let avgRisk = selectedSessions.map { $0.avgRisk }.average
        let avgFatigue = selectedSessions.map { $0.avgFatigue }.average
        let severeCount = selectedVetRecords.filter { $0.severity == .severe || $0.severity == .critical }.count

        let clinicalStatus: String
        if avgRisk >= 0.70 || severeCount > 0 {
            clinicalStatus = "ALERTA"
        } else if avgRisk >= 0.40 || avgFatigue >= 0.60 {
            clinicalStatus = "VIGILAR"
        } else {
            clinicalStatus = "ESTABLE"
        }

        let mainAlert: String
        if let report = latestAIReport {
            mainAlert = "\(report.mainRiskZone) · riesgo \(Int(report.globalRisk * 100))%"
        } else if let vet = selectedVetRecords.first {
            mainAlert = "Último veterinario: \(vet.injuryZone.isEmpty ? "zona sin definir" : vet.injuryZone) · \(vet.severity.rawValue)"
        } else if let session = selectedSessions.first {
            mainAlert = "Última sesión: riesgo \(Int(session.avgRisk * 100))% · calidad \(Int(session.avgQuality * 100))%"
        } else {
            mainAlert = "Sin datos suficientes todavía"
        }

        let recommendation: String
        if clinicalStatus == "ALERTA" {
            recommendation = "No aumentar carga. Revisar veterinario y comparar próximas sesiones con la línea base."
        } else if clinicalStatus == "VIGILAR" {
            recommendation = "Mantener seguimiento. Repetir medición y controlar fatiga, impacto y simetría."
        } else {
            recommendation = "Estado estable con los datos disponibles. Continuar generando histórico."
        }

        let report = StablePerformanceDashboardReport(
            id: UUID(),
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: Date(),
            sessionsCount: selectedSessions.count,
            vetRecordsCount: selectedVetRecords.count,
            averageQuality: avgQuality,
            averageRisk: avgRisk,
            averageFatigue: avgFatigue,
            lastSessionDate: selectedSessions.first?.date,
            lastVetRecordDate: selectedVetRecords.first?.date,
            clinicalStatus: clinicalStatus,
            mainAlert: mainAlert,
            recommendation: recommendation
        )

        let reportsFolder = folder.appendingPathComponent("Reports")
        try? FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        do {
            try JSONEncoder.avo.encode(report).write(to: reportsFolder.appendingPathComponent("performance_dashboard_report.json"), options: [.atomic])
            status = "PERFORMANCE DASHBOARD EXPORTED"
        } catch {
            status = "DASHBOARD EXPORT ERROR"
        }
    }

    func exportProfessionalReport(includePerformance: Bool, includeSessions: Bool, includeVeterinary: Bool, includeTimeline: Bool, includeAI: Bool, includeMedicalImages: Bool) {
        guard let profile = selectedHorseProfile, let item = selectedItem(), let folder = horseFolder(item) else {
            status = "NO HORSE SELECTED"
            return
        }

        let avgQuality = selectedSessions.map { $0.avgQuality }.average
        let avgRisk = selectedSessions.map { $0.avgRisk }.average
        let avgFatigue = selectedSessions.map { $0.avgFatigue }.average
        let severeCount = selectedVetRecords.filter { $0.severity == .severe || $0.severity == .critical }.count

        let clinicalStatus: String
        if avgRisk >= 0.70 || severeCount > 0 {
            clinicalStatus = "ALERTA"
        } else if avgRisk >= 0.40 || avgFatigue >= 0.60 {
            clinicalStatus = "VIGILAR"
        } else {
            clinicalStatus = "ESTABLE"
        }

        let executiveSummary: String
        if let report = latestAIReport {
            executiveSummary = "Estado \(clinicalStatus). IA: \(report.summary) Zona principal: \(report.mainRiskZone)."
        } else {
            executiveSummary = "Estado \(clinicalStatus). Informe generado con \(selectedSessions.count) sesiones biomecánicas y \(selectedVetRecords.count) registros veterinarios. Ejecuta RUN AI para añadir análisis inteligente avanzado."
        }

        let horseBlock = [
            "Nombre: \(profile.name)",
            "Edad: \(profile.ageYears) años",
            "Sexo: \(profile.sex.rawValue)",
            "Raza: \(profile.breed.isEmpty ? "--" : profile.breed)",
            "Modalidad: \(profile.competitionMode.isEmpty ? "--" : profile.competitionMode)",
            "Notas: \(profile.notes.isEmpty ? "--" : profile.notes)"
        ]

        let performanceBlock = [
            "Estado clínico-deportivo: \(clinicalStatus)",
            "Calidad media: \(Int(avgQuality * 100))%",
            "Riesgo medio: \(Int(avgRisk * 100))%",
            "Fatiga media: \(Int(avgFatigue * 100))%",
            "Sesiones analizadas: \(selectedSessions.count)",
            "Registros veterinarios: \(selectedVetRecords.count)"
        ]

        let sessionsBlock = selectedSessions.prefix(20).map { session in
            "\(Self.shortDate(session.date)) | \(session.title) | muestras \(session.samplesCount) | riesgo \(Int(session.avgRisk * 100))% | calidad \(Int(session.avgQuality * 100))%"
        }

        let veterinaryBlock = selectedVetRecords.prefix(20).map { record in
            "\(Self.shortDate(record.date)) | \(record.title) | \(record.injuryZone.isEmpty ? "zona sin definir" : record.injuryZone) | \(record.severity.rawValue) | \(record.diagnosis)"
        }

        let aiBlock: [String]
        if let report = latestAIReport {
            aiBlock = [
                "Riesgo global IA: \(Int(report.globalRisk * 100))%",
                "Zona principal: \(report.mainRiskZone)",
                "Resumen: \(report.summary)"
            ] + report.riskZones.map { "Zona \($0.zone): \(Int($0.score * 100))% - \($0.reason)" }
        } else {
            aiBlock = ["Sin análisis IA generado todavía. Usa RUN AI ANALYSIS antes de exportar para completar este bloque."]
        }

        var timelineBlock: [String] = []
        for s in selectedSessions.prefix(20) {
            timelineBlock.append("SESSION | \(Self.shortDate(s.date)) | \(s.title) | riesgo \(Int(s.avgRisk * 100))%")
        }
        for v in selectedVetRecords.prefix(20) {
            timelineBlock.append("VET | \(Self.shortDate(v.date)) | \(v.injuryZone) | \(v.severity.rawValue)")
        }
        timelineBlock.sort()

        let recommendations: [String]
        if let report = latestAIReport, !report.recommendations.isEmpty {
            recommendations = report.recommendations.map { "\($0.priority): \($0.text)" }
        } else if clinicalStatus == "ALERTA" {
            recommendations = ["No aumentar carga.", "Revisar veterinario.", "Comparar sesiones antes/después de lesión."]
        } else if clinicalStatus == "VIGILAR" {
            recommendations = ["Mantener seguimiento estrecho.", "Repetir medición y controlar fatiga, impacto y simetría."]
        } else {
            recommendations = ["Continuar generando histórico.", "Guardar sesiones limpias para mejorar el entrenamiento IA futuro."]
        }

        let export = StableProfessionalReportExport(
            id: UUID(),
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: Date(),
            reportType: "AVO Horse Professional Report Builder",
            includePerformance: includePerformance,
            includeSessions: includeSessions,
            includeVeterinary: includeVeterinary,
            includeTimeline: includeTimeline,
            includeAI: includeAI,
            includeMedicalImages: includeMedicalImages,
            title: "AVO Horse Professional Report - \(profile.name)",
            executiveSummary: executiveSummary,
            horseBlock: horseBlock,
            performanceBlock: includePerformance ? performanceBlock : [],
            sessionsBlock: includeSessions ? sessionsBlock : [],
            veterinaryBlock: includeVeterinary ? veterinaryBlock : [],
            aiBlock: includeAI ? aiBlock : [],
            timelineBlock: includeTimeline ? timelineBlock : [],
            recommendations: recommendations
        )

        let reportsFolder = folder.appendingPathComponent("Reports")
        try? FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        let txt = Self.makeProfessionalReportText(export)
        let pdfURL = reportsFolder.appendingPathComponent(Self.reportPDFFileName(horseName: profile.name, date: Date()))
        do {
            try JSONEncoder.avo.encode(export).write(to: reportsFolder.appendingPathComponent("professional_report_builder.json"), options: [.atomic])
            if let txtData = txt.data(using: String.Encoding.utf8) {
                try txtData.write(to: reportsFolder.appendingPathComponent("professional_report_builder.txt"), options: [.atomic])
            }
            try Self.writeProfessionalReportPDF(export: export, text: txt, to: pdfURL)
            status = "PRO REPORT PDF EXPORTED"
        } catch {
            status = "PRO REPORT ERROR"
        }
    }

    private static func reportPDFFileName(horseName: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let safeName = safeFolderName(horseName).isEmpty ? "Horse" : safeFolderName(horseName)
        return "AVO_Report_\(safeName)_\(formatter.string(from: date)).pdf"
    }

    private static func writeProfessionalReportPDF(export: StableProfessionalReportExport, text: String, to url: URL) throws {
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 44
        let contentWidth = pageWidth - (margin * 2)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.gray
        ]

        let lines = text.components(separatedBy: "\n")
        try renderer.writePDF(to: url) { context in
            var pageNumber = 0
            var y: CGFloat = margin

            func startPage() {
                context.beginPage()
                pageNumber += 1
                y = margin
                "AVO PERFORMANCE HORSE".draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 28), withAttributes: titleAttributes)
                y += 34
                "Professional Clinical / Sport Report".draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 18), withAttributes: sectionAttributes)
                y += 20
                UIColor.black.setStroke()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: contentWidth, height: 1)).stroke()
                y += 18
            }

            func drawFooter() {
                let footer = "Generated by AVO Horse · Page \(pageNumber) · \(Self.shortDate(export.generatedAt))"
                footer.draw(in: CGRect(x: margin, y: pageHeight - 30, width: contentWidth, height: 12), withAttributes: footerAttributes)
            }

            startPage()
            for rawLine in lines {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                let isSection = !line.isEmpty && line == line.uppercased() && line.count < 40
                let attributes = isSection ? sectionAttributes : bodyAttributes
                let height: CGFloat = isSection ? 18 : 14

                if y + height > pageHeight - 46 {
                    drawFooter()
                    startPage()
                }

                if line.isEmpty {
                    y += 8
                } else {
                    let rect = CGRect(x: margin, y: y, width: contentWidth, height: height + 4)
                    line.draw(in: rect, withAttributes: attributes)
                    y += height
                }
            }
            drawFooter()
        }
    }

    private static func makeProfessionalReportText(_ export: StableProfessionalReportExport) -> String {
        var lines: [String] = []
        lines.append(export.title)
        lines.append("Generated: \(Self.shortDate(export.generatedAt))")
        lines.append("")
        lines.append("EXECUTIVE SUMMARY")
        lines.append(export.executiveSummary)
        lines.append("")
        lines.append("HORSE FILE")
        lines.append(contentsOf: export.horseBlock)
        if !export.performanceBlock.isEmpty { lines.append(""); lines.append("PERFORMANCE"); lines.append(contentsOf: export.performanceBlock) }
        if !export.sessionsBlock.isEmpty { lines.append(""); lines.append("SESSIONS"); lines.append(contentsOf: export.sessionsBlock) }
        if !export.veterinaryBlock.isEmpty { lines.append(""); lines.append("VETERINARY"); lines.append(contentsOf: export.veterinaryBlock) }
        if !export.aiBlock.isEmpty { lines.append(""); lines.append("AI ANALYSIS"); lines.append(contentsOf: export.aiBlock) }
        if !export.timelineBlock.isEmpty { lines.append(""); lines.append("TIMELINE"); lines.append(contentsOf: export.timelineBlock) }
        lines.append("")
        lines.append("RECOMMENDATIONS")
        lines.append(contentsOf: export.recommendations)
        return lines.joined(separator: "\n")
    }

    func exportAITrainingManifest() {
        guard let profile = selectedHorseProfile, let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE SELECTED"; return }
        let aiFolder = folder.appendingPathComponent("AITraining")
        try? FileManager.default.createDirectory(at: aiFolder, withIntermediateDirectories: true)
        let manifest = StableAITrainingManifest(horseID: profile.id, horseName: profile.name, generatedAt: Date(), linkedSessionIDs: selectedSessions.map { $0.id }, linkedVetRecordIDs: selectedVetRecords.map { $0.id }, objective: "Associate veterinary injuries with biomechanics, anatomy tracking, impact, IMU, GPS and fatigue patterns.", notes: "Commercial stable hub dataset: sessions + vet + AI + Colab auto pack when available.")

        let snapshot = makeCommercialStableSnapshot(profile: profile)
        do {
            try JSONEncoder.avo.encode(manifest).write(to: aiFolder.appendingPathComponent("linked_dataset.json"), options: [.atomic])
            try JSONEncoder.avo.encode(snapshot).write(to: aiFolder.appendingPathComponent("stable_connected_snapshot.json"), options: [.atomic])
            try makeStableSnapshotText(snapshot).write(to: aiFolder.appendingPathComponent("stable_connected_snapshot.txt"), atomically: true, encoding: .utf8)
            createStableColabQuickStart(in: aiFolder, horseName: profile.name)
            exportPoseAutoColabPackIfPossible(aiFolder: aiFolder)
            status = "AI DATASET + COLAB PACK READY"
        } catch {
            status = "AI EXPORT ERROR"
        }
    }

    func exportSessionReviewPackage(sessionID: UUID?, notes: String) {
        guard let profile = selectedHorseProfile, let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE SELECTED"; return }
        guard let session = selectedSessions.first(where: { $0.id == sessionID }) ?? selectedSessions.first else { status = "NO SESSION SELECTED"; return }
        let reviewFolder = folder.appendingPathComponent("SessionReviews")
        try? FileManager.default.createDirectory(at: reviewFolder, withIntermediateDirectories: true)
        let safe = Self.safeFolderName(session.title.isEmpty ? "session" : session.title)
        let stamp = Self.fileTimestamp(Date())
        let payload: [String: String] = [
            "horse": profile.name,
            "sessionID": session.id.uuidString,
            "sessionTitle": session.title,
            "sessionDate": Self.shortDate(session.date),
            "sessionRelativePath": session.sessionRelativePath,
            "videoRelativePath": session.videoRelativePath ?? "",
            "sensorsRelativePath": session.sensorsRelativePath ?? "",
            "aiSummaryRelativePath": session.aiSummaryRelativePath ?? "",
            "samples": "\(session.samplesCount)",
            "quality": "\(Int(session.avgQuality * 100))%",
            "risk": "\(Int(session.avgRisk * 100))%",
            "fatigue": "\(Int(session.avgFatigue * 100))%",
            "trainerNotes": notes
        ]
        let text = payload.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        do {
            try JSONEncoder.avo.encode(payload).write(to: reviewFolder.appendingPathComponent("review_\(safe)_\(stamp).json"), options: [.atomic])
            try text.write(to: reviewFolder.appendingPathComponent("review_\(safe)_\(stamp).txt"), atomically: true, encoding: .utf8)
            status = "SESSION REVIEW EXPORTED"
        } catch {
            status = "SESSION REVIEW ERROR"
        }
    }

    private func makeCommercialStableSnapshot(profile: StableHorseProfile) -> [String: String] {
        let avgQ = selectedSessions.map { $0.avgQuality }.average
        let avgR = selectedSessions.map { $0.avgRisk }.average
        let avgF = selectedSessions.map { $0.avgFatigue }.average
        return [
            "horse": profile.name,
            "horseID": profile.id.uuidString,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "sessions": "\(selectedSessions.count)",
            "vetRecords": "\(selectedVetRecords.count)",
            "avgQuality": "\(Int(avgQ * 100))%",
            "avgRisk": "\(Int(avgR * 100))%",
            "avgFatigue": "\(Int(avgF * 100))%",
            "aiReady": latestAIReport == nil ? "false" : "true",
            "lastSession": selectedSessions.first.map { Self.shortDate($0.date) } ?? "none",
            "lastVetRecord": selectedVetRecords.first.map { Self.shortDate($0.date) } ?? "none",
            "commercialStatus": avgR > 0.65 ? "ALERTA" : (avgR > 0.35 ? "VIGILAR" : "ESTABLE")
        ]
    }

    private func makeStableSnapshotText(_ snapshot: [String: String]) -> String {
        (["AVO PERFORMANCE HORSE - STABLE CONNECTED SNAPSHOT", ""] + snapshot.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }).joined(separator: "\n")
    }

    private func createStableColabQuickStart(in folder: URL, horseName: String) {
        let text = """
        AVO HORSE - COLAB AUTO TRAINING QUICK START

        1) Exporta desde REVIEW IA usando COLAB AUTO PACK para obtener solo imágenes positivas con puntos reales.
        2) Sube el ZIP a Google Drive/AVO_HORSE_DATASETS.
        3) Abre AVO_HORSE_AUTO_TRAIN_COLAB.ipynb si está incluido en el export.
        4) En Colab ejecuta Runtime -> Run all.
        5) Descarga best o exporta a CoreML/mlpackage y reimpórtalo en la app.

        Horse: \(horseName)
        Generado: \(Self.shortDate(Date()))
        """
        try? text.write(to: folder.appendingPathComponent("COLAB_QUICK_START.txt"), atomically: true, encoding: .utf8)
    }

    private func exportPoseAutoColabPackIfPossible(aiFolder: URL) {
        do {
            let manager = HorseDatasetManager()
            let report = try HorseDatasetExporter().exportPoseColabPack(from: manager)
            try JSONEncoder.avo.encode(report).write(to: aiFolder.appendingPathComponent("latest_pose_colab_pack_report.json"), options: [.atomic])
        } catch {
            let message = "COLAB AUTO PACK PENDING: revisa GOOD/HORSE + puntos anatómicos reales en Review IA. \(error.localizedDescription)"
            try? message.write(to: aiFolder.appendingPathComponent("latest_pose_colab_pack_status.txt"), atomically: true, encoding: .utf8)
        }
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: date)
    }

    func importHorseProfilePhoto(from sourceURL: URL) {
        guard var profile = selectedHorseProfile, let item = selectedItem(), let folder = horseFolder(item) else {
            status = "NO HORSE SELECTED"
            return
        }

        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }

        let horseFileFolder = folder.appendingPathComponent("HorseFile")
        try? FileManager.default.createDirectory(at: horseFileFolder, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destination = horseFileFolder.appendingPathComponent("profile_photo.\(ext)")

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            profile.photoRelativePath = "HorseFile/profile_photo.\(ext)"
            updateSelectedHorse(profile: profile)
            status = "HORSE PHOTO IMPORTED"
        } catch {
            status = "PHOTO IMPORT ERROR"
        }
    }

    func saveMetricCalibration(_ calibration: StableMetricCalibrationProfile) {
        guard let item = selectedItem(), let folder = horseFolder(item) else {
            status = "NO HORSE SELECTED"
            return
        }

        let calibrationFolder = folder.appendingPathComponent("Calibration")
        try? FileManager.default.createDirectory(at: calibrationFolder, withIntermediateDirectories: true)

        do {
            try JSONEncoder.avo.encode(calibration).write(to: calibrationFolder.appendingPathComponent("metric_calibration_profile.json"), options: [.atomic])
            let archiveName = "metric_calibration_\(Self.sessionFolderName(calibration.updatedAt)).json"
            try JSONEncoder.avo.encode(calibration).write(to: calibrationFolder.appendingPathComponent(archiveName), options: [.atomic])
            status = "CALIBRATION SAVED"
        } catch {
            status = "CALIBRATION SAVE ERROR"
        }
    }


    func exportGaitCycleReport(_ report: StableGaitCycleReport) {
        guard let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE SELECTED"; return }
        let reportsFolder = folder.appendingPathComponent("GaitAnalysis")
        try? FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        do {
            try JSONEncoder.avo.encode(report).write(to: reportsFolder.appendingPathComponent("gait_report.json"), options: [.atomic])
            try Self.makeGaitText(report).data(using: String.Encoding.utf8)?.write(to: reportsFolder.appendingPathComponent("gait_report.txt"), options: [.atomic])
            status = "GAIT REPORT EXPORTED"
        } catch {
            status = "GAIT EXPORT ERROR"
        }
    }

    func exportLamenessReport(_ report: StableLamenessReport) {
        guard let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE SELECTED"; return }
        let reportsFolder = folder.appendingPathComponent("LamenessMonitor")
        try? FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        do {
            try JSONEncoder.avo.encode(report).write(to: reportsFolder.appendingPathComponent("lameness_report.json"), options: [.atomic])
            try Self.makeLamenessText(report).data(using: String.Encoding.utf8)?.write(to: reportsFolder.appendingPathComponent("lameness_report.txt"), options: [.atomic])
            status = "LAMENESS REPORT EXPORTED"
        } catch {
            status = "LAMENESS EXPORT ERROR"
        }
    }

    func exportRehabPlanReport(_ report: StableRehabPlanReport) {
        guard let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE SELECTED"; return }
        let reportsFolder = folder.appendingPathComponent("RehabPlans")
        try? FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        do {
            try JSONEncoder.avo.encode(report).write(to: reportsFolder.appendingPathComponent("rehab_plan.json"), options: [.atomic])
            try Self.makeRehabText(report).data(using: String.Encoding.utf8)?.write(to: reportsFolder.appendingPathComponent("rehab_plan.txt"), options: [.atomic])
            status = "REHAB PLAN EXPORTED"
        } catch {
            status = "REHAB EXPORT ERROR"
        }
    }

    func exportLoadMonitorReport(_ report: StableLoadMonitorReport) {
        guard let item = selectedItem(), let folder = horseFolder(item) else { status = "NO HORSE SELECTED"; return }
        let reportsFolder = folder.appendingPathComponent("LoadMonitor")
        try? FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        do {
            try JSONEncoder.avo.encode(report).write(to: reportsFolder.appendingPathComponent("load_report.json"), options: [.atomic])
            try Self.makeLoadText(report).data(using: String.Encoding.utf8)?.write(to: reportsFolder.appendingPathComponent("load_report.txt"), options: [.atomic])
            status = "LOAD REPORT EXPORTED"
        } catch {
            status = "LOAD EXPORT ERROR"
        }
    }

    private static func makeLoadText(_ report: StableLoadMonitorReport) -> String {
        var lines: [String] = []
        lines.append("WORKLOAD & FATIGUE LOAD MONITOR")
        lines.append("Horse: \(report.horseName)")
        lines.append("Generated: \(Self.shortDate(report.generatedAt))")
        lines.append("Sessions analyzed: \(report.sessionsAnalyzed)")
        lines.append("Daily load: \(Int(report.dailyLoad * 100))%")
        lines.append("Weekly load: \(Int(report.weeklyLoad * 100))%")
        lines.append("Fatigue accumulated: \(Int(report.fatigueAccumulated * 100))%")
        lines.append("Impact accumulated: \(Int(report.impactAccumulated * 100))%")
        lines.append("Overload risk: \(Int(report.overloadRisk * 100))%")
        lines.append("Recommended rest: \(report.recommendedRestHours) h")
        lines.append("Alert: \(report.alertLevel)")
        lines.append("")
        lines.append("SUMMARY")
        lines.append(report.summary)
        lines.append("")
        lines.append("RECOMMENDATIONS")
        lines.append(contentsOf: report.recommendations)
        return lines.joined(separator: "\n")
    }

    private static func makeGaitText(_ report: StableGaitCycleReport) -> String {
        var lines: [String] = []
        lines.append("GAIT CYCLE ANALYZER")
        lines.append("Horse: \(report.horseName)")
        lines.append("Generated: \(Self.shortDate(report.generatedAt))")
        lines.append("Gait: \(report.gaitType)")
        lines.append("Cycles: \(report.cyclesDetected)")
        lines.append("Cadence: " + String(format: "%.1f", report.cadence))
        lines.append("Stride: " + String(format: "%.2f", report.estimatedStrideMeters) + " m")
        lines.append("Symmetry: \(Int(report.symmetryScore * 100))%")
        lines.append("Regularity: \(Int(report.regularityScore * 100))%")
        lines.append("Risk: \(Int(report.irregularityRisk * 100))%")
        lines.append("")
        lines.append(report.summary)
        lines.append("")
        lines.append("RECOMMENDATIONS")
        lines.append(contentsOf: report.recommendations)
        return lines.joined(separator: "\n")
    }

    private static func makeLamenessText(_ report: StableLamenessReport) -> String {
        var lines: [String] = []
        lines.append("LAMENESS EARLY WARNING")
        lines.append("Horse: \(report.horseName)")
        lines.append("Generated: \(Self.shortDate(report.generatedAt))")
        lines.append("Alert: \(report.alertLevel)")
        lines.append("Suspected zone: \(report.suspectedZone)")
        lines.append("Risk: \(Int(report.lamenessRisk * 100))%")
        lines.append("Baseline quality: \(Int(report.baselineQuality * 100))%")
        lines.append("Current quality: \(Int(report.currentQuality * 100))%")
        lines.append("")
        lines.append("REASONS")
        lines.append(contentsOf: report.reasons)
        lines.append("")
        lines.append("RECOMMENDATIONS")
        lines.append(contentsOf: report.recommendations)
        return lines.joined(separator: "\n")
    }

    private static func makeRehabText(_ report: StableRehabPlanReport) -> String {
        var lines: [String] = []
        lines.append("REHABILITATION / RETURN TO WORK PLAN")
        lines.append("Horse: \(report.horseName)")
        lines.append("Generated: \(Self.shortDate(report.generatedAt))")
        lines.append("Injury focus: \(report.injuryFocus)")
        lines.append("Alert level: \(report.alertLevel)")
        lines.append("Current risk: \(Int(report.currentRisk * 100))%")
        lines.append("")
        lines.append(report.summary)
        lines.append("")
        lines.append("PHASES")
        for phase in report.phases {
            lines.append("Week \(phase.week): \(phase.title) - \(phase.workload)")
            lines.append("  Objective: \(phase.objective)")
            lines.append("  Limits: impact \(Int(phase.maxImpact * 100))%, fatigue \(Int(phase.maxFatigue * 100))%, asymmetry \(Int(phase.maxAsymmetry * 100))%")
        }
        lines.append("")
        lines.append("STOP RULES")
        lines.append(contentsOf: report.stopRules)
        let clearanceText = report.veterinaryClearanceRequired ? "YES" : "NO"
        lines.append("Veterinary clearance required: " + clearanceText)
        return lines.joined(separator: "\n")
    }

    func openRootFolder() {
        guard let root = rootFolderURL else { return }
        UIApplication.shared.open(root)
    }

    private func saveAppSettings() {
        guard let root = rootFolderURL else { return }
        let settings = StableAppSettings(rootFolderPath: root.path, lastUpdated: Date(), version: "AVO Horse Playground Registry V1")
        if let url = rootFolderURL?.appendingPathComponent("GlobalSettings/app_settings.json") {
            try? JSONEncoder.avo.encode(settings).write(to: url, options: [.atomic])
        }
    }

    private func selectedItem() -> StableHorseListItem? {
        guard let id = selectedHorseID else { return nil }
        return horsesIndex.first(where: { $0.id == id })
    }

    private func indexURL() -> URL? { rootFolderURL?.appendingPathComponent("index_horses.json") }

    private func horseFolder(_ item: StableHorseListItem) -> URL? {
        rootFolderURL?.appendingPathComponent("Horses").appendingPathComponent(item.folderName)
    }

    private func createHorseFolders(folderName: String) {
        guard let root = rootFolderURL else { return }
        let horse = root.appendingPathComponent("Horses").appendingPathComponent(folderName)
        let folders = [horse, horse.appendingPathComponent("HorseFile"), horse.appendingPathComponent("Sessions"), horse.appendingPathComponent("VetRecords"), horse.appendingPathComponent("AITraining"), horse.appendingPathComponent("Media"), horse.appendingPathComponent("Reports"), horse.appendingPathComponent("Calibration"), horse.appendingPathComponent("GaitAnalysis"), horse.appendingPathComponent("LamenessMonitor"), horse.appendingPathComponent("RehabPlans"), horse.appendingPathComponent("LoadMonitor")]
        for folder in folders { try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        saveCodable([StableSessionListItem](), to: horse.appendingPathComponent("sessions_index.json"))
        saveCodable([StableVetRecordListItem](), to: horse.appendingPathComponent("vet_index.json"))
    }

    private func saveProfile(_ profile: StableHorseProfile, folderName: String) {
        guard let root = rootFolderURL else { return }
        let url = root.appendingPathComponent("Horses").appendingPathComponent(folderName).appendingPathComponent("profile.json")
        try? JSONEncoder.avo.encode(profile).write(to: url, options: [.atomic])
    }

    private func updateIndexAfterSession(date: Date) {
        guard let id = selectedHorseID, let idx = horsesIndex.firstIndex(where: { $0.id == id }) else { return }
        horsesIndex[idx].lastSessionDate = date
        saveIndex()
    }

    private func updateIndexAfterVet(date: Date, alert: String) {
        guard let id = selectedHorseID, let idx = horsesIndex.firstIndex(where: { $0.id == id }) else { return }
        horsesIndex[idx].lastVetRecordDate = date
        horsesIndex[idx].alertSummary = alert.isEmpty ? "VET RECORD" : alert
        saveIndex()
    }

    private func saveCodable<T: Encodable>(_ value: T, to url: URL) {
        try? JSONEncoder.avo.encode(value).write(to: url, options: [.atomic])
    }

    private func loadCodable<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? JSONDecoder.avo.decode(T.self, from: Data(contentsOf: url))
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    static func safeFolderName(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let mapped = text.replacingOccurrences(of: " ", with: "_").unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(mapped).prefix(40).description
    }

    static func sessionFolderName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }
}

extension JSONEncoder {
    static var avo: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var avo: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

private extension Array where Element == Double {
    var average: Double { isEmpty ? 0.0 : reduce(0, +) / Double(count) }
}

// MARK: - UI

struct AVOStableRegistryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var stableStore: AVOStableStore
    var liveSamples: [SessionSample]
    var fallbackHorseName: String
    var riderName: String
    var latestLiDARSample: AVOLiDARDepthSample?
    var liveLiDARPoints: [AVOLiDARPoint2D]
    var fusedLiDARPoints3D: [AVOLiDARPoint3D] = []
    var lidarFusionReport: AVOLiDARFusionReport? = nil

    @State private var searchText = ""
    @State private var newHorseName = ""
    @State private var newBirthDate = Calendar.current.date(byAdding: .year, value: -4, to: Date()) ?? Date()
    @State private var newSex: StableHorseSex = .unknown
    @State private var newBreed = ""
    @State private var newMode = ""
    @State private var newNotes = ""
    @State private var vetTitle = "Exploración veterinaria"
    @State private var vetName = ""
    @State private var vetDiagnosis = ""
    @State private var vetZone = ""
    @State private var vetSeverity: StableInjurySeverity = .mild
    @State private var vetTreatment = ""
    @State private var vetObservations = ""
    @State private var showPerformanceDashboard = false
    @State private var showSessionsReview = false
    @State private var showVeterinaryHistory = false
    @State private var showAITrainingCenter = false
    @State private var showBiomechTimeline = false
    @State private var showCompareSessions = false
    @State private var showReportBuilder = false
    @State private var showHorseFileEditor = false
    @State private var showCalibrationCenter = false
    @State private var showGaitAnalyzer = false
    @State private var showLamenessMonitor = false
    @State private var showRehabPlanner = false
    @State private var showLoadMonitor = false

    var filteredHorses: [StableHorseListItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return stableStore.horsesIndex }
        return stableStore.horsesIndex.filter { item in
            item.name.lowercased().contains(q) || item.breed.lowercased().contains(q) || item.competitionMode.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geo in
                HStack(spacing: 12) {
                    referenceCentralPanel
                        .frame(
                            width: geo.size.width - max(270, geo.size.width * 0.245) - 34,
                            height: geo.size.height - 86,
                            alignment: .top
                        )

                    referenceRightStack
                        .frame(
                            width: max(270, geo.size.width * 0.245),
                            height: geo.size.height - 86,
                            alignment: .top
                        )
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 80)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .fullScreenCover(isPresented: $showPerformanceDashboard) {
            if let profile = stableStore.selectedHorseProfile {
                AVOHorsePerformanceDashboardPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    aiReport: stableStore.latestAIReport,
                    onRunAI: { stableStore.runFullClinicalBiomechPipeline() },
                    onExportDashboard: { stableStore.exportPerformanceDashboardReport() },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showSessionsReview) {
            if let profile = stableStore.selectedHorseProfile {
                AVOSessionsReviewPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    onClose: { showSessionsReview = false },
                    onSaveLiveSession: { stableStore.saveLiveSession(samples: liveSamples, horseNameFallback: fallbackHorseName, riderName: riderName) },
                    onExportSessionReview: { sessionID, notes in stableStore.exportSessionReviewPackage(sessionID: sessionID, notes: notes) },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showVeterinaryHistory) {
            if let profile = stableStore.selectedHorseProfile {
                AVOVeterinaryHistoryPage(
                    profile: profile,
                    records: stableStore.selectedVetRecords,
                    sessions: stableStore.selectedSessions,
                    onClose: { showVeterinaryHistory = false },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showAITrainingCenter) {
            if let profile = stableStore.selectedHorseProfile {
                AVOAITrainingCenterPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    aiReport: stableStore.latestAIReport,
                    onClose: { showAITrainingCenter = false },
                    onBuildDataset: { stableStore.exportAITrainingManifest() },
                    onRunAI: { stableStore.runFullClinicalBiomechPipeline() },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showBiomechTimeline) {
            if let profile = stableStore.selectedHorseProfile {
                AVOBiomechTimelinePage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    aiReport: stableStore.latestAIReport,
                    onClose: { showBiomechTimeline = false },
                    onRunAI: { stableStore.runFullClinicalBiomechPipeline() },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showCompareSessions) {
            if let profile = stableStore.selectedHorseProfile {
                AVOCompareSessionsPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    onClose: { showCompareSessions = false },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showReportBuilder) {
            if let profile = stableStore.selectedHorseProfile {
                AVOReportBuilderPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    aiReport: stableStore.latestAIReport,
                    onClose: { showReportBuilder = false },
                    onRunAI: { stableStore.runFullClinicalBiomechPipeline() },
                    onExportReport: { performance, sessions, veterinary, timeline, ai, medical in
                        stableStore.exportProfessionalReport(
                            includePerformance: performance,
                            includeSessions: sessions,
                            includeVeterinary: veterinary,
                            includeTimeline: timeline,
                            includeAI: ai,
                            includeMedicalImages: medical
                        )
                    },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showHorseFileEditor) {
            if let profile = stableStore.selectedHorseProfile {
                AVOHorseFileEditorPage(
                    profile: profile,
                    onClose: { showHorseFileEditor = false },
                    onSave: { updated in
                        stableStore.updateSelectedHorse(profile: updated)
                    },
                    onImportPhoto: { url in
                        stableStore.importHorseProfilePhoto(from: url)
                    },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showCalibrationCenter) {
            if let profile = stableStore.selectedHorseProfile {
                AVOMetricCalibrationCenterPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    latestLiDARSample: latestLiDARSample,
                    liveLiDARPoints: liveLiDARPoints,
                    fusedLiDARPoints3D: fusedLiDARPoints3D,
                    lidarFusionReport: lidarFusionReport,
                    onSave: { calibration in
                        stableStore.saveMetricCalibration(calibration)
                    },
                    onOpenFolder: { stableStore.openRootFolder() },
                    onClose: { showCalibrationCenter = false }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showGaitAnalyzer) {
            if let profile = stableStore.selectedHorseProfile {
                AVOGaitCycleAnalyzerPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    onClose: { showGaitAnalyzer = false },
                    onExport: { report in stableStore.exportGaitCycleReport(report) },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
        .fullScreenCover(isPresented: $showLamenessMonitor) {
            if let profile = stableStore.selectedHorseProfile {
                AVOLamenessMonitorPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    aiReport: stableStore.latestAIReport,
                    onClose: { showLamenessMonitor = false },
                    onExport: { report in stableStore.exportLamenessReport(report) },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }

        .fullScreenCover(isPresented: $showRehabPlanner) {
            if let profile = stableStore.selectedHorseProfile {
                AVORehabPlannerPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    aiReport: stableStore.latestAIReport,
                    onClose: { showRehabPlanner = false },
                    onExport: { report in stableStore.exportRehabPlanReport(report) },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }

        .fullScreenCover(isPresented: $showLoadMonitor) {
            if let profile = stableStore.selectedHorseProfile {
                AVOLoadMonitorPage(
                    profile: profile,
                    sessions: stableStore.selectedSessions,
                    vetRecords: stableStore.selectedVetRecords,
                    aiReport: stableStore.latestAIReport,
                    onClose: { showLoadMonitor = false },
                    onExport: { report in stableStore.exportLoadMonitorReport(report) },
                    onOpenFolder: { stableStore.openRootFolder() }
                )
            } else { Color.black.ignoresSafeArea() }
        }
    }

    var referenceStableSidebar: some View {
        VStack(spacing: 0) {
            stableSideButton(icon: "house.fill", title: "HOME", active: false) { }
            stableSideButton(icon: "hare.fill", title: "HORSES", active: true) { }
            stableSideButton(icon: "camera.fill", title: "SESSIONS", active: false) { showSessionsReview = true }
            stableSideButton(icon: "waveform.path.ecg", title: "BIOMECH", active: false) { showGaitAnalyzer = true }
            stableSideButton(icon: "cross.case.fill", title: "VET RECORDS", active: false) { showVeterinaryHistory = true }
            stableSideButton(icon: "doc.richtext.fill", title: "REPORTS", active: false) { showReportBuilder = true }
            stableSideButton(icon: "brain.head.profile", title: "AI ENGINE", active: false) { showAITrainingCenter = true }
            stableSideButton(icon: "gearshape.fill", title: "SETTINGS", active: false) { stableStore.openRootFolder() }
            Spacer(minLength: 6)
        }
        .padding(10)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.72), Color(red: 0.01, green: 0.06, blue: 0.07).opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.cyan.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func stableSideButton(icon: String, title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .black))
                    .foregroundColor(active ? .green : .white.opacity(0.85))
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(active ? .green : .white.opacity(0.72))
                Spacer()
                if active {
                    Text("✥")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 54)
            .background(active ? Color.green.opacity(0.18) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Color.green.opacity(0.55) : Color.clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    var referenceCentralPanel: some View {
        VStack(spacing: 10) {
            referenceHorseFile
                .frame(height: 260)

            HStack(spacing: 12) {
                referenceSessions
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                referenceVetRecords
                    .frame(width: 300)
                    .frame(maxHeight: .infinity)
            }

            referenceAIEngine
                .frame(height: 88)
        }
    }

    var referenceHorseFile: some View {
        ProBox("HORSE PROFESSIONAL FILE") {
            if let profile = stableStore.selectedHorseProfile {
                HStack(spacing: 20) {
                    profilePhotoBox(profile)
                        .frame(width: 210, height: 160)

                    VStack(alignment: .leading, spacing: 14) {
                        referenceInfoRow("AGE", "\(profile.ageYears) years")
                        referenceInfoRow("SEX", profile.sex.rawValue)
                        referenceInfoRow("BREED", profile.breed.isEmpty ? "--" : profile.breed)
                        referenceInfoRow("RACE", profile.breed.isEmpty ? "--" : profile.breed)
                        referenceInfoRow("MODALITY", profile.competitionMode.isEmpty ? "--" : profile.competitionMode)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 54, weight: .black))
                        .foregroundColor(.cyan.opacity(0.55))
                    Text("CREATE OR SELECT A HORSE")
                        .foregroundColor(.orange)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                    TextField("New horse name", text: $newHorseName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                    Button {
                        stableStore.createHorse(name: newHorseName, birthDate: newBirthDate, sex: newSex, breed: newBreed, competitionMode: newMode, notes: newNotes)
                        newHorseName = ""
                    } label: { BottomButton("CREATE HORSE", .green) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func profilePhotoBox(_ profile: StableHorseProfile) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.50))
            if let image = selectedHorseImage(profile) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                LinearGradient(colors: [Color(red: 0.18, green: 0.12, blue: 0.05), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Image(systemName: "hare.fill")
                    .font(.system(size: 72, weight: .black))
                    .foregroundColor(.white.opacity(0.34))
                Text("PHOTO")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.75))
                    .offset(y: 60)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }

    private func selectedHorseImage(_ profile: StableHorseProfile) -> UIImage? {
        guard let rel = profile.photoRelativePath,
              let item = stableStore.horsesIndex.first(where: { $0.id == profile.id }),
              let folder = stableStore.rootFolderURL?.appendingPathComponent("Horses").appendingPathComponent(item.folderName) else { return nil }
        return UIImage(contentsOfFile: folder.appendingPathComponent(rel).path)
    }

    private func referenceInfoRow(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.72))
                .frame(width: 120, alignment: .leading)
            Text(right)
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
        }
    }

    var referenceSessions: some View {
        ProBox("BIOMECH SESSIONS (\(stableStore.selectedSessions.count))") {
            VStack(spacing: 0) {
                if stableStore.selectedSessions.isEmpty {
                    Text("NO BIOMECH SESSIONS YET")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(stableStore.selectedSessions.prefix(8)) { session in
                                referenceSessionRow(session)
                                Divider().background(Color.cyan.opacity(0.16))
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        Button { showSessionsReview = true } label: { BottomButton("VIEW ALL", .cyan) }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(10)
        }
    }

    private func referenceSessionRow(_ session: StableSessionListItem) -> some View {
        HStack(spacing: 16) {
            Text(shortDateOnly(session.date))
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 95, alignment: .leading)
            Text(shortTimeOnly(session.date))
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 70, alignment: .leading)
            Text(session.title)
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.86))
            Spacer()
            Text("\(Int(session.avgRisk * 100))")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(session.avgRisk > 0.50 ? .red : .green)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.22))
    }

    var referenceRightStack: some View {
        VStack(spacing: 10) {
            referenceQuickActions
                .frame(maxHeight: .infinity)
        }
    }

    var referenceQuickActions: some View {
        ProBox("QUICK ACTIONS") {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: { BottomButton("CLOSE", .red) }
                }
                Button { showHorseFileEditor = true } label: { referenceActionButton("HORSE FILE EDITOR", .green) }
                Button { showCalibrationCenter = true } label: { referenceActionButton("CALIBRATION 3D", .cyan) }
                Button { showGaitAnalyzer = true } label: { referenceActionButton("GAIT ANALYZER", .orange) }
                Button { showLamenessMonitor = true } label: { referenceActionButton("LAMENESS MONITOR", .red) }
                Button { showRehabPlanner = true } label: { referenceActionButton("REHAB PLANNER", .purple) }
                Button { showLoadMonitor = true } label: { referenceActionButton("LOAD MONITOR", .orange) }
                Button { showPerformanceDashboard = true } label: { referenceActionButton("PERFORMANCE", .blue) }
                Button { showSessionsReview = true } label: { referenceActionButton("SESSIONS REVIEW", .cyan) }
                Button { showVeterinaryHistory = true } label: { referenceActionButton("VET HISTORY", .red) }
                Button { showBiomechTimeline = true } label: { referenceActionButton("BIOMECH TIMELINE", .orange) }
                Button { showCompareSessions = true } label: { referenceActionButton("COMPARE SESSIONS", .yellow) }
                Button { showReportBuilder = true } label: { referenceActionButton("REPORT BUILDER", .green) }
                Button { showAITrainingCenter = true } label: { referenceActionButton("AI TRAINING", .purple) }
                Button { stableStore.saveLiveSession(samples: liveSamples, horseNameFallback: fallbackHorseName, riderName: riderName, lidarSamples: []) } label: { referenceActionButton("SAVE LIVE SESSION", .green) }
                Button { stableStore.openRootFolder() } label: { referenceActionButton("OPEN FOLDER", .cyan) }
                Spacer(minLength: 0)
            }
            .padding(10)
        }
    }

    private func referenceActionButton(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: color.opacity(0.35), radius: 8, x: 0, y: 0)
    }

    var referenceVetRecords: some View {
        ProBox("VET / INJURY RECORDS (\(stableStore.selectedVetRecords.count))") {
            VStack(alignment: .leading, spacing: 9) {
                if let record = stableStore.selectedVetRecords.first {
                    Text(record.title)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text(Self.shortDate(record.date))
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    Text("• " + record.severity.rawValue)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(record.severity == .critical || record.severity == .severe ? .orange : .green)
                    Text(record.diagnosis.isEmpty ? "NO DIAGNOSIS" : record.diagnosis.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showVeterinaryHistory = true } label: { BottomButton("VIEW ALL", .cyan) }
                    }
                } else {
                    Text("NO VET RECORDS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Button {
                        stableStore.createVetRecord(title: vetTitle, vetName: vetName, diagnosis: vetDiagnosis, injuryZone: vetZone, severity: vetSeverity, treatment: vetTreatment, observations: vetObservations)
                    } label: { BottomButton("ADD FIRST RECORD", .red) }
                }
            }
            .padding(12)
        }
    }

    var referenceAIEngine: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.cyan.opacity(0.85))
                    .frame(width: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI BIOMECH ENGINE")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text(stableStore.latestAIReport?.summary ?? "Motor IA activo. Analizando patrones biomecánicos, riesgo, fatiga y simetría.")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(1)
                }
                Spacer()
                Text(stableStore.latestAIReport == nil ? "READY" : "AI READY")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(14)
        }
        .background(LinearGradient(colors: [Color.black.opacity(0.62), Color.cyan.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func shortDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f.string(from: date)
    }

    private func shortTimeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

struct HorsePerformanceDashboardPanel: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?

    private var avgQuality: Double { sessions.map { $0.avgQuality }.average }
    private var avgRisk: Double { sessions.map { $0.avgRisk }.average }
    private var avgFatigue: Double { sessions.map { $0.avgFatigue }.average }
    private var severeCount: Int { vetRecords.filter { $0.severity == .severe || $0.severity == .critical }.count }

    private var stateText: String {
        if let report = aiReport, report.globalRisk >= 0.70 { return "ALERTA IA" }
        if avgRisk >= 0.70 || severeCount > 0 { return "ALERTA" }
        if avgRisk >= 0.40 || avgFatigue >= 0.60 { return "VIGILAR" }
        return "ESTABLE"
    }

    private var stateColor: Color {
        stateText.contains("ALERTA") ? .red : (stateText == "VIGILAR" ? .orange : .green)
    }

    private var mainRecommendation: String {
        if let report = aiReport { return report.recommendations.first?.text ?? report.summary }
        if severeCount > 0 { return "Revisar registros veterinarios graves antes de aumentar carga." }
        if sessions.isEmpty { return "Crear sesiones biomecánicas para construir línea base del caballo." }
        if avgQuality < 0.45 { return "Mejorar encuadre y calidad de tracking antes de sacar conclusiones." }
        if avgFatigue > 0.60 { return "Controlar fatiga y repetir medición tras descanso." }
        return "Continuar generando histórico y comparar evolución por fecha."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("HORSE PERFORMANCE DASHBOARD")
                    .foregroundColor(.cyan)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                Spacer()
                Text(stateText)
                    .foregroundColor(stateColor)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
            }

            HStack(spacing: 8) {
                MiniText(name: "SESSIONS", value: "\(sessions.count)", color: .cyan)
                MiniText(name: "VET", value: "\(vetRecords.count)", color: .red)
                MiniText(name: "QUALITY", value: "\(Int(avgQuality * 100))%", color: avgQuality < 0.45 ? .orange : .green)
                MiniText(name: "RISK", value: "\(Int((aiReport?.globalRisk ?? avgRisk) * 100))%", color: stateColor)
                MiniText(name: "FATIGUE", value: "\(Int(avgFatigue * 100))%", color: avgFatigue > 0.60 ? .orange : .green)
            }

            HStack(spacing: 8) {
                StableMetricBar(title: "RISK", value: aiReport?.globalRisk ?? avgRisk, color: stateColor)
                StableMetricBar(title: "QUALITY", value: avgQuality, color: avgQuality < 0.45 ? .orange : .green)
                StableMetricBar(title: "FATIGUE", value: avgFatigue, color: avgFatigue > 0.60 ? .orange : .green)
            }

            Text(mainRecommendation)
                .foregroundColor(.white)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .lineLimit(2)

            HStack(spacing: 8) {
                Text("LAST SESSION: \(sessions.first.map { AVOStableRegistryView.shortDate($0.date) } ?? "--")")
                    .foregroundColor(.gray)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Spacer()
                Text("LAST VET: \(vetRecords.first.map { AVOStableRegistryView.shortDate($0.date) } ?? "--")")
                    .foregroundColor(.gray)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.24))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


fileprivate func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.string(from: date)
}
// MARK: - AVO Cloud / Multi-Stable Future Layer

enum AVOStableUserRole: String, Codable, CaseIterable, Identifiable {
    case owner = "Propietario"
    case trainer = "Entrenador"
    case vet = "Veterinario"
    case rider = "Jinete"
    case admin = "Administrador"
    case viewer = "Solo lectura"

    var id: String { rawValue }
}

struct AVOStableOrganization: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var type: String
    var createdAt: Date
    var notes: String
}

struct AVOStableUserProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var displayName: String
    var role: AVOStableUserRole
    var email: String
    var phone: String
    var canViewVetRecords: Bool
    var canEditVetRecords: Bool
    var canRunAITraining: Bool
    var canExportData: Bool
}

struct AVOStablePermissionPolicy: Codable, Hashable {
    var organizationID: UUID
    var createdAt: Date
    var policyVersion: String
    var notes: String
    var users: [AVOStableUserProfile]
}

struct AVOStableCloudSyncManifest: Codable, Hashable {
    var id: UUID
    var generatedAt: Date
    var appVersion: String
    var mode: String
    var rootFolder: String
    var horseCount: Int
    var organizationsCount: Int
    var usersCount: Int
    var exportReady: Bool
    var notes: String
}

extension AVOStableStore {
    func prepareCloudMultiStableLayer() {
        guard let root = rootFolderURL else {
            status = "NO ROOT FOLDER"
            return
        }

        let cloudRoot = root.appendingPathComponent("Cloud_MultiStable")
        let folders = [
            cloudRoot,
            cloudRoot.appendingPathComponent("Organizations"),
            cloudRoot.appendingPathComponent("Users"),
            cloudRoot.appendingPathComponent("Permissions"),
            cloudRoot.appendingPathComponent("ClinicAccess"),
            cloudRoot.appendingPathComponent("OwnerAccess"),
            cloudRoot.appendingPathComponent("TrainerAccess"),
            cloudRoot.appendingPathComponent("SyncQueue"),
            cloudRoot.appendingPathComponent("ConflictResolver"),
            cloudRoot.appendingPathComponent("Backups"),
            cloudRoot.appendingPathComponent("ModelVersions")
        ]

        for folder in folders {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let orgURL = cloudRoot.appendingPathComponent("Organizations/default_organization.json")
        let usersURL = cloudRoot.appendingPathComponent("Users/default_users.json")
        let policyURL = cloudRoot.appendingPathComponent("Permissions/default_permissions.json")
        let manifestURL = cloudRoot.appendingPathComponent("cloud_sync_manifest.json")

        let org = AVOStableOrganization(
            id: UUID(),
            name: "AVO Stable",
            type: "Local stable / future cloud organization",
            createdAt: Date(),
            notes: "Base preparada para varias cuadras, clínicas veterinarias, propietarios, entrenadores y sincronización futura."
        )

        let users = [
            AVOStableUserProfile(id: UUID(), displayName: "Administrador AVO", role: .admin, email: "", phone: "", canViewVetRecords: true, canEditVetRecords: true, canRunAITraining: true, canExportData: true),
            AVOStableUserProfile(id: UUID(), displayName: "Veterinario", role: .vet, email: "", phone: "", canViewVetRecords: true, canEditVetRecords: true, canRunAITraining: false, canExportData: true),
            AVOStableUserProfile(id: UUID(), displayName: "Entrenador", role: .trainer, email: "", phone: "", canViewVetRecords: false, canEditVetRecords: false, canRunAITraining: true, canExportData: false),
            AVOStableUserProfile(id: UUID(), displayName: "Propietario", role: .owner, email: "", phone: "", canViewVetRecords: true, canEditVetRecords: false, canRunAITraining: false, canExportData: false)
        ]

        let policy = AVOStablePermissionPolicy(
            organizationID: org.id,
            createdAt: Date(),
            policyVersion: "local-v1",
            notes: "Permisos locales preparados para pasar a nube sin cambiar la estructura de datos actual.",
            users: users
        )

        let manifest = AVOStableCloudSyncManifest(
            id: UUID(),
            generatedAt: Date(),
            appVersion: "AVO Horse Playground",
            mode: "LOCAL_FIRST_FUTURE_CLOUD",
            rootFolder: root.path,
            horseCount: horsesIndex.count,
            organizationsCount: 1,
            usersCount: users.count,
            exportReady: true,
            notes: "Checkpoint preparado para sincronización futura: no modifica Auto Pose, cámara, detector ni sesiones existentes."
        )

        do {
            try JSONEncoder.avo.encode(org).write(to: orgURL, options: [.atomic])
            try JSONEncoder.avo.encode(users).write(to: usersURL, options: [.atomic])
            try JSONEncoder.avo.encode(policy).write(to: policyURL, options: [.atomic])
            try JSONEncoder.avo.encode(manifest).write(to: manifestURL, options: [.atomic])
            status = "CLOUD LAYER READY"
        } catch {
            status = "CLOUD LAYER ERROR"
        }
    }

    func createStableBackupManifest() {
        guard let root = rootFolderURL else {
            status = "NO ROOT FOLDER"
            return
        }

        let backupFolder = root
            .appendingPathComponent("Cloud_MultiStable")
            .appendingPathComponent("Backups")
            .appendingPathComponent(AVOStableStore.sessionFolderName(Date()))

        try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        let manifest = AVOStableCloudSyncManifest(
            id: UUID(),
            generatedAt: Date(),
            appVersion: "AVO Horse Playground",
            mode: "LOCAL_BACKUP_MANIFEST",
            rootFolder: root.path,
            horseCount: horsesIndex.count,
            organizationsCount: 1,
            usersCount: 4,
            exportReady: true,
            notes: "Manifiesto de backup local. Los vídeos e imágenes quedan en sus carpetas visibles; este archivo prepara sincronización futura."
        )

        do {
            try JSONEncoder.avo.encode(manifest).write(to: backupFolder.appendingPathComponent("backup_manifest.json"), options: [.atomic])
            try JSONEncoder.avo.encode(horsesIndex).write(to: backupFolder.appendingPathComponent("index_horses_snapshot.json"), options: [.atomic])
            status = "BACKUP MANIFEST READY"
        } catch {
            status = "BACKUP MANIFEST ERROR"
        }
    }
}

struct AVOCloudMultiStablePanel: View {
    @ObservedObject var stableStore: AVOStableStore

    var body: some View {
        ProBox("CLOUD / MULTI-STABLE") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Local-first preparado para nube, clínicas, propietarios, entrenadores y varias cuadras.")
                    .foregroundColor(.gray)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .lineLimit(3)

                MiniText(name: "MODE", value: "LOCAL FIRST", color: .cyan)
                MiniText(name: "DATA", value: "VISIBLE FOLDERS", color: .green)
                MiniText(name: "SAFE", value: "NO CAMERA / AUTO POSE CHANGES", color: .orange)

                Button {
                    stableStore.prepareCloudMultiStableLayer()
                } label: {
                    BottomButton("PREPARE CLOUD LAYER", .purple)
                }

                Button {
                    stableStore.createStableBackupManifest()
                } label: {
                    BottomButton("CREATE BACKUP MANIFEST", .cyan)
                }
            }
        }
    }
}


// MARK: - Full Page Performance Dashboard

struct AVOHorsePerformanceDashboardPage: View {
    @Environment(\.dismiss) private var dismiss

    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?
    var onRunAI: () -> Void
    var onExportDashboard: () -> Void
    var onOpenFolder: () -> Void

    private var avgQuality: Double { sessions.map { $0.avgQuality }.average }
    private var avgRisk: Double { sessions.map { $0.avgRisk }.average }
    private var avgFatigue: Double { sessions.map { $0.avgFatigue }.average }
    private var severeCount: Int { vetRecords.filter { $0.severity == .severe || $0.severity == .critical }.count }
    private var effectiveRisk: Double { aiReport?.globalRisk ?? avgRisk }

    private var stateText: String {
        if effectiveRisk >= 0.70 || severeCount > 0 { return "ALERTA" }
        if effectiveRisk >= 0.40 || avgFatigue >= 0.60 { return "VIGILAR" }
        return "ESTABLE"
    }

    private var stateColor: Color {
        stateText == "ALERTA" ? .red : (stateText == "VIGILAR" ? .orange : .green)
    }

    private var recommendation: String {
        if let report = aiReport { return report.recommendations.first?.text ?? report.summary }
        if severeCount > 0 { return "Revisar registros veterinarios graves antes de aumentar carga." }
        if sessions.isEmpty { return "Crear sesiones biomecánicas para construir línea base del caballo." }
        if avgQuality < 0.45 { return "Mejorar encuadre y calidad de tracking antes de sacar conclusiones." }
        if avgFatigue > 0.60 { return "Controlar fatiga y repetir medición tras descanso." }
        return "Continuar generando histórico y comparar evolución por fecha."
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                header

                HStack(spacing: 12) {
                    mainStatusPanel
                        .frame(width: 330)

                    timelinePanel
                        .frame(maxWidth: .infinity)

                    aiRiskPanel
                        .frame(width: 340)
                }

                HStack(spacing: 12) {
                    sessionsPanel
                    vetPanel
                    recommendationsPanel
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("HORSE PERFORMANCE DASHBOARD")
                    .foregroundColor(.cyan)
                    .font(.system(size: 18, weight: .black, design: .monospaced))

                Text(profile.name.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 30, weight: .black, design: .monospaced))

                Text("\(profile.ageYears) YEARS · \(profile.sex.rawValue.uppercased()) · \(profile.breed.uppercased()) · \(profile.competitionMode.uppercased())")
                    .foregroundColor(.gray)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            Spacer()

            Text(stateText)
                .foregroundColor(stateColor)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(stateColor.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button { onRunAI() } label: { BottomButton("RUN AI", .orange) }
            Button { onExportDashboard() } label: { BottomButton("EXPORT", .blue) }
            Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
            Button { dismiss() } label: { BottomButton("CLOSE", .red) }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var mainStatusPanel: some View {
        AVOPageBox(title: "CURRENT STATUS") {
            VStack(alignment: .leading, spacing: 12) {
                AVOPageMetricBar(title: "GLOBAL RISK", value: effectiveRisk, color: stateColor)
                AVOPageMetricBar(title: "TRACKING QUALITY", value: avgQuality, color: avgQuality < 0.45 ? .orange : .green)
                AVOPageMetricBar(title: "FATIGUE", value: avgFatigue, color: avgFatigue > 0.60 ? .orange : .green)

                Divider().background(Color.white.opacity(0.2))

                MiniText(name: "SESSIONS", value: "\(sessions.count)", color: .cyan)
                MiniText(name: "VET RECORDS", value: "\(vetRecords.count)", color: .red)
                MiniText(name: "SEVERE", value: "\(severeCount)", color: severeCount > 0 ? .red : .green)
                MiniText(name: "AI REPORT", value: aiReport == nil ? "NO" : "YES", color: aiReport == nil ? .orange : .green)

                Text(recommendation)
                    .foregroundColor(.white)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .lineLimit(5)
                    .padding(.top, 4)
            }
        }
    }

    private var timelinePanel: some View {
        AVOPageBox(title: "EVOLUTION / TIMELINE") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    AVOTimelinePill(title: "FIRST SESSION", value: sessions.last.map { Self.shortDate($0.date) } ?? "--", color: .cyan)
                    AVOTimelinePill(title: "LAST SESSION", value: sessions.first.map { Self.shortDate($0.date) } ?? "--", color: .green)
                    AVOTimelinePill(title: "LAST VET", value: vetRecords.first.map { Self.shortDate($0.date) } ?? "--", color: .red)
                }

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(sessions.prefix(8))) { session in
                            HStack(spacing: 8) {
                                Text("SESSION")
                                    .foregroundColor(.green)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .frame(width: 70, alignment: .leading)
                                Text(Self.shortDate(session.date))
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                Spacer()
                                Text("Q \(Int(session.avgQuality * 100))%")
                                    .foregroundColor(.green)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                Text("RISK \(Int(session.avgRisk * 100))%")
                                    .foregroundColor(session.avgRisk > 0.60 ? .red : .orange)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        ForEach(Array(vetRecords.prefix(5))) { record in
                            HStack(spacing: 8) {
                                Text("VET")
                                    .foregroundColor(.red)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .frame(width: 70, alignment: .leading)
                                Text(Self.shortDate(record.date))
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                Text(record.injuryZone.isEmpty ? "NO ZONE" : record.injuryZone)
                                    .foregroundColor(.orange)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                Spacer()
                                Text(record.severity.rawValue.uppercased())
                                    .foregroundColor(record.severity == .severe || record.severity == .critical ? .red : .orange)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private var aiRiskPanel: some View {
        AVOPageBox(title: "AI RISK MAP") {
            VStack(alignment: .leading, spacing: 10) {
                if let report = aiReport {
                    Text(report.summary)
                        .foregroundColor(.white)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .lineLimit(5)

                    ForEach(report.riskZones.prefix(6)) { zone in
                        AVOPageMetricBar(title: zone.zone.uppercased(), value: zone.score, color: zone.score > 0.70 ? .red : (zone.score > 0.40 ? .orange : .green))
                    }
                } else {
                    Text("No hay análisis IA todavía. Pulsa RUN AI para generar ai_analysis_report.json, ai_risk_timeline.json y recomendaciones.")
                        .foregroundColor(.gray)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .lineLimit(8)
                    Spacer()
                    Button { onRunAI() } label: { BottomButton("RUN AI ANALYSIS", .orange) }
                }
            }
        }
    }

    private var sessionsPanel: some View {
        AVOPageBox(title: "BIOMECH SESSIONS") {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(sessions.prefix(12)) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .foregroundColor(.white)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Text(Self.shortDate(session.date))
                                .foregroundColor(.cyan)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                            Text("Samples \(session.samplesCount) · Q \(Int(session.avgQuality * 100))% · Risk \(Int(session.avgRisk * 100))% · Fatigue \(Int(session.avgFatigue * 100))%")
                                .foregroundColor(.gray)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var vetPanel: some View {
        AVOPageBox(title: "VETERINARY HISTORY") {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(vetRecords.prefix(12)) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .foregroundColor(.white)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Text(Self.shortDate(record.date))
                                .foregroundColor(.cyan)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                            Text("\(record.injuryZone) · \(record.severity.rawValue)")
                                .foregroundColor(.orange)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                            Text(record.diagnosis.isEmpty ? "NO DIAGNOSIS" : record.diagnosis)
                                .foregroundColor(.gray)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var recommendationsPanel: some View {
        AVOPageBox(title: "RECOMMENDATIONS") {
            VStack(alignment: .leading, spacing: 8) {
                if let report = aiReport {
                    ForEach(report.recommendations.prefix(10)) { rec in
                        Text("[\(rec.priority)] \(rec.text)")
                            .foregroundColor(rec.priority.lowercased().contains("high") ? .red : .white)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .lineLimit(3)
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    Text(recommendation)
                        .foregroundColor(.white)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .lineLimit(8)
                }
                Spacer()
            }
        }
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

struct AVOPageBox<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .black, design: .monospaced))
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.045))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct AVOPageMetricBar: View {
    var title: String
    var value: Double
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Spacer()
                Text("\(Int(max(0, min(1, value)) * 100))%")
                    .foregroundColor(color)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.78))
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                }
            }
            .frame(height: 8)
        }
    }
}

struct AVOTimelinePill: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


// MARK: - Full Page Sessions Review

struct AVOSessionsReviewPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var onClose: () -> Void
    var onSaveLiveSession: () -> Void
    var onExportSessionReview: (_ sessionID: UUID?, _ notes: String) -> Void
    var onOpenFolder: () -> Void

    @State private var selectedSessionID: UUID?
    @State private var trainerNotes: String = ""

    private var selectedSession: StableSessionListItem? {
        if let id = selectedSessionID, let found = sessions.first(where: { $0.id == id }) { return found }
        return sessions.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                pageHeader
                HStack(spacing: 12) {
                    sessionList.frame(width: 300)
                    reviewCanvas.frame(maxWidth: .infinity)
                    dataInspector.frame(width: 330)
                }
            }
            .padding(16)
        }
        .onAppear { selectedSessionID = selectedSession?.id }
    }

    private var pageHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SESSIONS REVIEW")
                    .foregroundColor(.cyan)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                Text(profile.name.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                Text("Revisión amplia de sesiones, datos, sensores, notas y enlace veterinario.")
                    .foregroundColor(.gray)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            Spacer()
            Button { onSaveLiveSession() } label: { BottomButton("SAVE LIVE", .green) }
            Button { onExportSessionReview(selectedSessionID, trainerNotes) } label: { BottomButton("EXPORT REVIEW", .orange) }
            Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
            Button { onClose() } label: { BottomButton("CLOSE", .red) }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sessionList: some View {
        AVOPageBox(title: "SESSION INDEX") {
            ScrollView {
                VStack(spacing: 8) {
                    if sessions.isEmpty {
                        Text("NO SESSIONS YET")
                            .foregroundColor(.orange)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                    ForEach(sessions) { session in
                        Button { selectedSessionID = session.id } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title.uppercased())
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                Text(Self.shortDate(session.date))
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                Text("Q \(Int(session.avgQuality * 100))% · RISK \(Int(session.avgRisk * 100))% · FAT \(Int(session.avgFatigue * 100))% · N \(session.samplesCount)")
                                    .foregroundColor(.green)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .padding(9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedSessionID == session.id ? Color.cyan.opacity(0.22) : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var reviewCanvas: some View {
        AVOPageBox(title: "VIDEO / SNAPSHOT / POSE REVIEW") {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.45))
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.45), lineWidth: 1)
                    VStack(spacing: 10) {
                        Text("SESSION REVIEW CANVAS")
                            .foregroundColor(.green)
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                        Text("Sesión conectada al perfil, sensores, vídeo, IA y contexto veterinario. Usa EXPORT REVIEW para guardar JSON/TXT de revisión.")
                            .foregroundColor(.gray)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                        if let s = selectedSession {
                            VStack(spacing: 5) {
                                Text(s.sessionRelativePath)
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .lineLimit(2)
                                Text("VIDEO: \(s.videoRelativePath ?? "PENDING")")
                                    .foregroundColor(s.videoRelativePath == nil ? .orange : .green)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .lineLimit(2)
                                Text("SAMPLES \(s.samplesCount) · Q \(Int(s.avgQuality * 100))% · RISK \(Int(s.avgRisk * 100))% · FAT \(Int(s.avgFatigue * 100))%")
                                    .foregroundColor(.white)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                            }
                        }
                    }
                    .padding(20)
                }
                .frame(maxHeight: .infinity)

                TextEditor(text: $trainerNotes)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .frame(height: 95)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var dataInspector: some View {
        AVOPageBox(title: "DATA INSPECTOR") {
            VStack(alignment: .leading, spacing: 10) {
                if let s = selectedSession {
                    AVOPageMetricBar(title: "QUALITY", value: s.avgQuality, color: s.avgQuality < 0.45 ? .orange : .green)
                    AVOPageMetricBar(title: "RISK", value: s.avgRisk, color: s.avgRisk > 0.60 ? .red : .green)
                    AVOPageMetricBar(title: "FATIGUE", value: s.avgFatigue, color: s.avgFatigue > 0.60 ? .orange : .green)
                    Divider().background(Color.white.opacity(0.2))
                    MiniText(name: "SAMPLES", value: "\(s.samplesCount)", color: .cyan)
                    MiniText(name: "DURATION", value: "\(Int(s.durationSeconds))s", color: .green)
                    MiniText(name: "SENSORS", value: s.sensorsRelativePath == nil ? "NO" : "YES", color: s.sensorsRelativePath == nil ? .orange : .green)
                    MiniText(name: "VIDEO", value: s.videoRelativePath == nil ? "PENDING" : "YES", color: s.videoRelativePath == nil ? .orange : .green)
                } else {
                    Text("Selecciona una sesión para revisar.")
                        .foregroundColor(.gray)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                Divider().background(Color.white.opacity(0.2))
                Text("LINKED VET CONTEXT")
                    .foregroundColor(.red)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(vetRecords.prefix(5)) { r in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.title)
                                    .foregroundColor(.white)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                Text("\(r.injuryZone) · \(r.severity.rawValue)")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
            }
        }
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Full Page Veterinary History

struct AVOVeterinaryHistoryPage: View {
    var profile: StableHorseProfile
    var records: [StableVetRecordListItem]
    var sessions: [StableSessionListItem]
    var onClose: () -> Void
    var onOpenFolder: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VETERINARY HISTORY")
                            .foregroundColor(.red)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                        Text(profile.name.uppercased())
                            .foregroundColor(.white)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                    }
                    Spacer()
                    Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
                    Button { onClose() } label: { BottomButton("CLOSE", .red) }
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 12) {
                    AVOPageBox(title: "VET RECORDS") {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(records) { r in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(r.title.uppercased())
                                            .foregroundColor(.white)
                                            .font(.system(size: 12, weight: .black, design: .monospaced))
                                        Text(Self.shortDate(r.date))
                                            .foregroundColor(.cyan)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        Text("\(r.injuryZone) · \(r.severity.rawValue)")
                                            .foregroundColor(r.severity == .severe || r.severity == .critical ? .red : .orange)
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                        Text(r.diagnosis.isEmpty ? "NO DIAGNOSIS" : r.diagnosis)
                                            .foregroundColor(.gray)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .lineLimit(4)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    AVOPageBox(title: "MEDICAL IMAGES / DOCUMENTS") {
                        VStack(spacing: 10) {
                            Text("Zona preparada para radiografías, ecografías, fotos e informes PDF por registro veterinario.")
                                .foregroundColor(.gray)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                            Text("Las imágenes se guardan en VetRecords/.../Images dentro de la carpeta visible de la app.")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    AVOPageBox(title: "RELATED SESSIONS") {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(sessions.prefix(8)) { s in
                                    MiniText(name: AVOSessionsReviewPage.shortDate(s.date), value: "R \(Int(s.avgRisk * 100))%", color: .cyan)
                                }
                            }
                        }
                    }
                    .frame(width: 300)
                }
            }
            .padding(16)
        }
    }

    static func shortDate(_ date: Date) -> String { AVOSessionsReviewPage.shortDate(date) }
}

// MARK: - Full Page AI Training Center

struct AVOAITrainingCenterPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?
    var onClose: () -> Void
    var onBuildDataset: () -> Void
    var onRunAI: () -> Void
    var onOpenFolder: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI TRAINING CENTER")
                            .foregroundColor(.purple)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                        Text(profile.name.uppercased())
                            .foregroundColor(.white)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                        Text("Dataset clínico-deportivo separado del Auto Pose y del detector en tiempo real.")
                            .foregroundColor(.gray)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    Button { onBuildDataset() } label: { BottomButton("BUILD DATASET + COLAB", .purple) }
                    Button { onRunAI() } label: { BottomButton("RUN AI", .orange) }
                    Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
                    Button { onClose() } label: { BottomButton("CLOSE", .red) }
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 12) {
                    AVOPageBox(title: "DATASET BUILDER") {
                        VStack(alignment: .leading, spacing: 12) {
                            AVOPageMetricBar(title: "SESSION COVERAGE", value: min(1.0, Double(sessions.count) / 20.0), color: .cyan)
                            AVOPageMetricBar(title: "VET LABEL COVERAGE", value: min(1.0, Double(vetRecords.count) / 10.0), color: .red)
                            MiniText(name: "SESSIONS", value: "\(sessions.count)", color: .cyan)
                            MiniText(name: "VET LABELS", value: "\(vetRecords.count)", color: .red)
                            MiniText(name: "COREML EXPORT", value: "FUTURE READY", color: .purple)
                            MiniText(name: "COLAB EXPORT", value: "AUTO PACK READY", color: .green)
                            Text("BUILD DATASET + COLAB crea linked_dataset.json, snapshot comercial, guía Colab y dispara COLAB AUTO PACK si hay GOOD/HORSE con puntos reales.")
                                .foregroundColor(.gray)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    }
                    .frame(width: 360)

                    AVOPageBox(title: "AI REPORT") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                if let report = aiReport {
                                    MiniText(name: "GLOBAL RISK", value: "\(Int(report.globalRisk * 100))%", color: report.globalRisk > 0.60 ? .red : .green)
                                    MiniText(name: "MAIN ZONE", value: report.mainRiskZone, color: .orange)
                                    Text(report.summary)
                                        .foregroundColor(.white)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    ForEach(report.recommendations) { rec in
                                        Text("• \(rec.priority): \(rec.text)")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    }
                                } else {
                                    Text("Pulsa RUN AI para crear ai_analysis_report.json, ai_risk_timeline.json y ai_recommendations.json.")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    AVOPageBox(title: "MODEL VERSIONS") {
                        VStack(alignment: .leading, spacing: 10) {
                            MiniText(name: "ANATOMY MODEL", value: "CURRENT", color: .green)
                            MiniText(name: "CLINICAL MODEL", value: "RULE ENGINE V1", color: .orange)
                            MiniText(name: "HORSE PROFILE", value: profile.name, color: .cyan)
                            Divider().background(Color.white.opacity(0.2))
                            Text("Futuro: versiones CoreML por caballo, por cuadra y modelo global AVO Horse.")
                                .foregroundColor(.gray)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                            Spacer()
                        }
                    }
                    .frame(width: 320)
                }
            }
            .padding(16)
        }
    }
}


// MARK: - Full Page Report Builder

struct AVOReportBuilderPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?
    var onClose: () -> Void
    var onRunAI: () -> Void
    var onExportReport: (_ performance: Bool, _ sessions: Bool, _ veterinary: Bool, _ timeline: Bool, _ ai: Bool, _ medical: Bool) -> Void
    var onOpenFolder: () -> Void

    @State private var includePerformance = true
    @State private var includeSessions = true
    @State private var includeVeterinary = true
    @State private var includeTimeline = true
    @State private var includeAI = true
    @State private var includeMedicalImages = true
    @State private var exportMessage = "READY"

    var avgQuality: Double { sessions.map { $0.avgQuality }.average }
    var avgRisk: Double { sessions.map { $0.avgRisk }.average }
    var avgFatigue: Double { sessions.map { $0.avgFatigue }.average }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPORT BUILDER")
                            .foregroundColor(.white)
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                        Text("\(profile.name.uppercased()) · PROFESSIONAL CLINICAL / SPORT REPORT")
                            .foregroundColor(.green)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    Button { onRunAI(); exportMessage = "AI UPDATED" } label: { BottomButton("RUN AI", .orange) }
                    Button {
                        onExportReport(includePerformance, includeSessions, includeVeterinary, includeTimeline, includeAI, includeMedicalImages)
                        exportMessage = "EXPORTED JSON + TXT + PDF"
                    } label: { BottomButton("EXPORT REPORT", .green) }
                    Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
                    Button { onClose() } label: { BottomButton("CLOSE", .red) }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    ProBox("REPORT CONTENT") {
                        VStack(alignment: .leading, spacing: 10) {
                            ReportToggleRow(title: "Performance Dashboard", subtitle: "Estado, riesgo, calidad, fatiga y recomendación.", isOn: $includePerformance)
                            ReportToggleRow(title: "Biomech Sessions", subtitle: "Resumen de sesiones, muestras, riesgo y calidad.", isOn: $includeSessions)
                            ReportToggleRow(title: "Veterinary History", subtitle: "Diagnósticos, zonas, gravedad y seguimiento.", isOn: $includeVeterinary)
                            ReportToggleRow(title: "Biomech Timeline", subtitle: "Línea temporal combinada sesión/veterinario.", isOn: $includeTimeline)
                            ReportToggleRow(title: "AI Analysis", subtitle: "Riesgo IA, zonas anatómicas y recomendaciones.", isOn: $includeAI)
                            ReportToggleRow(title: "Medical Images References", subtitle: "Preparado para incluir radiografías/ecografías/PDF enlazados.", isOn: $includeMedicalImages)
                            Spacer()
                            MiniText(name: "EXPORT", value: exportMessage, color: .green)
                        }
                    }
                    .frame(width: 330)

                    ProBox("LIVE PREVIEW") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ReportPreviewSection(title: "HORSE FILE", lines: horseLines())
                                if includePerformance { ReportPreviewSection(title: "PERFORMANCE", lines: performanceLines()) }
                                if includeSessions { ReportPreviewSection(title: "SESSIONS", lines: sessionLines()) }
                                if includeVeterinary { ReportPreviewSection(title: "VETERINARY", lines: vetLines()) }
                                if includeAI { ReportPreviewSection(title: "AI ANALYSIS", lines: aiLines()) }
                                if includeTimeline { ReportPreviewSection(title: "TIMELINE", lines: timelineLines()) }
                                ReportPreviewSection(title: "RECOMMENDATIONS", lines: recommendationLines())
                            }
                        }
                    }

                    ProBox("REPORT STATUS") {
                        VStack(alignment: .leading, spacing: 10) {
                            AVOMetricTile(title: "SESSIONS", value: "\(sessions.count)", color: .cyan)
                            AVOMetricTile(title: "VET RECORDS", value: "\(vetRecords.count)", color: .red)
                            AVOMetricTile(title: "AVG RISK", value: "\(Int(avgRisk * 100))%", color: avgRisk > 0.65 ? .red : .orange)
                            AVOMetricTile(title: "AVG QUALITY", value: "\(Int(avgQuality * 100))%", color: .green)
                            AVOMetricTile(title: "AI", value: aiReport == nil ? "NO REPORT" : "READY", color: aiReport == nil ? .orange : .green)
                            Text("Export creates professional_report_builder.json, professional_report_builder.txt and a real AVO_Report_*.pdf inside the selected horse Reports folder.")
                                .foregroundColor(.gray)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                    }
                    .frame(width: 300)
                }
            }
            .padding(10)
        }
    }

    private func horseLines() -> [String] {
        [
            "Nombre: \(profile.name)",
            "Edad: \(profile.ageYears) años",
            "Sexo: \(profile.sex.rawValue)",
            "Raza: \(profile.breed.isEmpty ? "--" : profile.breed)",
            "Modalidad: \(profile.competitionMode.isEmpty ? "--" : profile.competitionMode)"
        ]
    }

    private func performanceLines() -> [String] {
        [
            "Calidad media: \(Int(avgQuality * 100))%",
            "Riesgo medio: \(Int(avgRisk * 100))%",
            "Fatiga media: \(Int(avgFatigue * 100))%",
            "Sesiones: \(sessions.count)",
            "Veterinario: \(vetRecords.count)"
        ]
    }

    private func sessionLines() -> [String] {
        if sessions.isEmpty { return ["Sin sesiones biomecánicas todavía."] }
        return sessions.prefix(8).map { "\(shortDate($0.date)) · \($0.title) · riesgo \(Int($0.avgRisk * 100))% · calidad \(Int($0.avgQuality * 100))%" }
    }

    private func vetLines() -> [String] {
        if vetRecords.isEmpty { return ["Sin registros veterinarios todavía."] }
        return vetRecords.prefix(8).map { "\(shortDate($0.date)) · \($0.injuryZone.isEmpty ? "zona sin definir" : $0.injuryZone) · \($0.severity.rawValue) · \($0.diagnosis)" }
    }

    private func aiLines() -> [String] {
        guard let report = aiReport else { return ["Sin análisis IA. Pulsa RUN AI para actualizar."] }
        return ["Riesgo global: \(Int(report.globalRisk * 100))%", "Zona principal: \(report.mainRiskZone)", report.summary] + report.riskZones.prefix(6).map { "\($0.zone): \(Int($0.score * 100))%" }
    }

    private func timelineLines() -> [String] {
        var lines: [String] = []
        for s in sessions.prefix(8) { lines.append("SESSION · \(shortDate(s.date)) · \(s.title)") }
        for v in vetRecords.prefix(8) { lines.append("VET · \(shortDate(v.date)) · \(v.injuryZone) · \(v.severity.rawValue)") }
        return lines.sorted()
    }

    private func recommendationLines() -> [String] {
        if let report = aiReport, !report.recommendations.isEmpty {
            return report.recommendations.map { "\($0.priority): \($0.text)" }
        }
        if avgRisk > 0.65 { return ["No aumentar carga.", "Revisar veterinario y comparar sesiones.", "Generar análisis IA antes del próximo informe."] }
        return ["Continuar creando histórico limpio.", "Vincular sesiones con registros veterinarios.", "Exportar dataset para entrenamiento futuro."]
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ReportToggleRow: View {
    var title: String
    var subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                Text(subtitle)
                    .foregroundColor(.gray)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .green))
        .padding(8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ReportPreviewSection: View {
    var title: String
    var lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(.green)
                .font(.system(size: 14, weight: .black, design: .monospaced))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .foregroundColor(.white.opacity(0.86))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Full Page Biomechanical Timeline

struct AVOBiomechTimelinePage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?
    var onClose: () -> Void
    var onRunAI: () -> Void
    var onOpenFolder: () -> Void

    private var sortedSessions: [StableSessionListItem] {
        sessions.sorted { $0.date < $1.date }
    }

    private var sortedVetRecords: [StableVetRecordListItem] {
        vetRecords.sorted { $0.date < $1.date }
    }

    private var averageRisk: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map { $0.avgRisk }.reduce(0, +) / Double(sessions.count)
    }

    private var averageQuality: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map { $0.avgQuality }.reduce(0, +) / Double(sessions.count)
    }

    private var averageFatigue: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map { $0.avgFatigue }.reduce(0, +) / Double(sessions.count)
    }

    private var trendText: String {
        guard sessions.count >= 2 else { return "NEED MORE SESSIONS" }
        let ordered = sessions.sorted { $0.date < $1.date }
        let first = ordered.prefix(max(1, ordered.count / 2)).map { $0.avgRisk }.reduce(0, +) / Double(max(1, ordered.count / 2))
        let secondItems = ordered.suffix(max(1, ordered.count - ordered.count / 2))
        let second = secondItems.map { $0.avgRisk }.reduce(0, +) / Double(max(1, secondItems.count))
        if second > first + 0.12 { return "RISK INCREASING" }
        if second < first - 0.12 { return "RISK IMPROVING" }
        return "STABLE TREND"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BIOMECH TIMELINE")
                            .foregroundColor(.orange)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                        Text(profile.name.uppercased())
                            .foregroundColor(.white)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                        Text("Evolución completa de sesiones, lesiones, riesgo IA, impacto y calidad biomecánica.")
                            .foregroundColor(.gray)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    Button { onRunAI() } label: { BottomButton("RUN AI", .orange) }
                    Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
                    Button { onClose() } label: { BottomButton("CLOSE", .red) }
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 12) {
                    AVOPageBox(title: "GLOBAL EVOLUTION") {
                        VStack(alignment: .leading, spacing: 12) {
                            AVOPageMetricBar(title: "AVERAGE RISK", value: averageRisk, color: averageRisk > 0.60 ? .red : .green)
                            AVOPageMetricBar(title: "AVERAGE QUALITY", value: averageQuality, color: .cyan)
                            AVOPageMetricBar(title: "AVERAGE FATIGUE", value: averageFatigue, color: .orange)
                            MiniText(name: "TREND", value: trendText, color: trendText.contains("INCREASING") ? .red : .green)
                            MiniText(name: "SESSIONS", value: "\(sessions.count)", color: .cyan)
                            MiniText(name: "VET EVENTS", value: "\(vetRecords.count)", color: .red)
                            if let report = aiReport {
                                Divider().background(Color.white.opacity(0.2))
                                MiniText(name: "AI MAIN ZONE", value: report.mainRiskZone, color: .orange)
                                Text(report.summary)
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .lineLimit(6)
                            }
                            Spacer()
                        }
                    }
                    .frame(width: 360)

                    AVOPageBox(title: "CHRONOLOGICAL TIMELINE") {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(combinedTimelineItems(), id: \.id) { item in
                                    AVOTimelineRow(item: item)
                                }
                            }
                        }
                    }

                    AVOPageBox(title: "BEFORE / AFTER INJURY") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                if sortedVetRecords.isEmpty {
                                    Text("No hay registros veterinarios todavía. Cuando añadas lesiones, la app comparará automáticamente sesiones anteriores y posteriores.")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                } else {
                                    ForEach(sortedVetRecords) { record in
                                        AVOBeforeAfterVetBlock(record: record, sessions: sessions)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 390)
                }
            }
            .padding(16)
        }
    }

    private func combinedTimelineItems() -> [AVOTimelineItem] {
        var items: [AVOTimelineItem] = []
        for s in sortedSessions {
            let subtitle = "Risk \(Int(s.avgRisk * 100))% · Quality \(Int(s.avgQuality * 100))% · Fatigue \(Int(s.avgFatigue * 100))%"
            let severity = s.avgRisk > 0.65 ? "ALERT" : (s.avgRisk > 0.40 ? "WATCH" : "OK")
            items.append(AVOTimelineItem(date: s.date, kind: "SESSION", title: s.title, subtitle: subtitle, severity: severity))
        }
        for v in sortedVetRecords {
            let subtitle = "\(v.injuryZone) · \(v.severity.rawValue) · \(v.diagnosis.isEmpty ? "No diagnosis" : v.diagnosis)"
            items.append(AVOTimelineItem(date: v.date, kind: "VET", title: v.title, subtitle: subtitle, severity: v.severity.rawValue.uppercased()))
        }
        return items.sorted { $0.date > $1.date }
    }
}

struct AVOTimelineItem: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var kind: String
    var title: String
    var subtitle: String
    var severity: String
}

struct AVOTimelineRow: View {
    var item: AVOTimelineItem

    var color: Color {
        if item.kind == "VET" { return .red }
        if item.severity.contains("ALERT") { return .orange }
        if item.severity.contains("WATCH") { return .yellow }
        return .cyan
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) {
                Circle().fill(color).frame(width: 10, height: 10)
                Rectangle().fill(color.opacity(0.25)).frame(width: 2, height: 48)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.kind)
                        .foregroundColor(color)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                    Text(AVOSessionsReviewPage.shortDate(item.date))
                        .foregroundColor(.gray)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Spacer()
                    Text(item.severity)
                        .foregroundColor(color)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                Text(item.title.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                Text(item.subtitle)
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .lineLimit(3)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct AVOBeforeAfterVetBlock: View {
    var record: StableVetRecordListItem
    var sessions: [StableSessionListItem]

    private var beforeSessions: [StableSessionListItem] {
        sessions.filter { $0.date < record.date }.sorted { $0.date > $1.date }
    }

    private var afterSessions: [StableSessionListItem] {
        sessions.filter { $0.date >= record.date }.sorted { $0.date < $1.date }
    }

    private var beforeRisk: Double {
        let values = beforeSessions.prefix(3).map { $0.avgRisk }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var afterRisk: Double {
        let values = afterSessions.prefix(3).map { $0.avgRisk }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.title.uppercased())
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text("\(AVOSessionsReviewPage.shortDate(record.date)) · \(record.injuryZone) · \(record.severity.rawValue)")
                .foregroundColor(.red)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            HStack(spacing: 8) {
                AVOPageMetricBar(title: "BEFORE RISK", value: beforeRisk, color: beforeRisk > 0.60 ? .red : .green)
                AVOPageMetricBar(title: "AFTER RISK", value: afterRisk, color: afterRisk > 0.60 ? .red : .orange)
            }
            MiniText(name: "AI COMPARISON", value: comparisonText, color: comparisonText.contains("WORSE") ? .red : .green)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var comparisonText: String {
        if beforeSessions.isEmpty || afterSessions.isEmpty { return "NEED BEFORE/AFTER DATA" }
        if afterRisk > beforeRisk + 0.10 { return "WORSE AFTER VET EVENT" }
        if afterRisk < beforeRisk - 0.10 { return "IMPROVING AFTER VET EVENT" }
        return "NO BIG CHANGE"
    }
}

// MARK: - Full Page Compare Sessions

struct AVOCompareSessionsPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var onClose: () -> Void
    var onOpenFolder: () -> Void

    @State private var leftSessionID: UUID?
    @State private var rightSessionID: UUID?

    private var orderedSessions: [StableSessionListItem] {
        sessions.sorted { $0.date > $1.date }
    }

    private var leftSession: StableSessionListItem? {
        orderedSessions.first { $0.id == leftSessionID } ?? orderedSessions.first
    }

    private var rightSession: StableSessionListItem? {
        if let id = rightSessionID { return orderedSessions.first { $0.id == id } }
        return orderedSessions.dropFirst().first ?? orderedSessions.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("COMPARE SESSIONS")
                            .foregroundColor(.yellow)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                        Text(profile.name.uppercased())
                            .foregroundColor(.white)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                        Text("Comparación A/B para revisar evolución, calidad, riesgo, fatiga y relación veterinaria.")
                            .foregroundColor(.gray)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
                    Button { onClose() } label: { BottomButton("CLOSE", .red) }
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if orderedSessions.isEmpty {
                    AVOPageBox(title: "NO SESSIONS") {
                        Text("Todavía no hay sesiones guardadas para comparar. Graba o guarda una sesión desde BIOMECH / STABLE.")
                            .foregroundColor(.gray)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    HStack(spacing: 12) {
                        sessionSelector(title: "SESSION A", selectedID: $leftSessionID)
                            .frame(width: 320)
                        comparisonPanel
                        sessionSelector(title: "SESSION B", selectedID: $rightSessionID)
                            .frame(width: 320)
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            if leftSessionID == nil { leftSessionID = orderedSessions.first?.id }
            if rightSessionID == nil { rightSessionID = orderedSessions.dropFirst().first?.id ?? orderedSessions.first?.id }
        }
    }

    private func sessionSelector(title: String, selectedID: Binding<UUID?>) -> some View {
        AVOPageBox(title: title) {
            VStack(spacing: 8) {
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(orderedSessions) { session in
                            Button {
                                selectedID.wrappedValue = session.id
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(session.title.uppercased())
                                        .foregroundColor(.white)
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                    Text(AVOSessionsReviewPage.shortDate(session.date))
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    MiniText(name: "RISK", value: "\(Int(session.avgRisk * 100))%", color: session.avgRisk > 0.60 ? .red : .green)
                                    MiniText(name: "QUALITY", value: "\(Int(session.avgQuality * 100))%", color: .cyan)
                                }
                                .padding(9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedID.wrappedValue == session.id ? Color.yellow.opacity(0.24) : Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var comparisonPanel: some View {
        AVOPageBox(title: "A / B ANALYSIS") {
            VStack(alignment: .leading, spacing: 12) {
                if let a = leftSession, let b = rightSession {
                    HStack(spacing: 12) {
                        AVOSessionCompareCard(label: "A", session: a)
                        AVOSessionCompareCard(label: "B", session: b)
                    }
                    Divider().background(Color.white.opacity(0.2))
                    AVOCompareDeltaRow(title: "RISK DELTA", left: a.avgRisk, right: b.avgRisk, reverseGood: true)
                    AVOCompareDeltaRow(title: "QUALITY DELTA", left: a.avgQuality, right: b.avgQuality, reverseGood: false)
                    AVOCompareDeltaRow(title: "FATIGUE DELTA", left: a.avgFatigue, right: b.avgFatigue, reverseGood: true)
                    MiniText(name: "SAMPLES", value: "A \(a.samplesCount) / B \(b.samplesCount)", color: .cyan)
                    MiniText(name: "AI RESULT", value: compareResult(a: a, b: b), color: compareResult(a: a, b: b).contains("WORSE") ? .red : .green)
                    Divider().background(Color.white.opacity(0.2))
                    relatedVetBlock(a: a, b: b)
                    Spacer()
                } else {
                    Text("Selecciona dos sesiones para comparar.")
                        .foregroundColor(.gray)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
        }
    }

    private func compareResult(a: StableSessionListItem, b: StableSessionListItem) -> String {
        let riskDelta = b.avgRisk - a.avgRisk
        let qualityDelta = b.avgQuality - a.avgQuality
        if riskDelta > 0.12 || qualityDelta < -0.12 { return "B WORSE THAN A" }
        if riskDelta < -0.12 || qualityDelta > 0.12 { return "B BETTER THAN A" }
        return "SIMILAR SESSION PROFILE"
    }

    private func relatedVetBlock(a: StableSessionListItem, b: StableSessionListItem) -> some View {
        let start = min(a.date, b.date)
        let end = max(a.date, b.date)
        let related = vetRecords.filter { $0.date >= start && $0.date <= end }
        return VStack(alignment: .leading, spacing: 8) {
            Text("VET EVENTS BETWEEN A/B")
                .foregroundColor(.red)
                .font(.system(size: 11, weight: .black, design: .monospaced))
            if related.isEmpty {
                Text("No hay eventos veterinarios entre estas dos sesiones.")
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            } else {
                ForEach(related.prefix(4)) { r in
                    MiniText(name: AVOSessionsReviewPage.shortDate(r.date), value: "\(r.injuryZone) · \(r.severity.rawValue)", color: .red)
                }
            }
        }
    }
}

struct AVOSessionCompareCard: View {
    var label: String
    var session: StableSessionListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION \(label)")
                .foregroundColor(.yellow)
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text(session.title.uppercased())
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .lineLimit(2)
            Text(AVOSessionsReviewPage.shortDate(session.date))
                .foregroundColor(.gray)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            AVOPageMetricBar(title: "RISK", value: session.avgRisk, color: session.avgRisk > 0.60 ? .red : .green)
            AVOPageMetricBar(title: "QUALITY", value: session.avgQuality, color: .cyan)
            AVOPageMetricBar(title: "FATIGUE", value: session.avgFatigue, color: .orange)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AVOCompareDeltaRow: View {
    var title: String
    var left: Double
    var right: Double
    var reverseGood: Bool

    private var delta: Double { right - left }
    private var color: Color {
        if abs(delta) < 0.05 { return .cyan }
        let good = reverseGood ? delta < 0 : delta > 0
        return good ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Spacer()
                Text(String(format: "%+.1f%%", delta * 100))
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.80)).frame(width: geo.size.width * min(1, max(0.05, abs(delta))), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Horse File Editor Advanced

struct AVOHorseProfilePhotoPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct AVOHorseFileEditorPage: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: StableHorseProfile
    @State private var showPhotoPicker = false

    var onClose: () -> Void
    var onSave: (StableHorseProfile) -> Void
    var onImportPhoto: (URL) -> Void
    var onOpenFolder: () -> Void

    init(
        profile: StableHorseProfile,
        onClose: @escaping () -> Void,
        onSave: @escaping (StableHorseProfile) -> Void,
        onImportPhoto: @escaping (URL) -> Void,
        onOpenFolder: @escaping () -> Void
    ) {
        _draft = State(initialValue: profile)
        self.onClose = onClose
        self.onSave = onSave
        self.onImportPhoto = onImportPhoto
        self.onOpenFolder = onOpenFolder
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            HStack(spacing: 10) {
                mainFilePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                identificationPanel
                    .frame(maxWidth: .infinity)
                notesPanel
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showPhotoPicker) {
            AVOHorseProfilePhotoPicker { url in
                onImportPhoto(url)
                draft.photoRelativePath = "HorseFile/profile_photo.\(url.pathExtension.isEmpty ? "jpg" : url.pathExtension)"
                showPhotoPicker = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HORSE FILE EDITOR")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                Text("\(draft.name.uppercased()) · ficha profesional editable · edad automática \(draft.ageYears) años")
                    .foregroundColor(.green)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            Spacer()
            Button { showPhotoPicker = true } label: { BottomButton("IMPORT PHOTO", .cyan) }
            Button { onOpenFolder() } label: { BottomButton("OPEN FOLDER", .blue) }
            Button {
                onSave(draft)
            } label: { BottomButton("SAVE FILE", .green) }
            Button {
                onClose()
                dismiss()
            } label: { BottomButton("CLOSE", .red) }
        }
        .padding(12)
        .background(Color.white.opacity(0.055))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var mainFilePanel: some View {
        AVOPageBox(title: "MAIN HORSE FILE") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    editorTextField("Nombre", text: $draft.name)
                    DatePicker("Fecha de nacimiento", selection: $draft.birthDate, displayedComponents: .date)
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Picker("Sexo", selection: $draft.sex) {
                        ForEach(StableHorseSex.allCases) { sex in
                            Text(sex.rawValue).tag(sex)
                        }
                    }
                    .pickerStyle(.segmented)

                    editorTextField("Raza", text: $draft.breed)
                    editorTextField("Modalidad competición", text: $draft.competitionMode)
                    editorTextField("Propietario", text: binding(\.ownerName))
                    editorTextField("Entrenador", text: binding(\.trainerName))
                    editorTextField("Veterinario principal", text: binding(\.primaryVetName))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("PROFILE PHOTO")
                            .foregroundColor(.gray)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                        Text(draft.photoRelativePath ?? "Sin foto importada")
                            .foregroundColor((draft.photoRelativePath ?? "").isEmpty ? .orange : .cyan)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 20)
                }
            }
        }
    }

    private var identificationPanel: some View {
        AVOPageBox(title: "IDENTIFICATION / NFC") {
            VStack(alignment: .leading, spacing: 12) {
                editorTextField("Microchip / Chip", text: binding(\.chipNumber))
                editorTextField("NFC Horse ID", text: binding(\.nfcHorseID))
                editorTextField("Stable ID", text: binding(\.stableID))
                editorTextField("Rider ID", text: binding(\.riderID))

                Divider().background(Color.white.opacity(0.30))

                MiniText(name: "AGE", value: "\(draft.ageYears) años", color: .green)
                MiniText(name: "CREATED", value: shortDate(draft.createdAt), color: .cyan)
                MiniText(name: "UPDATED", value: shortDate(draft.updatedAt), color: .orange)

                Text("Estos IDs quedan preparados para enlazar NFC de caballo, jinete, cuadra y sesiones reales.")
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .lineLimit(6)

                Spacer()
            }
        }
    }

    private var notesPanel: some View {
        AVOPageBox(title: "CLINICAL / SPORT NOTES") {
            VStack(alignment: .leading, spacing: 12) {
                editorMultiline("Notas generales", text: $draft.notes)
                editorMultiline("Notas clínicas", text: binding(\.clinicalNotes))
                editorMultiline("Notas deportivas", text: binding(\.sportNotes))
                Spacer()
            }
        }
    }

    private func editorTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .foregroundColor(.gray)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
    }

    private func editorMultiline(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .foregroundColor(.gray)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            TextEditor(text: text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func binding(_ keyPath: WritableKeyPath<StableHorseProfile, String?>) -> Binding<String> {
        Binding<String>(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}


// MARK: - Rehab / Load Monitor Pages

struct AVORehabPlannerPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?
    var onClose: () -> Void
    var onExport: (StableRehabPlanReport) -> Void
    var onOpenFolder: () -> Void

    @State private var plan: StableRehabPlanReport?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                HStack(spacing: 12) {
                    AVOPageBox(title: "RETURN TO WORK PLAN") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                if let plan = plan {
                                    MiniText(name: "FOCUS", value: plan.injuryFocus, color: .red)
                                    MiniText(name: "ALERT", value: plan.alertLevel, color: plan.alertLevel == "ALTA" ? .red : .orange)
                                    AVOPageMetricBar(title: "CURRENT RISK", value: plan.currentRisk, color: plan.currentRisk > 0.55 ? .red : .green)
                                    Text(plan.summary).foregroundColor(.gray).font(.system(size: 12, weight: .bold, design: .monospaced))
                                    Divider().background(Color.white.opacity(0.25))
                                    ForEach(plan.phases) { phase in
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("WEEK \(phase.week) · \(phase.title)").foregroundColor(.white).font(.system(size: 13, weight: .black, design: .monospaced))
                                            Text(phase.workload).foregroundColor(.green).font(.system(size: 11, weight: .bold, design: .monospaced))
                                            Text(phase.objective).foregroundColor(.gray).font(.system(size: 11, weight: .bold, design: .monospaced))
                                            MiniText(name: "LIMITS", value: "Impact \(Int(phase.maxImpact * 100))% · Fatigue \(Int(phase.maxFatigue * 100))% · Asym \(Int(phase.maxAsymmetry * 100))%", color: .cyan)
                                        }
                                        .padding(9)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                } else {
                                    Text("Pulsa BUILD PLAN para crear un plan de recuperación basado en veterinario, lameness y sesiones.").foregroundColor(.gray).font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                            }
                        }
                    }
                    AVOPageBox(title: "STOP RULES") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach((plan?.stopRules ?? defaultStopRules()), id: \.self) { rule in
                                Text("• \(rule)").foregroundColor(.white).font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            Spacer()
                            MiniText(name: "VET CLEARANCE", value: (plan?.veterinaryClearanceRequired ?? true) ? "REQUIRED" : "OPTIONAL", color: .red)
                        }
                    }
                    .frame(width: 410)
                }
            }
            .padding(12)
        }
        .onAppear { if plan == nil { plan = makePlan() } }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("REHABILITATION & RETURN-TO-WORK PLANNER")
                    .foregroundColor(.purple)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                Text(profile.name.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                Text("Fases de reposo, paseo, trote y carga progresiva con límites de impacto, fatiga y asimetría.")
                    .foregroundColor(.gray)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            Spacer()
            Button { plan = makePlan() } label: { BottomButton("BUILD PLAN", .purple) }
            Button { if let plan = plan { onExport(plan) } } label: { BottomButton("EXPORT", .green) }.disabled(plan == nil)
            Button { onOpenFolder() } label: { BottomButton("FOLDER", .cyan) }
            Button { onClose() } label: { BottomButton("CLOSE", .red) }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func makePlan() -> StableRehabPlanReport {
        let recentRisk = sessions.suffix(max(1, min(3, sessions.count))).map { $0.avgRisk }.average
        let baseline = sessions.prefix(max(1, min(3, sessions.count))).map { $0.avgQuality }.average
        let severe = vetRecords.contains { $0.severity == .severe || $0.severity == .critical }
        let currentRisk = min(1, max(recentRisk, (aiReport?.globalRisk ?? 0) * 0.85, severe ? 0.62 : 0.0))
        let level = currentRisk > 0.68 ? "ALTA" : (currentRisk > 0.38 ? "MODERADA" : "BAJA")
        let focus = aiReport?.mainRiskZone ?? vetRecords.first?.injuryZone ?? "Recuperación general"
        let phases = buildPhases(risk: currentRisk)
        let summary = "Plan progresivo para \(profile.name), enfocado en \(focus). No sustituye criterio veterinario; sirve como guía deportiva basada en datos guardados."
        return StableRehabPlanReport(id: UUID(), horseID: profile.id, horseName: profile.name, generatedAt: Date(), injuryFocus: focus, alertLevel: level, currentRisk: currentRisk, baselineQuality: baseline, phases: phases, stopRules: defaultStopRules(), veterinaryClearanceRequired: currentRisk > 0.35 || severe, summary: summary)
    }

    private func buildPhases(risk: Double) -> [StableRehabPhase] {
        let conservative = risk > 0.55
        return [
            StableRehabPhase(week: 1, title: "Reposo controlado", workload: conservative ? "Paseo de mano corto, sin trabajo montado" : "Paseo suave controlado", maxImpact: 0.25, maxFatigue: 0.25, maxAsymmetry: 0.12, objective: "Reducir inflamación, observar apoyo y registrar baseline de baja carga."),
            StableRehabPhase(week: 2, title: "Paseo progresivo", workload: "Paseo 15-25 min, superficie regular", maxImpact: 0.35, maxFatigue: 0.35, maxAsymmetry: 0.10, objective: "Confirmar que no aumenta asimetría ni impacto."),
            StableRehabPhase(week: 3, title: "Trote muy controlado", workload: conservative ? "Bloques cortos de trote solo si vet autoriza" : "Trote ligero en bloques cortos", maxImpact: 0.45, maxFatigue: 0.45, maxAsymmetry: 0.08, objective: "Comparar regularidad y lameness contra baseline."),
            StableRehabPhase(week: 4, title: "Carga técnica", workload: "Trabajo progresivo sin picos de intensidad", maxImpact: 0.55, maxFatigue: 0.55, maxAsymmetry: 0.07, objective: "Volver a patrón estable antes de aumentar exigencia."),
            StableRehabPhase(week: 5, title: "Retorno deportivo", workload: "Aumentar carga solo si el dashboard permanece estable", maxImpact: 0.65, maxFatigue: 0.60, maxAsymmetry: 0.06, objective: "Validar retorno con sesión comparable, LiDAR y sensores.")
        ]
    }

    private func defaultStopRules() -> [String] {
        [
            "Detener si aumenta la asimetría respecto a la sesión anterior.",
            "Detener si el impacto supera el límite de la fase.",
            "Volver a fase anterior si aparece alerta de cojera moderada/alta.",
            "No avanzar de fase sin mejoría o autorización veterinaria cuando haya lesión grave.",
            "Registrar cada sesión con la misma calibración para comparar correctamente."
        ]
    }
}


// MARK: - Workload & Fatigue Load Monitor

struct AVOLoadMonitorPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?
    var onClose: () -> Void
    var onExport: (StableLoadMonitorReport) -> Void
    var onOpenFolder: () -> Void

    @State private var report: StableLoadMonitorReport?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                HStack {
                    Text("WORKLOAD & FATIGUE LOAD MONITOR")
                        .foregroundColor(.white)
                        .font(.system(size: 23, weight: .black, design: .monospaced))
                    Spacer()
                    Button { report = makeReport() } label: { BottomButton("ANALYZE LOAD", .orange) }
                    Button { if let report { onExport(report) } } label: { BottomButton("EXPORT", .green) }
                    Button { onOpenFolder() } label: { BottomButton("OPEN FOLDER", .cyan) }
                    Button { onClose() } label: { BottomButton("CLOSE", .red) }
                }

                HStack(spacing: 10) {
                    ProBox("HORSE LOAD STATE") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.name.uppercased())
                                .foregroundColor(.white)
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                            MiniText(name: "SESSIONS", value: "\(sessions.count)", color: Color.cyan)
                            MiniText(name: "VET", value: "\(vetRecords.count)", color: Color.red)
                            MiniText(name: "AI", value: aiReport == nil ? "NO REPORT" : "READY", color: aiReport == nil ? Color.orange : Color.green)
                            Text("Control de carga diaria/semanal, fatiga acumulada, impacto y descanso recomendado antes de aumentar trabajo.")
                                .foregroundColor(.gray)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                    }
                    .frame(width: 310)

                    ProBox("LOAD ANALYSIS") {
                        if let report {
                            VStack(alignment: .leading, spacing: 12) {
                                AVOMetricTile(title: "ALERT", value: report.alertLevel, color: report.overloadRisk > 0.68 ? Color.red : (report.overloadRisk > 0.40 ? Color.orange : Color.green))
                                StableMetricBar(title: "DAILY LOAD", value: report.dailyLoad, color: Color.cyan)
                                StableMetricBar(title: "WEEKLY LOAD", value: report.weeklyLoad, color: Color.blue)
                                StableMetricBar(title: "FATIGUE", value: report.fatigueAccumulated, color: Color.orange)
                                StableMetricBar(title: "IMPACT", value: report.impactAccumulated, color: Color.red)
                                StableMetricBar(title: "OVERLOAD RISK", value: report.overloadRisk, color: report.overloadRisk > 0.68 ? Color.red : Color.green)
                                MiniText(name: "REST", value: "\(report.recommendedRestHours) h", color: Color.green)
                                Text(report.summary)
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                        } else {
                            Text("Pulsa ANALYZE LOAD para crear el informe de carga y fatiga del caballo.")
                                .foregroundColor(.gray)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }

                    ProBox("RECOMMENDATIONS") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach((report?.recommendations ?? defaultRecommendations()), id: \.self) { line in
                                    Text("• \(line)")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(width: 360)
                }
            }
            .padding(14)
        }
        .onAppear { if report == nil { report = makeReport() } }
    }

    private func makeReport() -> StableLoadMonitorReport {
        let sorted = sessions.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(7))
        let today = Calendar.current.startOfDay(for: Date())
        let todaySessions = sorted.filter { Calendar.current.startOfDay(for: $0.date) == today }
        let dailyLoad = min(1.0, todaySessions.map { max($0.avgRisk, $0.avgFatigue) }.reduce(0, +) / 2.0 + Double(todaySessions.count) * 0.10)
        let weeklyIntensity = recent.map { ($0.avgRisk + $0.avgFatigue + (1.0 - $0.avgQuality)) / 3.0 }.average
        let weeklyLoad = min(1.0, weeklyIntensity + Double(recent.count) * 0.07)
        let fatigue = min(1.0, recent.map { $0.avgFatigue }.average + weeklyLoad * 0.35)
        let impact = min(1.0, recent.map { $0.avgRisk }.average + Double(recent.count) * 0.04)
        let vetPenalty = vetRecords.contains { $0.severity == .severe || $0.severity == .critical } ? 0.18 : 0.0
        let aiPenalty = (aiReport?.globalRisk ?? 0.0) * 0.22
        let overload = min(1.0, max(dailyLoad * 0.55 + weeklyLoad * 0.45, fatigue * 0.65 + impact * 0.35) + vetPenalty + aiPenalty)
        let level = overload > 0.68 ? "ALTA" : (overload > 0.40 ? "MODERADA" : "CONTROLADA")
        let rest = overload > 0.68 ? 48 : (overload > 0.40 ? 24 : 0)
        let summary = overload > 0.68 ? "Carga alta: bajar intensidad y revisar la próxima sesión antes de progresar." : (overload > 0.40 ? "Carga moderada: mantener control y evitar picos de impacto." : "Carga controlada: el caballo se mantiene dentro de márgenes razonables.")
        return StableLoadMonitorReport(id: UUID(), horseID: profile.id, horseName: profile.name, generatedAt: Date(), sessionsAnalyzed: recent.count, dailyLoad: dailyLoad, weeklyLoad: weeklyLoad, fatigueAccumulated: fatigue, impactAccumulated: impact, overloadRisk: overload, recommendedRestHours: rest, alertLevel: level, summary: summary, recommendations: recommendations(for: overload, rest: rest))
    }

    private func recommendations(for risk: Double, rest: Int) -> [String] {
        if risk > 0.68 {
            return [
                "Reducir carga durante al menos \(rest) horas.",
                "Evitar trabajo de alta intensidad y superficies duras.",
                "Comparar la próxima sesión contra baseline sano.",
                "Revisar historial veterinario si la fatiga o impacto no baja."
            ]
        }
        if risk > 0.40 {
            return [
                "Mantener trabajo controlado sin aumentar volumen.",
                "Registrar siguiente sesión con la misma calibración 3D.",
                "Vigilar asimetría, regularidad y fatiga acumulada."
            ]
        }
        return defaultRecommendations()
    }

    private func defaultRecommendations() -> [String] {
        [
            "Mantener seguimiento semanal de carga.",
            "Usar LiDAR/calibración para comparar métricas reales.",
            "Registrar cambios de superficie, intensidad y descanso."
        ]
    }
}
