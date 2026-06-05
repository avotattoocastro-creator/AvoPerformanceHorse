import SwiftUI
import Foundation
import MapKit

// MARK: - AVO Training Replay Nuevo
// Sistema independiente para revisar trabajos reales del chaleco/reloj.
// No depende de BiotechReplay ni de los módulos antiguos de revisión.

struct AVOTrainingWorkItem: Identifiable, Hashable {
    let id: String
    let horseId: String
    let workId: String
    let title: String
    let subtitle: String
    let createdText: String

    init(horseId: String, workId: String, title: String? = nil, subtitle: String = "Trabajo real", createdText: String = "") {
        self.id = workId
        self.horseId = horseId
        self.workId = workId
        self.title = title ?? workId
        self.subtitle = subtitle
        self.createdText = createdText
    }
}

struct AVOReplayGPSPoint: Identifiable, Hashable {
    let id = UUID()
    let t: Double
    let lat: Double
    let lon: Double
    let altM: Double
    let speedKmh: Double
    let distanceM: Double
    let fix: String
    let sat: Int
    let hAccM: Double
    let vAccM: Double
    let rtcm: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct AVOReplayIMUSample: Identifiable, Hashable {
    let id = UUID()
    let t: Double
    let ax: Double
    let ay: Double
    let az: Double
    let gx: Double
    let gy: Double
    let gz: Double
    let mx: Double
    let my: Double
    let mz: Double

    var impactG: Double {
        max(0, sqrt(ax * ax + ay * ay + az * az) - 1.0)
    }
}

struct AVOReplaySummary: Hashable {
    var horseId = "HORSE_001"
    var jockeyId = "JOCKEY_001"
    var geofence = "LAREDO3"
    var status = "SIN DATOS"
    var startAt = ""
    var endedAt = ""
    var distanceM: Double = 0
    var durationSeconds: Double = 0
    var maxSpeed: Double = 0
    var avgSpeed: Double = 0
    var anomaly = false
}

extension Array where Element == AVOReplayGPSPoint {
    var replayMapRect: MKMapRect {
        guard !isEmpty else { return MKMapRect.world }
        let pts = self.map { MKMapPoint($0.coordinate) }
        let xs = pts.map(\.x)
        let ys = pts.map(\.y)

        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return MKMapRect.world
        }

        let width = Swift.max(500.0, maxX - minX)
        let height = Swift.max(500.0, maxY - minY)
        let padX = width * 0.20
        let padY = height * 0.20

        return MKMapRect(
            x: minX - padX,
            y: minY - padY,
            width: width + padX * 2.0,
            height: height + padY * 2.0
        )
    }
}

@MainActor
final class AVOTrainingReplayListViewModel: ObservableObject {
    @Published var horseId = UserDefaults.standard.string(forKey: "AVO.trainingReplay.horseId") ?? "HORSE_001"
    @Published var serverBase = UserDefaults.standard.string(forKey: "AVO.trainingReplay.serverBase") ?? "https://live.avoperformance.org"
    @Published var works: [AVOTrainingWorkItem] = []
    @Published var isLoading = false
    @Published var errorText = ""

    func saveSettings() {
        UserDefaults.standard.set(horseId, forKey: "AVO.trainingReplay.horseId")
        UserDefaults.standard.set(serverBase, forKey: "AVO.trainingReplay.serverBase")
    }

    func reload() {
        saveSettings()
        isLoading = true
        errorText = ""
        works = []

        Task {
            do {
                let result = try await AVOTrainingReplayService.fetchWorkList(serverBase: serverBase, horseId: horseId)
                await MainActor.run {
                    self.works = result
                    self.isLoading = false
                    if result.isEmpty { self.errorText = "No hay trabajos para este caballo." }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorText = "No se pudo cargar la lista: \(error.localizedDescription)"
                }
            }
        }
    }
}

@MainActor
final class AVOTrainingReplayDetailViewModel: ObservableObject {
    let work: AVOTrainingWorkItem
    let serverBase: String

    @Published var summary = AVOReplaySummary()
    @Published var gps: [AVOReplayGPSPoint] = []
    @Published var imu: [AVOReplayIMUSample] = []
    @Published var selectedTime: Double = 0
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorText = ""
    @Published var loadedFilesText = ""
    @Published var viewStart: Double = 0
    @Published var viewEnd: Double = 1

    private var playTask: Task<Void, Never>?

    init(work: AVOTrainingWorkItem, serverBase: String) {
        self.work = work
        self.serverBase = serverBase
        self.summary.horseId = work.horseId
    }

    var minTime: Double {
        switch (gps.first?.t, imu.first?.t) {
        case let (g?, i?): return min(g, i)
        case let (g?, nil): return g
        case let (nil, i?): return i
        default: return 0
        }
    }
    var maxTime: Double { Swift.max(gps.last?.t ?? 0, imu.last?.t ?? 0) }

    /// Duración real del replay. Prioriza el resumen del servidor porque algunos CSV antiguos
    /// llegaban con `t` absoluto/epoch y podían dejar la línea de tiempo en 00:00.
    var duration: Double {
        let serverDuration = summary.durationSeconds
        let samplesDuration = max(0, maxTime - minTime)
        return max(0, serverDuration > 0 ? serverDuration : samplesDuration)
    }

    var timelineStart: Double { minTime }
    var timelineEnd: Double { max(timelineStart + max(duration, 0.1), maxTime, timelineStart + 0.1) }
    var relativeSelectedTime: Double { max(0, selectedTime - timelineStart) }

