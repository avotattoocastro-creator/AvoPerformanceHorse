import SwiftUI
import UIKit

struct AVOBiomechFullPage: View {
    @State private var showSettingsPanel = false
    @State private var showLeftInfoPanels = false
    @State private var showTrackingPanel = false
    @State private var showTopGatePanel = false
    @State private var showRecordPanel = false
    @State private var showHubConfiguration = false

    @AppStorage("biotech_show_phase133_rec_panel") private var biotechShowRecPanel = false
    @AppStorage("biotech_show_selected_horse_header") private var biotechShowHorseHeader = true

    @AppStorage("avoHubShowToolDock") private var hubShowToolDock = true
    @AppStorage("avoHubShowBottomBar") private var hubShowBottomBar = true
    @AppStorage("avoHubShowLowerTelemetry") private var hubShowLowerTelemetry = true
    @AppStorage("avoHubShowFloatingRecord") private var hubShowFloatingRecord = false
    @AppStorage("avoHubShowTopGate") private var hubShowTopGate = false
    @AppStorage("avoHubShowInfoPanel") private var hubShowInfoPanel = false
    @AppStorage("avoHubShowTrackingPanel") private var hubShowTrackingPanel = false
    @AppStorage("avoHubButtonClient") private var hubButtonClient = true
    @AppStorage("avoHubButtonAuto") private var hubButtonAuto = true
    @AppStorage("avoHubButtonSlow") private var hubButtonSlow = true
    @AppStorage("avoHubButtonSnap") private var hubButtonSnap = true
    @AppStorage("avoHubButtonData") private var hubButtonData = true
    @AppStorage("avoHubButtonReview") private var hubButtonReview = true
    @AppStorage("avoHubButtonExport") private var hubButtonExport = true
    @AppStorage("avoHubButtonExports") private var hubButtonExports = true
    @AppStorage("avoHubButtonSave") private var hubButtonSave = true
    @AppStorage("avoHubButtonLock") private var hubButtonLock = true
    @AppStorage("avoHubMetricGait") private var hubMetricGait = true
    @AppStorage("avoHubMetricAsym") private var hubMetricAsym = true
    @AppStorage("avoHubMetricRisk") private var hubMetricRisk = true
    @AppStorage("avoHubMetricFatigue") private var hubMetricFatigue = true
    @AppStorage("avoHubMetricQuality") private var hubMetricQuality = true
    @AppStorage("avoHubMetricHR") private var hubMetricHR = true
    @AppStorage("avoHubMetricSpeed") private var hubMetricSpeed = true
    @AppStorage("avoHubMetricStride") private var hubMetricStride = true
    @AppStorage("avoHubDockPoints") private var hubDockPoints = true
    @AppStorage("avoHubDockRec") private var hubDockRec = true
    @AppStorage("avoHubDockAuto") private var hubDockAuto = true
    @AppStorage("avoHubDockTrack") private var hubDockTrack = true
    @AppStorage("avoHubDockInfo") private var hubDockInfo = true
    @AppStorage("avoHubDockHUD") private var hubDockHUD = true
    @AppStorage("avoHubDockHeat") private var hubDockHeat = true
    @AppStorage("avoHubDockLock") private var hubDockLock = true
    @AppStorage("avoHubDockCam") private var hubDockCam = true
    @AppStorage("avoHubDockSettings") private var hubDockSettings = true
    @AppStorage("avoHubStatusRSSI") private var hubStatusRSSI = true
    @AppStorage("avoHubStatusConnection") private var hubStatusConnection = true
    @AppStorage("avoHubStatusFrequency") private var hubStatusFrequency = true
    @AppStorage("avoHubStatusRecMode") private var hubStatusRecMode = true
    @AppStorage("avoHubStatusLiDAR") private var hubStatusLiDAR = true
    @AppStorage("avoHubStatusDataset") private var hubStatusDataset = true
    @AppStorage("avoHubStatusAlert") private var hubStatusAlert = true
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var camera: CameraManager
    @ObservedObject var sensors: SensorHub
    @ObservedObject var stableStore: AVOStableStore
    @ObservedObject var settings: HardwareSettings

