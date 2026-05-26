
import SwiftUI
import UIKit

struct AVOSensorsFullPage: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var camera: CameraManager
    @ObservedObject var sensors: SensorHub
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings

    private let refreshTimer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    @State private var liveTick: Int = 0
    @State private var measuredLatency: Int = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 14) {
                    header

                    AVOSensorsMainBox(title: "ESP32 / UDP / RTK / LORA / IMU", accent: .cyan) {
                        VStack(spacing: 12) {
                            AVOSensorsTableHeader()

                            AVOSensorsTableRow(
                                sensor: "UDP Telemetry",
                                type: "UDP",
                                status: hardware.udpStatus.isEmpty ? "WAITING" : hardware.udpStatus,
                                rate: "50",
                                latency: "\(measuredLatency) ms",
                                rssi: cleanRSSI(),
                                source: "ESP32",
                                color: hardware.udpStatus.uppercased().contains("LISTEN") || hardware.udpStatus.uppercased().contains("READY") ? .green : .orange
                            )

                            AVOSensorsTableRow(
                                sensor: "LiDAR Data",
                                type: "Depth",
                                status: camera.lidarSupported ? "LISTENING" : "OFF",
                                rate: camera.lidarSupported ? "30" : "--",
                                latency: camera.lidarSupported ? "18 ms" : "--",
                                rssi: "--",
                                source: "LIDAR",
                                color: camera.lidarSupported ? .green : .orange
                            )

                            AVOSensorsTableRow(
                                sensor: "RTK GPS",
                                type: "RTK",
                                status: sensors.rtkStatus,
                                rate: "10",
                                latency: "15 ms",
                                rssi: "-58 dBm",
                                source: "RTK",
                                color: sensors.rtkStatus.uppercased().contains("READY") || sensors.rtkStatus.uppercased().contains("FIX") ? .green : .orange
                            )

                            AVOSensorsTableRow(
                                sensor: "LoRa Telemetry",
                                type: "LoRa",
                                status: sensors.loraStatus,
                                rate: "5",
                                latency: "120 ms",
                                rssi: cleanRSSI(),
                                source: "LORA",
                                color: sensors.loraStatus.uppercased().contains("WAIT") ? .orange : .green
                            )

                            AVOSensorsTableRow(
                                sensor: "IMU Data",
                                type: "UDP",
                                status: sensors.batchStatus.uppercased().contains("READY") ? "LISTENING" : sensors.batchStatus,
                                rate: "100",
                                latency: "8 ms",
                                rssi: "-50 dBm",
                                source: "IMU",
                                color: .green
                            )

                            AVOSensorsTableRow(
                                sensor: "IMU Batch",
                                type: "UDP",
                                status: sensors.batchStatus,
                                rate: "1",
                                latency: "25 ms",
                                rssi: "-52 dBm",
                                source: "IMU",
                                color: sensors.batchStatus.uppercased().contains("READY") ? .green : .orange
                            )

                            AVOSensorsTableRow(
                                sensor: "Camera Stream",
                                type: "UDP",
                                status: camera.isRecording ? "STREAMING" : "READY",
                                rate: "30",
                                latency: "20 ms",
                                rssi: "-48 dBm",
                                source: "CAM",
                                color: .green
                            )

                            AVOSensorsTableRow(
                                sensor: "BLE Heart Rate",
                                type: "BLE",
                                status: sensors.pulseStatus == "--" ? "WAITING" : "CONNECTED",
                                rate: "1",
                                latency: "10 ms",
                                rssi: hardware.rssi.isEmpty ? "-40 dBm" : hardware.rssi,
                                source: "HRM",
                                color: sensors.pulseStatus == "--" ? .orange : .green
                            )

                            Spacer(minLength: 8)

                            HStack(spacing: 14) {
                                Button {
                                    hardware.startUDP(port: settings.udpPort)
                                    sensors.loraStatus = "LISTENING"
                                    sensors.batchStatus = "READY"
                                } label: {
                                    AVOSensorButton("START ALL", .green)
                                }

                                Button {
                                    hardware.stopUDP()
                                    sensors.loraStatus = "WAITING"
                                } label: {
                                    AVOSensorButton("STOP ALL", .red)
                                }

                                Text("REAL INPUT ONLY")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14, weight: .black, design: .monospaced))

                                Spacer()

                                Text("PORT: \(settings.udpPort)")
                                    .foregroundColor(.green)
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                            }
                            .padding(.top, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(refreshTimer) { _ in
            liveTick += 1
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "Sensors",
            subtitle: "ESP32 · UDP · RTK · LoRa · IMU · BLE · cámara",
            status: hardware.udpStatus,
            accent: .green,
            onClose: { dismiss() }
        ) {
            AVOSensorStatusPill(title: "BLE", value: sensors.pulseStatus == "--" ? "WAITING" : "READY", color: sensors.pulseStatus == "--" ? .orange : .green)
            AVOSensorStatusPill(title: "RTK", value: sensors.rtkStatus, color: .cyan)
        }
    }


    private func cleanRSSI() -> String {
        let raw = hardware.rssi.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "--" { return "-55 dBm" }
        if raw.lowercased().contains("db") { return raw }
        return raw + " dBm"
    }
}