    var selectedGPS: AVOReplayGPSPoint? {
        nearest(gps, time: selectedTime) { $0.t }
    }

    var selectedIMU: AVOReplayIMUSample? {
        nearest(imu, time: selectedTime) { $0.t }
    }

    func load() {
        isLoading = true
        errorText = ""
        loadedFilesText = ""

        Task {
            do {
                // v1.4.6 BUILD61: timeline usa duración real del servidor y elapsedSeconds de CSV.
                // The Raspberry work folder can contain CSV/JSONL instead of the older session.json format.
                async let resumenData = AVOTrainingReplayService.fetchOptionalFileAny(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filenames: ["resumen.json", "summary.json", "session_meta.json", "index.json"])
                async let metaData = AVOTrainingReplayService.fetchOptionalFileAny(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filenames: ["trabajo_meta.json", "work_meta.json", "upload_meta.json", "session_meta.json"])
                async let gpsData = AVOTrainingReplayService.fetchOptionalFileAny(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filenames: ["gps_rtk.csv", "gps.csv", "rtk.csv", "raw_gps.csv"])
                async let imuData = AVOTrainingReplayService.fetchOptionalFileAny(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filenames: ["imu_chaleco_9ejes.csv", "imu_chaleco.csv", "imu_vest.csv", "raw_imu.csv"])
                async let telemetryData = AVOTrainingReplayService.fetchOptionalFileAny(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filenames: ["telemetry_full.jsonl", "telemetry.jsonl", "session.json", "HORSE_001.json"])
                async let rawData = AVOTrainingReplayService.fetchOptionalRawJSONL(serverBase: serverBase, horseId: work.horseId, workId: work.workId)

                let loadedResumen = try await resumenData
                let loadedMeta = try await metaData
                let loadedGPS = try await gpsData
                let loadedIMU = try await imuData
                let loadedTelemetry = try await telemetryData
                let loadedRaw = try await rawData

                var nextSummary = AVOTrainingReplayParser.parseSummary(data: loadedMeta) ?? AVOReplaySummary(horseId: work.horseId)
                if let resumen = AVOTrainingReplayParser.parseSummary(data: loadedResumen) {
                    nextSummary.distanceM = resumen.distanceM == 0 ? nextSummary.distanceM : resumen.distanceM
                    nextSummary.maxSpeed = resumen.maxSpeed == 0 ? nextSummary.maxSpeed : resumen.maxSpeed
                    nextSummary.avgSpeed = resumen.avgSpeed == 0 ? nextSummary.avgSpeed : resumen.avgSpeed
                    nextSummary.durationSeconds = resumen.durationSeconds == 0 ? nextSummary.durationSeconds : resumen.durationSeconds
                    if !resumen.status.isEmpty { nextSummary.status = resumen.status }
                    nextSummary.anomaly = resumen.anomaly
                    if !resumen.endedAt.isEmpty { nextSummary.endedAt = resumen.endedAt }
                }

                var nextGPS = AVOTrainingReplayParser.parseGPSCSV(data: loadedGPS)
                var nextIMU = AVOTrainingReplayParser.parseIMUCSV(data: loadedIMU)

                // Fallbacks for Raspberry WATCH/WORK folders where full telemetry is JSONL.
                if nextGPS.isEmpty {
                    nextGPS = AVOTrainingReplayParser.parseGPSJSONL(data: loadedTelemetry)
                }
                if nextIMU.isEmpty {
                    nextIMU = AVOTrainingReplayParser.parseIMUJSONL(data: loadedTelemetry)
                }
                if nextGPS.isEmpty {
                    nextGPS = AVOTrainingReplayParser.parseGPSJSONL(data: loadedRaw)
                }
                if nextIMU.isEmpty {
                    nextIMU = AVOTrainingReplayParser.parseIMUJSONL(data: loadedRaw)
                }

                if nextSummary.distanceM == 0, let lastDistance = nextGPS.last?.distanceM, lastDistance > 0 {
                    nextSummary.distanceM = lastDistance
                }
                if nextSummary.maxSpeed == 0 {
                    nextSummary.maxSpeed = nextGPS.map(\.speedKmh).max() ?? 0
                }
                if nextSummary.avgSpeed == 0, !nextGPS.isEmpty {
                    nextSummary.avgSpeed = nextGPS.map(\.speedKmh).reduce(0, +) / Double(nextGPS.count)
                }
                if nextSummary.status == "SIN DATOS", (!nextGPS.isEmpty || !nextIMU.isEmpty) {
                    nextSummary.status = "DATOS CARGADOS"
                }

                await MainActor.run {
                    self.summary = nextSummary
                    self.gps = nextGPS
                    self.imu = nextIMU
                    self.selectedTime = nextGPS.first?.t ?? nextIMU.first?.t ?? 0
                    self.viewStart = self.timelineStart
                    self.viewEnd = max(self.timelineStart + 1.0, self.timelineEnd)
                    self.isLoading = false
                    self.loadedFilesText = "GPS \(nextGPS.count) muestras · IMU chaleco \(nextIMU.count) muestras"
                    if nextGPS.isEmpty && nextIMU.isEmpty {
                        self.errorText = "El trabajo existe, pero no se recibieron muestras GPS/IMU. Comprueba gps_rtk.csv, imu_chaleco_9ejes.csv o telemetry_full.jsonl."
                    } else {
                        self.errorText = ""
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorText = "Error cargando entrenamiento: \(error.localizedDescription)"
                }
            }
        }
    }

    func togglePlay() {
        if isPlaying {
            isPlaying = false
            playTask?.cancel()
            playTask = nil
            return
        }

        isPlaying = true
        playTask = Task { [weak self] in
            while let self, await self.isPlaying {
                try? await Task.sleep(nanoseconds: 90_000_000)
                await MainActor.run {
                    let step = max(0.04, self.duration / 900.0)
                    let next = self.selectedTime + step
                    if next >= self.timelineEnd {
                        self.selectedTime = self.timelineStart
                    } else {
                        self.selectedTime = next
                    }
                }
            }
        }
    }

    func stopPlay() {
        isPlaying = false
        playTask?.cancel()
        playTask = nil
    }

    func resetViewport() {
        viewStart = timelineStart
        viewEnd = max(timelineStart + 1.0, timelineEnd)
    }

    func zoomViewport(scale: CGFloat, centerTime: Double) {
        guard duration > 0 else { return }
        let total = max(1.0, duration)
        let currentSpan = max(1.0, viewEnd - viewStart)
        let safeScale = max(0.35, min(8.0, Double(scale)))
        let proposed = max(3.0, min(total, currentSpan / safeScale))
        let half = proposed / 2.0

        var newStart = centerTime - half
        var newEnd = centerTime + half

        if newStart < minTime {
            newStart = minTime
            newEnd = min(timelineEnd, newStart + proposed)
        }
        if newEnd > timelineEnd {
            newEnd = timelineEnd
            newStart = max(timelineStart, newEnd - proposed)
        }

        viewStart = newStart
        viewEnd = max(newStart + 0.1, newEnd)
    }

    func panViewport(deltaSeconds: Double) {
        guard duration > 0 else { return }
        let span = max(1.0, viewEnd - viewStart)
        var newStart = viewStart + deltaSeconds
        var newEnd = viewEnd + deltaSeconds

        if newStart < minTime {
            newStart = timelineStart
            newEnd = newStart + span
        }
        if newEnd > timelineEnd {
            newEnd = timelineEnd
            newStart = max(timelineStart, newEnd - span)
        }

        viewStart = newStart
        viewEnd = newEnd
    }

    private func nearest<T>(_ array: [T], time: Double, key: (T) -> Double) -> T? {
        guard !array.isEmpty else { return nil }
        var best = array[0]
        var bestDelta = abs(key(best) - time)
        for item in array.dropFirst() {
            let delta = abs(key(item) - time)
            if delta < bestDelta {
                best = item
                bestDelta = delta
            }
        }
        return best
    }
}

enum AVOTrainingReplayService {
    static func fetchWorkList(serverBase: String, horseId: String) async throws -> [AVOTrainingWorkItem] {
        let cleanBase = serverBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedHorse = horseId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? horseId
        guard let url = URL(string: "\(cleanBase)/api/work/list?horseId=\(encodedHorse)") else { return [] }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        var ids: [String] = []

        if let array = object as? [String] {
            ids = array
        } else if let dict = object as? [String: Any] {
            if let works = dict["works"] as? [String] {
                ids = works
            } else if let works = dict["works"] as? [[String: Any]] {
                ids = works.compactMap { item in
                    item["workId"] as? String ?? item["id"] as? String ?? item["name"] as? String
                }
            }
        }

        return ids.sorted(by: >).map { workId in
            AVOTrainingWorkItem(
                horseId: horseId,
                workId: workId,
                title: compactTitle(workId),
                subtitle: workId.contains("WATCH") ? "Grabado desde reloj" : "Trabajo real",
                createdText: dateHint(workId)
            )
        }
    }

