import SwiftUI
import UIKit

struct AVOSettingsFullPage: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var camera: CameraManager
    @ObservedObject var sensors: SensorHub
    @ObservedObject var store: SessionStore
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings
    @ObservedObject var stableStore: AVOStableStore

    @Binding var modelImportStatus: String
    @State private var showAppFolderPicker = false
    @State private var showAITrainingSettingsPage = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 8) {
                    header

                    HStack(spacing: 8) {
                        appModePanel
                        hardwareNetworkPanel
                        aiBiomechPanel
                    }
                    .frame(height: max(220, geo.size.height * 0.265))

                    HStack(spacing: 8) {
                        alertThresholdsPanel
                        sessionStoragePanel
                        diagnosticPanel
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAppFolderPicker) {
            AVOFolderPicker { url in
                stableStore.setRootFolder(url)
                showAppFolderPicker = false
            }
        }
        .fullScreenCover(isPresented: $showAITrainingSettingsPage) {
            AVOAITrainingSettingsPage(datasetManager: camera.datasetManager)
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "Settings",
            subtitle: "App + hardware control · configuración central",
            status: settings.commercialMode.rawValue,
            accent: .green,
            onClose: { dismiss() }
        ) {
            AVOUnifiedHeaderActionButton(title: "AI TRAIN / DRIVE", color: .cyan) {
                showAITrainingSettingsPage = true
            }
        }
    }


    private var appModePanel: some View {
        AVOPremiumPanel("APP MODE / SAFETY", accent: .green) {
            AVODenseValue(name: "Mode", value: settings.commercialMode.rawValue, color: .green)
            AVODenseValue(name: "Lock UI", value: settings.lockedMode ? "LOCKED" : "UNLOCKED", color: settings.lockedMode ? .red : .green)
            AVODenseValue(name: "Fullscreen", value: settings.fullscreenMode ? "ON" : "OFF", color: .cyan)
            HStack(spacing: 8) {
                Button { settings.toggleMode() } label: { BottomButton("MODE", .green) }
                Button { settings.lockedMode.toggle() } label: { BottomButton("LOCK", .yellow) }
            }
            Spacer()
        }
    }

    private var hardwareNetworkPanel: some View {
        AVOPremiumPanel("HARDWARE / NETWORK", accent: .cyan) {
            AVODenseValue(name: "UDP", value: hardware.udpStatus, color: .green)
            AVODenseValue(name: "UDP Port", value: "\(settings.udpPort)", color: .white)
            AVODenseValue(name: "Base IP", value: settings.baseIP, color: .white)
            AVODenseValue(name: "BLE", value: hardware.bleStatus, color: .cyan)
            HStack(spacing: 8) {
                Button { hardware.startUDP(port: settings.udpPort) } label: { BottomButton("UDP", .green) }
                Button { hardware.startBLEScan() } label: { BottomButton("BLE", .cyan) }
                Button { hardware.stopBLE() } label: { BottomButton("BLE OFF", .orange) }
            }
            Spacer()
        }
    }

    private var aiBiomechPanel: some View {
        AVOPremiumPanel("AI / BIOMECH", accent: .purple) {
            AVODenseValue(name: "CoreML", value: "MODEL CHECK READY", color: .cyan)
            AVODenseValue(name: "Camera", value: camera.trackingText, color: .green)
            AVODenseValue(name: "Quality", value: "\(Int(camera.quality * 100))%", color: .green)
            AVODenseValue(name: "Risk", value: "\(Int(camera.risk * 100))%", color: .red)
            HStack(spacing: 8) {
                BottomButton("PERMS", .cyan)
                Button { showAITrainingSettingsPage = true } label: { BottomButton("DRIVE/COLAB", .cyan) }
                BottomButton("COREML", .purple)
                BottomButton("ACK", .orange)
            }
            ModelImporterView(modelStatus: $modelImportStatus) {
                camera.reloadPoseModelFromDocuments()
            }
            .scaleEffect(0.78)
            .frame(maxWidth: .infinity)
            Spacer()
        }
    }

    private var alertThresholdsPanel: some View {
        AVOPremiumPanel("ALERT THRESHOLDS", accent: .orange) {
            VStack(alignment: .leading, spacing: 10) {
                Text("LIVE")
                    .foregroundColor(.green)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Slider(value: $settings.alertThresholdRisk, in: 0...1)
                Text("BIOMECH")
                    .foregroundColor(.green)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                Slider(value: $settings.alertThresholdFatigue, in: 0...1)
                AVODenseValue(name: "Current alert", value: compactAlertText(), color: compactAlertColor())
                Spacer()
            }
        }
    }

    private var sessionStoragePanel: some View {
        AVOPremiumPanel("SESSION / STORAGE", accent: .green) {
            AVODenseValue(name: "Samples", value: "\(camera.sessionSamples.count)", color: .green)
            AVODenseValue(name: "Saved", value: "\(store.availableSessions.count)", color: .cyan)
            AVODenseValue(name: "App folder", value: stableStore.rootFolderURL?.lastPathComponent ?? "Mi app", color: .green)
            HStack(spacing: 8) {
                Button {
                    store.saveSession(samples: camera.sessionSamples)
                } label: {
                    BottomButton("SAVE", .green)
                }
                Button {
                    showAppFolderPicker = true
                } label: {
                    BottomButton("APP FOLDER", .green)
                }
                Button {
                    stableStore.loadIndex()
                } label: {
                    BottomButton("SYNC FOLDER", .orange)
                }
            }
            Spacer()
        }
    }

    private var diagnosticPanel: some View {
        AVOPremiumPanel("DIAGNOSTIC", accent: .red) {
            AVODenseValue(name: "Lora", value: sensors.loraStatus, color: .green)
            AVODenseValue(name: "Live rate", value: sensors.liveRateText, color: .cyan)
            AVODenseValue(name: "RTK", value: sensors.rtkStatus, color: .green)
            AVODenseValue(name: "Battery", value: sensors.remoteBattery, color: .orange)
            Spacer()
        }
    }

    private func compactAlertText() -> String {
        if camera.audibleAlert.contains("NO") { return "OK" }
        if camera.risk > 0.70 || camera.fatigue > 0.70 { return "WATCH" }
        if camera.audibleAlert.contains("VISUAL") { return "ALERT" }
        return "CHECK"
    }

    private func compactAlertColor() -> Color {
        let alert = compactAlertText()
        if alert == "OK" { return .green }
        if alert == "WATCH" { return .orange }
        if alert == "ALERT" { return .red }
        return .red
    }
}
