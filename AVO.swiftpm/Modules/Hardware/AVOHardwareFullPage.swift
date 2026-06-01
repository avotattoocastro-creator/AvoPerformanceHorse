import SwiftUI

struct AVOHardwareFullPage: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings
    @ObservedObject var sensors: SensorHub

    @AppStorage("avoHardwareAutoUDP") private var autoUDP = true
    @AppStorage("avoHardwareAutoBLE") private var autoBLE = false
    @AppStorage("avoHardwareShowBLE") private var showBLE = true
    @AppStorage("avoHardwareShowUDP") private var showUDP = true
    @AppStorage("avoHardwareShowNFC") private var showNFC = true
    @AppStorage("avoHardwareShowIMU") private var showIMU = true
    @AppStorage("avoHardwareShowRTK") private var showRTK = true
    @AppStorage("avoHardwareShowProtocol") private var showProtocol = true
    @AppStorage("avoHardwareShowDiagnostics") private var showDiagnostics = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 10) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        section("CONEXIONES") {
                            statusRow("UDP", hardware.udpStatus, .green)
                            statusRow("PUERTO UDP", "\(settings.udpPort)", .white)
                            statusRow("BASE IP", settings.baseIP, .cyan)
                            statusRow("BASE PORT", settings.basePort, .cyan)
                            statusRow("BLE", hardware.bleStatus, .cyan)
                            statusRow("ESP32", hardware.esp32Status, .green)
                            statusRow("PACKETS", hardware.packetStatus, .orange)
                            statusRow("FRECUENCIA", hardware.liveRateText, .cyan)
                            HStack(spacing: 8) {
                                Button { hardware.startUDP(port: settings.udpPort) } label: { actionButton("START UDP", .green) }
                                Button { hardware.stopUDP() } label: { actionButton("STOP UDP", .red) }
                            }
                            HStack(spacing: 8) {
                                Button { hardware.startBLEScan() } label: { actionButton("SCAN BLE", .cyan) }
                                Button { hardware.stopBLE() } label: { actionButton("STOP BLE", .orange) }
                            }
                        }

                        section("ACTIVAR / DESACTIVAR HARDWARE") {
                            toggleRow("Auto iniciar UDP", "Arranque automático del receptor UDP 7777.", isOn: $autoUDP)
                            toggleRow("Auto escanear BLE", "Busca el Heltec/ESP32 al abrir hardware.", isOn: $autoBLE)
                            toggleRow("Mostrar bloque BLE", "Estado de escaneo, conexión y emparejado.", isOn: $showBLE)
                            toggleRow("Mostrar bloque UDP", "Telemetría por red local/base.", isOn: $showUDP)
                            toggleRow("Mostrar bloque NFC", "Identificación caballo/jinete.", isOn: $showNFC)
                            toggleRow("Mostrar bloque IMU", "Pitch, roll, impacto y lote IMU.", isOn: $showIMU)
                            toggleRow("Mostrar bloque RTK/GPS", "Coordenadas externas y estado RTK.", isOn: $showRTK)
                            toggleRow("Mostrar protocolo", "Cadena completa del protocolo de datos.", isOn: $showProtocol)
                            toggleRow("Mostrar diagnóstico", "RSSI, batería, secuencia y pérdida de paquetes.", isOn: $showDiagnostics)
                        }

                        if showBLE {
                            section("BLE / HELTEC") {
                                statusRow("SCAN", hardware.isScanning ? "SCANNING" : "STOPPED", hardware.isScanning ? .green : .orange)
                                statusRow("TARGET", "AVO_HORSE_HELTEC", .green)
                                statusRow("SAVED MAC", settings.savedHeltecMAC.isEmpty ? "NOT SET" : settings.savedHeltecMAC, .cyan)
                                statusRow("RSSI", hardware.rssi, .orange)
                                ForEach(hardware.discoveredDevices) { device in
                                    statusRow(device.name, "\(device.mac)  RSSI \(device.rssi)", .cyan)
                                }
                            }
                        }

                        if showNFC {
                            section("NFC / IDENTIFICACIÓN") {
                                statusRow("HORSE ID", hardware.nfcHorse, .green)
                                statusRow("RIDER ID", hardware.nfcRider, .cyan)
                                statusRow("LAST TAG", hardware.lastNFCTag, .orange)
                            }
                        }

                        if showIMU {
                            section("IMU / CINCHA / MOVIMIENTO") {
                                statusRow("PITCH", String(format: "%.2f", hardware.imuPitch), .green)
                                statusRow("ROLL", String(format: "%.2f", hardware.imuRoll), .cyan)
                                statusRow("IMPACT", String(format: "%.2f G", hardware.imuImpact), .orange)
                                statusRow("MOTION", String(format: "%.2f", hardware.motionIntensity), .green)
                                statusRow("GAIT", hardware.gaitState, .cyan)
                                statusRow("BATCH", "\(hardware.batchCount)", .purple)
                                statusRow("SENSOR HUB", sensors.imuStatus, .green)
                                Button { settings.calibrateIMU() } label: { actionButton("CALIBRAR IMU", .green) }
                                statusRow("CALIBRACIÓN", settings.calibrationStatus, .cyan)
                            }
                        }

                        if showRTK {
                            section("RTK / GPS EXTERNO") {
                                statusRow("RTK", hardware.hasExternalRTK ? "EXTERNAL LOCK" : "WAITING", hardware.hasExternalRTK ? .green : .orange)
                                statusRow("LAT", String(format: "%.6f", hardware.externalCoordinate.latitude), .cyan)
                                statusRow("LON", String(format: "%.6f", hardware.externalCoordinate.longitude), .cyan)
                                statusRow("PATH", "\(hardware.externalPath.count) POINTS", .green)
                                statusRow("SENSOR HUB", sensors.rtkStatus, .green)
                            }
                        }

                        if showDiagnostics {
                            section("DIAGNÓSTICO") {
                                statusRow("PULSE", hardware.pulse, .green)
                                statusRow("SPEED", hardware.speed, .cyan)
                                statusRow("CADENCE", hardware.cadence, .white)
                                statusRow("BATTERY", hardware.remoteBattery, .orange)
                                statusRow("SEQ", hardware.seqStatus, .green)
                                statusRow("LOST PACKETS", "\(hardware.lostPackets)", .red)
                                Text("MODO REAL: sin paquetes simulados en producción")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                            }
                        }

                        if showProtocol {
                            section("PROTOCOLO") {
                                Text(hardware.protocolStatus)
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color.black.opacity(0.35))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
            .padding(14)
        }
        .onAppear {
            if autoUDP { hardware.startUDP(port: settings.udpPort) }
            if autoBLE { hardware.startBLEScan() }
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "Hardware",
            subtitle: "Página independiente · conexiones reales · lista de módulos",
            status: hardware.udpStatus,
            accent: .green,
            onClose: { dismiss() }
        ) {
            EmptyView()
        }
    }


    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(.green)
                .font(.system(size: 15, weight: .black, design: .monospaced))
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusRow(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Text(title.uppercased())
                .foregroundColor(.gray)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .frame(width: 150, alignment: .leading)
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                Text(subtitle)
                    .foregroundColor(.gray)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .lineLimit(2)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .green))
        .padding(.vertical, 5)
    }

    private func actionButton(_ title: String, _ color: Color) -> some View {
        Text(title)
            .foregroundColor(.black)
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(color.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