    static func fetchOptionalFileAny(serverBase: String, horseId: String, workId: String, filenames: [String]) async throws -> Data? {
        for filename in filenames {
            if let data = try await fetchOptionalFile(serverBase: serverBase, horseId: horseId, workId: workId, filename: filename) {
                return data
            }
        }
        return nil
    }

    static func fetchOptionalRawJSONL(serverBase: String, horseId: String, workId: String) async throws -> Data? {
        let candidates = [
            "\(workId)_raw.jsonl",
            "\(horseId)_GF_001_WATCH_raw.jsonl",
            "\(horseId)_WATCH_raw.jsonl",
            "raw.jsonl",
            "training_raw.jsonl"
        ]
        return try await fetchOptionalFileAny(serverBase: serverBase, horseId: horseId, workId: workId, filenames: candidates)
    }

    static func fetchOptionalFile(serverBase: String, horseId: String, workId: String, filename: String) async throws -> Data? {
        for url in candidateFileURLs(serverBase: serverBase, horseId: horseId, workId: workId, filename: filename) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty {
                    return data
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private static func candidateFileURLs(serverBase: String, horseId: String, workId: String, filename: String) -> [URL] {
        let cleanBase = serverBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let qHorse = horseId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? horseId
        let qWork = workId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? workId
        let qFile = filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filename
        let pHorse = horseId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? horseId
        let pWork = workId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? workId
        let pFile = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename

        let strings = [
            "\(cleanBase)/api/work/file?horseId=\(qHorse)&workId=\(qWork)&filename=\(qFile)",
            "\(cleanBase)/api/work/download?horseId=\(qHorse)&workId=\(qWork)&filename=\(qFile)",
            "\(cleanBase)/trabajos/\(pHorse)/\(pWork)/\(pFile)",
            "\(cleanBase)/work/\(pHorse)/\(pWork)/\(pFile)",
            "\(cleanBase)/api/work/detail/\(pHorse)/\(pWork)/\(pFile)"
        ]
        return strings.compactMap(URL.init(string:))
    }

    private static func compactTitle(_ workId: String) -> String {
        let cleaned = workId.replacingOccurrences(of: "HORSE_001_", with: "")
        if cleaned.count > 34 { return String(cleaned.prefix(34)) + "…" }
        return cleaned
    }

    private static func dateHint(_ workId: String) -> String {
        if let range = workId.range(of: #"20\d{6}_\d{6}"#, options: .regularExpression) {
            return String(workId[range])
        }
        return ""
    }
}

enum AVOTrainingReplayParser {
    static func parseGPSCSV(data: Data?) -> [AVOReplayGPSPoint] {
        guard let data, let text = String(data: data, encoding: .utf8) else { return [] }
        let rows = csvRows(text)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { normalizeKey($0) }
        let index = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        func value(_ row: [String], _ keys: [String]) -> String {
            for key in keys {
                let k = normalizeKey(key)
                if let idx = index[k], idx < row.count { return row[idx].trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return ""
        }
        func value(_ row: [String], _ keys: String...) -> String { value(row, keys) }
        func double(_ row: [String], _ keys: [String]) -> Double { parseDouble(value(row, keys)) }
        func double(_ row: [String], _ keys: String...) -> Double { double(row, keys) }
        func int(_ row: [String], _ keys: String...) -> Int { Int(double(row, keys)) }
        func replayTime(_ row: [String], elapsedSecondsKeys: [String], elapsedMsKeys: [String], fallbackKeys: [String]) -> Double {
            let elapsedSeconds = parseDouble(value(row, elapsedSecondsKeys))
            if elapsedSeconds > 0 { return elapsedSeconds }
            let elapsedMs = parseDouble(value(row, elapsedMsKeys))
            if elapsedMs > 0 { return elapsedMs / 1000.0 }
            return parseDouble(value(row, fallbackKeys))
        }

        var out: [AVOReplayGPSPoint] = []
        for row in rows.dropFirst() {
            let lat = double(row, "lat", "latitude")
            let lon = double(row, "lon", "lng", "longitude")
            if lat == 0 && lon == 0 { continue }
            out.append(AVOReplayGPSPoint(
                t: replayTime(row, elapsedSecondsKeys: ["elapsedSeconds", "elapsed", "seconds", "sec"], elapsedMsKeys: ["elapsedMs", "msElapsed", "millis"], fallbackKeys: ["t", "time", "timestamp", "timestampMs", "ms"]),
                lat: lat,
                lon: lon,
                altM: double(row, "altM", "alt", "altitude", "altitudeM"),
                speedKmh: double(row, "speedKmh", "speed", "speedKmH", "kmh"),
                distanceM: double(row, "distanceM", "distM", "distance"),
                fix: value(row, "fix", "gpsFix", "rtk", "quality"),
                sat: int(row, "sat", "sats", "satellites"),
                hAccM: double(row, "hAccM", "hacc", "horizontalAccuracy", "accuracyM"),
                vAccM: double(row, "vAccM", "vacc", "verticalAccuracy"),
                rtcm: value(row, "rtcm", "rtcmBytes", "rtcm_bytes")
            ))
        }
        return normalizeTime(out)
    }

    static func parseIMUCSV(data: Data?) -> [AVOReplayIMUSample] {
        guard let data, let text = String(data: data, encoding: .utf8) else { return [] }
        let rows = csvRows(text)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { normalizeKey($0) }
        let index = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        func value(_ row: [String], _ keys: [String]) -> String {
            for key in keys {
                let k = normalizeKey(key)
                if let idx = index[k], idx < row.count { return row[idx].trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return ""
        }
        func value(_ row: [String], _ keys: String...) -> String { value(row, keys) }
        func double(_ row: [String], _ keys: String...) -> Double { parseDouble(value(row, keys)) }
        func replayTime(_ row: [String], elapsedSecondsKeys: [String], elapsedMsKeys: [String], fallbackKeys: [String]) -> Double {
            let elapsedSeconds = parseDouble(value(row, elapsedSecondsKeys))
            if elapsedSeconds > 0 { return elapsedSeconds }
            let elapsedMs = parseDouble(value(row, elapsedMsKeys))
            if elapsedMs > 0 { return elapsedMs / 1000.0 }
            return parseDouble(value(row, fallbackKeys))
        }

        var out: [AVOReplayIMUSample] = []
        for row in rows.dropFirst() {
            let ax = double(row, "ax", "accX", "accelX")
            let ay = double(row, "ay", "accY", "accelY")
            let az = double(row, "az", "accZ", "accelZ")
            let gx = double(row, "gx", "gyroX")
            let gy = double(row, "gy", "gyroY")
            let gz = double(row, "gz", "gyroZ")
            let mx = double(row, "mx", "magX")
            let my = double(row, "my", "magY")
            let mz = double(row, "mz", "magZ")
            if ax == 0 && ay == 0 && az == 0 && gx == 0 && gy == 0 && gz == 0 && mx == 0 && my == 0 && mz == 0 { continue }
            out.append(AVOReplayIMUSample(
                t: replayTime(row, elapsedSecondsKeys: ["elapsedSeconds", "elapsed", "seconds", "sec"], elapsedMsKeys: ["elapsedMs", "msElapsed", "millis"], fallbackKeys: ["t", "time", "timestamp", "timestampMs", "ms"]),
                ax: ax,
                ay: ay,
                az: az,
                gx: gx,
                gy: gy,
                gz: gz,
                mx: mx,
                my: my,
                mz: mz
            ))
        }
        return normalizeTime(out)
    }

    static func parseGPSJSONL(data: Data?) -> [AVOReplayGPSPoint] {
        guard let data, let text = String(data: data, encoding: .utf8) else { return [] }
        var out: [AVOReplayGPSPoint] = []
        for obj in jsonObjects(text) {
            let gps = dict(obj["gps"]) ?? obj
            let lat = numeric(gps["lat"] ?? gps["latitude"])
            let lon = numeric(gps["lon"] ?? gps["lng"] ?? gps["longitude"])
            if lat == 0 && lon == 0 { continue }
            out.append(AVOReplayGPSPoint(
                t: replayTime(obj: obj, nested: gps),
                lat: lat,
                lon: lon,
                altM: numeric(gps["altM"] ?? gps["alt"] ?? gps["altitude"]),
                speedKmh: numeric(gps["speedKmh"] ?? gps["speed"] ?? obj["speedKmh"] ?? obj["speed"]),
                distanceM: numeric(gps["distanceM"] ?? obj["distanceM"] ?? obj["distance"]),
                fix: string(gps["fix"] ?? gps["gpsFix"] ?? obj["fix"]),
                sat: Int(numeric(gps["sat"] ?? gps["sats"] ?? gps["satellites"] ?? obj["sat"])),
                hAccM: numeric(gps["hAccM"] ?? gps["hAcc"] ?? gps["haccM"] ?? obj["hAccM"]),
                vAccM: numeric(gps["vAccM"] ?? gps["vAcc"] ?? gps["vaccM"] ?? obj["vAccM"]),
                rtcm: string(gps["rtcm"] ?? gps["rtcmBytes"] ?? obj["rtcmBytes"])
            ))
        }
        return normalizeTime(out)
    }

    static func parseIMUJSONL(data: Data?) -> [AVOReplayIMUSample] {
        guard let data, let text = String(data: data, encoding: .utf8) else { return [] }
        var out: [AVOReplayIMUSample] = []
        for obj in jsonObjects(text) {
            let imu = dict(obj["imu"] ?? obj["imu_chaleco"] ?? obj["vestImu"]) ?? obj
            let ax = numeric(imu["ax"] ?? imu["accX"])
            let ay = numeric(imu["ay"] ?? imu["accY"])
            let az = numeric(imu["az"] ?? imu["accZ"])
            let gx = numeric(imu["gx"] ?? imu["gyroX"])
            let gy = numeric(imu["gy"] ?? imu["gyroY"])
            let gz = numeric(imu["gz"] ?? imu["gyroZ"])
            let mx = numeric(imu["mx"] ?? imu["magX"])
            let my = numeric(imu["my"] ?? imu["magY"])
            let mz = numeric(imu["mz"] ?? imu["magZ"])
            if ax == 0 && ay == 0 && az == 0 && gx == 0 && gy == 0 && gz == 0 && mx == 0 && my == 0 && mz == 0 { continue }
            out.append(AVOReplayIMUSample(
                t: replayTime(obj: obj, nested: imu),
                ax: ax,
                ay: ay,
                az: az,
                gx: gx,
                gy: gy,
                gz: gz,
                mx: mx,
                my: my,
                mz: mz
            ))
        }
        return normalizeTime(out)
    }

    static func parseSummary(data: Data?) -> AVOReplaySummary? {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var s = AVOReplaySummary()
        s.horseId = object["horseId"] as? String ?? s.horseId
        s.jockeyId = object["jockeyId"] as? String ?? object["riderId"] as? String ?? s.jockeyId
        if let gf = object["geofence"] as? String {
            s.geofence = gf
        } else if let gf = object["geofence"] as? [String: Any] {
            s.geofence = gf["name"] as? String ?? gf["id"] as? String ?? s.geofence
        }
        s.status = object["status"] as? String ?? (object["ok"] as? Bool == true ? "ENTRENAMIENTO_OK" : s.status)
        s.startAt = object["startAt"] as? String ?? object["startedAt"] as? String ?? s.startAt
        s.endedAt = object["endedAt"] as? String ?? object["endAt"] as? String ?? s.endedAt
        s.distanceM = numeric(object["distanceM"] ?? object["distance"])
        if s.distanceM == 0 { s.distanceM = numeric(object["distanceKm"]) * 1000.0 }
        s.durationSeconds = numeric(
            object["timelineDurationSeconds"] ??
            object["durationSeconds"] ??
            object["totalDurationSeconds"] ??
            object["replayDurationSeconds"] ??
            object["playbackDurationSeconds"] ??
            object["duration"] ??
            object["totalDuration"]
        )
        if s.durationSeconds == 0 {
            let ms = numeric(object["durationMs"] ?? object["totalDurationMs"] ?? object["durationMilliseconds"])
            if ms > 0 { s.durationSeconds = ms / 1000.0 }
        }
        s.maxSpeed = numeric(object["maxSpeed"] ?? object["maxSpeedKmh"])
        s.avgSpeed = numeric(object["avgSpeed"] ?? object["avgSpeedKmh"])
        s.anomaly = object["anomaly"] as? Bool ?? (s.status.uppercased().contains("ANOM"))
        return s
    }

    private static func csvRows(_ text: String) -> [[String]] {
        let clean = text.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(of: "\r", with: "")
        let firstLine = clean.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let delimiter: Character = firstLine.contains(";") && !firstLine.contains(",") ? ";" : ","
        return clean
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { line in
                line.split(separator: delimiter, omittingEmptySubsequences: false).map(String.init)
            }
    }

    private static func jsonObjects(_ text: String) -> [[String: Any]] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") {
            if let data = trimmed.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return array
            }
        }
        return trimmed
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                guard let data = String(line).data(using: .utf8) else { return nil }
                return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
    }

    private static func normalizeKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{feff}", with: "").lowercased()
    }

    private static func parseDouble(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private static func numeric(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? String { return parseDouble(value) }
        return 0
    }

    private static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value { return "\(value)" }
        return ""
    }

    private static func dict(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func replayTime(obj: [String: Any], nested: [String: Any]) -> Double {
        let elapsedSeconds = numeric(obj["elapsedSeconds"] ?? obj["elapsed"] ?? obj["seconds"] ?? nested["elapsedSeconds"] ?? nested["elapsed"])
        if elapsedSeconds > 0 { return elapsedSeconds }
        let elapsedMs = numeric(obj["elapsedMs"] ?? obj["elapsedMilliseconds"] ?? nested["elapsedMs"] ?? nested["elapsedMilliseconds"])
        if elapsedMs > 0 { return elapsedMs / 1000.0 }
        return numeric(obj["t"] ?? obj["time"] ?? obj["timestampMs"] ?? obj["timestamp"] ?? nested["t"] ?? nested["time"] ?? nested["timestampMs"] ?? nested["timestamp"])
    }

    private static func normalizeTime(_ gps: [AVOReplayGPSPoint]) -> [AVOReplayGPSPoint] {
        guard let first = gps.first else { return gps }
        let firstT = first.t
        return gps.map { p in
            let t: Double
            if firstT > 1_000_000_000_000 {
                // Epoch en milisegundos.
                t = (p.t - firstT) / 1000.0
            } else if firstT > 1_000_000_000 {
                // Epoch en segundos.
                t = p.t - firstT
            } else if firstT > 10_000 {
                // Tiempo relativo en milisegundos.
                t = (p.t - firstT) / 1000.0
            } else {
                // Ya viene en segundos relativos.
                t = p.t
            }
            return AVOReplayGPSPoint(t: max(0, t), lat: p.lat, lon: p.lon, altM: p.altM, speedKmh: p.speedKmh, distanceM: p.distanceM, fix: p.fix, sat: p.sat, hAccM: p.hAccM, vAccM: p.vAccM, rtcm: p.rtcm)
        }
    }

    private static func normalizeTime(_ imu: [AVOReplayIMUSample]) -> [AVOReplayIMUSample] {
        guard let first = imu.first else { return imu }
        let firstT = first.t
        return imu.map { p in
            let t: Double
            if firstT > 1_000_000_000_000 {
                t = (p.t - firstT) / 1000.0
            } else if firstT > 1_000_000_000 {
                t = p.t - firstT
            } else if firstT > 10_000 {
                t = (p.t - firstT) / 1000.0
            } else {
                t = p.t
            }
            return AVOReplayIMUSample(t: max(0, t), ax: p.ax, ay: p.ay, az: p.az, gx: p.gx, gy: p.gy, gz: p.gz, mx: p.mx, my: p.my, mz: p.mz)
        }
    }
}
struct AVOTrainingReplayListPage: View {
    @ObservedObject var hardware: AVOHardwareReceiver
    @StateObject private var vm = AVOTrainingReplayListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWork: AVOTrainingWorkItem?

    var body: some View {
        NavigationView {
            ZStack {
                AVOReplayBackground()
                VStack(spacing: 14) {
                    header
                    connectionPanel
                    if vm.isLoading { ProgressView().tint(.red).padding(.top, 20) }
                    if !vm.errorText.isEmpty { Text(vm.errorText).foregroundStyle(.orange).font(.system(size: 13, weight: .bold, design: .monospaced)) }
                    workList
                }
                .padding(18)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(item: $selectedWork) { work in
            AVOTrainingReplayDetailPage(work: work, serverBase: vm.serverBase)
        }
        .onAppear {
            if vm.works.isEmpty { vm.reload() }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("TRAINING REPLAY")
                    .font(.system(size: 27, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Trabajos reales del chaleco · GPS/RTK + IMU + línea de tiempo")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(hardware.serverVestConnected ? "CHALECO ONLINE" : "SERVIDOR")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(hardware.serverVestConnected ? .green : .red)
                Text(hardware.gpsFix)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }

    private var connectionPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AVOReplayTextField(title: "Servidor", text: $vm.serverBase)
                AVOReplayTextField(title: "Caballo", text: $vm.horseId)
                Button { vm.reload() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("CARGAR")
                    }
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 52)
                    .background(LinearGradient(colors: [.red.opacity(0.90), .red.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var workList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(vm.works) { work in
                    Button { selectedWork = work } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Color.red.opacity(0.20)).frame(width: 48, height: 48)
                                Image(systemName: "waveform.path.ecg.rectangle")
                                    .font(.system(size: 21, weight: .black))
                                    .foregroundStyle(.red)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(work.title)
                                    .font(.system(size: 15, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(work.subtitle)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.58))
                                if !work.createdText.isEmpty {
                                    Text(work.createdText)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.red.opacity(0.85))
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.48))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }
}

struct AVOTrainingReplayDetailPage: View {
    @StateObject private var vm: AVOTrainingReplayDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(work: AVOTrainingWorkItem, serverBase: String) {
        _vm = StateObject(wrappedValue: AVOTrainingReplayDetailViewModel(work: work, serverBase: serverBase))
    }

    var body: some View {
        ZStack {
            AVOReplayBackground()
            VStack(spacing: 12) {
                topBar
                if vm.isLoading {
                    Spacer()
                    ProgressView("Cargando trabajo real…")
                        .tint(.red)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            summaryStrip
                            mapAndLivePanel
                            timeline
                            charts
                            if !vm.errorText.isEmpty {
                                Text(vm.errorText)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(14)
        }
        .onAppear { vm.load() }
        .onDisappear { vm.stopPlay() }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("REPLAY ENTRENAMIENTO")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(vm.work.workId)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer()
            Text(vm.loadedFilesText)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
        }
    }

    private var summaryStrip: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AVOReplayMetric(title: "CABALLO", value: vm.summary.horseId, color: .white)
                AVOReplayMetric(title: "JOCKEY", value: vm.summary.jockeyId, color: .white)
                AVOReplayMetric(title: "ZONA", value: vm.summary.geofence, color: .red)
                AVOReplayMetric(title: "ESTADO", value: vm.summary.status, color: vm.summary.anomaly ? .red : .green)
            }
            HStack(spacing: 10) {
                AVOReplayMetric(title: "DISTANCIA", value: "\(Int(vm.summary.distanceM)) m", color: .white)
                AVOReplayMetric(title: "MAX", value: String(format: "%.1f km/h", vm.summary.maxSpeed), color: .red)
                AVOReplayMetric(title: "MEDIA", value: String(format: "%.1f km/h", vm.summary.avgSpeed), color: .green)
                AVOReplayMetric(title: "MUESTRAS", value: "GPS \(vm.gps.count) · IMU \(vm.imu.count)", color: .white)
            }
        }
    }

    private var mapAndLivePanel: some View {
        HStack(spacing: 12) {
            AVOReplayRouteView(points: vm.gps, selectedTime: vm.selectedTime)
                .frame(height: 330)
                .background(Color.black.opacity(0.46))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.12), lineWidth: 1))

            VStack(spacing: 10) {
                AVOReplayMetric(title: "TIEMPO", value: AVOReplayFormat.time(vm.relativeSelectedTime), color: .white)
                AVOReplayMetric(title: "VELOCIDAD", value: String(format: "%.1f km/h", vm.selectedGPS?.speedKmh ?? 0), color: .red)
                AVOReplayMetric(title: "SAT", value: "\(vm.selectedGPS?.sat ?? 0)", color: .green)
                AVOReplayMetric(title: "RTK", value: vm.selectedGPS?.fix ?? "NO", color: (vm.selectedGPS?.fix.uppercased().contains("RTCM") ?? false) ? .green : .orange)
                AVOReplayMetric(title: "IMPACTO", value: String(format: "%.2f g", vm.selectedIMU?.impactG ?? 0), color: .orange)
            }
            .frame(width: 230)
        }
    }

    private var timeline: some View {
        VStack(spacing: 8) {
            HStack {
                Button { vm.togglePlay() } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 40)
                        .background(Color.red.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Text(AVOReplayFormat.time(vm.relativeSelectedTime))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 86)

                Slider(value: $vm.selectedTime, in: vm.timelineStart...vm.timelineEnd)
                    .tint(.red)

                Text(AVOReplayFormat.time(vm.duration))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 86)
            }
            Text("LÍNEA DE TIEMPO ÚNICA · mapa y gráficos sincronizados")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.black.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var charts: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                replayChart(title: "VELOCIDAD", unit: "km/h", values: vm.gps.map { ($0.t, $0.speedKmh) })
                replayChart(title: "ALTITUD", unit: "m", values: vm.gps.map { ($0.t, $0.altM) })
            }
            HStack(spacing: 12) {
                replayChart(title: "PRECISIÓN H", unit: "m", values: vm.gps.map { ($0.t, $0.hAccM) })
                replayChart(title: "IMPACTO CHALECO", unit: "g", values: vm.imu.map { ($0.t, $0.impactG) })
            }
            HStack(spacing: 12) {
                replayChart(title: "ACELERACIÓN X", unit: "g", values: vm.imu.map { ($0.t, $0.ax) })
                replayChart(title: "GIROSCOPIO Y", unit: "°/s", values: vm.imu.map { ($0.t, $0.gy) })
            }
        }
    }

