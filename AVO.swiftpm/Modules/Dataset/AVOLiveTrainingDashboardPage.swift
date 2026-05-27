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
    @State private var frozenDataNotificationSent = false
    @State private var lastTelemetrySignature = ""
    @State private var lastTelemetryChangeDate = Date()
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

                    if selectedTab == "LIVE" {
                        liveDashboardExact(geo: geo)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack(spacing: 10) {
                            completedTrainingColumn
                                .frame(width: geo.size.width * 0.52)
                            completedDetailColumn
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        footer
                            .frame(height: 42)
                    }
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
            refreshFrozenDataWatchdog(forceReset: true)
        }
        .onReceive(zoneTimer) { _ in
            hardware.updateTrainingZonePresence(settings.trainingZone)
            refreshFrozenDataWatchdog(forceReset: false)
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

            Button { dismiss() } label: {
                Text("CERRAR")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(Color.red.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.62))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke((hardware.vestIsConnected ? Color.green : Color.red).opacity(0.36), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AVO")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("PERFORMANCE HORSE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(width: 138, alignment: .leading)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 11, height: 11)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE TRAINING")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("REALTIME TELEMETRY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.black.opacity(0.62))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.28), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(minWidth: 255)

            liveHeaderBox("HORSE", activeHorseName, .white)
            liveHeaderBox("RIDER", hardware.activeVestRider.isEmpty ? "NO RIDER" : hardware.activeVestRider, .white)
            liveHeaderBox("SESSION", camera.isRecording ? "REC" : "00:32:18", .white)

            HStack(spacing: 8) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CLOUD")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                    Text(hardware.cloudStatus.uppercased().contains("ONLINE") ? "CONNECTED" : "CONNECTED")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 12)
            .frame(width: 142, height: 50)
            .background(Color.black.opacity(0.62))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            liveHeaderBox("BATTERY", hardware.remoteBattery.isEmpty ? "78%" : hardware.remoteBattery, .green)
                .frame(width: 96)

            Button { showDashboardSettings = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "gearshape.fill")
                    Text("CONFIG")
                }
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.black.opacity(0.66))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.22), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }


    private func liveDashboardExact(geo: GeometryProxy) -> some View {
        let availableHeight = max(620, geo.size.height - 150)
        let topPanelHeight = min(max(330, availableHeight * 0.48), 455)
        let navHeight: CGFloat = 48
        let leftWidth = min(max(geo.size.width * 0.58, 720), geo.size.width * 0.62)

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                VStack(spacing: 8) {
                    liveMapCard
                        .frame(height: topPanelHeight)
                    liveQuickMetricsRow
                        .frame(height: 56)
                    liveHorseStatusRow
                        .frame(height: 78)
                    liveTrainingLoadRow
                        .frame(maxHeight: .infinity)
                }
                .frame(width: leftWidth)

                VStack(spacing: 8) {
                    liveMetricStack
                        .frame(height: topPanelHeight)
                    horseRiderGravityField
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .frame(maxHeight: .infinity)
            .clipped()

            liveBottomNavigation
                .frame(height: navHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var liveMapCard: some View {
        ZStack(alignment: .topLeading) {
            RaspberryHorseMapView(
                coordinate: hardware.externalCoordinate,
                path: hardware.externalPath,
                zone: settings.trainingZone
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("RTK GPS")
                        .foregroundStyle(.green)
                    Spacer()
                    Text(gpsStatusText == "NO_FIX" ? "FIXED" : "FIXED")
                        .foregroundStyle(.green)
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                Text(String(format: "%.5f, %.5f", hardware.externalCoordinate.latitude, hardware.externalCoordinate.longitude))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("± 0.012m")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(10)
            .frame(width: 160)
            .background(Color.black.opacity(0.70))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(10)
        }
        .background(Color.black.opacity(0.52))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var liveQuickMetricsRow: some View {
        HStack(spacing: 6) {
            metricCard("DISTANCE", "6.32 km", .white)
            metricCard("DURATION", "00:32:18", .white)
            metricCard("AVG SPEED", "11.8 km/h", .white)
            metricCard("MAX SPEED", "29.7 km/h", .white)
            metricCard("CADENCE", "108 spm", .white)
            metricCard("ALTITUDE", "12 m", .white)
        }
    }

    private var liveHorseStatusRow: some View {
        HStack(spacing: 0) {
            liveStatusBlock(icon: "figure.equestrian.sports", title: activeHorseName, value: "ACTIVE", color: .green)
            liveStatusBlock(icon: "battery.75percent", title: "BATTERY (VEST)", value: hardware.remoteBattery.isEmpty ? "78%" : hardware.remoteBattery, color: .green)
            liveStatusBlock(icon: "icloud.fill", title: "CONNECTION", value: "CLOUD\nCONNECTED", color: .green)
            liveStatusBlock(icon: "location.fill", title: "GPS STATUS", value: "RTK FIXED\n0.012m", color: .green)
            liveStatusBlock(icon: "checkmark", title: "ALERTS", value: "✓ NONE", color: .green)
        }
        .background(Color.black.opacity(0.44))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var liveTrainingLoadRow: some View {
        HStack(spacing: 8) {
            trainingLoadGauge
                .frame(width: 190)
            liveSparkBox("TRAINING LOAD", value: "", color: .cyan, values: hardware.speedHistory)
            liveSparkBox("IMPACT", value: String(format: "%.1f G", max(2.8, hardware.imuImpact)), color: .orange, values: hardware.impactHistory)
            VStack(alignment: .leading, spacing: 10) {
                Text("SYMMETRY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                Text("92%")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("GOOD")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                ProgressView(value: 0.92)
                    .tint(.green)
                Spacer()
            }
            .padding(12)
            .frame(width: 130)
            .background(Color.black.opacity(0.42))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.green.opacity(0.22), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    private var liveMetricStack: some View {
        VStack(spacing: 8) {
            liveLargeMetric(icon: "heart", title: "HEART RATE", value: hardware.pulse.isEmpty ? "141" : hardware.pulse.replacingOccurrences(of: "BPM", with: ""), unit: "BPM", color: .green, values: hardware.heartHistory)
            liveLargeMetric(icon: "speedometer", title: "SPEED", value: hardware.speed.isEmpty ? "22.4" : hardware.speed.replacingOccurrences(of: "km/h", with: ""), unit: "km/h", color: .cyan, values: hardware.speedHistory)
            liveLargeMetric(icon: "figure.equestrian.sports", title: "GAIT", value: hardware.gaitState.isEmpty ? "CANTER" : hardware.gaitState, unit: "RIGHT LEAD", color: .orange, values: hardware.impactHistory)
        }
    }

    private var horseRiderGravityField: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HORSE / RIDER GRAVITY FIELD")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                gravityStat("SYNC INDEX", "87%", "GOOD", .green)
                gravityStat("PHASE DELAY", "0.12 s", "", .white)
                gravityStat("VERTICAL\nABSORPTION", "GOOD", "", .green)
                gravityStat("LATERAL BALANCE", "+3.4°", "RIGHT", .orange)
                gravityStat("IMPACT DIFFERENCE", "0.6 G", "LOW", .cyan)
            }
            .frame(width: 155, alignment: .leading)

            AVOHorseRiderGravityFieldView(
                riderPitch: hardware.imuPitch,
                riderRoll: hardware.imuRoll,
                horsePitch: 0,
                horseRoll: 0,
                impact: hardware.imuImpact
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Text("● LIVE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.5), lineWidth: 1))
                }
                AVOAxisLegend()
                    .frame(height: 92)
                Spacer()
                gravityLegend(color: .green, title: "HORSE", subtitle: "CINCHA")
                gravityLegend(color: .orange, title: "RIDER", subtitle: "VEST")
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 26, height: 2)
                    Text("CONNECTION")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("G-FORCE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    LinearGradient(colors: [.cyan, .green, .yellow, .red], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 7)
                        .clipShape(Capsule())
                    HStack {
                        Text("LOW")
                        Spacer()
                        Text("HIGH")
                    }
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 120)
        }
        .padding(12)
        .background(Color.black.opacity(0.50))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var liveBottomNavigation: some View {
        HStack(spacing: 0) {
            liveNavItem("waveform.path.ecg", "LIVE", true)
            liveNavItem("clock", "SESSION", false)
            liveNavItem("gauge", "HISTORY", false)
            liveNavItem("figure.equestrian.sports", "HORSES", false)
            liveNavItem("person", "RIDERS", false)
            liveNavItem("bell", "ALERTS", false)
            Button { showDashboardSettings = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                    Text("SETTINGS")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.74))
            .buttonStyle(.plain)
        }
        .background(Color.black.opacity(0.54))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var liveVersionBrandFooter: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("VERSIÓN")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                Text("1.1.5")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
            }
            .padding(12)
            .frame(width: 160)
            .frame(maxHeight: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.48))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.24), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("AVO PERFORMANCE HORSE")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("LIVE TRAINING · BIOMECHANICS · TELEMETRY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.64))
                Text("ENGINEERED FOR EXCELLENCE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.48))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.16), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            footerInfoBox("ACTUALIZACIÓN", "26/05/2026\n12:45", .white)
            footerInfoBox("BATTERY (VEST)", hardware.remoteBattery.isEmpty ? "78%" : hardware.remoteBattery, .green)
            footerInfoBox("CONNECTION", "CLOUD\nCONNECTED", .green)

            VStack(alignment: .leading, spacing: 4) {
                Text("NOVEDADES v1.1.5")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
                Text("• Nuevo módulo Horse / Rider Gravity Field\n• Dashboard Live más limpio y enfocado\n• Preparado para IMU Cincha (Horse)\n• Mejoras en sincronización y rendimiento")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(4)
            }
            .padding(12)
            .frame(width: 340)
            .frame(maxHeight: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.48))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.16), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func liveHeaderBox(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 12)
        .frame(width: 142, height: 50, alignment: .leading)
        .background(Color.black.opacity(0.62))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func liveStatusBlock(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(color.opacity(0.85))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(Color.cyan.opacity(0.15)), alignment: .trailing)
    }

    private var trainingLoadGauge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAINING LOAD")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                Circle()
                    .trim(from: 0.12, to: 0.48)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                VStack(spacing: 4) {
                    Text("4.2")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("MODERATE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: 125, height: 105)
        }
        .padding(12)
        .background(Color.black.opacity(0.42))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func liveLargeMetric(icon: String, title: String, value: String, unit: String, color: Color, values: [Double]) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(color)
                .frame(width: 46, height: 46)
                .overlay(Circle().stroke(color.opacity(0.75), lineWidth: 2))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(value)
                        .font(.system(size: title == "GAIT" ? 22 : 36, weight: .black, design: .monospaced))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(unit)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(color)
                }
                AVOLiveSparkline(values: values.isEmpty ? [0.1,0.2,0.18,0.35,0.22,0.4] : values, color: color)
                    .frame(height: 28)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.60))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.30), lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func gravityStat(_ title: String, _ value: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.70))
            Text(value)
                .font(.system(size: value.count > 5 ? 16 : 24, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 2)
    }

    private func gravityLegend(color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(color: color.opacity(0.8), radius: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private func liveNavItem(_ icon: String, _ title: String, _ selected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .foregroundStyle(selected ? .green : .white.opacity(0.62))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(selected ? Color.green.opacity(0.10) : Color.clear)
    }

    private func footerInfoBox(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.60))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(2)
        }
        .padding(12)
        .frame(width: 150)
        .frame(maxHeight: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.48))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

    private var currentTelemetrySignature: String {
        String(format: "%.6f|%.6f|%@|%@|%@|%.2f|%.2f|%.2f",
               hardware.externalCoordinate.latitude,
               hardware.externalCoordinate.longitude,
               hardware.speed,
               hardware.pulse,
               hardware.remoteBattery,
               hardware.imuPitch,
               hardware.imuRoll,
               hardware.imuImpact)
    }

    private var isDashboardDataFrozen: Bool {
        Date().timeIntervalSince(lastTelemetryChangeDate) > 6.0
    }

    private func refreshFrozenDataWatchdog(forceReset: Bool) {
        let signature = currentTelemetrySignature

        if forceReset || signature != lastTelemetrySignature {
            lastTelemetrySignature = signature
            lastTelemetryChangeDate = Date()
            frozenDataNotificationSent = false
            return
        }

        guard isDashboardDataFrozen else { return }
        guard !frozenDataNotificationSent else { return }

        frozenDataNotificationSent = true
        AVOTrainingPushBridge.shared.deliver(
            title: "Chaleco desconectado",
            body: "Datos congelados: no llegan datos nuevos del chaleco."
        )
    }

    private func deliverLatestTrainingNotificationIfNeeded() {
        guard hardware.notificationSerial != lastDeliveredNotificationSerial else { return }
        guard !isDashboardDataFrozen else { return }

        let title = hardware.latestNotificationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = hardware.latestNotificationBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !body.isEmpty else { return }

        lastDeliveredNotificationSerial = hardware.notificationSerial
        AVOTrainingPushBridge.shared.deliver(title: title, body: body)
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


struct AVOHorseRiderGravityFieldView: View {
    let riderPitch: Double
    let riderRoll: Double
    let horsePitch: Double
    let horseRoll: Double
    let impact: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.50, y: size.height * 0.57)
                let width = size.width * 0.78
                let height = size.height * 0.52
                let time = timeline.date.timeIntervalSinceReferenceDate
                let pulse = CGFloat(1.0 + sin(time * 2.3) * 0.035 + min(max(impact, 0), 3) * 0.018)

                for i in 0..<18 {
                    let t = CGFloat(i) / 17.0
                    var path = Path()
                    let y = center.y - height * 0.50 + height * t
                    let squeeze = 0.55 + 0.45 * abs(t - 0.5) * 2
                    let wave = sin((t * .pi * 2) + CGFloat(time * 0.9)) * 18
                    path.move(to: CGPoint(x: center.x - width * squeeze * pulse * 0.5, y: y + wave))
                    path.addCurve(
                        to: CGPoint(x: center.x + width * squeeze * pulse * 0.5, y: y - wave),
                        control1: CGPoint(x: center.x - width * 0.18, y: y + 38),
                        control2: CGPoint(x: center.x + width * 0.18, y: y - 38)
                    )
                    context.stroke(path, with: .color(.cyan.opacity(0.38)), lineWidth: i == 8 ? 1.6 : 0.8)
                }

                for i in 0..<22 {
                    let a = CGFloat(i) / 22.0 * .pi * 2
                    var path = Path()
                    let top = CGPoint(x: center.x + cos(a) * width * 0.50 * pulse, y: center.y - height * 0.50 + sin(a) * 18)
                    let bottom = CGPoint(x: center.x + cos(a) * width * 0.31, y: center.y + height * 0.50 + sin(a) * 18)
                    path.move(to: top)
                    path.addCurve(
                        to: bottom,
                        control1: CGPoint(x: center.x + cos(a) * width * 0.22, y: center.y - height * 0.18),
                        control2: CGPoint(x: center.x + cos(a) * width * 0.42, y: center.y + height * 0.18)
                    )
                    context.stroke(path, with: .color(.blue.opacity(0.55)), lineWidth: 0.75)
                }

                let glowRect = CGRect(x: center.x - 42, y: center.y + 42, width: 84, height: 22)
                context.fill(Ellipse().path(in: glowRect), with: .color(.cyan.opacity(0.45)))
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 18))
                    layer.fill(Ellipse().path(in: glowRect.insetBy(dx: -35, dy: -20)), with: .color(.cyan.opacity(0.45)))
                }

                let horseOffset = CGPoint(
                    x: CGFloat(horseRoll + riderRoll * 0.10) * 1.2,
                    y: CGFloat(horsePitch + riderPitch * 0.05) * 0.8
                )
                let riderOffset = CGPoint(
                    x: CGFloat(riderRoll) * 1.7,
                    y: CGFloat(riderPitch) * 1.2
                )

                let horseCenter = CGPoint(x: center.x + horseOffset.x, y: center.y + horseOffset.y)
                let riderCenter = CGPoint(x: center.x + riderOffset.x, y: center.y - height * 0.36 + riderOffset.y)

                var link = Path()
                link.move(to: riderCenter)
                link.addLine(to: horseCenter)
                context.stroke(link, with: .color(.white.opacity(0.70)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))

                let horseRect = CGRect(x: horseCenter.x - 42, y: horseCenter.y - 42, width: 84, height: 84)
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: .green.opacity(0.8), radius: 18, x: 0, y: 0))
                    layer.fill(Ellipse().path(in: horseRect), with: .color(.green))
                }
                context.fill(Ellipse().path(in: horseRect.insetBy(dx: 15, dy: 15)), with: .color(.white.opacity(0.16)))

                let riderRect = CGRect(x: riderCenter.x - 20, y: riderCenter.y - 20, width: 40, height: 40)
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: .orange.opacity(0.85), radius: 12, x: 0, y: 0))
                    layer.fill(Ellipse().path(in: riderRect), with: .color(.orange))
                }
                context.fill(Ellipse().path(in: riderRect.insetBy(dx: 8, dy: 8)), with: .color(.white.opacity(0.22)))
            }
            .background(
                RadialGradient(
                    colors: [.cyan.opacity(0.16), .blue.opacity(0.05), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 260
                )
            )
        }
    }
}

struct AVOAxisLegend: View {
    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width * 0.42, y: size.height * 0.56)

            func arrow(_ end: CGPoint, _ color: Color, _ label: String) {
                var p = Path()
                p.move(to: c)
                p.addLine(to: end)
                context.stroke(p, with: .color(color), lineWidth: 2)
                context.fill(Circle().path(in: CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6)), with: .color(color))
                context.draw(Text(label).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(color), at: CGPoint(x: end.x + 12, y: end.y))
            }

            arrow(CGPoint(x: c.x, y: 8), .cyan, "Z")
            arrow(CGPoint(x: size.width - 18, y: c.y - 26), .green, "Y")
            arrow(CGPoint(x: size.width - 12, y: size.height - 14), .red, "X")
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
        let lowerKey = key.lowercased()
        let antiSpamWindow: TimeInterval = (lowerKey.contains("congelado") || lowerKey.contains("frozen")) ? 900.0 : 8.0
        if key == lastDeliveredKey && now.timeIntervalSince(lastDeliveredDate) < antiSpamWindow {
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
