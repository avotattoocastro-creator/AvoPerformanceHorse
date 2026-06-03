
import SwiftUI

struct PhasePanel: View {
    let mode: DashboardMode
    
    @ObservedObject var camera: CameraManager
    @ObservedObject var location: LocationManager
    @ObservedObject var sensors: SensorHub
    @ObservedObject var store: SessionStore
    @ObservedObject var profiles: ProfileStore
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings
    
    var body: some View {
        ProBox(panelTitle) {
            switch mode {
                
            case .live:
                RealGPSMapView(location: location)
                    .frame(height: 180)
                
            case .biomech:
                biomechPanel
                
            case .replay:
                replayPanel
                
            case .profiles:
                profilesPanel
                
            case .sensors:
                sensorsPanel
                
            case .report:
                reportPanel

            case .videoEditor:
                AVOVideoEvidenceEditorView(
                    camera: camera,
                    sensors: sensors,
                    stableStore: AVOStableStore(),
                    hardware: hardware,
                    settings: settings
                )

            case .analysis:
                VStack(alignment: .leading, spacing: 8) {
                    MiniText(name: "ENGINE", value: "ADV BIOMECH TRACKING", color: .green)
                    MiniText(name: "SKELETON", value: "STABILIZED + TEMPORAL LOCK", color: .cyan)
                    MiniText(name: "LIDAR", value: "FUSION READY", color: .purple)
                    MiniText(name: "REPORT", value: "VET / COLAB BRIDGE", color: .orange)
                }
                
            case .settings:
                settingsPanel
                
            case .hardware:
                EmptyView()

            case .devices:
                EmptyView()

            case .review:
                EmptyView()

            case .aiTraining:
                EmptyView()
                
            case .stable:
                Text("STABLE REGISTRY AVAILABLE IN MAIN DASHBOARD")
                    .foregroundColor(.white)

            case .configHub:
                AVOHubConfigurationPage()
            
        
}
        }
        .frame(width: 928, height: 225)
    }
    
    var biomechPanel: some View {
        ZStack {
            CameraPreview(manager: camera)
                .frame(width: 908, height: 185)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            HorseOverlay(
                horseBox: camera.horseBox,
                riderBox: camera.riderBox,
                riderPosePoints: camera.riderPosePoints,
                horseKeypoints: camera.horseKeypoints,
                quality: camera.quality,
                fatigue: camera.fatigue,
                risk: camera.risk
            )
            .frame(width: 908, height: 185)
            
            VStack {
                HStack {
                    Text("REAL BIOMECH AI VIEW")
                        .foregroundColor(.green)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    
                    Spacer()
                    
                    Text(camera.vetDiagnosis)
                        .foregroundColor(.orange)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    biomechMini(title: "GAIT", value: camera.gait, color: .cyan)
                    biomechMini(title: "ASYM", value: camera.asymmetry, color: .green)
                    biomechMini(title: "RISK", value: "\(Int(camera.risk * 100))%", color: .red)
                    biomechMini(title: "FATIGUE", value: "\(Int(camera.fatigue * 100))%", color: .orange)
                    biomechMini(title: "QUALITY", value: "\(Int(camera.quality * 100))%", color: .green)
                    biomechMini(title: "HR", value: sensors.pulseStatus, color: .green)
                }
            }
            .padding(8)
        }
    }
    
    func biomechMini(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .foregroundColor(.white.opacity(0.75))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
            
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 110, height: 42)
        .background(Color.black.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.65), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    var replayPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            MiniText(name: "FILE", value: store.selectedSessionName, color: .cyan)
            MiniText(name: "STATUS", value: store.replayStatus, color: .cyan)
            MiniText(name: "INDEX", value: "\(store.replayIndex)", color: .green)
            MiniText(name: "SAMPLES", value: "\(store.replaySamples.count)", color: .green)
            