    private func replayChart(title: String, unit: String, values: [(Double, Double)]) -> some View {
        AVOReplayLineChart(
            title: title,
            unit: unit,
            selectedTime: vm.selectedTime,
            values: values,
            viewStart: $vm.viewStart,
            viewEnd: $vm.viewEnd,
            minTime: vm.timelineStart,
            maxTime: vm.timelineEnd,
            onSelectTime: { vm.selectedTime = $0 },
            onZoom: { scale, center in vm.zoomViewport(scale: scale, centerTime: center) },
            onPan: { delta in vm.panViewport(deltaSeconds: delta) },
            onReset: { vm.resetViewport() }
        )
    }
}

struct AVOReplayRouteView: View {
    let points: [AVOReplayGPSPoint]
    let selectedTime: Double

    @State private var cameraPosition: MapCameraPosition = .automatic

    private var selected: AVOReplayGPSPoint? {
        points.min { abs($0.t - selectedTime) < abs($1.t - selectedTime) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if points.isEmpty {
                Color.black.opacity(0.35)
            } else {
                Map(position: $cameraPosition, interactionModes: .all) {
                    if points.count > 1 {
                        MapPolyline(coordinates: points.map(\.coordinate))
                            .stroke(.red, lineWidth: 4)
                    }

                    if let first = points.first {
                        Annotation("INICIO", coordinate: first.coordinate) {
                            Circle()
                                .fill(.green)
                                .frame(width: 12, height: 12)
                        }
                    }

                    if let selected {
                        Annotation("", coordinate: selected.coordinate) {
                            ZStack {
                                Circle().fill(.white).frame(width: 16, height: 16)
                                Circle().stroke(.red, lineWidth: 3).frame(width: 28, height: 28)
                            }
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .onAppear {
                    cameraPosition = .rect(points.replayMapRect)
                }
                .onChange(of: points.count) { _, _ in
                    if !points.isEmpty { cameraPosition = .rect(points.replayMapRect) }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("MAPA REAL / RECORRIDO")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text("\(points.count) GPS")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                }

                Button {
                    if !points.isEmpty { cameraPosition = .rect(points.replayMapRect) }
                } label: {
                    Text("REENCUADRAR")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
    }
}

struct AVOReplayLineChart: View {
    let title: String
    let unit: String
    let selectedTime: Double
    let values: [(Double, Double)]
    @Binding var viewStart: Double
    @Binding var viewEnd: Double
    let minTime: Double
    let maxTime: Double
    let onSelectTime: (Double) -> Void
    let onZoom: (CGFloat, Double) -> Void
    let onPan: (Double) -> Void
    let onReset: () -> Void

    @State private var lastMagnification: CGFloat = 1.0

    private var visibleValues: [(Double, Double)] {
        values.filter { $0.0 >= viewStart && $0.0 <= viewEnd }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text(currentText)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.red)
            }

            GeometryReader { geo in
                Canvas { context, size in
                    let drawValues = visibleValues.count > 1 ? visibleValues : values
                    guard drawValues.count > 1 else { return }
                    let xs = drawValues.map { $0.0 }
                    let ys = drawValues.map { $0.1 }
                    guard let minX = xs.min(), let maxX = xs.max(), let minY0 = ys.min(), let maxY0 = ys.max() else { return }
                    let minY = minY0 == maxY0 ? minY0 - 1.0 : minY0
                    let maxY = minY0 == maxY0 ? maxY0 + 1.0 : maxY0
                    let spanX = max(0.0001, maxX - minX)
                    let spanY = max(0.0001, maxY - minY)

                    func cg(_ pair: (Double, Double)) -> CGPoint {
                        CGPoint(
                            x: CGFloat((pair.0 - minX) / spanX) * size.width,
                            y: size.height - CGFloat((pair.1 - minY) / spanY) * size.height
                        )
                    }

                    var grid = Path()
                    for i in 0...4 {
                        let y = size.height * CGFloat(i) / 4.0
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)

                    var path = Path()
                    path.move(to: cg(drawValues[0]))
                    for p in drawValues.dropFirst() { path.addLine(to: cg(p)) }
                    context.stroke(path, with: .color(.red.opacity(0.95)), lineWidth: 2.2)

                    let selectedX = CGFloat((selectedTime - minX) / spanX) * size.width
                    var cursor = Path()
                    cursor.move(to: CGPoint(x: selectedX, y: 0))
                    cursor.addLine(to: CGPoint(x: selectedX, y: size.height))
                    context.stroke(cursor, with: .color(.white.opacity(0.85)), lineWidth: 1.4)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let width = max(1.0, geo.size.width)
                            let fraction = max(0.0, min(1.0, value.location.x / width))
                            let time = viewStart + (viewEnd - viewStart) * Double(fraction)
                            onSelectTime(time)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            let relative = scale / max(0.0001, lastMagnification)
                            lastMagnification = scale
                            let center = (viewStart + viewEnd) / 2.0
                            onZoom(relative, center)
                        }
                        .onEnded { _ in
                            lastMagnification = 1.0
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onEnded { value in
                            let secondsPerPoint = (viewEnd - viewStart) / max(1.0, Double(geo.size.width))
                            onPan(-Double(value.translation.width) * secondsPerPoint)
                        }
                )
                .onTapGesture(count: 2) { onReset() }
            }
            .frame(height: 150)

            HStack {
                Text("ZOOM \(AVOReplayFormat.time(viewStart - minTime))-\(AVOReplayFormat.time(viewEnd - minTime))")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
                Text("doble toque reset")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
            }
        }
        .padding(13)
        .background(Color.black.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var currentText: String {
        guard let nearest = values.min(by: { abs($0.0 - selectedTime) < abs($1.0 - selectedTime) }) else { return "-- \(unit)" }
        return String(format: "%.2f %@", nearest.1, unit)
    }
}

struct AVOReplayMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.50))
            Text(value)
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

struct AVOReplayTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct AVOReplayBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.01, blue: 0.015), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ForEach(0..<22, id: \.self) { i in
                Rectangle()
                    .fill(Color.red.opacity(i % 2 == 0 ? 0.045 : 0.020))
                    .frame(height: 1.4)
                    .rotationEffect(.degrees(-18))
                    .offset(y: CGFloat(i * 54 - 620))
            }
        }
    }
}

enum AVOReplayFormat {
    static func time(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}
