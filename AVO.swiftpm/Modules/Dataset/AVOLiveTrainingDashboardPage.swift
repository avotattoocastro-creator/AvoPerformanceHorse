import SwiftUI
import UIKit
import MapKit
import CoreLocation
import AudioToolbox
import UserNotifications

// MARK: - AVO LIVE TRAINING DASHBOARD
// Independent dashboard for beach sessions fed by the vest / Raspberry server.
// No iPad camera. No lateral menu. Designed as a real-time wall monitor.

struct AVOLiveTrainingDashboardPage: View {
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var sensors: SensorHub
    @ObservedObject var camera: CameraManager
    @ObservedObject var stableStore: AVOStableStore
    @ObservedObject var settings: HardwareSettings
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = "LIVE"
    @State private var selectedSessionID: UUID?
    @State private var showDashboardSettings = false
    @State private var showGeofenceEditor = false
    @State private var lastDeliveredNotificationSerial = 0
    @StateObject private var dashboardSettings = AVODashboardSettingsStore()
    private let zoneTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(red: 0.012, green: 0.018, blue: 0.020),
                        Color.black,
                        Color(red: 0.020, green: 0.025, blue: 0.020)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    connectionBanner
                    header
                        .frame(height: 50)

                    HStack(spacing: 10) {
                        if selectedTab == "LIVE" {
                            leftTrainingColumn
                                .frame(width: geo.size.width * 0.64)
                            rightTelemetryColumn
                        } else {
                            completedTrainingColumn
                                .frame(width: geo.size.width * 0.52)
                            completedDetailColumn
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    footer
                        .frame(height: 42)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear {
            dashboardSettings.apply(to: hardware)
            AVOTrainingPushBridge.shared.requestAuthorization()
            hardware.setActiveVestHorse(activeHorseName)
            hardware.updateTrainingZonePresence(settings.trainingZone)
        }
        .onReceive(zoneTimer) { _ in
            hardware.updateTrainingZonePresence(settings.trainingZone)
            deliverLatestTrainingNotificationIfNeeded()
        }
        .fullScreenCover(isPresented: $showDashboardSettings) {
            AVODashboardSettingsPage(
                hardware: hardware,
                settings: dashboardSettings,
                onClose: { showDashboardSettings = false }
            )
        }
        .fullScreenCover(isPresented: $showGeofenceEditor) {
            AVOTrainingGeofenceEditorPage(
                hardware: hardware,
                settings: settings,
                stableStore: stableStore,
                onClose: { showGeofenceEditor = false }
            )
        }
    }


    private var connectionBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(hardware.vestIsConnected ? Color.green : Color.red)
                .frame(width: 11, height: 11)
            Text(hardware.vestConnectionAlert)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(hardware.vestIsConnected ? .green : .orange)
            Spacer()
            Text("ACTIVE VEST HORSE: \(hardware.activeVestHorse)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)
            Text("· RIDER: \(hardware.activeVestRider)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.62))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke((hardware.vestIsConnected ? Color.green : Color.red).opacity(0.36), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DASHBOARD · BEACH TRAINING · LIVE")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("HORSE: \(activeHorseName) · REALTIME FROM RASPBERRY SERVER · VEST TELEMETRY · GPS / HEART / GAIT / LOAD")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
            }

            Spacer()

            dashboardTab("LIVE", selectedTab == "LIVE")
            dashboardTab("FINISHED", selectedTab == "FINISHED")
            trainingPill("HORSE", activeHorseName, .green)
            trainingPill("VEST", hardware.vestIsConnected ? "CONNECTED" : "DISCONNECTED", hardware.vestIsConnected ? .green : .red)
            trainingPill("SERVER", raspberryStatusText, raspberryStatusColor)
            trainingPill("RATE", hardware.liveRateText, .cyan)

            Button { showGeofenceEditor = true } label: {
                Text("GEOFENCE")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button { showDashboardSettings = true } label: {
                Text("CONFIG")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button { dismiss() } label: {
                Text("CERRAR")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var leftTrainingColumn: some View {
        VStack(spacing: 10) {
            ProBox("LIVE BEACH GPS / TRACKING") {
                VStack(spacing: 8) {
                    RaspberryHorseMapView(
                        coordinate: hardware.externalCoordinate,
                        path: hardware.externalPath,
                        zone: settings.trainingZone
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(spacing: 8) {
                        metricCard("LAT", String(format: "%.6f", hardware.externalCoordinate.latitude), .white)
                        metricCard("LON", String(format: "%.6f", hardware.externalCoordinate.longitude), .white)
                        metricCard("POINTS", "\(hardware.externalPath.count)", .green)
                        metricCard("ZONE", gpsStatusText, gpsStatusText == "WAITING" ? .orange : .green)
                    }
                    .frame(height: 64)
                }
            }

            ProBox("TRAINING LOAD / SESSION TIMELINE") {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        liveSparkBox("HEART", value: hardware.pulse, color: .green, values: hardware.heartHistory)
                        liveSparkBox("SPEED", value: hardware.speed, color: .cyan, values: hardware.speedHistory)
                        liveSparkBox("IMPACT", value: String(format: "%.2f G", hardware.imuImpact), color: .orange, values: hardware.impactHistory)
                    }

                    HStack(spacing: 8) {
                        metricCard("PITCH", String(format: "%.1f°", hardware.imuPitch), .cyan)
                        metricCard("ROLL", String(format: "%.1f°", hardware.imuRoll), .cyan)
                        metricCard("MOTION", String(format: "%.2f", hardware.motionIntensity), .green)
                        metricCard("GAIT", hardware.gaitState, .orange)
                    }
                    .frame(height: 72)
                }
            }
            .frame(height: 170)
        }
    }

    private var rightTelemetryColumn: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
            ProBox("HORSE LIVE METRICS") {
                VStack(spacing: 8) {
                    activeHorsePanel
                    notificationPanel
                    bigMetric("HEART RATE", hardware.pulse, .green)
                    bigMetric("SPEED", hardware.speed, .cyan)
                    bigMetric("GAIT", hardware.gaitState, .green)
                    bigMetric("ASYMMETRY", camera.asymmetry, .orange)
                }
            }

            ProBox("RASPBERRY / VEST LINK") {
                VStack(spacing: 8) {
                    MiniText(name: "CLOUD", value: hardware.cloudStatus, color: hardware.cloudStatus.contains("ONLINE") ? .green : .orange)
                    MiniText(name: "API", value: hardware.cloudAPI, color: .cyan)
                    MiniText(name: "HTTP", value: "\(hardware.cloudLastHTTPCode)", color: hardware.cloudLastHTTPCode == 200 ? .green : .orange)
                    MiniText(name: "FIX", value: hardware.gpsFix, color: hardware.gpsFix.contains("RTK") ? .green : .orange)
                    MiniText(name: "SAT", value: "\(hardware.gpsSatellites)", color: hardware.gpsSatellites > 0 ? .green : .orange)
                    MiniText(name: "NTRIP", value: hardware.gpsNTRIP ? "ON" : "OFF", color: hardware.gpsNTRIP ? .green : .orange)
                    MiniText(name: "UDP", value: hardware.udpStatus, color: .green)
                    MiniText(name: "BLE", value: hardware.bleStatus, color: .cyan)
                    MiniText(name: "PACKETS", value: hardware.packetStatus, color: .green)
                    MiniText(name: "BATTERY", value: hardware.remoteBattery, color: .orange)
                    MiniText(name: "VEST HORSE", value: hardware.activeVestHorse, color: .green)
                    MiniText(name: "VEST RIDER", value: hardware.activeVestRider, color: .cyan)
                    MiniText(name: "ZONE", value: hardware.trainingZonePresence, color: hardware.isInsideTrainingZone ? .green : .orange)
                }
            }
            .frame(height: 185)

            ProBox("BEACH TRAINING STATUS") {
                VStack(spacing: 8) {
                    statusLine("MODE", "REMOTE LIVE")
                    statusLine("SOURCE", "RASPBERRY SERVER")
                    statusLine("VEST", hardware.vestConnectionState)
                    statusLine("CAMERA", "OFF · DASHBOARD ONLY")
                    statusLine("SESSION", camera.isRecording ? "RECORDING · \(activeHorseName)" : "MONITORING · \(activeHorseName)")
                    statusLine("MOTION", String(format: "%.2f · %@", hardware.motionIntensity, hardware.gaitState))
                    statusLine("ZONE", hardware.trainingZonePresence)
                    statusLine("PUSH", hardware.latestNotificationTitle)
                    statusLine("ALERT", hardware.imuImpact > 0.55 ? "CHECK IMPACT" : "OK")
                    Spacer()
                }
            }
            .frame(height: 120)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            footerCell("HORSE", activeHorseName, .green)
            footerCell("CONNECTION", hardware.vestIsConnected ? "VEST ON" : "VEST OFF", hardware.vestIsConnected ? .green : .red)
            footerCell("GPS", gpsStatusText, .green)
            footerCell("ZONE", hardware.isInsideTrainingZone ? "INSIDE" : "OUTSIDE", hardware.isInsideTrainingZone ? .green : .orange)
            footerCell("HR", hardware.pulse, .green)
            footerCell("SPEED", hardware.speed, .cyan)
            footerCell("BAT", hardware.remoteBattery, .orange)
            footerCell("RSSI", hardware.rssi, .orange)
            Spacer()
            Text("NO CAMERA · REAL TIME TRAINING MONITOR")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.74))
        }
        .padding(.horizontal, 14)
        .background(Color.black.opacity(0.74))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var raspberryStatusText: String {
        if hardware.cloudStatus.uppercased().contains("ONLINE") { return "CLOUD ONLINE" }
        if hardware.cloudStatus.uppercased().contains("OFFLINE") { return "CLOUD OFFLINE" }
        if hardware.udpStatus.uppercased().contains("LISTENING") { return "UDP READY" }
        if hardware.bleStatus.uppercased().contains("READY") { return "BLE READY" }
        return "WAITING"
    }

