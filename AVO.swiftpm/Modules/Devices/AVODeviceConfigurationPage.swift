import SwiftUI

struct AVODeviceConfigurationPage: View {

    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings

    @Environment(\.dismiss) private var dismiss

    @State private var config = AVODeviceConfiguration()
    @State private var selectedDevice: AVODeviceNode = .lilygo
    @State private var statusLine = "DEVICE CONFIG READY"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.005, green: 0.007, blue: 0.009),
                        Color(red: 0.025, green: 0.025, blue: 0.030),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    ZStack {
                        centerDeviceModel
                            .frame(width: min(geo.size.width * 0.36, 420), height: min(geo.size.height * 0.56, 440))
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.49)

                        leftConfigurationColumn
                            .frame(width: min(geo.size.width * 0.29, 360))
                            .position(x: min(geo.size.width * 0.18, 230), y: geo.size.height * 0.49)

                        rightConfigurationColumn
                            .frame(width: min(geo.size.width * 0.29, 360))
                            .position(x: geo.size.width - min(geo.size.width * 0.18, 230), y: geo.size.height * 0.49)

                        bottomCommandDock
                            .frame(width: min(geo.size.width * 0.88, 980))
                            .position(x: geo.size.width / 2, y: geo.size.height - 72)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.09))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DEVICE CONFIGURATION")
                    .font(.system(size: 21, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("LILYGO T-SIM · RTK · IMU · NFC · CINCHA · RASPBERRY SERVER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer()

            statusPill(title: "APP STORE SAFE", color: .cyan)
            statusPill(title: hardware.bleStatus, color: .green)
            statusPill(title: hardware.udpStatus, color: .orange)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.72))
        .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .bottom)
    }

    private var centerDeviceModel: some View {
        VStack(spacing: 16) {
            Text("CONNECTED DEVICE MODEL")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))

            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.18), Color.black.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 34)
                            .stroke(Color.green.opacity(0.42), lineWidth: 1.4)
                    )
                    .shadow(color: Color.green.opacity(0.18), radius: 25)

                VStack(spacing: 18) {
                    deviceBoard(title: "GPS RTK / GNSS", subtitle: config.rtkEnabled ? "ACTIVE" : "OFF", color: .cyan)
                        .offset(x: -18)
                    deviceBoard(title: "LILYGO T-SIM A7670E", subtitle: config.simEnabled ? "SIM ONLINE READY" : "SIM OFF", color: .green)
                        .offset(x: 16)
                    deviceBoard(title: "IMU + NFC + CINCHA BUS", subtitle: moduleSummary, color: .orange)
                        .offset(x: -8)
                }
                .rotation3DEffect(.degrees(9), axis: (x: 1, y: -0.6, z: 0))
                .padding(28)

                VStack {
                    HStack {
                        Text("BLE / RASPBERRY CONFIG MODE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(8)
                            .background(Color.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(18)
            }

            HStack(spacing: 8) {
                deviceNodeButton(.lilygo)
                deviceNodeButton(.rtk)
                deviceNodeButton(.imu)
                deviceNodeButton(.nfc)
                deviceNodeButton(.girth)
            }
        }
    }

    private var moduleSummary: String {
        var active: [String] = []
        if config.imuEnabled { active.append("IMU") }
        if config.nfcEnabled { active.append("NFC") }
        if config.girthEnabled { active.append("GIRTH") }
        if config.loraEnabled { active.append("LORA") }
        return active.isEmpty ? "ALL OFF" : active.joined(separator: " · ")
    }

    private var leftConfigurationColumn: some View {
        ScrollView {
            VStack(spacing: 12) {
                configCard("RASPBERRY LIVE SERVER", icon: "server.rack") {
                    Toggle("Activar servidor Raspberry", isOn: $config.raspberryServerEnabled)
                    labeledText("Host/IP", text: $config.raspberryHost)
                    intStepper("Puerto", value: $config.raspberryPort, range: 1000...9999)
                }

                configCard("SIM / LTE", icon: "simcard.fill") {
                    Toggle("Activar SIM LTE", isOn: $config.simEnabled)
                    labeledText("APN", text: $config.simAPN)
                    Text("Configuración preparada para BLE y servidor Raspberry.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.60))
                }

                configCard("NTRIP / RTK CORRECTIONS", icon: "dot.radiowaves.left.and.right") {
                    labeledText("NTRIP Host", text: $config.ntripHost)
                    intStepper("NTRIP Port", value: $config.ntripPort, range: 1...9999)
                    labeledText("Mountpoint", text: $config.ntripMount)
                    labeledText("Usuario NTRIP", text: $config.ntripUser)
                    labeledText("Contraseña NTRIP", text: $config.ntripPassword)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var rightConfigurationColumn: some View {
        ScrollView {
            VStack(spacing: 12) {
                configCard("COMPONENTES DEL CHALECO", icon: "cpu.fill") {
                    Toggle("RTK GPS", isOn: $config.rtkEnabled)
                    Toggle("IMU", isOn: $config.imuEnabled)
                    Toggle("Cincha / sensores girth", isOn: $config.girthEnabled)
                    Toggle("NFC caballo/jinete", isOn: $config.nfcEnabled)
                    Toggle("LoRa", isOn: $config.loraEnabled)
                    Toggle("BLE fallback", isOn: $config.bleEnabled)
                }

                configCard("STREAMING", icon: "waveform.path.ecg") {
                    intStepper("Frecuencia Hz", value: $config.streamRateHz, range: 1...100)
                    Text("Recomendado: 20 Hz live · 50/100 Hz para IMU burst local.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.52))
                }

                configCard("CONEXIÓN APP STORE", icon: "checkmark.seal.fill") {
                    Text("Build limpia para App Store Connect: configuración por BLE o Raspberry Server, sin conexión cableada directa en esta versión.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.60))
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var bottomCommandDock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                commandButton("ENVIAR POR BLE", icon: "antenna.radiowaves.left.and.right") {
                    hardware.sendDeviceConfiguration(config)
                    statusLine = "BLE CONFIG COMMAND SENT IF CONNECTED"
                }

                commandButton("SIMULAR ACK", icon: "checkmark.seal.fill") {
                    hardware.parsePacket("{\"seq\":1,\"battery\":92,\"rssi\":-61,\"horse\":\"HORSE01\",\"rider\":\"RIDER01\",\"speed\":0.0}")
                    statusLine = "SIMULATED DEVICE ACK"
                }
            }

            HStack {
                Text(statusLine)
                Spacer()
                Text("CABLE DIRECT CONFIG REMOVED")
                    .lineLimit(1)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.62))
        }
        .padding(12)
        .background(Color.black.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func deviceBoard(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
            }

            Text(subtitle)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.9))

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 6)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.66))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.40), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.20), radius: 12, x: 0, y: 8)
    }

    private func configCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.green)
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .tint(.green)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.82))
        }
        .padding(13)
        .background(Color.black.opacity(0.62))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func labeledText(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func intStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper("\(title): \(value.wrappedValue)", value: value, in: range)
    }

    private func commandButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func deviceNodeButton(_ node: AVODeviceNode) -> some View {
        Button {
            selectedDevice = node
        } label: {
            Text(node.rawValue)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(selectedDevice == node ? .black : .green)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(selectedDevice == node ? Color.green : Color.black.opacity(0.64))
                .clipShape(Capsule())
        }
    }
}

enum AVODeviceNode: String, CaseIterable {
    case lilygo = "LILYGO"
    case rtk = "RTK"
    case imu = "IMU"
    case nfc = "NFC"
    case girth = "CINCHA"
}
