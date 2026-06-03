import Foundation
import SwiftUI
import CoreLocation

// MARK: - HARDWARE PHASE 127
// TELEMETRY HUB COMPLETE SYSTEM
//
// Closes the hardware telemetry path:
// ESP32/LoRa/GPS/IMU/NFC packets -> normalized telemetry -> DataBus -> Storage -> BIOTECH.

public enum AVOHardwareLinkState: String, Codable, CaseIterable, Hashable {
    case offline
    case waiting
    case connected
    case weakSignal
    case recording
    case error
}

public struct AVOHorseHardwarePacket: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var timestamp: Date
    public var sequence: Int
    public var latitude: Double?
    public var longitude: Double?
    public var heartRate: Double?
    public var speed: Double?
    public var cadence: Double?
    public var rssi: Double?
    public var battery: Double?
    public var pitch: Double?
    public var roll: Double?
    public var impact: Double?
    public var horseId: String?
    public var riderId: String?
    public var imu: [Double]
    public var source: String

    public init(timestamp: Date = Date(),
                sequence: Int,
                latitude: Double? = nil,
                longitude: Double? = nil,
                heartRate: Double? = nil,
                speed: Double? = nil,
                cadence: Double? = nil,
                rssi: Double? = nil,
                battery: Double? = nil,
                pitch: Double? = nil,
                roll: Double? = nil,
                impact: Double? = nil,
                horseId: String? = nil,
                riderId: String? = nil,
                imu: [Double] = [],
                source: String = "unknown") {
        self.timestamp = timestamp
        self.sequence = sequence
        self.latitude = latitude
        self.longitude = longitude
        self.heartRate = heartRate
        self.speed = speed
        self.cadence = cadence
        self.rssi = rssi
        self.battery = battery
        self.pitch = pitch
        self.roll = roll
        self.impact = impact
        self.horseId = horseId
        self.riderId = riderId
        self.imu = imu
        self.source = source
    }
}

public struct AVOTelemetrySessionSummary: Codable, Hashable {
    public var phase: String
    public var horseName: String
    public var packetCount: Int
    public var averageRSSI: Double
    public var averageSpeed: Double
    public var averageHeartRate: Double
    public var maxImpact: Double
    public var lowBatteryEvents: Int
    public var weakSignalEvents: Int
    public var createdAt: Date
}

@MainActor
public final class AVOHardwareTelemetryHub: ObservableObject {

    public static let shared = AVOHardwareTelemetryHub()

    @Published public private(set) var linkState: AVOHardwareLinkState = .waiting
    @Published public private(set) var status: String = "HARDWARE TELEMETRY READY"
    @Published public private(set) var packets: [AVOHorseHardwarePacket] = []
    @Published public private(set) var latestPacket: AVOHorseHardwarePacket?
    @Published public private(set) var selectedHorseName: String = "SIN_CABALLO"
    @Published public private(set) var selectedRiderId: String = "SIN_JINETE"
    @Published public private(set) var lastExportURL: URL?

    public var maxPacketsInMemory: Int = 36000

    private let storage = AVOStorageEngine.shared
    private let dataBus = AVOSystemDataBus.shared
    private let biotech = BiotechCompleteSystemController.shared

    private init() {}

    public func selectHorse(name: String, horseId: String? = nil) {
        selectedHorseName = clean(name.isEmpty ? "SIN_CABALLO" : name)
        BiotechHorseSessionRecorder.shared.setSelectedHorse(selectedHorseName)
        biotech.prepare(horseName: selectedHorseName)
        status = "HORSE TELEMETRY SELECTED: \(selectedHorseName)"
    }

    public func selectRider(id: String) {
        selectedRiderId = id.isEmpty ? "SIN_JINETE" : id
        status = "RIDER SELECTED: \(selectedRiderId)"
    }

    public func ingest(packet: AVOHorseHardwarePacket) {
        latestPacket = packet
        packets.append(packet)

        if packets.count > maxPacketsInMemory {
            packets.removeFirst(packets.count - maxPacketsInMemory)
        }

        linkState = classifyLink(packet)
        status = "PACKET \(packet.sequence) · \(linkState.rawValue.uppercased())"

        publishToDataBus(packet)
    }

    public func ingestProtocolLine(_ line: String) {
        guard let packet = parseProtocolLine(line) else {
            linkState = .error
            status = "PACKET PARSE ERROR"
            return
        }
        ingest(packet: packet)
    }

    public func startRecording() {
        linkState = .recording
        status = "HARDWARE RECORDING"
    }

    public func stopRecording() {
        exportSessionTelemetry()
        linkState = .connected
        status = "HARDWARE RECORDING STOPPED"
    }

    public func clear() {
        packets.removeAll()
        latestPacket = nil
        linkState = .waiting
        status = "HARDWARE BUFFER CLEARED"
    }

