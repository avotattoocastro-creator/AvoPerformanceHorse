import Foundation

// MARK: - HARDWARE PHASE 127
// TELEMETRY FUSION COMPLETE
//
// Converts hardware packets into BIOTECH-ready metrics.

public struct AVOTelemetryFusionFrame: Codable, Hashable, Identifiable {
    public var id = UUID()
    public var packetSequence: Int
    public var speed: Double
    public var heartRate: Double
    public var cadence: Double
    public var impact: Double
    public var loadScore: Double
    public var fatigueCandidate: Double
    public var riskScore: Double
    public var notes: [String]
}

@MainActor
public final class AVOTelemetryFusionEngine {

    public init() {}

    public func fuse(packet: AVOHorseHardwarePacket) -> AVOTelemetryFusionFrame {
        let speed = packet.speed ?? 0
        let hr = packet.heartRate ?? 0
        let cadence = packet.cadence ?? 0
        let impact = packet.impact ?? 0

        let load = min(1, (speed / 18.0) * 0.35 + (hr / 220.0) * 0.35 + (impact / 8.0) * 0.30)
        let fatigue = min(1, (hr / 220.0) * 0.45 + (cadence / 180.0) * 0.25 + (impact / 8.0) * 0.30)
        let risk = min(1, fatigue * 0.45 + load * 0.35 + (impact / 10.0) * 0.20)

        var notes: [String] = []
        if risk > 0.70 { notes.append("HIGH_TELEMETRY_RISK") }
        if impact > 6 { notes.append("HIGH_IMPACT") }
        if (packet.battery ?? 100) < 20 { notes.append("LOW_BATTERY") }
        if (packet.rssi ?? 0) < -105 { notes.append("WEAK_SIGNAL") }

        return AVOTelemetryFusionFrame(
            packetSequence: packet.sequence,
            speed: speed,
            heartRate: hr,
            cadence: cadence,
            impact: impact,
            loadScore: load,
            fatigueCandidate: fatigue,
            riskScore: risk,
            notes: notes
        )
    }

    public func fuseSession(_ packets: [AVOHorseHardwarePacket]) -> [AVOTelemetryFusionFrame] {
        packets.map { fuse(packet: $0) }
    }

    public func exportCSV(_ frames: [AVOTelemetryFusionFrame]) -> String {
        var rows = ["seq,speed,hr,cadence,impact,load,fatigue,risk,notes"]
        for f in frames {
            rows.append([
                String(f.packetSequence),
                String(f.speed),
                String(f.heartRate),
                String(f.cadence),
                String(f.impact),
                String(f.loadScore),
                String(f.fatigueCandidate),
                String(f.riskScore),
                f.notes.joined(separator: "|")
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }
}

@MainActor
public final class AVOTelemetryFusionController: ObservableObject {

    public static let shared = AVOTelemetryFusionController()

    @Published public private(set) var status: String = "TELEMETRY FUSION READY"
    @Published public private(set) var fusedFrames: [AVOTelemetryFusionFrame] = []
    @Published public private(set) var lastExportURL: URL?

    private let engine = AVOTelemetryFusionEngine()
    private let hardware = AVOHardwareTelemetryHub.shared
    private let storage = AVOStorageEngine.shared

    private init() {}

    public func runFusion() {
        fusedFrames = engine.fuseSession(hardware.packets)
        status = "FUSION DONE \(fusedFrames.count)"
    }

    public func exportFusion(horseName: String) {
        do {
            runFusion()
            let csv = engine.exportCSV(fusedFrames)
            let url = try storage.writeText(csv, area: .analytics, horseName: horseName, fileName: "hardware_telemetry_fusion.csv")
            lastExportURL = url
            status = "FUSION EXPORTED"
        } catch {
            status = "FUSION EXPORT ERROR: \(error.localizedDescription)"
        }
    }
}