    private var raspberryStatusColor: Color {
        raspberryStatusText.contains("ONLINE") || raspberryStatusText.contains("READY") ? .green : .orange
    }

    private var gpsStatusText: String {
        if hardware.gpsFix != "NO_FIX" { return hardware.gpsFix }
        return hardware.externalPath.count > 2 ? "TRACKING" : "WAITING"
    }
    private var activeHorseName: String {
        let stableName = stableStore.selectedHorseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stableName.isEmpty && stableName != "NO HORSE" { return stableName }
        let vest = hardware.activeVestHorse.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vest.isEmpty && vest != "NO HORSE" && vest != "--" { return vest }
        let nfc = hardware.nfcHorse.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nfc.isEmpty && nfc != "--" { return nfc }
        return "NO HORSE SELECTED"
    }

    private var activeHorseMeta: String {
        guard let profile = stableStore.selectedHorseProfile else { return "Selecciona un caballo en Stable para asociar el entrenamiento live." }
        let breed = profile.breed.isEmpty ? "BREED --" : profile.breed
        let mode = profile.competitionMode.isEmpty ? "MODE --" : profile.competitionMode
        return "\(breed) · \(profile.sex.rawValue) · \(profile.ageYears)y · \(mode)"
    }

    private var currentSelectedSession: StableSessionListItem? {
        if let id = selectedSessionID, let found = stableStore.selectedSessions.first(where: { $0.id == id }) { return found }
        return stableStore.selectedSessions.first
    }