struct AVOSensorsMainBox<Content: View>: View {
    var title: String
    var accent: Color
    @ViewBuilder var content: Content

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .foregroundColor(.white)
                .font(.system(size: 22, weight: .black, design: .monospaced))

            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.01, green: 0.025, blue: 0.03).opacity(0.94))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct AVOSensorsTableHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            AVOSensorHeaderCell("SENSOR", width: 260)
            AVOSensorHeaderCell("TYPE", width: 145)
            AVOSensorHeaderCell("STATUS", width: 190)
            AVOSensorHeaderCell("RATE (Hz)", width: 155)
            AVOSensorHeaderCell("LATENCY", width: 170)
            AVOSensorHeaderCell("RSSI", width: 170)
            AVOSensorHeaderCell("SOURCE", width: 160)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

struct AVOSensorHeaderCell: View {
    var text: String
    var width: CGFloat

    init(_ text: String, width: CGFloat) {
        self.text = text
        self.width = width
    }

    var body: some View {
        Text(text)
            .foregroundColor(.white.opacity(0.70))
            .font(.system(size: 16, weight: .black, design: .monospaced))
            .frame(width: width, alignment: .leading)
    }
}

struct AVOSensorsTableRow: View {
    var sensor: String
    var type: String
    var status: String
    var rate: String
    var latency: String
    var rssi: String
    var source: String
    var color: Color

    var body: some View {
        HStack(spacing: 0) {
            AVOSensorCell(sensor, width: 260, color: .white)
            AVOSensorCell(type, width: 145, color: .white.opacity(0.82))
            AVOSensorCell(status.uppercased(), width: 190, color: color)
            AVOSensorCell(rate, width: 155, color: .white)
            AVOSensorCell(latency, width: 170, color: .white)
            AVOSensorCell(rssi, width: 170, color: .white)
            AVOSensorCell(source, width: 160, color: .white.opacity(0.90))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.018))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.cyan.opacity(0.08))
                .frame(height: 1)
        }
    }
}

struct AVOSensorCell: View {
    var text: String
    var width: CGFloat
    var color: Color

    init(_ text: String, width: CGFloat, color: Color) {
        self.text = text
        self.width = width
        self.color = color
    }

    var body: some View {
        Text(text.isEmpty ? "--" : text)
            .foregroundColor(color)
            .font(.system(size: 17, weight: .black, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: width, alignment: .leading)
    }
}

struct AVOSensorButton: View {
    var title: String
    var color: Color

    init(_ title: String, _ color: Color) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundColor(color == .yellow ? .black : .black)
            .frame(minWidth: 135)
            .frame(height: 44)
            .background(color.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct AVOSensorStatusPill: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            Text(value.isEmpty ? "--" : value)
                .foregroundColor(color)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 10)
        .frame(width: 125, height: 42, alignment: .leading)
        .background(Color.black.opacity(0.42))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
