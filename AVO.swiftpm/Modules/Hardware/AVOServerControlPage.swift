import SwiftUI

struct AVOServerControlPage: View {
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings
    @Environment(\.dismiss) private var dismiss

    @State private var host = "live.avoperformance.org"
    @State private var port = "443"
    @State private var path = "/api/telemetry"
    @State private var useHTTPS = true
    @State private var pollSeconds = 0.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.006, green: 0.012, blue: 0.014), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    header
                        .frame(height: 58)

                    HStack(spacing: 10) {
                        leftPanel
                            .frame(width: geo.size.width * 0.46)
                        rightPanel
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    footer
                        .frame(height: 34)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear { loadCurrentServer() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SERVER CONTROL")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Raspberry · chalecos · cloud · API · RTK/NTRIP · watchdog")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            Spacer()
            serverPill("SERVER", serverStateText, serverStateColor)
            serverPill("VEST", vestStateText, vestStateColor)
            serverPill("RTK", hardware.gpsFix, rtkColor)
            Button { dismiss() } label: {
                Text("CERRAR")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.red.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("SERVER CONFIG")
            labeledField("HOST", text: $host)
            HStack(spacing: 8) {
                labeledField("PORT", text: $port)
                labeledField("PATH", text: $path)
            }
            Toggle("HTTPS", isOn: $useHTTPS)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("POLL RATE")
                    Spacer()
                    Text(String(format: "%.2fs", pollSeconds))
                        .foregroundStyle(.green)
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                Slider(value: $pollSeconds, in: 0.25...3.0, step: 0.25)
            }
            .padding(10)
            .background(Color.black.opacity(0.50))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                actionButton("CONNECT", .green) { applyServerAndConnect() }
                actionButton("STOP", .red) { hardware.stopRaspberryCloud() }
            }
            HStack(spacing: 8) {
                actionButton("UDP 7777", .cyan) { hardware.startUDP(port: 7777) }
                actionButton("RESET WATCH", .orange) { hardware.startRaspberryCloud(interval: pollSeconds) }
            }

            serverBox("ACTIVE ENDPOINT") {
                statusLine("API", hardware.cloudAPI, .cyan)
                statusLine("HTTP", "\(hardware.cloudLastHTTPCode)", hardware.cloudLastHTTPCode == 200 ? .green : .orange)
                statusLine("LAST ERROR", hardware.cloudLastError, hardware.cloudLastError == "--" ? .green : .orange)
                statusLine("POLL", String(format: "%.2fs", pollSeconds), .green)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.black.opacity(0.45))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var rightPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                serverBox("RASPBERRY") {
                    statusLine("CLOUD", hardware.cloudStatus, serverStateColor)
                    statusLine("REGISTRY", hardware.vestRegistryStatus, vestStateColor)
                    statusLine("AVAILABLE", hardware.availableVests.isEmpty ? "--" : hardware.availableVests.joined(separator: ", "), .green)
                    statusLine("SELECTED", hardware.selectedVestID, .cyan)
                    statusLine("UDP", hardware.udpStatus, hardware.udpStatus.contains("LISTENING") ? .green : .orange)
                }
                serverBox("VEST STATUS") {
                    statusLine("STATE", hardware.vestConnectionState, vestStateColor)
                    statusLine("ALERT", hardware.vestConnectionAlert, vestStateColor)
                    statusLine("HORSE", hardware.activeVestHorse, .green)
                    statusLine("RIDER", hardware.activeVestRider, .green)
                    statusLine("BATTERY", hardware.remoteBattery, batteryColor)
                }
            }

            HStack(spacing: 10) {
                serverBox("GPS / RTK") {
                    statusLine("FIX", hardware.gpsFix, rtkColor)
                    statusLine("SAT", "\(hardware.gpsSatellites)", hardware.gpsSatellites >= 12 ? .green : .orange)
                    statusLine("HDOP", String(format: "%.2f", hardware.gpsHDOP), hardware.gpsHDOP <= 1.5 ? .green : .orange)
                    statusLine("NTRIP", hardware.gpsNTRIP ? "ON" : "OFF", hardware.gpsNTRIP ? .green : .orange)
                    statusLine("ALT", String(format: "%.1f m", hardware.gpsAltitude), .cyan)
                }
                serverBox("LIVE TELEMETRY") {
                    statusLine("HR", hardware.pulse, .green)
                    statusLine("SPEED", hardware.speed, .cyan)
                    statusLine("GAIT", hardware.gaitState, .orange)
                    statusLine("RSSI", hardware.rssi, .orange)
                    statusLine("RATE", hardware.liveRateText, .cyan)
                }
            }

            serverBox("RAW SERVER PAYLOAD") {
                ScrollView {
                    Text(hardware.cloudLastPayload)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("Server page v1.3.5 build 50 · endpoints: /api/vests · /api/vests/{id}/status · /api/telemetry")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text("GEOFENCE: \(hardware.trainingZonePresence)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(hardware.isInsideTrainingZone ? .green : .orange)
        }
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.50))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadCurrentServer() {
        guard let url = URL(string: hardware.cloudAPI) else { return }
        host = url.host ?? host
        if let urlPort = url.port { port = "\(urlPort)" }
        useHTTPS = (url.scheme ?? "https") == "https"
        path = url.path.isEmpty ? "/api/telemetry" : url.path
    }

    private func applyServerAndConnect() {
        let cleanPort = Int(port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 443
        hardware.configureRaspberryCloud(host: host, port: cleanPort, path: path, useHTTPS: useHTTPS, pollSeconds: pollSeconds, enabled: true)
    }

    private var serverStateText: String {
        let s = hardware.cloudStatus.uppercased()
        if s.contains("ONLINE") { return "ONLINE" }
        if s.contains("FROZEN") || s.contains("DEGRADED") { return "FROZEN" }
        if hardware.cloudLastHTTPCode == 200 { return "HTTP 200" }
        return "OFFLINE"
    }

    private var serverStateColor: Color {
        if serverStateText == "ONLINE" || serverStateText == "HTTP 200" { return .green }
        if serverStateText == "FROZEN" { return .orange }
        return .red
    }

    private var vestStateText: String {
        let s = hardware.vestConnectionState.uppercased()
        if s.contains("FROZEN") { return "FROZEN" }
        if hardware.vestIsConnected { return "CONNECTED" }
        if s.contains("OFFLINE") || s.contains("DISCONNECTED") { return "OFFLINE" }
        return "WAITING"
    }

    private var vestStateColor: Color {
        if vestStateText == "CONNECTED" { return .green }
        if vestStateText == "FROZEN" { return .orange }
        return .red
    }

    private var rtkColor: Color {
        let fix = hardware.gpsFix.uppercased()
        if hardware.gpsNTRIP || fix.contains("FIXED") || fix.contains("RTK") { return .green }
        if fix.contains("GPS") || fix.contains("3D") || fix.contains("NMEA") { return .orange }
        return .red
    }

    private var batteryColor: Color {
        let n = Int(hardware.remoteBattery.filter { $0.isNumber }) ?? 0
        if n >= 50 { return .green }
        if n >= 25 { return .orange }
        return .red
    }

    private func panelTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(.green)
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.60))
            TextField(label, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.black.opacity(0.62))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.13), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    private func actionButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func serverPill(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func serverBox<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.48))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusLine(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 86, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 0)
        }
    }
}