    private var selectedSessionHorseName: String {
        let stableName = stableStore.selectedHorseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return stableName.isEmpty ? "NO HORSE" : stableName
    }


    private var activeHorsePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("ACTIVE HORSE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Text(camera.isRecording ? "LIVE REC" : "LIVE MONITOR")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(camera.isRecording ? .red : .green)
            }
            Text(activeHorseName)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(activeHorseMeta)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.35), lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var notificationPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("PUSH / EVENTS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Text("iOS READY · ANDROID BRIDGE READY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.85))
            }
            Text(hardware.latestNotificationTitle)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(hardware.latestNotificationBody)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
            if let first = hardware.notificationFeed.first {
                Text("LAST: \(first.type.uppercased())")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyan.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func deliverLatestTrainingNotificationIfNeeded() {
        guard hardware.notificationSerial != lastDeliveredNotificationSerial else { return }
        lastDeliveredNotificationSerial = hardware.notificationSerial
        AVOTrainingPushBridge.shared.deliver(
            title: hardware.latestNotificationTitle,
            body: hardware.latestNotificationBody
        )
        hardware.acknowledgeAppNotificationDelivery()
    }

    private var completedTrainingColumn: some View {
        ProBox("FINISHED TRAININGS · HORSE SESSIONS") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    metricCard("HORSE", selectedSessionHorseName, .green)
                    metricCard("SESSIONS", "\(stableStore.selectedSessions.count)", .cyan)
                    metricCard("STATUS", stableStore.status, .orange)
                }
                .frame(height: 76)

                if stableStore.selectedSessions.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Text("NO FINISHED TRAININGS")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("Las sesiones cerradas aparecerán aquí asociadas al caballo seleccionado: \(activeHorseName).")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.52))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(stableStore.selectedSessions) { session in
                                completedSessionRow(session)
                            }
                        }
                    }
                }
            }
        }
    }

    private var completedDetailColumn: some View {
        ProBox("TRAINING DETAIL · SELECTED HORSE") {
            VStack(alignment: .leading, spacing: 10) {
                if let session = currentSelectedSession {
                    detailHero(session)
                    VStack(spacing: 8) {
                        bigMetric("HORSE", selectedSessionHorseName, .green)
                        bigMetric("SESSION", session.title, .cyan)
                    }
                    HStack(spacing: 8) {
                        metricCard("DURATION", formatDuration(session.durationSeconds), .white)
                        metricCard("SAMPLES", "\(session.samplesCount)", .green)
                    }
                    .frame(height: 74)
                    HStack(spacing: 8) {
                        metricCard("QUALITY", "\(Int(session.avgQuality * 100))%", .green)
                        metricCard("RISK", "\(Int(session.avgRisk * 100))%", session.avgRisk > 0.55 ? .orange : .green)
                        metricCard("FATIGUE", "\(Int(session.avgFatigue * 100))%", .orange)
                    }
                    .frame(height: 74)
                    VStack(spacing: 6) {
                        MiniText(name: "VIDEO", value: session.videoRelativePath == nil ? "NO VIDEO" : "VIDEO LINKED", color: session.videoRelativePath == nil ? .orange : .green)
                        MiniText(name: "SENSORS", value: session.sensorsRelativePath == nil ? "NO SENSOR FILE" : "SENSORS LINKED", color: session.sensorsRelativePath == nil ? .orange : .green)
                        MiniText(name: "AI", value: session.aiSummaryRelativePath == nil ? "NO AI SUMMARY" : "AI SUMMARY LINKED", color: session.aiSummaryRelativePath == nil ? .orange : .green)
                    }
                    Spacer()
                } else {
                    Spacer()
                    Text("SELECT A FINISHED TRAINING")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                    Text("Cada entrenamiento cerrado se muestra con el caballo al que pertenece.")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.52))
                    Spacer()
                }
            }
        }
    }

    private func dashboardTab(_ title: String, _ selected: Bool) -> some View {
        Button { selectedTab = title } label: {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(selected ? Color.green : Color.black.opacity(0.52))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.34), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func completedSessionRow(_ session: StableSessionListItem) -> some View {
        let selected = currentSelectedSession?.id == session.id
        return Button { selectedSessionID = session.id } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedSessionHorseName)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                    Text(session.title)
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(shortDateTime(session.date)) · \(formatDuration(session.durationSeconds)) · samples \(session.samplesCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Q \(Int(session.avgQuality * 100))%")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("RISK \(Int(session.avgRisk * 100))%")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(session.avgRisk > 0.55 ? .orange : .white.opacity(0.70))
                }
            }
            .padding(12)
            .background(selected ? Color.green.opacity(0.15) : Color.black.opacity(0.44))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.green.opacity(0.72) : Color.white.opacity(0.10), lineWidth: selected ? 1.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func detailHero(_ session: StableSessionListItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CLOSED TRAINING")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            Text(selectedSessionHorseName)
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(shortDateTime(session.date))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.32), lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func shortDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy HH:mm"
        return f.string(from: date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func trainingPill(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 130, alignment: .leading)
        .background(Color.black.opacity(0.52))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.34), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func metricCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.42))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func bigMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(Color.black.opacity(0.45))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.38), lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statusLine(_ title: String, _ value: String) -> some View {
        MiniText(name: title, value: value, color: value.contains("OK") || value.contains("REMOTE") || value.contains("OFF") ? .green : .orange)
    }

    private func footerCell(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(width: 128)
    }

    private func liveSparkBox(_ title: String, value: String, color: Color, values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
                Spacer()
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }
            AVOLiveSparkline(values: values, color: color)
                .frame(height: 62)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.40))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

}