    public func buildSummary() -> AVOTelemetrySessionSummary {
        let rssiValues = packets.compactMap(\.rssi)
        let speedValues = packets.compactMap(\.speed)
        let hrValues = packets.compactMap(\.heartRate)
        let impacts = packets.compactMap(\.impact)

        return AVOTelemetrySessionSummary(
            phase: "127",
            horseName: selectedHorseName,
            packetCount: packets.count,
            averageRSSI: average(rssiValues),
            averageSpeed: average(speedValues),
            averageHeartRate: average(hrValues),
            maxImpact: impacts.max() ?? 0,
            lowBatteryEvents: packets.filter { ($0.battery ?? 100) < 20 }.count,
            weakSignalEvents: packets.filter { ($0.rssi ?? 0) < -105 }.count,
            createdAt: Date()
        )
    }

    public func exportSessionTelemetry() {
        do {
            let telemetryCSV = exportCSV()
            let url = try storage.writeText(
                telemetryCSV,
                area: .analytics,
                horseName: selectedHorseName,
                fileName: "hardware_telemetry_packets.csv"
            )

            let summaryURL = try storage.folder(for: .manifests, horseName: selectedHorseName)
                .appendingPathComponent("hardware_telemetry_summary.json")

            try storage.writeJSON(buildSummary(), to: summaryURL)
            lastExportURL = url
            status = "HARDWARE TELEMETRY EXPORTED"
        } catch {
            status = "HARDWARE EXPORT ERROR: \(error.localizedDescription)"
        }
    }

    public func exportCSV() -> String {
        var rows = ["time,seq,lat,lon,hr,speed,cadence,rssi,battery,pitch,roll,impact,horse,rider,source"]

        let formatter = ISO8601DateFormatter()

        for p in packets {
            rows.append([
                formatter.string(from: p.timestamp),
                String(p.sequence),
                opt(p.latitude),
                opt(p.longitude),
                opt(p.heartRate),
                opt(p.speed),
                opt(p.cadence),
                opt(p.rssi),
                opt(p.battery),
                opt(p.pitch),
                opt(p.roll),
                opt(p.impact),
                p.horseId ?? selectedHorseName,
                p.riderId ?? selectedRiderId,
                p.source
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    public func parseProtocolLine(_ line: String) -> AVOHorseHardwarePacket? {
        // Expected:
        // PROTO: t,seq,lat,lon,pulse,speed,cadence,rssi,battery,pitch,roll,impact,horse,rider,imu[]
        let cleanLine = line
            .replacingOccurrences(of: "PROTO:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleanLine.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count >= 12 else { return nil }

        let seq = Int(parts[safe: 1] ?? "0") ?? packets.count + 1

        let imuValues: [Double]
        if parts.count > 14 {
            imuValues = parts.dropFirst(14).compactMap { Double($0.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")) }
        } else {
            imuValues = []
        }

        return AVOHorseHardwarePacket(
            timestamp: Date(),
            sequence: seq,
            latitude: Double(parts[safe: 2] ?? ""),
            longitude: Double(parts[safe: 3] ?? ""),
            heartRate: Double(parts[safe: 4] ?? ""),
            speed: Double(parts[safe: 5] ?? ""),
            cadence: Double(parts[safe: 6] ?? ""),
            rssi: Double(parts[safe: 7] ?? ""),
            battery: Double(parts[safe: 8] ?? ""),
            pitch: Double(parts[safe: 9] ?? ""),
            roll: Double(parts[safe: 10] ?? ""),
            impact: Double(parts[safe: 11] ?? ""),
            horseId: parts[safe: 12],
            riderId: parts[safe: 13],
            imu: imuValues,
            source: "hardware-proto"
        )
    }

    private func classifyLink(_ packet: AVOHorseHardwarePacket) -> AVOHardwareLinkState {
        if let battery = packet.battery, battery <= 5 { return .error }
        if let rssi = packet.rssi, rssi < -112 { return .weakSignal }
        return .connected
    }

    private func publishToDataBus(_ packet: AVOHorseHardwarePacket) {
        dataBus.setArea(.hardware)
        dataBus.setMode(.idle)
    }

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func opt(_ value: Double?) -> String {
        value == nil ? "" : String(value!)
    }

    private func clean(_ value: String) -> String {
        value.replacingOccurrences(of: " ", with: "_")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

@MainActor
public struct AVOHardwareTelemetryHubPanel: View {

    @ObservedObject private var hub = AVOHardwareTelemetryHub.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HARDWARE TELEMETRY HUB")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            HStack {
                metric("STATE", hub.linkState.rawValue.uppercased())
                metric("PKT", "\(hub.packets.count)")
                metric("RSSI", hub.latestPacket?.rssi == nil ? "--" : String(format: "%.0f", hub.latestPacket!.rssi!))
                metric("BAT", hub.latestPacket?.battery == nil ? "--" : String(format: "%.0f%%", hub.latestPacket!.battery!))
            }

            Text(hub.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)

            HStack {
                Button("REC HW") { hub.startRecording() }
                    .buttonStyle(.borderedProminent)

                Button("STOP") { hub.stopRecording() }
                    .buttonStyle(.bordered)

                Button("EXPORT") { hub.exportSessionTelemetry() }
                    .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))
        }
        .padding(12)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
