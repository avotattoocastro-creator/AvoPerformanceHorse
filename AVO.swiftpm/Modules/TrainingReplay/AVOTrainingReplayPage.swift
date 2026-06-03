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
        sqrt(ax * ax + ay * ay + az * az)
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
    var maxSpeed: Double = 0
    var avgSpeed: Double = 0
    var anomaly = false
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

    private var playTask: Task<Void, Never>?

    init(work: AVOTrainingWorkItem, serverBase: String) {
        self.work = work
        self.serverBase = serverBase
        self.summary.horseId = work.horseId
    }

    var minTime: Double { min(gps.first?.t ?? 0, imu.first?.t ?? 0) }
    var maxTime: Double { max(gps.last?.t ?? 0, imu.last?.t ?? 0) }
    var duration: Double { max(0, maxTime - minTime) }

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
                async let resumenData = AVOTrainingReplayService.fetchOptionalFile(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filename: "resumen.json")
                async let metaData = AVOTrainingReplayService.fetchOptionalFile(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filename: "trabajo_meta.json")
                async let gpsData = AVOTrainingReplayService.fetchOptionalFile(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filename: "gps_rtk.csv")
                async let imuData = AVOTrainingReplayService.fetchOptionalFile(serverBase: serverBase, horseId: work.horseId, workId: work.workId, filename: "imu_chaleco_9ejes.csv")

                let loadedResumen = try await resumenData
                let loadedMeta = try await metaData
                let loadedGPS = try await gpsData
                let loadedIMU = try await imuData

                var nextSummary = AVOTrainingReplayParser.parseSummary(data: loadedMeta) ?? AVOReplaySummary(horseId: work.horseId)
                if let resumen = AVOTrainingReplayParser.parseSummary(data: loadedResumen) {
                    nextSummary.distanceM = resumen.distanceM == 0 ? nextSummary.distanceM : resumen.distanceM
                    nextSummary.maxSpeed = resumen.maxSpeed == 0 ? nextSummary.maxSpeed : resumen.maxSpeed
                    nextSummary.avgSpeed = resumen.avgSpeed == 0 ? nextSummary.avgSpeed : resumen.avgSpeed
                    if !resumen.status.isEmpty { nextSummary.status = resumen.status }
                    nextSummary.anomaly = resumen.anomaly
                    if !resumen.endedAt.isEmpty { nextSummary.endedAt = resumen.endedAt }
                }

                let nextGPS = AVOTrainingReplayParser.parseGPSCSV(data: loadedGPS)
                let nextIMU = AVOTrainingReplayParser.parseIMUCSV(data: loadedIMU)

                await MainActor.run {
                    self.summary = nextSummary
                    self.gps = nextGPS
                    self.imu = nextIMU
                    self.selectedTime = nextGPS.first?.t ?? nextIMU.first?.t ?? 0
                    self.isLoading = false
                    self.loadedFilesText = "GPS \(nextGPS.count) muestras · IMU chaleco \(nextIMU.count) muestras"
                    if nextGPS.isEmpty && nextIMU.isEmpty {
                        self.errorText = "El trabajo existe, pero no se recibieron muestras GPS/IMU."
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
                    if next >= self.maxTime {
                        self.selectedTime = self.minTime
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
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let index = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        func value(_ row: [String], _ key: String) -> String { index[key].flatMap { $0 < row.count ? row[$0] : nil } ?? "" }
        func double(_ row: [String], _ key: String) -> Double { Double(value(row, key).replacingOccurrences(of: ",", with: ".")) ?? 0 }
        func int(_ row: [String], _ key: String) -> Int { Int(Double(value(row, key)) ?? 0) }

        return rows.dropFirst().compactMap { row in
            let lat = double(row, "lat")
            let lon = double(row, "lon")
            if lat == 0 && lon == 0 { return nil }
            return AVOReplayGPSPoint(
                t: double(row, "t"),
                lat: lat,
                lon: lon,
                altM: double(row, "altM"),
                speedKmh: double(row, "speedKmh"),
                distanceM: double(row, "distanceM"),
                fix: value(row, "fix"),
                sat: int(row, "sat"),
                hAccM: double(row, "hAccM"),
                vAccM: double(row, "vAccM"),
                rtcm: value(row, "rtcm")
            )
        }
    }

    static func parseIMUCSV(data: Data?) -> [AVOReplayIMUSample] {
        guard let data, let text = String(data: data, encoding: .utf8) else { return [] }
        let rows = csvRows(text)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let index = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        func value(_ row: [String], _ key: String) -> String { index[key].flatMap { $0 < row.count ? row[$0] : nil } ?? "" }
        func double(_ row: [String], _ key: String) -> Double { Double(value(row, key).replacingOccurrences(of: ",", with: ".")) ?? 0 }

        return rows.dropFirst().map { row in
            AVOReplayIMUSample(
                t: double(row, "t"),
                ax: double(row, "ax"),
                ay: double(row, "ay"),
                az: double(row, "az"),
                gx: double(row, "gx"),
                gy: double(row, "gy"),
                gz: double(row, "gz"),
                mx: double(row, "mx"),
                my: double(row, "my"),
                mz: double(row, "mz")
            )
        }
    }

    static func parseSummary(data: Data?) -> AVOReplaySummary? {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var s = AVOReplaySummary()
        s.horseId = object["horseId"] as? String ?? s.horseId
        s.jockeyId = object["jockeyId"] as? String ?? s.jockeyId
        s.geofence = object["geofence"] as? String ?? s.geofence
        s.status = object["status"] as? String ?? (object["ok"] as? Bool == true ? "ENTRENAMIENTO_OK" : s.status)
        s.startAt = object["startAt"] as? String ?? s.startAt
        s.endedAt = object["endedAt"] as? String ?? object["endAt"] as? String ?? s.endedAt
        s.distanceM = numeric(object["distanceM"])
        s.maxSpeed = numeric(object["maxSpeed"])
        s.avgSpeed = numeric(object["avgSpeed"])
        s.anomaly = object["anomaly"] as? Bool ?? (s.status.uppercased().contains("ANOM"))
        return s
    }

    private static func csvRows(_ text: String) -> [[String]] {
        text
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { line in
                line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            }
    }

    private static func numeric(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) ?? 0 }
        return 0
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
                AVOReplayMetric(title: "TIEMPO", value: AVOReplayFormat.time(vm.selectedTime - vm.minTime), color: .white)
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

                Text(AVOReplayFormat.time(vm.selectedTime - vm.minTime))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 86)

                Slider(value: $vm.selectedTime, in: vm.minTime...max(vm.minTime + 0.1, vm.maxTime))
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
                AVOReplayLineChart(title: "VELOCIDAD", unit: "km/h", selectedTime: vm.selectedTime, values: vm.gps.map { ($0.t, $0.speedKmh) })
                AVOReplayLineChart(title: "ALTITUD", unit: "m", selectedTime: vm.selectedTime, values: vm.gps.map { ($0.t, $0.altM) })
            }
            HStack(spacing: 12) {
                AVOReplayLineChart(title: "PRECISIÓN H", unit: "m", selectedTime: vm.selectedTime, values: vm.gps.map { ($0.t, $0.hAccM) })
                AVOReplayLineChart(title: "IMPACTO CHALECO", unit: "g", selectedTime: vm.selectedTime, values: vm.imu.map { ($0.t, $0.impactG) })
            }
            HStack(spacing: 12) {
                AVOReplayLineChart(title: "ACELERACIÓN X", unit: "g", selectedTime: vm.selectedTime, values: vm.imu.map { ($0.t, $0.ax) })
                AVOReplayLineChart(title: "GIROSCOPIO Y", unit: "°/s", selectedTime: vm.selectedTime, values: vm.imu.map { ($0.t, $0.gy) })
            }
        }
    }
}