struct RaspberryHorseMapView: View {
    let coordinate: CLLocationCoordinate2D
    let path: [CLLocationCoordinate2D]
    let zone: TrainingZone

    var body: some View {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.010, longitudeDelta: 0.010)
        )

        let binding = Binding<MapCameraPosition>(
            get: { .region(region) },
            set: { _ in }
        )

        ZStack(alignment: .topLeading) {
            Map(position: binding) {
                if path.count > 1 {
                    MapPolyline(coordinates: path)
                        .stroke(.green, lineWidth: 5)
                }
                MapCircle(center: zone.coordinate, radius: zone.radiusMeters)
                    .foregroundStyle(.green.opacity(0.16))
                    .stroke(.green, lineWidth: 2)
                Marker(zone.name, coordinate: zone.coordinate)
                    .tint(.green)
                Marker("HORSE", coordinate: coordinate)
                    .tint(.red)
            }
            .mapStyle(.imagery(elevation: .realistic))

            VStack(alignment: .leading, spacing: 6) {
                Text("RASPBERRY GPS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                Text(String(format: "%.5f  %.5f", coordinate.latitude, coordinate.longitude))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(8)
            .background(Color.black.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.24), lineWidth: 1))
    }
}

struct AVOLiveSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                let maxValue = values.max() ?? 1
                let minValue = values.min() ?? 0
                let range = max(maxValue - minValue, 0.0001)
                for index in values.indices {
                    let x = geo.size.width * CGFloat(index) / CGFloat(values.count - 1)
                    let normalized = (values[index] - minValue) / range
                    let y = geo.size.height * CGFloat(1.0 - normalized)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 3)
        }
    }
}



