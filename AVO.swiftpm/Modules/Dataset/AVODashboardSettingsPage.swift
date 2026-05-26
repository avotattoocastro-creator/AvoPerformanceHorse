import SwiftUI

// MARK: - Dashboard connection / metrics configuration
// Independent page for everything related to the LIVE Dashboard: Raspberry cloud URL,
// polling rate, UDP fallback, visible metrics and debug state.

final class AVODashboardSettingsStore: ObservableObject {
    @Published var cloudEnabled: Bool {
        didSet { UserDefaults.standard.set(cloudEnabled, forKey: "AVO.dashboard.cloudEnabled") }
    }
    @Published var useHTTPS: Bool {
        didSet { UserDefaults.standard.set(useHTTPS, forKey: "AVO.dashboard.useHTTPS") }
    }
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "AVO.dashboard.host") }
    }
    @Published var port: String {
        didSet { UserDefaults.standard.set(port, forKey: "AVO.dashboard.port") }
    }
    @Published var path: String {
        didSet { UserDefaults.standard.set(path, forKey: "AVO.dashboard.path") }
    }
    @Published var pollRate: Double {
        didSet { UserDefaults.standard.set(pollRate, forKey: "AVO.dashboard.pollRate") }
    }
    @Published var udpEnabled: Bool {
        didSet { UserDefaults.standard.set(udpEnabled, forKey: "AVO.dashboard.udpEnabled") }
    }
    @Published var udpPort: String {
        didSet { UserDefaults.standard.set(udpPort, forKey: "AVO.dashboard.udpPort") }
    }
    @Published var showGPS: Bool {
        didSet { UserDefaults.standard.set(showGPS, forKey: "AVO.dashboard.showGPS") }
    }
    @Published var showIMU: Bool {
        didSet { UserDefaults.standard.set(showIMU, forKey: "AVO.dashboard.showIMU") }
    }
    @Published var showBattery: Bool {
        didSet { UserDefaults.standard.set(showBattery, forKey: "AVO.dashboard.showBattery") }
    }
    @Published var showDebug: Bool {
        didSet { UserDefaults.standard.set(showDebug, forKey: "AVO.dashboard.showDebug") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.cloudEnabled = defaults.object(forKey: "AVO.dashboard.cloudEnabled") as? Bool ?? true
        self.useHTTPS = defaults.object(forKey: "AVO.dashboard.useHTTPS") as? Bool ?? false
        self.host = defaults.string(forKey: "AVO.dashboard.host") ?? "79.117.33.132"
        self.port = defaults.string(forKey: "AVO.dashboard.port") ?? "5000"
        self.path = defaults.string(forKey: "AVO.dashboard.path") ?? "/api/latest"
        self.pollRate = defaults.object(forKey: "AVO.dashboard.pollRate") as? Double ?? 0.5
        self.udpEnabled = defaults.object(forKey: "AVO.dashboard.udpEnabled") as? Bool ?? true
        self.udpPort = defaults.string(forKey: "AVO.dashboard.udpPort") ?? "7777"
        self.showGPS = defaults.object(forKey: "AVO.dashboard.showGPS") as? Bool ?? true
        self.showIMU = defaults.object(forKey: "AVO.dashboard.showIMU") as? Bool ?? true
        self.showBattery = defaults.object(forKey: "AVO.dashboard.showBattery") as? Bool ?? true
        self.showDebug = defaults.object(forKey: "AVO.dashboard.showDebug") as? Bool ?? true
    }

    var resolvedURL: String {
        let scheme = useHTTPS ? "https" : "http"
        let cleanHost = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/" + path
        return "\(scheme)://\(cleanHost):\(Int(port) ?? 5000)\(cleanPath)"
    }

    func apply(to hardware: AVOHardwareReceiver) {
        hardware.configureRaspberryCloud(
            host: host,
            port: Int(port) ?? 5000,
            path: path,
            useHTTPS: useHTTPS,
            pollSeconds: pollRate,
            enabled: cloudEnabled
        )

        if udpEnabled {
            hardware.startUDP(port: UInt16(udpPort) ?? 7777)
        } else {
            hardware.stopUDP()
        }
    }
}