struct AVOReplayRouteView: View {
    let points: [AVOReplayGPSPoint]
    let selectedTime: Double

    private var selected: AVOReplayGPSPoint? {
        points.min { abs($0.t - selectedTime) < abs($1.t - selectedTime) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.35)
                AVOReplayRouteCanvas(points: points, selected: selected)
                    .padding(18)
                VStack {
                    HStack {
                        Text("MAPA / RECORRIDO")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.76))
                        Spacer()
                        Text("\(points.count) GPS")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    .padding(14)
                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct AVOReplayRouteCanvas: View {
    let points: [AVOReplayGPSPoint]
    let selected: AVOReplayGPSPoint?

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let lats = points.map(\.lat)
            let lons = points.map(\.lon)
            guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
            let latSpan = max(0.0000001, maxLat - minLat)
            let lonSpan = max(0.0000001, maxLon - minLon)

            func point(_ p: AVOReplayGPSPoint) -> CGPoint {
                let x = ((p.lon - minLon) / lonSpan) * size.width
                let y = size.height - ((p.lat - minLat) / latSpan) * size.height
                return CGPoint(x: x, y: y)
            }

            var path = Path()
            path.move(to: point(points[0]))
            for p in points.dropFirst() { path.addLine(to: point(p)) }
            context.stroke(path, with: .color(.red.opacity(0.88)), lineWidth: 3)

            let start = point(points[0])
            context.fill(Path(ellipseIn: CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)), with: .color(.green))

            if let selected {
                let s = point(selected)
                context.fill(Path(ellipseIn: CGRect(x: s.x - 9, y: s.y - 9, width: 18, height: 18)), with: .color(.white))
                context.stroke(Path(ellipseIn: CGRect(x: s.x - 14, y: s.y - 14, width: 28, height: 28)), with: .color(.red), lineWidth: 3)
            }
        }
    }
}

struct AVOReplayLineChart: View {
    let title: String
    let unit: String
    let selectedTime: Double
    let values: [(Double, Double)]

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
            Canvas { context, size in
                guard values.count > 1 else { return }
                let xs = values.map { $0.0 }
                let ys = values.map { $0.1 }
                guard let minX = xs.min(), let maxX = xs.max(), let minY0 = ys.min(), let maxY0 = ys.max() else { return }
                let minY = minY0 == maxY0 ? minY0 - 1 : minY0
                let maxY = minY0 == maxY0 ? maxY0 + 1 : maxY0
                let spanX = max(0.0001, maxX - minX)
                let spanY = max(0.0001, maxY - minY)

                func cg(_ pair: (Double, Double)) -> CGPoint {
                    CGPoint(
                        x: ((pair.0 - minX) / spanX) * size.width,
                        y: size.height - ((pair.1 - minY) / spanY) * size.height
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
                path.move(to: cg(values[0]))
                for p in values.dropFirst() { path.addLine(to: cg(p)) }
                context.stroke(path, with: .color(.red.opacity(0.95)), lineWidth: 2.2)

                let selectedX = ((selectedTime - minX) / spanX) * size.width
                var cursor = Path()
                cursor.move(to: CGPoint(x: selectedX, y: 0))
                cursor.addLine(to: CGPoint(x: selectedX, y: size.height))
                context.stroke(cursor, with: .color(.white.opacity(0.80)), lineWidth: 1.4)
            }
            .frame(height: 150)
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
