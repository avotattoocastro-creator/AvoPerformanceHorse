import SwiftUI
import UIKit
import MapKit
import CoreLocation
import AudioToolbox
import UserNotifications


// MARK: - Remote Training Sessions loaded from Raspberry server
struct AVOTrainingAnalysisSample: Identifiable, Hashable {
    var id = UUID()
    var time: String
    var latitude: Double?
    var longitude: Double?
    var speedKmh: Double
    var impactG: Double
    var heartRate: Double
    var asymmetry: Double
    var cadence: Double

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct AVORemoteTrainingSession: Identifiable, Hashable {
    var id: String
    var horseId: String
    var horseName: String
    var status: String
    var startedAt: String
    var endedAt: String
    var durationSeconds: Double
    var distanceKm: Double
    var avgSpeedKmh: Double
    var maxSpeedKmh: Double
    var avgHeartRate: Double
    var maxHeartRate: Double
    var geofenceId: String
    var geofenceName: String
    var track: [CLLocationCoordinate2D]
    var samples: [AVOTrainingAnalysisSample]

    static func == (lhs: AVORemoteTrainingSession, rhs: AVORemoteTrainingSession) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - UI performance helpers for heavy Raspberry sessions
private func avoDownsampleSamplesForUI(_ samples: [AVOTrainingAnalysisSample], limit: Int) -> [AVOTrainingAnalysisSample] {
    guard limit > 0, samples.count > limit else { return samples }
    let step = max(1, Int(ceil(Double(samples.count) / Double(limit))))
    var result: [AVOTrainingAnalysisSample] = []
    result.reserveCapacity(min(samples.count, limit + 2))
    for index in stride(from: 0, to: samples.count, by: step) { result.append(samples[index]) }
    if let last = samples.last, result.last?.id != last.id { result.append(last) }
    return result
}

private func avoDownsampleCoordinatesForUI(_ coords: [CLLocationCoordinate2D], limit: Int) -> [CLLocationCoordinate2D] {
    guard limit > 0, coords.count > limit else { return coords }
    let step = max(1, Int(ceil(Double(coords.count) / Double(limit))))
    var result: [CLLocationCoordinate2D] = []
    result.reserveCapacity(min(coords.count, limit + 2))
    for index in stride(from: 0, to: coords.count, by: step) { result.append(coords[index]) }
    if let last = coords.last {
        let alreadyLast = result.last.map { abs($0.latitude - last.latitude) < 0.0000001 && abs($0.longitude - last.longitude) < 0.0000001 } ?? false
        if !alreadyLast { result.append(last) }
    }
    return result
}

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
    @State private var selectedRemoteSessionId: String?
    @State private var selectedSessionHorseId = "HORSE_001"
    @State private var analysisSessionToOpen: AVORemoteTrainingSession?
    @State private var isLoadingSessionAnalysis = false
    @State private var analysisLoadStatus = "ANALYSIS READY"
    @State private var remoteTrainingSessions: [AVORemoteTrainingSession] = []
    @State private var sessionsLoadStatus = "SESSIONS WAITING"
    @State private var sessionsLastFetchDate = Date.distantPast
    @State private var showDashboardSettings = false
    @State private var showGeofenceEditor = false
    @State private var lastDeliveredNotificationSerial = 0
    @State private var frozenDataNotificationSent = false
    @State private var lastTelemetrySignature = ""
    @State private var lastTelemetryChangeDate = Date()
    @State private var liveSessionStartDate = Date()
    @State private var dashboardGeofenceStatus = "GEOFENCE WAITING"
    @State private var lastDashboardGeofenceFetch = Date.distantPast
    @State private var hasRecordedInsideTrainingZone = false
    @State private var sessionSavedAfterExit = false
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
            refreshDashboardSessionState()
            loadDashboardGeofenceFromLatest(force: true)
            selectedSessionHorseId = normalizedHorseId(activeHorseName)
            loadRemoteTrainingSessions(force: true)
            refreshFrozenDataWatchdog(forceReset: true)
        }
        .onReceive(zoneTimer) { _ in
            hardware.updateTrainingZonePresence(settings.trainingZone)
            refreshDashboardSessionState()
            loadDashboardGeofenceFromLatest(force: false)
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
        .fullScreenCover(item: $analysisSessionToOpen) { session in
            AVOTrainingSessionAnalysisPage(
                session: session,
                fallbackZone: settings.trainingZone,
                onClose: { analysisSessionToOpen = nil }
            )
        }
    }