    var onRecord: () -> Void
    var onSnap: () -> Void
    var onToggleDataset: () -> Void
    var onReview: () -> Void
    var onExport: () -> Void
    var onExports: () -> Void
    var onSave: () -> Void
    var onToggleLock: () -> Void

    private var fallbackHorseName: String {
        "NO HORSE"
    }

    private var latestLiDARSample: Double? {
        camera.lidarDistanceMeters > 0 ? camera.lidarDistanceMeters : nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 8) {
                    header
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    cameraStage
                        .frame(width: geo.size.width - 32, height: max(360, geo.size.height - 148))

                    if hubShowBottomBar {
                        biomechBottomBar
                            .frame(width: geo.size.width, height: 58)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)

            }
            .ignoresSafeArea()
            .onAppear {
                AVODashboardCameraHandoff.prepareBiotechCamera()
                BiotechCompleteSystemController.shared.prepare(horseName: BiotechHorseSessionRecorder.shared.selectedHorseName)
            }
        }
        .fullScreenCover(isPresented: $showHubConfiguration) {
            AVOHubConfigurationPage()
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "Biomech",
            subtitle: "BIOTECH STUDIO · REC CLIENTE · REC BIOMECH · DATA REVIEW · TRACKING",
            status: settings.commercialMode.rawValue,
            accent: .cyan,
            onClose: { dismiss() }
        ) {
            EmptyView()
        }
    }


    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.88))
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: 1))
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var cameraStage: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CameraPreview(manager: camera)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.04))

                AVOFullViewHorseSkeletonOverlay(camera: camera)

                AVOLiDARHorseContourOverlay(camera: camera)

                biomechFrameOverlay

                if showTopGatePanel || hubShowTopGate {
                    trackingGateBadge
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, 18)
                }

                if biotechShowHorseHeader {
                    BiotechSelectedHorseCompactStrip()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                }

                if showTrackingPanel && hubShowTrackingPanel {
                    VStack(alignment: .trailing, spacing: 6) {
                        AVOCameraOwnershipBadge()
                        BiotechDataStatusBadge()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 70)
                    .padding(.trailing, 18)
                }

                if hubShowToolDock {
                    biomechCollapsibleToolDock
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 18)
                        .padding(.top, 92)
                }

                if showLeftInfoPanels && hubShowInfoPanel {
                    compactModeSessionPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 112)
                        .padding(.top, 92)
                }

                if showTrackingPanel && hubShowTrackingPanel {
                    compactTrackingPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 18)
                        .padding(.bottom, 126)
                }
                if showRecordPanel || hubShowFloatingRecord || biotechShowRecPanel {
                    BiotechRecFloatingPanelV4(
                        camera: camera,
                        selectedHorseName: BiotechHorseSessionRecorder.shared.selectedHorseName,
                        requestedFPS: 120
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 18)
                    .padding(.bottom, hubShowLowerTelemetry ? 86 : 18)
                }

                if hubShowLowerTelemetry {
                    lowerTelemetryHUD
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.20), lineWidth: 1))
            .shadow(color: Color.cyan.opacity(0.08), radius: 14)
        }
    }


    private var trackingGateBadge: some View {
        VStack(spacing: 3) {
            Text(camera.trackingGateStatusText)
                .foregroundColor(camera.trackingGateStatusText.contains("WEAK") ? .orange : .green)
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text(camera.trackingGateScoreText + " · " + camera.trackingGateReasonText)
                .foregroundColor(.cyan)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            Text(camera.bodyPersistenceText + " · " + camera.trainingFrameRankText)
                .foregroundColor(.green)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            Text(camera.bodyOrientationText + " · " + camera.bodyPhaseText)
                .foregroundColor(.white.opacity(0.82))
                .font(.system(size: 8, weight: .black, design: .monospaced))
            Text(camera.biomechAIStatusText + " · " + camera.biomechAISuspicionText)
                .foregroundColor(camera.biomechAIStatusText.contains("HIGH") ? .red : .orange)
                .font(.system(size: 8, weight: .black, design: .monospaced))
            Text(camera.biomechAISupportText)
                .foregroundColor(.cyan)
                .font(.system(size: 8, weight: .black, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.62))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }


    private var biomechCollapsibleToolDock: some View {
        VStack(spacing: 0) {
            biomechToolButton(icon: "slider.horizontal.3", title: "CFG", isOn: showHubConfiguration) {
                showHubConfiguration = true
            }

            if hubDockPoints {
            biomechToolButton(icon: "target", title: "PUNTOS", isOn: !camera.trackedHorseJoints.isEmpty) {
                showTopGatePanel.toggle()
            }
            }

            if hubDockRec {
            biomechToolButton(icon: "record.circle", title: "REC", isOn: showRecordPanel || camera.isRecording) {
                showRecordPanel.toggle()
            }
            }

            if hubDockAuto {
            biomechToolButton(icon: "bolt.badge.a", title: "AUTO", isOn: camera.autoRecEnabled) {
                camera.toggleAutoRecMode()
            }
            }

            if hubDockTrack {
            biomechToolButton(icon: "figure.walk", title: "TRACK", isOn: showTrackingPanel) {
                showTrackingPanel.toggle()
            }
            }

            if hubDockInfo {
            biomechToolButton(icon: "info.circle", title: "INFO", isOn: showLeftInfoPanels) {
                showLeftInfoPanels.toggle()
            }
            }

            if hubDockHUD {
            biomechToolButton(icon: "grid", title: "HUD", isOn: showTopGatePanel) {
                showTopGatePanel.toggle()
            }
            }

            if hubDockHeat {
            biomechToolButton(icon: "flame", title: "HEAT", isOn: camera.bodyHeatmapText != "HEATMAP --") {
                showTrackingPanel.toggle()
            }
            }

            if hubDockLock {
            biomechToolButton(icon: "lock", title: "LOCK", isOn: camera.hasActiveObjectLock) {
                camera.hasActiveObjectLock.toggle()
            }
            }

            if hubDockCam {
            biomechToolButton(icon: "camera.rotate", title: "CAM", isOn: true) {
                camera.switchCamera()
            }
            }

            if hubDockSettings {
            biomechToolButton(icon: "gearshape", title: "SET", isOn: showSettingsPanel) {
                showSettingsPanel.toggle()
            }
            }
        }
        .frame(width: 74)
        .background(Color.black.opacity(0.58))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func biomechToolButton(icon: String, title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(isOn ? .green : .white.opacity(0.82))

                Text(title)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(isOn ? .green : .white.opacity(0.78))
                    .lineLimit(1)

                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(isOn ? .green : .orange)
            }
            .frame(width: 74, height: 58)
            .background(isOn ? Color.green.opacity(0.08) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var compactModeSessionPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MODO / SESIÓN")
                    .foregroundColor(.green)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Spacer()
                Button {
                    showLeftInfoPanels = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 10, weight: .black))
                }
                .buttonStyle(.plain)
            }

            compactInfoRow("MODO", "FULL BIOMECH", .green)
            compactInfoRow("CABALLO", fallbackHorseName.uppercased(), .green)
            compactInfoRow("SESIÓN", camera.isRecording ? "REC" : "STANDBY", camera.isRecording ? .red : .green)
            compactInfoRow("AUTO", camera.autoRecStatus, camera.autoRecEnabled ? .green : .orange)
            compactInfoRow("LIDAR", latestLiDARSample == nil ? "--" : "ON", latestLiDARSample == nil ? .orange : .green)
            compactInfoRow("CALIDAD", "\(Int(camera.quality * 100))%", camera.quality < 0.35 ? .orange : .green)
        }
        .padding(10)
        .frame(width: 190, alignment: .leading)
        .background(Color.black.opacity(0.66))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var compactTrackingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ANATOMY / TRACKING")
                    .foregroundColor(.green)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Spacer()
                Button {
                    showTrackingPanel = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 10, weight: .black))
                }
                .buttonStyle(.plain)
            }

            compactInfoRow("POSE", camera.horsePoseStatus, .green)
            compactInfoRow("JOINT", "\(camera.trackedHorseJoints.count)/\(HorseJoint.allCases.count)", .green)
            compactInfoRow("TRACK", camera.anatomyTrackingQualityText, .orange)
            compactInfoRow("PERSIST", camera.bodyPersistenceText, .orange)
            compactInfoRow("GATE", camera.trackingGateScoreText, .orange)
            compactInfoRow("A-GATE", camera.autoRecGateText, camera.autoRecGateText.contains("OK") ? .green : .orange)
            compactInfoRow("ORIENT", camera.bodyOrientationText, .green)
            compactInfoRow("PHASE", camera.bodyPhaseText, .yellow)
            compactInfoRow("AI", camera.biomechAISuspicionText, camera.biomechAIStatusText.contains("HIGH") ? .red : .orange)
            compactInfoRow("GAIT34", camera.gaitEngineText, .green)
            compactInfoRow("BODY", camera.bodyMapStatusText, .cyan)
            compactInfoRow("VET", camera.vetRiskLevelText, camera.vetRiskLevelText.contains("HIGH") || camera.vetRiskLevelText.contains("CRITICAL") ? .red : .green)
            compactInfoRow("DATA", camera.autoDatasetV2Text, .orange)
        }
        .padding(10)
        .frame(width: 248, alignment: .leading)
        .background(Color.black.opacity(0.66))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func compactInfoRow(_ left: String, _ right: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(left)
                .foregroundColor(.white.opacity(0.72))
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .frame(width: 58, alignment: .leading)

            Text(right.isEmpty ? "--" : right)
                .foregroundColor(color)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.45)

            Spacer(minLength: 0)
        }
    }

    private var biomechFrameOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .stroke(Color.green.opacity(0.22), lineWidth: 1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                CornerShape(corner: .topLeft).stroke(Color.green.opacity(0.65), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .position(x: 42, y: 42)
                CornerShape(corner: .topRight).stroke(Color.green.opacity(0.65), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .position(x: geo.size.width - 42, y: 42)
                CornerShape(corner: .bottomLeft).stroke(Color.green.opacity(0.65), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .position(x: 42, y: geo.size.height - 42)
                CornerShape(corner: .bottomRight).stroke(Color.green.opacity(0.65), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .position(x: geo.size.width - 42, y: geo.size.height - 42)
            }
            .allowsHitTesting(false)
        }
    }

    private var leftInfoHUD: some View {
        VStack(alignment: .leading, spacing: 10) {
            AVOHUDLine(title: "MODE", value: "FULL BIOMECH", color: .green)
            AVOHUDLine(title: "HORSE", value: stableStore.selectedHorseName.uppercased(), color: .white)
            AVOHUDLine(title: "SESSION", value: camera.sessionText.uppercased(), color: .white)
            AVOHUDLine(title: "LIDAR", value: camera.lidarSupported ? "ON" : "OFF", color: camera.lidarSupported ? .green : .orange)
        }
        .padding(12)
        .frame(width: 230, alignment: .leading)
        .background(Color.black.opacity(0.66))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.38), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var rightInfoHUD: some View {
        VStack(alignment: .trailing, spacing: 10) {
            MiniText(name: "HR", value: sensors.pulseStatus, color: .cyan)
            MiniText(name: "SPEED", value: sensors.speedStatus, color: .white)
        }
        .padding(12)
        .frame(width: 160, alignment: .trailing)
        .background(Color.black.opacity(0.66))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.38), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var toolRail: some View {
        VStack(spacing: 0) {
            ForEach(["circle", "camera.viewfinder", "scope", "dot.scope", "hare.fill"], id: \.self) { icon in
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white.opacity(0.88))
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.58))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.09), lineWidth: 1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.28), lineWidth: 1))
    }

    private var biomechFloatingRecordButton: some View {
        VStack(alignment: .trailing, spacing: 8) {
            recordModeSelector
            recordActionButtons
        }
        .padding(10)
        .background(Color.black.opacity(0.86))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(camera.isRecording ? Color.red : Color.white.opacity(0.26), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: camera.isRecording ? Color.red.opacity(0.45) : Color.white.opacity(0.12), radius: 10)
    }

    private var recordModeSelector: some View {
        HStack(spacing: 6) {
            biomechRecordModeButton(title: "CLIENT", mode: .client)
            biomechRecordModeButton(title: "SLOW", mode: .biomechSlow)
            Button {
                camera.toggleAutoRecMode()
            } label: {
                Text(camera.autoRecEnabled ? "AUTO ON" : "AUTO OFF")
                    .foregroundColor(camera.autoRecEnabled ? .black : .white)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .frame(width: 72, height: 26)
                    .background(camera.autoRecEnabled ? Color.green : Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
    }

    private func biomechRecordModeButton(title: String, mode: AVOBiomechRecordingMode) -> some View {
        Button {
            camera.setVideoRecordMode(mode)
        } label: {
            Text(title)
                .foregroundColor(camera.videoRecordMode == mode ? .black : .white)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .frame(width: 64, height: 26)
                .background(camera.videoRecordMode == mode ? (mode == .client ? Color.green : Color.orange) : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(camera.isRecording)
    }

    private var recordActionButtons: some View {
        HStack(spacing: 8) {
            Button {
                camera.toggleClientVideoRecording()
            } label: {
                recordPill(title: camera.isRecording && camera.videoRecordMode == .client ? "STOP CLIENT" : "REC CLIENT", color: .green, active: camera.isRecording && camera.videoRecordMode == .client)
            }
            .buttonStyle(.plain)

            Button {
                camera.toggleBiomechSlowVideoRecording()
            } label: {
                recordPill(title: camera.isRecording && camera.videoRecordMode == .biomechSlow ? "STOP SLOW" : "REC BIOMECH", color: .orange, active: camera.isRecording && camera.videoRecordMode == .biomechSlow)
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(camera.videoModeStatus + " · " + camera.biomechVideoStatus + " · " + camera.autoRecStatus)
                .foregroundColor(.white.opacity(0.76))
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .offset(y: 16)
        }
        .padding(.bottom, 12)
    }

    private func recordPill(title: String, color: Color, active: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(active ? Color.red : Color.white)
                .frame(width: 11, height: 11)
            Text(title)
                .foregroundColor(active ? .red : color)
                .font(.system(size: 12, weight: .black, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.black.opacity(0.90))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.red : color.opacity(0.58), lineWidth: 1.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var lowerTelemetryHUD: some View {
        HStack(spacing: 0) {
            if hubMetricGait {
                AVOHUDMetric(title: "GAIT", value: camera.gait.uppercased(), color: .green)
            }
            if hubMetricAsym {
                AVOHUDMetric(title: "ASYM", value: camera.asymmetry, color: .white)
            }
            if hubMetricRisk {
                AVOHUDMetric(title: "RISK", value: "\(Int(camera.risk * 100))%", color: .red)
            }
            if hubMetricFatigue {
                AVOHUDMetric(title: "FATIGUE", value: "\(Int(camera.fatigue * 100))%", color: .orange)
            }
            if hubMetricQuality {
                AVOHUDMetric(title: "QUALITY", value: "\(Int(camera.quality * 100))%", color: .green)
            }
            if hubMetricHR {
                AVOHUDMetric(title: "HR", value: sensors.pulseStatus, color: .cyan)
            }
            if hubMetricSpeed {
                AVOHUDMetric(title: "SPEED", value: sensors.speedStatus, color: .cyan)
            }
            if hubMetricStride {
                AVOHUDMetric(title: "STRIDE", value: camera.strideText.replacingOccurrences(of: "STRIDE ", with: ""), color: .white)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 10, height: 10)
                Text(camera.isRecording ? "REC" : (camera.autoRecEnabled ? "AUTO" : "READY"))
                    .foregroundColor(camera.isRecording ? .red : (camera.autoRecEnabled ? .green : .white))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
            }
            .frame(width: 122)
        }
        .frame(height: 56)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.70))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var biomechBottomBar: some View {
        HStack(spacing: 0) {
            if hubStatusRSSI {
                BottomStatusBox(title: "RSSI", value: "--", color: .green, width: 120)
            }
            if hubStatusConnection {
                BottomStatusBox(title: "CONNECTION", value: "BLE", color: .green, width: 150)
            }
            if hubStatusFrequency {
                BottomStatusBox(title: "FREQUENCY", value: sensors.liveRateText.replacingOccurrences(of: "LIVE ", with: ""), color: .cyan, width: 140)
            }
            if hubStatusRecMode {
                BottomStatusBox(title: "REC MODE", value: camera.videoRecordMode.shortTitle, color: camera.videoRecordMode == .client ? .green : .orange, width: 105)
            }
            if hubStatusLiDAR {
                BottomStatusBox(title: "LiDAR", value: camera.lidarSupported ? camera.lidarDistanceText : "OFF", color: camera.lidarSupported ? .cyan : .orange, width: 105)
            }

            HStack(spacing: 7) {
                if hubButtonClient {
                    BottomActionButton(title: camera.isRecording ? "STOP" : "CLIENT", color: camera.isRecording ? .orange : .green, action: { camera.toggleClientVideoRecording() })
                }
                if hubButtonAuto {
                    BottomActionButton(title: camera.autoRecEnabled ? "AUTO ON" : "AUTO", color: camera.autoRecEnabled ? .green : .orange, action: { camera.toggleAutoRecMode() })
                }
                if hubButtonSlow {
                    BottomActionButton(title: "SLOW", color: .orange, action: { camera.toggleBiomechSlowVideoRecording() })
                }
                if hubButtonSnap {
                    BottomActionButton(title: "SNAP", color: .cyan, action: onSnap)
                }
                if hubButtonData {
                    BottomActionButton(title: camera.isDatasetRecording ? "DATA OFF" : "DATA", color: camera.isDatasetRecording ? .orange : .purple, action: onToggleDataset)
                }
                if hubButtonReview {
                    BottomActionButton(title: "REVIEW", color: .cyan, action: onReview)
                }
                if hubButtonExport {
                    BottomActionButton(title: "EXPORT", color: .green, action: onExport)
                }
                if hubButtonExports {
                    BottomActionButton(title: "EXPORTS", color: .mint, action: onExports)
                }
                if hubButtonSave {
                    BottomActionButton(title: "SAVE", color: .green, action: onSave)
                }
                if hubButtonLock {
                    BottomActionButton(title: settings.lockedMode ? "OPEN" : "LOCK", color: .yellow, action: onToggleLock)
                }
            }
            .frame(width: 500, height: 58)
            .background(Color.black.opacity(0.22))

            if hubStatusDataset {
                BottomStatusBox(title: "DATASET", value: camera.datasetCountText.replacingOccurrences(of: "DATASET ", with: ""), color: camera.isDatasetRecording ? .purple : .green, width: 165)
            }
            if hubStatusAlert {
                BottomStatusBox(title: "ALERT", value: camera.vetAlert.replacingOccurrences(of: "VET AI ", with: ""), color: .red, width: 105)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct AVOHUDLine: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(title + ":")
                .foregroundColor(.white.opacity(0.65))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .frame(width: 72, alignment: .leading)
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Spacer(minLength: 0)
        }
    }
}

private struct AVOHUDMetric: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .foregroundColor(.white.opacity(0.58))
                .font(.system(size: 10, weight: .black, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(width: 120, height: 48)
        .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1), alignment: .trailing)
    }
}

private enum AVOHUDCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct CornerShape: Shape {
    var corner: AVOHUDCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .topRight:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        return path
    }
}


// MARK: - PHASE133 REAL BIOTECH REC DATA PANEL
// Directly embedded in AVOBiomechFullPage.swift.

@MainActor
private struct Phase133BiotechSelectedHorseHeader: View {
    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared
    @ObservedObject private var complete = BiotechCompleteSystemController.shared

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hare.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 1) {
                Text("CABALLO ACTIVO")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Text(horseName)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Text(complete.mode.rawValue.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(width: 320, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
    }

    private var horseName: String {
        let v = recorder.selectedHorseName
        return (v.isEmpty || v == "SIN_CABALLO") ? "SIN CABALLO SELECCIONADO" : v
    }
}

@MainActor
private struct Phase133BiotechRecPanel: View {
    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared
    @ObservedObject private var complete = BiotechCompleteSystemController.shared
    @ObservedObject private var dataBridge = BiotechDataToReviewBridge.shared

    var body: some View {
        VStack(spacing: 8) {
            Text("PANEL REC V4")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.green)

            HStack(spacing: 7) {
                chip("CLIENT", active: complete.mode == .recClient || complete.mode == .fullCapture)
                chip("BIOMECH", active: complete.mode == .recBiotech || complete.mode == .fullCapture)
                chip("DATA", active: dataBridge.isDataOn)
            }

            HStack(spacing: 8) {
                Button {
                    prepare()
                    complete.startClientREC()
                } label: {
                    recLabel("REC CLIENT", color: .green)
                }
                .buttonStyle(.plain)

                Button {
                    prepare()
                    complete.startBiotechREC()
                } label: {
                    recLabel("REC BIOMECH", color: .orange)
                }
                .buttonStyle(.plain)
            }

            Button {
                prepare()
                complete.toggleData(requestedFPS: 120)
            } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(dataBridge.isDataOn ? Color.green : Color.white)
                        .frame(width: 9, height: 9)

                    Text(dataBridge.isDataOn ? "REC DATA ON → REVIEW" : "REC DATA OFF")
                        .font(.system(size: 11, weight: .black, design: .monospaced))

                    Spacer()

                    Text("120FPS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(dataBridge.isDataOn ? Color.green.opacity(0.24) : Color.purple.opacity(0.34))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(dataBridge.isDataOn ? Color.green.opacity(0.8) : Color.purple.opacity(0.9), lineWidth: 1))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button("FULL CAPTURE") {
                    prepare()
                    complete.startFullCapture()
                }
                .buttonStyle(.borderedProminent)

                Button("STOP") {
                    complete.stopAll()
                }
                .buttonStyle(.bordered)

                Button("MANIFEST") {
                    complete.exportManifest()
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))

            HStack {
                Text(horseName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)

                Spacer()

                Text(dataBridge.isDataOn ? "DATA \(dataBridge.capturedCount)" : "DATA READY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(dataBridge.isDataOn ? .green : .white.opacity(0.65))
            }
        }
        .padding(12)
        .frame(width: 390)
        .background(Color.black.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
    }

    private func prepare() {
        let h = horseName == "SIN CABALLO SELECCIONADO" ? "SIN_CABALLO" : horseName
        recorder.setSelectedHorse(h)
        complete.prepare(horseName: h)
    }

    private var horseName: String {
        let v = recorder.selectedHorseName
        return (v.isEmpty || v == "SIN_CABALLO") ? "SIN CABALLO SELECCIONADO" : v
    }

    private func chip(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(active ? Color.black : Color.white.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(active ? Color.green : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func recLabel(_ title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color.white).frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(color.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.85), lineWidth: 1))
    }
}

@MainActor
private struct Phase133BiotechForcedLayer: View {
    @AppStorage("biotech_show_phase133_rec_panel") private var showRecPanel: Bool = true
    @AppStorage("biotech_show_selected_horse_header") private var showHorseHeader: Bool = true

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if showHorseHeader {
                    Phase133BiotechSelectedHorseHeader()
                        .padding(.trailing, 175)
                        .padding(.top, 14)
                }
            }

            Spacer()

            HStack {
                Spacer()
                if showRecPanel {
                    Phase133BiotechRecPanel()
                        .padding(.trailing, 28)
                        .padding(.bottom, 86)
                }
            }
        }
        .allowsHitTesting(true)
    }
}