struct AVODashboardSettingsPage: View {
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: AVODashboardSettingsStore
    var onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(
                    colors: [Color(red: 0.01, green: 0.015, blue: 0.018), .black, Color(red: 0.00, green: 0.04, blue: 0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    header
                        .frame(height: 62)

                    ScrollView {
                        VStack(spacing: 12) {
                            connectionPanel
                            transportPanel
                            metricPanel
                            diagnosticsPanel
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(18)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear { settings.apply(to: hardware) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DASHBOARD CONFIGURATION")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("CONNECTIONS · METRICS · RASPBERRY CLOUD · UDP FALLBACK · LIVE DEBUG")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            Spacer()
            configPill("CLOUD", hardware.cloudStatus, hardware.cloudStatus.contains("ONLINE") ? .green : .orange)
            configPill("HTTP", "\(hardware.cloudLastHTTPCode)", hardware.cloudLastHTTPCode == 200 ? .green : .orange)
            Button { settings.apply(to: hardware) } label: { configButton("APLICAR", .green) }
            Button { onClose() } label: { configButton("CERRAR", .red) }
        }
    }

    private var connectionPanel: some View {
        settingsBox("RASPBERRY CLOUD SERVER") {
            ToggleRow(title: "Activar Cloud Dashboard", subtitle: "Lee /api/latest desde la Raspberry pública o local.", isOn: $settings.cloudEnabled)
            ToggleRow(title: "Usar HTTPS", subtitle: "Dejar OFF mientras se prueba por IP pública HTTP.", isOn: $settings.useHTTPS)
            FieldRow(title: "Servidor / IP", text: $settings.host, placeholder: "79.117.33.132")
            FieldRow(title: "Puerto", text: $settings.port, placeholder: "5000", keyboard: .numberPad)
            FieldRow(title: "Endpoint", text: $settings.path, placeholder: "/api/latest")
            VStack(alignment: .leading, spacing: 8) {
                Text("REFRESCO: \(String(format: "%.2f", settings.pollRate)) s")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                Slider(value: $settings.pollRate, in: 0.25...3.0, step: 0.25)
            }
            readOnlyLine("URL FINAL", settings.resolvedURL, .cyan)
        }
    }

    private var transportPanel: some View {
        settingsBox("TRANSPORT / FALLBACK") {
            ToggleRow(title: "UDP local fallback", subtitle: "Mantiene el receptor antiguo como modo prueba/local.", isOn: $settings.udpEnabled)
            FieldRow(title: "Puerto UDP", text: $settings.udpPort, placeholder: "7777", keyboard: .numberPad)
            readOnlyLine("UDP", hardware.udpStatus, .green)
            readOnlyLine("BLE", hardware.bleStatus, .cyan)
        }
    }

    private var metricPanel: some View {
        settingsBox("MÉTRICAS VISIBLES EN DASHBOARD") {
            ToggleRow(title: "GPS / RTK", subtitle: "Latitud, longitud, FIX, satélites, HDOP y NTRIP.", isOn: $settings.showGPS)
            ToggleRow(title: "IMU", subtitle: "Aceleración, giro, impacto, pitch/roll estimados.", isOn: $settings.showIMU)
            ToggleRow(title: "Batería / RSSI", subtitle: "Batería de chaleco y señal móvil del módem.", isOn: $settings.showBattery)
            ToggleRow(title: "Panel debug", subtitle: "Payload, errores, HTTP y estado cloud.", isOn: $settings.showDebug)
        }
    }

    private var diagnosticsPanel: some View {
        settingsBox("LIVE DIAGNOSTICS") {
            readOnlyLine("Cloud Status", hardware.cloudStatus, hardware.cloudStatus.contains("ONLINE") ? .green : .orange)
            readOnlyLine("API", hardware.cloudAPI, .cyan)
            readOnlyLine("Error", hardware.cloudLastError, hardware.cloudLastError == "--" ? .green : .orange)
            readOnlyLine("Horse", hardware.nfcHorse, .green)
            readOnlyLine("GPS", "\(hardware.externalCoordinate.latitude), \(hardware.externalCoordinate.longitude)", .white)
            readOnlyLine("FIX", "\(hardware.gpsFix) · NTRIP \(hardware.gpsNTRIP ? "ON" : "OFF") · SAT \(hardware.gpsSatellites) · HDOP \(String(format: "%.2f", hardware.gpsHDOP))", .green)
            readOnlyLine("Speed", hardware.speed, .cyan)
            readOnlyLine("Battery", hardware.remoteBattery, .orange)
            readOnlyLine("RSSI", hardware.rssi, .orange)
            if settings.showDebug {
                Text(hardware.cloudLastPayload)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func settingsBox<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            content()
        }
        .padding(14)
        .background(Color.black.opacity(0.66))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func configPill(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 110, alignment: .leading)
        .background(Color.black.opacity(0.72))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func configButton(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundStyle(color == .red ? .black : .black)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func readOnlyLine(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .top) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .tint(.green)
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct FieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 130, alignment: .leading)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