            HStack {
                Button { store.refreshSessions() } label: { BottomButton("LIST FILES", .green) }
                Button { store.loadLastSession() } label: { BottomButton("LOAD LAST", .cyan) }
                Button { store.replayPaused.toggle() } label: { BottomButton(store.replayPaused ? "PLAY" : "PAUSE", .cyan) }
                Button { store.jumpReplayForward() } label: { BottomButton("SKIP", .cyan) }
                Button { store.stopReplay() } label: { BottomButton("STOP", .orange) }
            }
        }
    }
    
    var profilesPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            MiniText(name: "HORSE", value: profiles.horseName, color: .green)
            MiniText(name: "RIDER", value: profiles.riderName, color: .cyan)
            MiniText(name: "PROFILE", value: profiles.profileStatus, color: .orange)
            MiniText(name: "NFC", value: profiles.nfcStatus, color: .purple)
            
            HStack {
                Button { profiles.nextHorse() } label: { BottomButton("NEXT HORSE", .green) }
                Button { profiles.nextRider() } label: { BottomButton("NEXT RIDER", .cyan) }
                
                Button {
                    profiles.applyNFC(
                        horseID: hardware.nfcHorse,
                        riderID: hardware.nfcRider
                    )
                } label: {
                    BottomButton("LOAD NFC", .purple)
                }
                
                Button { profiles.saveProfiles() } label: { BottomButton("SAVE PROFILE", .green) }
                Button { profiles.loadProfiles() } label: { BottomButton("LOAD PROFILE", .cyan) }
            }
        }
    }
    
    var sensorsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    MiniText(name: "UDP", value: hardware.udpStatus, color: .green)
                    MiniText(name: "PACKETS", value: hardware.packetStatus, color: .cyan)
                    MiniText(name: "LIVE RATE", value: sensors.liveRateText, color: .green)
                    MiniText(name: "SEQ", value: sensors.seqStatus, color: hardware.lostPackets > 0 ? .orange : .green)
                }
                .frame(width: 300)
                
                VStack(alignment: .leading, spacing: 5) {
                    MiniText(name: "ESP32", value: hardware.esp32Status, color: .green)
                    MiniText(name: "LORA", value: sensors.loraStatus, color: .green)
                    MiniText(name: "RTK", value: sensors.rtkStatus, color: .green)
                    MiniText(name: "BAT", value: sensors.remoteBattery, color: .orange)
                }
                .frame(width: 220)
                
                VStack(alignment: .leading, spacing: 5) {
                    MiniText(name: "PULSE", value: sensors.pulseStatus, color: .green)
                    MiniText(name: "SPEED", value: sensors.speedStatus, color: .cyan)
                    MiniText(name: "CADENCE", value: sensors.cadenceStatus, color: .white)
                    MiniText(name: "IMU", value: sensors.batchStatus, color: .purple)
                }
                .frame(width: 220)
                
                VStack(alignment: .leading, spacing: 5) {
                    MiniText(name: "PITCH", value: String(format: "%.2f", sensors.imuPitch), color: .white)
                    MiniText(name: "ROLL", value: String(format: "%.2f", sensors.imuRoll), color: .white)
                    MiniText(name: "IMPACT", value: String(format: "%.2f", sensors.imuImpact), color: .orange)
                    MiniText(name: "PROTO", value: "t + seq + imu[]", color: .cyan)
                }
                .frame(width: 160)
            }
            
            HStack {
                Button {
                    hardware.startUDP(port: settings.udpPort)
                } label: {
                    BottomButton("START UDP", .green)
                }
                
                Button {
                    hardware.stopUDP()
                } label: {
                    BottomButton("STOP UDP", .orange)
                }
                
                Button {
                    settings.udpPort += 1
                    hardware.startUDP(port: settings.udpPort)
                } label: {
                    BottomButton("PORT +", .cyan)
                }
                
                Button {
                    settings.udpPort = max(1000, settings.udpPort - 1)
                    hardware.startUDP(port: settings.udpPort)
                } label: {
                    BottomButton("PORT -", .cyan)
                }
                
                Text("PORT \(settings.udpPort)")
                    .foregroundColor(.green)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
        }
    }
    
    var reportPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            MiniText(name: "SAMPLES", value: "\(camera.sessionSamples.count)", color: .green)
            MiniText(name: "REPORT", value: camera.reportText, color: .orange)
            MiniText(name: "PDF", value: store.pdfStatus, color: .orange)
            MiniText(name: "SYNC", value: store.syncStatus, color: .blue)
            MiniText(name: "HISTORY", value: store.historyStatus, color: .purple)
            MiniText(name: "ALERT", value: camera.audibleAlert, color: .red)
            
            HStack {
                Button {
                    store.saveSession(samples: camera.sessionSamples)
                } label: {
                    BottomButton("SAVE JSON", .green)
                }
                
                Button {
                    store.createPDFReport(
                        samples: camera.sessionSamples,
                        horse: profiles.horseName,
                        rider: profiles.riderName
                    )
                } label: {
                    BottomButton("PDF", .orange)
                }
                
                Button {
                    store.updateHistory(samples: camera.sessionSamples)
                } label: {
                    BottomButton("HISTORY", .purple)
                }
            }
        }
    }
    
    var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            MiniText(name: "MODE", value: settings.commercialMode.rawValue, color: .green)
            MiniText(name: "UDP PORT", value: "\(settings.udpPort)", color: .cyan)
            MiniText(name: "BASE IP", value: settings.baseIP, color: .white)
            MiniText(name: "BASE PORT", value: settings.basePort, color: .white)
            MiniText(name: "PERMISSIONS", value: settings.permissionsStatus, color: .orange)
            MiniText(name: "COREML", value: settings.coreMLStatus, color: .cyan)
            MiniText(name: "AUTO REC", value: settings.autoRecordInsideZone ? "ON" : "OFF", color: settings.autoRecordInsideZone ? .green : .orange)
            MiniText(name: "ZONE", value: location.zoneStatus, color: location.zoneStatus.contains("INSIDE") ? .green : .orange)
            
            HStack {
                Button { settings.toggleMode() } label: { BottomButton("MODE", .green) }
                Button { settings.autoRecordInsideZone.toggle() } label: { BottomButton("AUTO REC", .orange) }
                Button { settings.checkPermissions() } label: { BottomButton("PERMS", .cyan) }
                Button { settings.checkCoreMLModels() } label: { BottomButton("COREML", .purple) }
                Button { settings.prepareAppStore() } label: { BottomButton("APP", .blue) }
            }
        }
    }
    
    var panelTitle: String {
        switch mode {
        case .live:
            return "LIVE GPS / TRACKING"
        case .biomech:
            return "BIOMECHANICS / REAL AI CAMERA"
        case .replay:
            return "SESSION FILES / ADVANCED REPLAY"
        case .profiles:
            return "PERSISTENT PROFILE EDITOR"
        case .sensors:
            return "HIGH RATE SENSOR PANEL / 25Hz LIVE / 100Hz IMU BATCH READY"
        case .report:
            return "REPORT / HISTORY / ALERTS"
        case .videoEditor:
            return "VIDEO EVIDENCE EDITOR / MULTILAYER"
        case .analysis:
            return "BIOMECH ANALYSIS ENGINE PRO / ADV TRACK"
        case .settings:
            return "PERMISSIONS / COREML / TESTFLIGHT / REAL QA"
        case .hardware:
            return "BLE / UDP / LORA / ESP32 HARDWARE PANEL"
        case .devices:
            return "DEVICE CONFIGURATION / SIM / RASPBERRY / MODULES"
        case .review:
            return "AI POINT REVIEW / TRAINING EXPORT"
        case .aiTraining:
            return "AI TRAINING SETTINGS / DRIVE + COLAB"
        case .stable:
            return "STABLE REGISTRY / HORSES / VET / AI"
        case .configHub:
            return "CONFIG HUB / GLOBAL APP SETTINGS"
            
        }
    }
}