    private var connectionBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(vestStatusColor)
                .frame(width: 11, height: 11)
            Text(vestBannerText)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(vestStatusColor)
            Spacer()
            Text("ACTIVE VEST HORSE: \(activeVestHorseDisplay)")
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
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(vestStatusColor.opacity(0.40), lineWidth: 1))
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
                    .fill(liveZoneHeaderColor)
                    .frame(width: 11, height: 11)
                    .shadow(color: liveZoneHeaderColor.opacity(0.85), radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE TRAINING")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("REALTIME TELEMETRY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(liveZoneHeaderTitle)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(liveZoneHeaderColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(dashboardGeofenceStatus)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(liveZoneHeaderColor.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(liveZoneHeaderColor.opacity(0.42), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.black.opacity(0.62))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.28), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(minWidth: 255)

            liveHeaderBox("HORSE", activeHorseName, .white)
            liveHeaderBox("RIDER", hardware.activeVestRider.isEmpty ? "NO RIDER" : hardware.activeVestRider, .white)
            liveSessionHeaderBox

            HStack(spacing: 8) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CLOUD")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                    Text(vestStatusShortText)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(vestStatusColor)
                }
            }
            .padding(.horizontal, 12)
            .frame(width: 142, height: 50)
            .background(Color.black.opacity(0.62))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            liveHeaderBox("BATTERY", hardware.remoteBattery.isEmpty ? "BAT --" : hardware.remoteBattery, batteryColor)
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

            rtkInlineStatusRow
                .padding(.top, 10)
                .padding(.horizontal, 10)
        }
        .background(Color.black.opacity(0.52))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(mapSignalColor.opacity(0.95), lineWidth: isDashboardDataFrozen ? 3 : 2))
        .shadow(color: mapSignalColor.opacity(0.42), radius: 10)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var rtkInlineStatusRow: some View {
        HStack(spacing: 10) {
            rtkHudCell("RTK", rtkFixLabel, rtkSignalColor)
            rtkHudCell("ACC", rtkAccuracyText, rtkSignalColor)
            rtkHudCell("SAT", "\(hardware.gpsSatellites)", hardware.gpsSatellites >= 8 ? .green : .orange)
            rtkHudCell("NTRIP", hardware.gpsNTRIP ? "ON" : "OFF", hardware.gpsNTRIP ? .green : .orange)
            rtkHudCell("HDOP", String(format: "%.2f", hardware.gpsHDOP), hardware.gpsHDOP <= 2.0 ? .green : .orange)
            Spacer(minLength: 6)
            Text(String(format: "%.5f, %.5f", hardware.externalCoordinate.latitude, hardware.externalCoordinate.longitude))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.74))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(rtkSignalColor.opacity(0.42), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func rtkHudCell(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var liveQuickMetricsRow: some View {
        HStack(spacing: 6) {
            metricCard("DISTANCE", liveDistanceText, zoneMetricColor)
            metricCard("DURATION", liveSessionDurationText, zoneMetricColor)
            metricCard("AVG SPEED", avgSpeedText, zoneMetricColor)
            metricCard("MAX SPEED", maxSpeedText, zoneMetricColor)
            metricCard("CADENCE", cadenceText, zoneMetricColor)
            metricCard("ALTITUDE", altitudeText, zoneMetricColor)
        }
    }

    private var liveHorseStatusRow: some View {
        HStack(spacing: 0) {
            liveStatusBlock(icon: "figure.equestrian.sports", title: activeHorseName, value: vestIsServerConnected ? "ACTIVE" : vestStatusShortText, color: vestStatusColor)
            liveStatusBlock(icon: "battery.75percent", title: "BATTERY (VEST)", value: cleanBatteryText, color: batteryColor)
            liveStatusBlock(icon: "icloud.fill", title: "CONNECTION", value: connectionStatusText, color: connectionColor)
            liveStatusBlock(icon: "location.fill", title: "GPS STATUS", value: rtkFixLabel + "\n" + rtkAccuracyText, color: rtkSignalColor)
            liveStatusBlock(icon: hardware.isInsideTrainingZone ? "checkmark.seal.fill" : "exclamationmark.triangle.fill", title: "TRAINING ZONE", value: alertStatusText, color: zoneMetricColor)
        }
        .background(Color.black.opacity(0.44))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(zoneMetricColor.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var liveTrainingLoadRow: some View {
        HStack(spacing: 8) {
            trainingLoadGauge
                .frame(width: 190)
            liveSparkBox("TRAINING LOAD", value: "", color: .cyan, values: hardware.speedHistory)
            liveSparkBox("IMPACT", value: hardware.impactHistory.isEmpty ? "NO DATA" : String(format: "%.1f G", hardware.imuImpact), color: .orange, values: hardware.impactHistory)
            VStack(alignment: .leading, spacing: 10) {
                Text("SYMMETRY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                Text(hardware.impactHistory.isEmpty ? "NO DATA" : syncIndexText)
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(hardware.impactHistory.isEmpty ? "NO REAL SENSOR" : syncQualityText)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(hardware.impactHistory.isEmpty ? .orange : syncColor)
                ProgressView(value: hardware.impactHistory.isEmpty ? 0.0 : (Double(syncIndexText.replacingOccurrences(of: "%", with: "")) ?? 0) / 100.0)
                    .tint(hardware.impactHistory.isEmpty ? .orange : syncColor)
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
            liveLargeMetric(icon: "heart", title: "HEART RATE", value: heartRateValue, unit: "BPM", color: .green, values: safeSeries(hardware.heartHistory))
            liveLargeMetric(icon: "speedometer", title: "SPEED", value: speedValue, unit: "km/h", color: .cyan, values: safeSeries(hardware.speedHistory))
            liveLargeMetric(icon: "figure.equestrian.sports", title: "GAIT", value: gaitValue, unit: "RIGHT LEAD", color: .orange, values: safeSeries(hardware.impactHistory))
        }
    }

    private var horseRiderGravityField: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HORSE / RIDER GRAVITY FIELD")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                gravityStat("SYNC INDEX", syncIndexText, syncQualityText, syncColor)
                gravityStat("PHASE DELAY", phaseDelayText, "", .white)
                gravityStat("VERTICAL\nABSORPTION", verticalAbsorptionText, "", verticalAbsorptionColor)
                gravityStat("LATERAL BALANCE", lateralBalanceText, lateralBalanceSideText, lateralBalanceColor)
                gravityStat("IMPACT DIFFERENCE", impactDifferenceText, impactQualityText, impactQualityColor)
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
                        .foregroundStyle(isDashboardDataFrozen ? .red : .green)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke((isDashboardDataFrozen ? Color.red : Color.green).opacity(0.5), lineWidth: 1))
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
            Button {
                selectedTab = "LIVE"
            } label: {
                liveNavItem("waveform.path.ecg", "LIVE", selectedTab == "LIVE")
            }
            .buttonStyle(.plain)

            Button {
                selectedTab = "SESSION"
                selectedSessionHorseId = normalizedHorseId(activeHorseName)
                loadRemoteTrainingSessions(force: true)
            } label: {
                liveNavItem("clock", "SESSION", selectedTab == "SESSION")
            }
            .buttonStyle(.plain)

            liveNavItem("gauge", "HISTORY", false)
            liveNavItem("figure.equestrian.sports", "HORSES", false)
            liveNavItem("person", "RIDERS", false)
            Button { showGeofenceEditor = true } label: { liveNavItem("mappin.and.ellipse", "GEOFENCE", false) }.buttonStyle(.plain)
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
                Text("1.1.9")
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
                Text("NOVEDADES v1.1.9")
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

    private var liveSessionHeaderBox: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("SESSION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Circle()
                    .fill(sessionStatusColor)
                    .frame(width: 7, height: 7)
            }
            Text(liveSessionDurationText)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(sessionStatusText)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(sessionStatusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.60)
        }
        .padding(.horizontal, 12)
        .frame(width: 158, height: 50, alignment: .leading)
        .background(Color.black.opacity(0.62))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(sessionStatusColor.opacity(0.42), lineWidth: 1.3))
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
            footerCell("CONNECTION", vestStatusShortText, vestStatusColor)
            footerCell("GPS", gpsStatusText, .green)
            footerCell("ZONE", hardware.isInsideTrainingZone ? "INSIDE" : "OUTSIDE", hardware.isInsideTrainingZone ? .green : .orange)
            footerCell("HR", hardware.pulse, .green)
            footerCell("SPEED", hardware.speed, .cyan)
            footerCell("BAT", hardware.remoteBattery, batteryColor)
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

    private var vestServerState: String { hardware.serverVestState.uppercased() }
    private var vestIsServerConnected: Bool { vestServerState == "CONNECTED" && hardware.serverVestConnected }
    private var vestIsServerFrozen: Bool { vestServerState == "FROZEN" || hardware.serverVestFrozen }
    private var vestIsServerDisconnected: Bool { vestServerState == "DISCONNECTED" || hardware.serverVestDisconnected }
    private var vestStatusColor: Color {
        if vestIsServerDisconnected { return .red }
        if vestIsServerFrozen { return .orange }
        if vestIsServerConnected { return .green }
        return .orange
    }
    private var vestStatusShortText: String {
        if vestIsServerDisconnected { return "DESCONECTADO" }
        if vestIsServerFrozen { return "CONGELADO" }
        if vestIsServerConnected { return "CONECTADO" }
        return "WAITING"
    }
    private var vestStatusBlockText: String {
        if vestIsServerDisconnected { return "VEST\nDISCONNECTED" }
        if vestIsServerFrozen { return "DATA\nFROZEN" }
        if vestIsServerConnected { return "VEST\nCONNECTED" }
        return "VEST\nWAITING"
    }
    private var vestBannerText: String {
        let label = hardware.serverVestLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty && label != "CHALECO ESPERANDO" { return label }
        if vestIsServerDisconnected { return "Chaleco desconectado por CLOUD" }
        if vestIsServerFrozen { return "Chaleco congelado por CLOUD" }
        if vestIsServerConnected { return "Chaleco conectado por CLOUD" }
        return hardware.vestConnectionAlert
    }
    private var activeVestHorseDisplay: String {
        vestIsServerDisconnected ? "NO ACTIVE VEST" : activeHorseName
    }
    private var isVestDataUnavailable: Bool { vestIsServerFrozen || vestIsServerDisconnected }

    private var raspberryStatusColor: Color {
        raspberryStatusText.contains("ONLINE") || raspberryStatusText.contains("READY") ? .green : .orange
    }

    private var gpsStatusText: String {
        if hardware.gpsFix != "NO_FIX" { return hardware.gpsFix }
        return hardware.externalPath.count > 2 ? "TRACKING" : "WAITING"
    }

    private var rtkFixLabel: String {
        let raw = hardware.gpsFix.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if vestIsServerDisconnected { return "NO GPS" }
        if vestIsServerFrozen { return "FROZEN" }
        if hardware.gpsCarrSoln == 2 { return "RTK FIX" }
        if hardware.gpsCarrSoln == 1 { return "RTK FLOAT" }
        if hardware.gpsNTRIP && hardware.gpsRtcmBytes > 0 && raw.contains("DGPS") { return "DGPS RTCM" }
        if hardware.gpsNTRIP && hardware.gpsRtcmBytes > 0 { return raw.isEmpty || raw == "NO_FIX" ? "RTCM ACTIVE" : raw }
        if raw.contains("RTK") && raw.contains("FIX") { return "RTK FIX" }
        if raw.contains("FIXED") { return "RTK FIX" }
        if raw.contains("FLOAT") { return "RTK FLOAT" }
        if raw.contains("3D") || raw.contains("GPS") || raw.contains("DGPS") { return raw.isEmpty ? "GPS 3D" : raw }
        if hardware.gpsSatellites >= 8 { return "GPS 3D" }
        if hardware.externalPath.count > 2 { return "GPS NMEA" }
        return "WAITING"
    }

    private var rtkSignalColor: Color {
        if vestIsServerDisconnected { return .red }
        if vestIsServerFrozen { return .orange }
        if rtkFixLabel.contains("RTK FIX") || rtkFixLabel.contains("RTCM ACTIVE") || rtkFixLabel.contains("DGPS RTCM") { return .green }
        if rtkFixLabel.contains("FLOAT") || rtkFixLabel.contains("3D") || rtkFixLabel.contains("NMEA") { return .orange }
        return .red
    }

    private var mapSignalColor: Color {
        if vestIsServerDisconnected { return .red }
        if vestIsServerFrozen { return .orange }
        if hardware.gpsHDOP > 0 && hardware.gpsHDOP <= 2.0 && hardware.gpsSatellites >= 8 { return .green }
        if hardware.gpsSatellites > 0 || hardware.externalPath.count > 2 { return .orange }
        return .red
    }

    private var rtkAccuracyText: String {
        let hdop = hardware.gpsHDOP
        if hdop.isFinite && hdop > 0 && hdop < 50 { return String(format: "± %.2fm", hdop) }
        return "± --"
    }

    private var cleanBatteryText: String {
        let raw = hardware.remoteBattery.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "BAT --" }
        return raw.replacingOccurrences(of: "BAT ", with: "")
    }

    private var batteryColor: Color {
        let raw = cleanBatteryText.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "BAT", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let level = Double(raw) ?? -1
        if level < 0 { return .orange }
        if level <= 15 { return .red }
        if level <= 35 { return .orange }
        return .green
    }

    private var connectionStatusText: String {
        if vestIsServerDisconnected { return "VEST\nDISCONNECTED" }
        if vestIsServerFrozen { return "DATA\nFROZEN" }
        if vestIsServerConnected && hardware.cloudStatus.uppercased().contains("ONLINE") { return "CLOUD\nCONNECTED" }
        if hardware.cloudStatus.uppercased().contains("ONLINE") { return "CLOUD\nONLINE" }
        if hardware.udpStatus.uppercased().contains("LISTENING") { return "UDP\nREADY" }
        return "WAITING\nSIGNAL"
    }

    private var connectionColor: Color {
        if vestIsServerDisconnected { return .red }
        if vestIsServerFrozen { return .orange }
        return connectionStatusText.contains("CONNECTED") || connectionStatusText.contains("ONLINE") || connectionStatusText.contains("READY") ? .green : .orange
    }

    private var zoneMetricColor: Color {
        if vestIsServerDisconnected { return .red }
        if vestIsServerFrozen { return .orange }
        return hardware.isInsideTrainingZone ? .green : .white
    }

    private var alertStatusText: String {
        if vestIsServerDisconnected { return "VEST\nOFFLINE" }
        if vestIsServerFrozen { return "DATA\nFROZEN" }
        return hardware.isInsideTrainingZone ? "IN TRAINING\nZONE" : "OUTSIDE\nZONE"
    }

    private var liveZoneHeaderTitle: String {
        if vestIsServerDisconnected { return "CHALECO DESCONECTADO" }
        if vestIsServerFrozen || isDashboardDataFrozen { return "CHALECO CONGELADO" }
        return hardware.isInsideTrainingZone ? "EN ZONA ENTRENAMIENTO" : "FUERA DE ZONA"
    }

    private var liveZoneHeaderColor: Color {
        if vestIsServerDisconnected { return .red }
        if vestIsServerFrozen { return .orange }
        return hardware.isInsideTrainingZone ? .green : .red
    }

    private var sessionStatusText: String {
        if vestIsServerDisconnected || vestIsServerFrozen { return "SESSION STOP" }
        if hardware.rawRecordingActive { return "RAW REC" }
        if hardware.isInsideTrainingZone { return "GRABANDO" }
        if sessionSavedAfterExit || hardware.rawRecordingSDOK { return "GUARDADA" }
        return "SESSION STOP"
    }

    private var sessionStatusColor: Color {
        switch sessionStatusText {
        case "GRABANDO", "RAW REC": return .red
        case "GUARDADA": return .green
        default: return .orange
        }
    }

    private var liveSessionDurationText: String { formatDuration(Date().timeIntervalSince(liveSessionStartDate)) }
    private var liveDistanceText: String { String(format: "%.2f km", computedDistanceKm) }
    private var avgSpeedText: String { String(format: "%.1f km/h", computedAverageSpeed) }
    private var maxSpeedText: String { String(format: "%.1f km/h", computedMaxSpeed) }
    private var cadenceText: String {
        let raw = hardware.cadence.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty || raw == "CAD --" ? "-- spm" : raw.replacingOccurrences(of: "BPM", with: "spm")
    }
    private var altitudeText: String { String(format: "%.0f m", hardware.gpsAltitude) }

    private var heartRateValue: String {
        let raw = hardware.pulse.replacingOccurrences(of: "BPM", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty || raw == "--" ? "NO DATA" : raw
    }

    private var speedValue: String {
        let raw = hardware.speed.replacingOccurrences(of: "km/h", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "0.0" : raw
    }

    private var gaitValue: String {
        let raw = hardware.gaitState.trimmingCharacters(in: .whitespacesAndNewlines)
        return hardware.impactHistory.isEmpty ? "NO DATA" : (raw.isEmpty ? "STATIC" : raw.uppercased())
    }

    private var computedAverageSpeed: Double {
        let speeds = hardware.speedHistory.filter { $0.isFinite && $0 >= 0 }
        guard !speeds.isEmpty else { return Double(speedValue) ?? 0 }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    private var computedMaxSpeed: Double {
        hardware.speedHistory.filter { $0.isFinite }.max() ?? (Double(speedValue) ?? 0)
    }

    private var computedDistanceKm: Double {
        let pts = hardware.externalPath
        guard pts.count > 1 else { return 0 }
        var meters = 0.0
        for index in 1..<pts.count {
            let a = CLLocation(latitude: pts[index - 1].latitude, longitude: pts[index - 1].longitude)
            let b = CLLocation(latitude: pts[index].latitude, longitude: pts[index].longitude)
            let d = a.distance(from: b)
            if d.isFinite && d >= 0 && d < 80 { meters += d }
        }
        return meters / 1000.0
    }

    private var syncIndexText: String {
        let rollPenalty = min(45.0, abs(hardware.imuRoll) * 1.25)
        let pitchPenalty = min(30.0, abs(hardware.imuPitch) * 1.10)
        let impactPenalty = min(25.0, max(0.0, hardware.imuImpact) * 4.0)
        let sync = max(0.0, 100.0 - rollPenalty - pitchPenalty - impactPenalty)
        return "\(Int(sync.rounded()))%"
    }
    private var syncQualityText: String { (Int(syncIndexText.replacingOccurrences(of: "%", with: "")) ?? 0) >= 80 ? "GOOD" : "LOW" }
    private var syncColor: Color { syncQualityText == "GOOD" ? .green : .red }
    private var phaseDelayText: String { String(format: "%.2f s", min(0.99, abs(hardware.imuRoll - hardware.imuPitch) / 100.0)) }
    private var verticalAbsorptionText: String { hardware.imuImpact < 3.0 ? "GOOD" : hardware.imuImpact < 6.0 ? "CHECK" : "HIGH" }
    private var verticalAbsorptionColor: Color { verticalAbsorptionText == "GOOD" ? .green : verticalAbsorptionText == "CHECK" ? .orange : .red }
    private var lateralBalanceText: String { String(format: "%+.1f°", hardware.imuRoll) }
    private var lateralBalanceSideText: String { hardware.imuRoll >= 0 ? "RIGHT" : "LEFT" }
    private var lateralBalanceColor: Color { abs(hardware.imuRoll) < 5 ? .green : .orange }
    private var impactDifferenceText: String { String(format: "%.1f G", max(0.0, hardware.imuImpact)) }
    private var impactQualityText: String { hardware.imuImpact < 2.5 ? "LOW" : hardware.imuImpact < 5.5 ? "MID" : "HIGH" }
    private var impactQualityColor: Color { impactQualityText == "LOW" ? .cyan : impactQualityText == "MID" ? .orange : .red }

    private func safeSeries(_ values: [Double]) -> [Double] {
        let filtered = values.filter { $0.isFinite }
        return filtered.isEmpty ? [0.0, 0.0, 0.0, 0.0] : filtered
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

    private var compactSaysLive: Bool {
        hardware.cloudStatus.uppercased().contains("ONLINE") &&
        hardware.serverVestConnected &&
        !hardware.serverVestFrozen &&
        !hardware.serverVestDisconnected &&
        hardware.serverVestAgeSeconds >= 0 &&
        hardware.serverVestAgeSeconds <= 5.0
    }

    private var isDashboardDataFrozen: Bool {
        if hardware.serverVestFrozen || hardware.serverVestDisconnected { return true }
        if compactSaysLive { return false }
        return Date().timeIntervalSince(lastTelemetryChangeDate) > 6.0
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

    private func refreshDashboardSessionState() {
        if hardware.isInsideTrainingZone && !isDashboardDataFrozen && vestIsServerConnected {
            if !hasRecordedInsideTrainingZone {
                liveSessionStartDate = Date()
            }
            hasRecordedInsideTrainingZone = true
            sessionSavedAfterExit = false
        } else if hasRecordedInsideTrainingZone && !hardware.isInsideTrainingZone {
            sessionSavedAfterExit = true
        }
    }

    private func loadDashboardGeofenceFromLatest(force: Bool) {
        guard force || Date().timeIntervalSince(lastDashboardGeofenceFetch) > 6.0 else { return }
        lastDashboardGeofenceFetch = Date()

        let horseId = "HORSE_001"
        let latestURL = URL(string: hardware.cloudAPI) ?? URL(string: "https://live.avoperformance.org/api/latest")
        guard let url = latestURL else { return }

        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 8
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200...299).contains(code),
                      let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    await loadDashboardGeofenceByHorseIdFallback(horseId: horseId)
                    return
                }

                if let zone = dashboardTrainingZoneFromLatestJSON(obj, horseId: horseId) {
                    await MainActor.run {
                        settings.trainingZone = zone
                        hardware.updateTrainingZonePresence(zone)
                        dashboardGeofenceStatus = "GEOFENCE LOADED /API/LATEST"
                        print("AVO DASHBOARD GEOFENCE LOAD API_LATEST", zone)
                    }
                } else {
                    await loadDashboardGeofenceByHorseIdFallback(horseId: horseId)
                }
            } catch {
                await loadDashboardGeofenceByHorseIdFallback(horseId: horseId)
            }
        }
    }

    private func loadDashboardGeofenceByHorseIdFallback(horseId: String) async {
        guard let url = URL(string: "https://live.avoperformance.org/api/geofence/latest?horseId=\(horseId)") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 8
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(code),
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let zone = dashboardTrainingZoneFromLatestJSON(obj, horseId: horseId) else {
                await MainActor.run { dashboardGeofenceStatus = "GEOFENCE WAITING" }
                return
            }
            await MainActor.run {
                settings.trainingZone = zone
                hardware.updateTrainingZonePresence(zone)
                dashboardGeofenceStatus = "GEOFENCE LOADED SERVER"
                print("AVO DASHBOARD GEOFENCE LOAD SERVER", zone)
            }
        } catch {
            await MainActor.run { dashboardGeofenceStatus = "GEOFENCE WAITING" }
        }
    }

    private func dashboardTrainingZoneFromLatestJSON(_ json: [String: Any], horseId: String) -> TrainingZone? {
        if let envelope = json["geofence"] as? [String: Any] {
            if let nested = envelope["geofence"] as? [String: Any], let zone = dashboardTrainingZone(from: nested, horseId: horseId) { return zone }
            if let zone = dashboardTrainingZone(from: envelope, horseId: horseId) { return zone }
        }
        if let zone = dashboardTrainingZone(from: json, horseId: horseId) { return zone }
        return nil
    }

    private func dashboardTrainingZone(from dict: [String: Any], horseId: String) -> TrainingZone? {
        if let dictHorse = dict["horseId"] as? String, !dictHorse.isEmpty, dictHorse != horseId { return nil }
        let lat = dashboardDouble(dict["lat"]) ?? dashboardDouble(dict["latitude"])
        let lon = dashboardDouble(dict["lon"]) ?? dashboardDouble(dict["lng"]) ?? dashboardDouble(dict["longitude"])
        guard let lat, let lon else { return nil }
        let radius = dashboardDouble(dict["radiusM"]) ?? dashboardDouble(dict["radiusMeters"]) ?? dashboardDouble(dict["radius"]) ?? 120.0
        let name = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPolygon = dict["polygon"] as? [[String: Any]] ?? []
        let polygon = rawPolygon.compactMap { item -> TrainingZonePoint? in
            guard let pLat = dashboardDouble(item["lat"] ?? item["latitude"]),
                  let pLon = dashboardDouble(item["lon"] ?? item["lng"] ?? item["longitude"]) else { return nil }
            return TrainingZonePoint(latitude: pLat, longitude: pLon)
        }
        return TrainingZone(
            name: (name?.isEmpty == false ? name! : "TRAINING_ZONE"),
            latitude: lat,
            longitude: lon,
            radiusMeters: radius,
            polygon: polygon
        )
    }

    private func dashboardDouble(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }


    private var remoteHorseIds: [String] {
        var ids = ["HORSE_001"]
        let active = normalizedHorseId(activeHorseName)
        if !ids.contains(active) { ids.append(active) }
        for session in remoteTrainingSessions {
            let id = normalizedHorseId(session.horseId)
            if !ids.contains(id) { ids.append(id) }
        }
        return ids
    }

    private var remoteSessionsForSelectedHorse: [AVORemoteTrainingSession] {
        remoteTrainingSessions
            .filter { normalizedHorseId($0.horseId) == normalizedHorseId(selectedSessionHorseId) }
            .sorted { remoteSessionSortDate($0) > remoteSessionSortDate($1) }
    }

    private var selectedRemoteSession: AVORemoteTrainingSession? {
        if let selectedRemoteSessionId,
           let found = remoteSessionsForSelectedHorse.first(where: { $0.id == selectedRemoteSessionId }) {
            return found
        }
        return remoteSessionsForSelectedHorse.first
    }

    private func normalizedHorseId(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.uppercased() == "NO HORSE SELECTED" || trimmed.uppercased() == "NO HORSE" || trimmed == "--" {
            return "HORSE_001"
        }
        return trimmed.uppercased().replacingOccurrences(of: " ", with: "_")
    }

    private func loadRemoteTrainingSessions(force: Bool) {
        guard force || Date().timeIntervalSince(sessionsLastFetchDate) > 10.0 else { return }
        sessionsLastFetchDate = Date()
        sessionsLoadStatus = "LOADING SERVER"

        let horse = normalizedHorseId(selectedSessionHorseId).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "HORSE_001"
        guard let url = URL(string: "https://live.avoperformance.org/api/sessions/index?horseId=\(horse)") else { return }
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 9
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200...299).contains(code), !data.isEmpty else {
                    await MainActor.run { sessionsLoadStatus = "SERVER EMPTY RESPONSE" }
                    print("AVO SESSIONS INDEX EMPTY OR HTTP", code)
                    return
                }
                let json = try JSONSerialization.jsonObject(with: data)
                let parsed = parseRemoteSessionsList(json)
                await MainActor.run {
                    remoteTrainingSessions = parsed.map { lightweightSessionForList($0) }.sorted { remoteSessionSortDate($0) > remoteSessionSortDate($1) }
                    if selectedRemoteSessionId == nil { selectedRemoteSessionId = remoteSessionsForSelectedHorse.first?.id }
                    sessionsLoadStatus = parsed.isEmpty ? "NO SERVER SESSIONS" : "SERVER SESSIONS LOADED"
                    print("AVO SESSIONS INDEX LOADED", parsed.count)
                }
            } catch {
                await MainActor.run { sessionsLoadStatus = "SESSIONS SERVER ERROR" }
                print("AVO SESSIONS INDEX ERROR", error)
            }
        }
    }

    private func lightweightSessionForList(_ session: AVORemoteTrainingSession) -> AVORemoteTrainingSession {
        var item = session
        // The list must stay light: no heavy samples and only a tiny GPS preview if present.
        item.samples = []
        item.track = avoDownsampleCoordinatesForUI(item.track, limit: 80)
        return item
    }

    private func optimizedSessionForAnalysis(_ session: AVORemoteTrainingSession) -> AVORemoteTrainingSession {
        var item = session
        item.samples = avoDownsampleSamplesForUI(item.samples, limit: 900)
        item.track = avoDownsampleCoordinatesForUI(item.track, limit: 900)
        return item
    }

    private func openRemoteSessionAnalysis(_ session: AVORemoteTrainingSession) {
        guard !isLoadingSessionAnalysis else { return }

        // Do not block the UI. Open immediately if we already have usable data.
        if !session.samples.isEmpty || session.track.count > 20 {
            analysisLoadStatus = "ANALYSIS READY"
            analysisSessionToOpen = optimizedSessionForAnalysis(session)
            return
        }

        isLoadingSessionAnalysis = true
        analysisLoadStatus = "LOADING ANALYSIS"
        guard !session.id.isEmpty,
              let safe = session.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            isLoadingSessionAnalysis = false
            analysisLoadStatus = "BAD SESSION ID"
            analysisSessionToOpen = optimizedSessionForAnalysis(session)
            return
        }

        let urlStrings = [
            "https://live.avoperformance.org/api/sessions/\(safe)",
            "https://live.avoperformance.org/api/session/\(safe)"
        ]

        Task {
            var lastErrorText = "NO DETAIL"
            for urlString in urlStrings {
                guard let url = URL(string: urlString) else { continue }
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.timeoutInterval = 8
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200...299).contains(code), !data.isEmpty else {
                        lastErrorText = "HTTP \(code)"
                        continue
                    }
                    let json = try JSONSerialization.jsonObject(with: data)
                    let sessions = parseRemoteSessionsList(json)
                    let parsedDetail = sessions.first ?? parseRemoteSession(json)
                    if let parsedDetail {
                        var detail = parsedDetail
                        if detail.id.hasPrefix("SESSION_") || detail.id.isEmpty { detail.id = session.id }
                        if detail.horseId.isEmpty { detail.horseId = session.horseId }
                        if detail.startedAt.isEmpty { detail.startedAt = session.startedAt }
                        if detail.durationSeconds <= 0 { detail.durationSeconds = session.durationSeconds }
                        if detail.distanceKm <= 0 { detail.distanceKm = session.distanceKm }
                        let optimized = optimizedSessionForAnalysis(detail)
                        await MainActor.run {
                            if let idx = remoteTrainingSessions.firstIndex(where: { $0.id == optimized.id || $0.id == session.id }) {
                                remoteTrainingSessions[idx] = optimized
                            } else {
                                remoteTrainingSessions.append(optimized)
                            }
                            selectedRemoteSessionId = optimized.id
                            isLoadingSessionAnalysis = false
                            analysisLoadStatus = "ANALYSIS READY"
                            analysisSessionToOpen = optimized
                            print("AVO SESSION ANALYSIS DETAIL LOADED", optimized.id, optimized.samples.count, optimized.track.count)
                        }
                        return
                    }
                    lastErrorText = "PARSE EMPTY"
                } catch {
                    lastErrorText = String(describing: error)
                    print("AVO SESSION ANALYSIS DETAIL TRY ERROR", urlString, error)
                }
            }

            // Last resort: never leave the user with a dead button. Open the analysis shell with index data.
            await MainActor.run {
                isLoadingSessionAnalysis = false
                analysisLoadStatus = "ANALYSIS INDEX ONLY"
                analysisSessionToOpen = optimizedSessionForAnalysis(session)
                print("AVO SESSION ANALYSIS FALLBACK OPEN", session.id, lastErrorText)
            }
        }
    }

    private func loadRemoteTrainingSessionDetail(_ sessionId: String) {
        guard !sessionId.isEmpty,
              let safe = sessionId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://live.avoperformance.org/api/session/\(safe)") else { return }
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 9
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200...299).contains(code), !data.isEmpty else { return }
                let json = try JSONSerialization.jsonObject(with: data)
                let sessions = parseRemoteSessionsList(json)
                guard let detail = sessions.first ?? parseRemoteSession(json) else { return }
                await MainActor.run {
                    if let idx = remoteTrainingSessions.firstIndex(where: { $0.id == detail.id || $0.id == sessionId }) {
                        remoteTrainingSessions[idx] = optimizedSessionForAnalysis(detail)
                    } else {
                        remoteTrainingSessions.append(optimizedSessionForAnalysis(detail))
                    }
                    selectedRemoteSessionId = detail.id
                    print("AVO SESSION DETAIL LOADED", detail.id)
                }
            } catch {
                print("AVO SESSION DETAIL ERROR", error)
            }
        }
    }

    private func parseRemoteSessionsList(_ json: Any) -> [AVORemoteTrainingSession] {
        if let array = json as? [[String: Any]] {
            return array.compactMap { parseRemoteSession($0) }
        }
        guard let dict = json as? [String: Any] else { return [] }
        for key in ["sessions", "items", "data", "results", "index"] {
            if let array = dict[key] as? [[String: Any]] {
                return array.compactMap { parseRemoteSession($0) }
            }
        }
        if let nested = dict["session"] as? [String: Any] {
            var merged = nested
            if let samples = dict["samples"] { merged["samples"] = samples }
            if let track = dict["track"] { merged["track"] = track }
            return [parseRemoteSession(merged)].compactMap { $0 }
        }
        if let nested = dict["meta"] as? [String: Any] {
            var merged = nested
            if let samples = dict["samples"] { merged["samples"] = samples }
            if let track = dict["track"] { merged["track"] = track }
            return [parseRemoteSession(merged)].compactMap { $0 }
        }
        let dictValues = dict.values.compactMap { $0 as? [String: Any] }
        if !dictValues.isEmpty { return dictValues.compactMap { parseRemoteSession($0) } }
        return [parseRemoteSession(dict)].compactMap { $0 }
    }

    private func parseRemoteSession(_ dictAny: Any) -> AVORemoteTrainingSession? {
        guard var dict = dictAny as? [String: Any] else { return nil }
        if let nested = dict["session"] as? [String: Any] {
            var merged = nested
            if let samples = dict["samples"] { merged["samples"] = samples }
            if let track = dict["track"] { merged["track"] = track }
            dict = merged
        }
        if let nested = dict["meta"] as? [String: Any] {
            dict.merge(nested) { current, _ in current }
        }

        let id = remoteString(dict, ["id", "sid", "sessionId", "session_id", "folder", "name"]) ?? remoteString(dict, ["title"]) ?? "SESSION_\(UUID().uuidString.prefix(8))"
        let horseId = normalizedHorseId(remoteString(dict, ["horseId", "horse_id", "horse", "activeHorse", "horseName"]) ?? "HORSE_001")
        let horseName = remoteString(dict, ["horseName", "horse_name", "horse", "horseId"]) ?? horseId
        let status = (remoteString(dict, ["status", "state", "sessionStatus"]) ?? "SAVED").uppercased()
        let started = remoteString(dict, ["startedAt", "startTime", "started", "createdAt", "date", "timestamp"]) ?? dateStringFromSessionId(id)
        let ended = remoteString(dict, ["endedAt", "endTime", "ended", "closedAt", "updatedAt"]) ?? ""
        let duration = remoteDouble(dict, ["durationSeconds", "duration", "elapsedSeconds", "totalSeconds"]) ?? durationFromStrings(started: started, ended: ended)
        let distance = remoteDouble(dict, ["distanceKm", "distance_km", "distance", "km"]) ?? 0
        let avgSpeed = remoteDouble(dict, ["avgSpeedKmh", "avgSpeed", "averageSpeed", "speedAvg"]) ?? 0
        let maxSpeed = remoteDouble(dict, ["maxSpeedKmh", "maxSpeed", "speedMax"]) ?? 0
        let avgHR = remoteDouble(dict, ["avgHeartRate", "avgHr", "heartRateAvg", "hrAvg"]) ?? 0
        let maxHR = remoteDouble(dict, ["maxHeartRate", "maxHr", "heartRateMax", "hrMax"]) ?? 0
        let geofenceId = remoteString(dict, ["geofenceId", "geofence_id", "zoneId"]) ?? ""
        let geofenceName = remoteString(dict, ["geofenceName", "geofence_name", "zoneName"]) ?? ""
        let samples = remoteAnalysisSamples(dict)
        let track = remoteTrack(dict).isEmpty ? samples.compactMap { $0.coordinate } : remoteTrack(dict)

        return AVORemoteTrainingSession(
            id: id,
            horseId: horseId,
            horseName: horseName,
            status: status,
            startedAt: started,
            endedAt: ended,
            durationSeconds: duration,
            distanceKm: distance,
            avgSpeedKmh: avgSpeed,
            maxSpeedKmh: maxSpeed,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            geofenceId: geofenceId,
            geofenceName: geofenceName,
            track: track,
            samples: samples
        )
    }

    private func remoteString(_ dict: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
            if let value = dict[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }

    private func remoteDouble(_ dict: [String: Any], _ keys: [String]) -> Double? {
        for key in keys {
            if let value = dashboardDouble(dict[key]) { return value }
        }
        return nil
    }

    private func remoteAnalysisSamples(_ dict: [String: Any]) -> [AVOTrainingAnalysisSample] {
        for key in ["samples", "telemetry", "points", "track", "path"] {
            if let arr = dict[key] as? [[String: Any]] {
                let parsed = arr.enumerated().compactMap { index, item -> AVOTrainingAnalysisSample? in
                    let gps = (item["gps"] as? [String: Any]) ?? (item["location"] as? [String: Any]) ?? item
                    let lat = dashboardDouble(gps["lat"] ?? gps["latitude"])
                    let lon = dashboardDouble(gps["lon"] ?? gps["lng"] ?? gps["longitude"])
                    let time = remoteString(item, ["time", "t", "timestamp", "createdAt", "ts"]) ?? "T+\(index)s"
                    let speed = remoteDouble(item, ["speedKmh", "speed", "speed_kmh", "kmh"]) ?? remoteDouble(gps, ["speedKmh", "speed", "speed_kmh", "kmh"]) ?? 0
                    let impact = remoteDouble(item, ["impactG", "impact", "gForce", "g", "maxG"]) ?? 0
                    let hr = remoteDouble(item, ["heartRate", "heart_rate", "bpm", "hr"]) ?? 0
                    let asym = remoteDouble(item, ["asymmetry", "asym", "symmetryDelta", "lateralBalance"]) ?? 0
                    let cadence = remoteDouble(item, ["cadence", "spm"]) ?? 0
                    if lat == nil && lon == nil && speed == 0 && impact == 0 && hr == 0 && asym == 0 { return nil }
                    return AVOTrainingAnalysisSample(time: time, latitude: lat, longitude: lon, speedKmh: speed, impactG: impact, heartRate: hr, asymmetry: asym, cadence: cadence)
                }
                if !parsed.isEmpty { return parsed }
            }
        }
        return []
    }

    private func remoteTrack(_ dict: [String: Any]) -> [CLLocationCoordinate2D] {
        for key in ["track", "path", "points", "samples", "gps", "locations"] {
            if let arr = dict[key] as? [[String: Any]] {
                let pts = arr.compactMap { item -> CLLocationCoordinate2D? in
                    let source = (item["gps"] as? [String: Any]) ?? item
                    guard let lat = dashboardDouble(source["lat"] ?? source["latitude"]),
                          let lon = dashboardDouble(source["lon"] ?? source["lng"] ?? source["longitude"]) else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                if !pts.isEmpty { return pts }
            }
        }
        return []
    }

    private func remoteSessionSortDate(_ session: AVORemoteTrainingSession) -> Date {
        if let date = parseRemoteDate(session.startedAt) { return date }
        if let date = parseRemoteDate(dateStringFromSessionId(session.id)) { return date }
        return Date.distantPast
    }

    private func dateStringFromSessionId(_ id: String) -> String {
        let pattern = #"(20\d{6})[_-]?(\d{6})"#
        if let range = id.range(of: pattern, options: .regularExpression) {
            let raw = String(id[range]).replacingOccurrences(of: "-", with: "_")
            let clean = raw.replacingOccurrences(of: "_", with: "")
            if clean.count >= 14 {
                let y = clean.prefix(4)
                let mo = clean.dropFirst(4).prefix(2)
                let d = clean.dropFirst(6).prefix(2)
                let h = clean.dropFirst(8).prefix(2)
                let mi = clean.dropFirst(10).prefix(2)
                let s = clean.dropFirst(12).prefix(2)
                return "\(y)-\(mo)-\(d)T\(h):\(mi):\(s)Z"
            }
        }
        return ""
    }

    private func parseRemoteDate(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyyMMdd_HHmmss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"]
        for format in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            f.dateFormat = format
            if let date = f.date(from: value) { return date }
        }
        return nil
    }

    private func durationFromStrings(started: String, ended: String) -> Double {
        guard let a = parseRemoteDate(started), let b = parseRemoteDate(ended) else { return 0 }
        return max(0, b.timeIntervalSince(a))
    }

    private var completedTrainingColumn: some View {
        ProBox("SERVER TRAINING SESSIONS · HORSE INDEX") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SELECT HORSE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.58))
                        Picker("HORSE", selection: $selectedSessionHorseId) {
                            ForEach(remoteHorseIds, id: \.self) { id in
                                Text(id).tag(id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.green)
                        .onChange(of: selectedSessionHorseId) { _ in
                            selectedRemoteSessionId = remoteSessionsForSelectedHorse.first?.id
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.32), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    metricCard("SESSIONS", "\(remoteSessionsForSelectedHorse.count)", .cyan)
                    metricCard("STATUS", sessionsLoadStatus, sessionsLoadStatus.contains("LOADED") ? .green : .orange)

                    Button {
                        loadRemoteTrainingSessions(force: true)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("REFRESH")
                        }
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 76)
                        .background(Color.cyan.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.34), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 82)

                if remoteSessionsForSelectedHorse.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Text("NO SERVER SESSIONS")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("El servidor debe devolver JSON en /api/sessions/index. Ahora mismo la Raspberry está respondiendo vacío o sin sesiones para \(selectedSessionHorseId).")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.52))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(remoteSessionsForSelectedHorse.prefix(60))) { session in
                                remoteSessionRow(session)
                            }
                            if remoteSessionsForSelectedHorse.count > 60 {
                                Text("Mostrando 60 sesiones recientes de \(remoteSessionsForSelectedHorse.count). Pulsa REFRESH o filtra por caballo.")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.52))
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { loadRemoteTrainingSessions(force: true) }
    }

    private var completedDetailColumn: some View {
        ProBox("TRAINING DETAIL · SERVER SESSION") {
            VStack(alignment: .leading, spacing: 10) {
                if let session = selectedRemoteSession {
                    remoteSessionHero(session)
                    Button {
                        openRemoteSessionAnalysis(session)
                    } label: {
                        HStack {
                            Image(systemName: "waveform.path.ecg.rectangle")
                            Text("ANÁLISIS COMPLETO DE SESIÓN")
                            Spacer()
                            Text(isLoadingSessionAnalysis ? "CARGANDO DATOS..." : analysisLoadStatus)
                        }
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    RaspberryHorseMapView(
                        coordinate: session.track.last ?? hardware.externalCoordinate,
                        path: [],
                        zone: settings.trainingZone
                    )
                    .frame(height: 160)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.24), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 8) {
                        metricCard("DURATION", formatDuration(session.durationSeconds), .white)
                        metricCard("DISTANCE", String(format: "%.2f km", session.distanceKm), .cyan)
                    }
                    .frame(height: 74)
                    HStack(spacing: 8) {
                        metricCard("AVG SPEED", String(format: "%.1f km/h", session.avgSpeedKmh), .cyan)
                        metricCard("MAX SPEED", String(format: "%.1f km/h", session.maxSpeedKmh), .orange)
                    }
                    .frame(height: 74)
                    HStack(spacing: 8) {
                        metricCard("AVG HR", session.avgHeartRate > 0 ? String(format: "%.0f bpm", session.avgHeartRate) : "--", .green)
                        metricCard("MAX HR", session.maxHeartRate > 0 ? String(format: "%.0f bpm", session.maxHeartRate) : "--", .red)
                    }
                    .frame(height: 74)
                    VStack(spacing: 6) {
                        MiniText(name: "GEOFENCE", value: session.geofenceName.isEmpty ? (session.geofenceId.isEmpty ? "NO GEOFENCE LINK" : session.geofenceId) : session.geofenceName, color: session.geofenceName.isEmpty && session.geofenceId.isEmpty ? .orange : .green)
                        MiniText(name: "TRACK POINTS", value: "\(session.track.count)", color: session.track.isEmpty ? .orange : .cyan)
                        MiniText(name: "SOURCE", value: "/api/sessions/index + /api/session/<sid>", color: .cyan)
                    }
                    Spacer()
                } else {
                    Spacer()
                    Text("SELECT A SERVER TRAINING")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                    Text("Las sesiones cerradas se leen desde la Raspberry y se filtran por caballo.")
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

    private func remoteSessionRow(_ session: AVORemoteTrainingSession) -> some View {
        let selected = selectedRemoteSession?.id == session.id
        return Button {
            selectedRemoteSessionId = session.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.horseName.isEmpty ? session.horseId : session.horseName)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                    Text(session.id)
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(remoteDateDisplay(session.startedAt)) · \(formatDuration(session.durationSeconds)) · \(String(format: "%.2f km", session.distanceKm))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(session.status.isEmpty ? "SAVED" : session.status)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(session.status.contains("REC") || session.status.contains("ACTIVE") ? .red : .green)
                    Text(String(format: "AVG %.1f · MAX %.1f", session.avgSpeedKmh, session.maxSpeedKmh))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.88))
                    Text("TRACK \(session.track.count)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(session.track.isEmpty ? .orange : .green)
                }
            }
            .padding(12)
            .background(selected ? Color.green.opacity(0.15) : Color.black.opacity(0.44))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.green.opacity(0.72) : Color.white.opacity(0.10), lineWidth: selected ? 1.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func remoteSessionHero(_ session: AVORemoteTrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("SERVER TRAINING")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(session.status.isEmpty ? "SAVED" : session.status)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(session.status.contains("REC") || session.status.contains("ACTIVE") ? .red : .green)
            }
            Text(session.horseName.isEmpty ? session.horseId : session.horseName)
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(session.id)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(remoteDateDisplay(session.startedAt))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.32), lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func remoteDateDisplay(_ raw: String) -> String {
        if let date = parseRemoteDate(raw) { return shortDateTime(date) }
        return raw.isEmpty ? "DATE --" : raw
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



// MARK: - Full server session analysis page
struct AVOTrainingSessionAnalysisPage: View {
    let session: AVORemoteTrainingSession
    let fallbackZone: TrainingZone
    let onClose: () -> Void

    @State private var cursorIndex: Double = 0
    @State private var realStartIndex: Int?
    @State private var realEndIndex: Int?
    @State private var noteText: String = ""
    @State private var markerStatus: String = "MARK REAL TRAINING START/END"
    @State private var pdfURL: URL?

    private var allSamples: [AVOTrainingAnalysisSample] {
        if !session.samples.isEmpty { return avoDownsampleSamplesForUI(session.samples, limit: 900) }
        return avoDownsampleCoordinatesForUI(session.track, limit: 900).enumerated().map { index, coord in
            AVOTrainingAnalysisSample(
                time: "GPS \(index)",
                latitude: coord.latitude,
                longitude: coord.longitude,
                speedKmh: 0,
                impactG: 0,
                heartRate: 0,
                asymmetry: 0,
                cadence: 0
            )
        }
    }

    private var maxCursorIndex: Double { Double(max(0, allSamples.count - 1)) }
    private var currentIndex: Int { min(max(0, Int(cursorIndex.rounded())), max(0, allSamples.count - 1)) }

    private var analysisRange: ClosedRange<Int> {
        guard !allSamples.isEmpty else { return 0...0 }
        let a = realStartIndex ?? 0
        let b = realEndIndex ?? (allSamples.count - 1)
        return min(a, b)...max(a, b)
    }

    private var selectedSamples: [AVOTrainingAnalysisSample] {
        guard !allSamples.isEmpty else { return [] }
        return Array(allSamples[analysisRange])
    }

    private var selectedTrack: [CLLocationCoordinate2D] {
        avoDownsampleCoordinatesForUI(selectedSamples.compactMap { $0.coordinate }, limit: 500)
    }

    private var fullTrack: [CLLocationCoordinate2D] {
        let coords = allSamples.compactMap { $0.coordinate }
        return avoDownsampleCoordinatesForUI(coords.isEmpty ? session.track : coords, limit: 500)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(colors: [Color.black, Color.green.opacity(0.08), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    analysisHeader
                        .frame(height: 58)

                    HStack(spacing: 10) {
                        VStack(spacing: 10) {
                            ProBox("GPS MAP · REAL TRAINING LINE") {
                                RaspberryHorseMapView(
                                    coordinate: selectedTrack.last ?? fullTrack.last ?? fallbackZone.coordinate,
                                    path: selectedTrack.isEmpty ? fullTrack : selectedTrack,
                                    zone: fallbackZone
                                )
                            }
                            .frame(height: geo.size.height * 0.34)

                            timelinePanel
                                .frame(height: 158)

                            notesPanel
                        }
                        .frame(width: geo.size.width * 0.50)

                        VStack(spacing: 10) {
                            metricsGrid
                                .frame(height: geo.size.height * 0.28)
                            chartsGrid
                            exportPanel
                                .frame(height: 112)
                        }
                    }
                }
                .padding(14)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear { loadLocalMarkers() }
    }

    private var analysisHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SESSION ANALYSIS · AVO PERFORMANCE HORSE")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                Text("\(session.horseId) · \(session.id) · \(session.status)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Text(markerStatus)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(markerStatus.contains("SAVED") ? .green : .orange)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color.black.opacity(0.52))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.green.opacity(0.24), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            Button("CERRAR") { onClose() }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color.red.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var timelinePanel: some View {
        ProBox("TIMELINE · MARK REAL TRAINING SEGMENT") {
            VStack(alignment: .leading, spacing: 10) {
                AVOTrainingTimelineView(
                    samples: avoDownsampleSamplesForUI(allSamples, limit: 400),
                    cursorIndex: currentIndex,
                    startIndex: realStartIndex,
                    endIndex: realEndIndex
                )
                .frame(height: 46)

                Slider(value: $cursorIndex, in: 0...max(maxCursorIndex, 1), step: 1)
                    .tint(.green)

                HStack(spacing: 8) {
                    analysisButton("INICIO REAL", color: .green) {
                        realStartIndex = currentIndex
                        if let end = realEndIndex, end < currentIndex { realEndIndex = nil }
                        saveLocalMarkers()
                    }
                    analysisButton("FIN REAL", color: .orange) {
                        realEndIndex = currentIndex
                        if let start = realStartIndex, start > currentIndex { realStartIndex = nil }
                        saveLocalMarkers()
                    }
                    analysisButton("FULL", color: .cyan) {
                        realStartIndex = 0
                        realEndIndex = max(0, allSamples.count - 1)
                        saveLocalMarkers()
                    }
                    analysisButton("LIMPIAR", color: .red) {
                        realStartIndex = nil
                        realEndIndex = nil
                        saveLocalMarkers()
                    }
                }

                HStack {
                    MiniText(name: "CURSOR", value: "\(currentIndex + 1)/\(max(allSamples.count, 1))", color: .cyan)
                    MiniText(name: "REAL START", value: realStartIndex.map { "#\($0 + 1)" } ?? "--", color: .green)
                    MiniText(name: "REAL END", value: realEndIndex.map { "#\($0 + 1)" } ?? "--", color: .orange)
                    MiniText(name: "MODE", value: (realStartIndex != nil || realEndIndex != nil) ? "REAL SEGMENT" : "FULL SESSION", color: .green)
                }
            }
        }
    }

    private var notesPanel: some View {
        ProBox("NOTES · TRAINER / VET") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $noteText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.35))
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
                Text("Los apuntes se incluyen en el PDF local de la sesión.")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
    }

    private var metricsGrid: some View {
        ProBox("REAL SEGMENT METRICS") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    analysisMetric("DURATION", formatDuration(estimatedDurationSeconds), .white)
                    analysisMetric("DISTANCE", String(format: "%.2f km", selectedDistanceKm), .cyan)
                    analysisMetric("POINTS", "\(selectedSamples.count)", .green)
                }
                HStack(spacing: 8) {
                    analysisMetric("AVG SPEED", String(format: "%.1f km/h", avg(selectedSamples.map { $0.speedKmh })), .cyan)
                    analysisMetric("MAX SPEED", String(format: "%.1f km/h", selectedSamples.map { $0.speedKmh }.max() ?? 0), .orange)
                    analysisMetric("MIN SPEED", String(format: "%.1f km/h", selectedSamples.map { $0.speedKmh }.filter { $0 > 0 }.min() ?? 0), .white)
                }
                HStack(spacing: 8) {
                    analysisMetric("AVG BPM", bpmValue(avg(selectedSamples.map { $0.heartRate })), .green)
                    analysisMetric("MAX BPM", bpmValue(selectedSamples.map { $0.heartRate }.max() ?? 0), .red)
                    analysisMetric("ASYMM", String(format: "%.2f", avg(selectedSamples.map { abs($0.asymmetry) })), .orange)
                }
            }
        }
    }

    private var chartsGrid: some View {
        ProBox("GRAPHS · SPEED / IMPACT / BPM / ASYMMETRY") {
            VStack(spacing: 8) {
                AVOAnalysisChart(title: "SPEED KM/H", values: selectedSamples.map { $0.speedKmh }, color: .cyan)
                AVOAnalysisChart(title: "IMPACT G", values: selectedSamples.map { $0.impactG }, color: .orange)
                AVOAnalysisChart(title: "BPM", values: selectedSamples.map { $0.heartRate }, color: .green)
                AVOAnalysisChart(title: "ASYMMETRY", values: selectedSamples.map { abs($0.asymmetry) }, color: .red)
            }
        }
    }

    private var exportPanel: some View {
        ProBox("REPORT EXPORT") {
            HStack(spacing: 10) {
                Button {
                    pdfURL = createSessionPDF()
                } label: {
                    Label("CREAR PDF", systemImage: "doc.richtext")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: 150, height: 46)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("COMPARTIR", systemImage: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 150, height: 46)
                            .background(Color.cyan.opacity(0.22))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Spacer()
                Text(pdfURL == nil ? "PDF incluirá métricas, tramo real y apuntes." : "PDF READY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(pdfURL == nil ? .white.opacity(0.56) : .green)
            }
        }
    }

    private func analysisButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(color.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.45), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func analysisMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.44))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var estimatedDurationSeconds: Double {
        if !selectedSamples.isEmpty, selectedSamples.count < allSamples.count, session.durationSeconds > 0, allSamples.count > 1 {
            return session.durationSeconds * Double(max(0, selectedSamples.count - 1)) / Double(max(1, allSamples.count - 1))
        }
        return session.durationSeconds > 0 ? session.durationSeconds : Double(max(0, selectedSamples.count - 1))
    }

    private var selectedDistanceKm: Double {
        let coords = selectedSamples.compactMap { $0.coordinate }
        guard coords.count > 1 else { return session.distanceKm }
        var meters: Double = 0
        for i in 1..<coords.count {
            meters += CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude).distance(from: CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude))
        }
        return meters / 1000.0
    }

    private func avg(_ values: [Double]) -> Double {
        let clean = values.filter { $0.isFinite && $0 > 0 }
        guard !clean.isEmpty else { return 0 }
        return clean.reduce(0, +) / Double(clean.count)
    }

    private func bpmValue(_ value: Double) -> String {
        value > 0 ? String(format: "%.0f bpm", value) : "--"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func markerKey(_ suffix: String) -> String { "AVO_SESSION_ANALYSIS_\(session.id)_\(suffix)" }

    private func loadLocalMarkers() {
        let defaults = UserDefaults.standard
        let start = defaults.integer(forKey: markerKey("START"))
        let end = defaults.integer(forKey: markerKey("END"))
        if defaults.object(forKey: markerKey("START")) != nil { realStartIndex = min(start, max(0, allSamples.count - 1)) }
        if defaults.object(forKey: markerKey("END")) != nil { realEndIndex = min(end, max(0, allSamples.count - 1)) }
        noteText = defaults.string(forKey: markerKey("NOTES")) ?? ""
    }

    private func saveLocalMarkers() {
        let defaults = UserDefaults.standard
        if let realStartIndex { defaults.set(realStartIndex, forKey: markerKey("START")) } else { defaults.removeObject(forKey: markerKey("START")) }
        if let realEndIndex { defaults.set(realEndIndex, forKey: markerKey("END")) } else { defaults.removeObject(forKey: markerKey("END")) }
        defaults.set(noteText, forKey: markerKey("NOTES"))
        markerStatus = "REAL SEGMENT SAVED LOCAL"
        print("AVO SESSION ANALYSIS MARKERS SAVED", session.id, realStartIndex as Any, realEndIndex as Any)
    }

    private func createSessionPDF() -> URL? {
        saveLocalMarkers()
        let safeName = session.id.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AVO_Training_\(safeName).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let title = "AVO PERFORMANCE HORSE · SESSION REPORT"
                let body = """
                Horse: \(session.horseId)
                Session: \(session.id)
                Status: \(session.status)
                Real segment: \(realStartIndex.map { "#\($0 + 1)" } ?? "FULL START") → \(realEndIndex.map { "#\($0 + 1)" } ?? "FULL END")
                Duration: \(formatDuration(estimatedDurationSeconds))
                Distance: \(String(format: "%.2f km", selectedDistanceKm))
                Avg speed: \(String(format: "%.1f km/h", avg(selectedSamples.map { $0.speedKmh })))
                Max speed: \(String(format: "%.1f km/h", selectedSamples.map { $0.speedKmh }.max() ?? 0))
                Avg BPM: \(bpmValue(avg(selectedSamples.map { $0.heartRate })))
                Max BPM: \(bpmValue(selectedSamples.map { $0.heartRate }.max() ?? 0))
                Avg impact: \(String(format: "%.2f G", avg(selectedSamples.map { $0.impactG })))
                Asymmetry: \(String(format: "%.2f", avg(selectedSamples.map { abs($0.asymmetry) })))

                Notes:
                \(noteText.isEmpty ? "--" : noteText)
                """
                let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.black]
                let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: UIColor.darkGray]
                title.draw(in: CGRect(x: 36, y: 36, width: 523, height: 40), withAttributes: titleAttrs)
                body.draw(in: CGRect(x: 36, y: 92, width: 523, height: 650), withAttributes: bodyAttrs)
            }
            markerStatus = "PDF READY"
            return url
        } catch {
            markerStatus = "PDF ERROR"
            print("AVO PDF ERROR", error)
            return nil
        }
    }
}