final class AVOTrainingPushBridge: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AVOTrainingPushBridge()

    private let center = UNUserNotificationCenter.current()
    private var lastDeliveredKey = ""
    private var lastDeliveredDate = Date.distantPast
    private var didConfigure = false
    private var didRequestAuthorization = false

    private override init() { super.init() }

    func configureNotificationSystem() {
        guard !didConfigure else { return }
        didConfigure = true
        center.delegate = self

        let openAction = UNNotificationAction(
            identifier: "AVO_OPEN_LIVE",
            title: "Abrir LIVE",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "AVO_TRAINING_EVENT",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]) { granted, error in
            if let error {
                print("AVO notification authorization error: \(error.localizedDescription)")
            }
            if !granted {
                print("AVO notifications not granted yet")
            }
        }
    }

    func deliver(title: String, body: String) {
        configureNotificationSystem()
        requestAuthorization()

        let key = "\(title)|\(body)"
        let now = Date()
        if key == lastDeliveredKey && now.timeIntervalSince(lastDeliveredDate) < 2.0 {
            return
        }
        lastDeliveredKey = key
        lastDeliveredDate = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "AVO_TRAINING_EVENT"
        content.threadIdentifier = "AVO_TRAINING_LIVE"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "avo-training-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        center.add(request) { error in
            if let error {
                print("AVO notification delivery error: \(error.localizedDescription)")
            }
        }

        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(1007)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