struct AVOAnalysisChart: View {
    let title: String
    let values: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
                Text(summary)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }
            AVOLiveSparkline(values: cleanValues, color: color)
                .frame(height: 42)
        }
        .padding(8)
        .background(Color.black.opacity(0.38))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cleanValues: [Double] {
        let v = values.map { $0.isFinite ? $0 : 0 }
        return v.count > 1 ? v : [0, 0]
    }

    private var summary: String {
        let v = cleanValues.filter { $0 > 0 }
        guard !v.isEmpty else { return "--" }
        return String(format: "AVG %.1f · MAX %.1f", v.reduce(0, +) / Double(v.count), v.max() ?? 0)
    }
}

struct AVOTrainingTimelineView: View {
    let samples: [AVOTrainingAnalysisSample]
    let cursorIndex: Int
    let startIndex: Int?
    let endIndex: Int?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.56))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))

                Path { path in
                    let values = samples.map { max(0, $0.speedKmh) }
                    guard values.count > 1 else { return }
                    let maxValue = max(values.max() ?? 1, 1)
                    for index in values.indices {
                        let x = geo.size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                        let y = geo.size.height * CGFloat(1.0 - values[index] / maxValue)
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(.cyan, lineWidth: 2)
                markerLine(index: startIndex, color: .green, geo: geo)
                markerLine(index: endIndex, color: .orange, geo: geo)
                markerLine(index: cursorIndex, color: .white, geo: geo)
            }
        }
    }

    private func markerLine(index: Int?, color: Color, geo: GeometryProxy) -> some View {
        let count = max(1, samples.count - 1)
        let raw = CGFloat(index ?? 0) / CGFloat(count)
        let x = geo.size.width * min(max(raw, 0), 1)
        return Rectangle()
            .fill(color)
            .frame(width: 3)
            .offset(x: x)
            .shadow(color: color.opacity(0.7), radius: 5)
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
                if zone.isFreeDrawZone {
                    MapPolygon(coordinates: zone.polygonCoordinates)
                        .foregroundStyle(.green.opacity(0.20))
                        .stroke(.green, lineWidth: 3)
                } else {
                    MapCircle(center: zone.coordinate, radius: zone.radiusMeters)
                        .foregroundStyle(.green.opacity(0.16))
                        .stroke(.green, lineWidth: 2)
                }
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
