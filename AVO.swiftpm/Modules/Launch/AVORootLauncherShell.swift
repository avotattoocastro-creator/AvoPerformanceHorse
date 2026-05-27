import SwiftUI
import PDFKit
import UIKit

/// Root commercial shell for AVO Performance Horse.
/// This file owns the Launch navigation and shared app services.
/// DashboardView is no longer the application root.
struct AVORootLauncherShell: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var sensors = SensorHub()
    @StateObject private var store = SessionStore()
    @StateObject private var profiles = ProfileStore()
    @StateObject private var hardware = AVOHardwareReceiver()
    @StateObject private var settings = HardwareSettings()
    @StateObject private var pdfManager = PDFReportManager()
    @StateObject private var stableStore = AVOStableStore()
    @StateObject private var latestExportSharer = LatestExportSharer()

    @State private var presentedMode: DashboardMode?
    @State private var showLatestExportShare = false
    @State private var modelImportStatus = "HORSE POSE MODEL READY"

    private let syncTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        AVOHomeLauncherView { mode in
            if mode == .review {
                camera.prepareDatasetForReview()
            }
            presentedMode = mode
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .onAppear {
            AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: true)
        }
        .onReceive(syncTimer) { _ in
            AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: stableStore.selectedHorseProfile != nil)
        }
        .fullScreenCover(item: $presentedMode) { mode in
            modulePage(for: mode)
        }
        .sheet(isPresented: $pdfManager.showPreview) {
            if let url = pdfManager.pdfURL {
                PDFPreview(url: url)
            }
        }
        .sheet(isPresented: $showLatestExportShare) {
            if let url = latestExportSharer.zipURL {
                LatestExportShareSheet(url: url)
            } else {
                Text("Preparando export...")
            }
        }
    }

    @ViewBuilder
    private func modulePage(for mode: DashboardMode) -> some View {
        switch mode {
        case .live:
            AVOLiveTrainingDashboardPage(
                hardware: hardware,
                sensors: sensors,
                camera: camera,
                stableStore: stableStore,
                settings: settings
            )

        case .biomech:
            AVOBiomechFullPage(
                camera: camera,
                sensors: sensors,
                stableStore: stableStore,
                settings: settings,
                onRecord: { camera.toggleSession() },
                onSnap: {
                    camera.reportText = "SNAP READY"
                    store.exportStatus = "SNAP READY"
                },
                onToggleDataset: { camera.toggleDatasetRecording() },
                onReview: { camera.prepareDatasetForReview() },
                onExport: { camera.prepareDatasetForReview() },
                onExports: {
                    latestExportSharer.shareLatestExport {
                        showLatestExportShare = true
                    }
                },
                onSave: {
                    store.saveSession(samples: camera.sessionSamples)
                    stableStore.saveLiveSession(
                        samples: camera.sessionSamples,
                        horseNameFallback: profiles.horseName,
                        riderName: profiles.riderName,
                        lidarSamples: camera.lidarSamples
                    )
                },
                onToggleLock: { settings.lockedMode.toggle() }
            )

        case .replay:
            AVOReplayFullPage(
                store: store,
                camera: camera,
                stableStore: stableStore
            )

        case .videoEditor:
            AVOVideoEvidenceEditorView(
                camera: camera,
                sensors: sensors,
                stableStore: stableStore,
                hardware: hardware,
                settings: settings
            )

        case .analysis:
            AVOBiomechAnalysisEngineProPage(
                camera: camera,
                sensors: sensors,
                stableStore: stableStore,
                hardware: hardware,
                settings: settings
            )

        case .profiles:
            AVOProfilesFullPage(
                profiles: profiles,
                stableStore: stableStore,
                hardware: hardware
            )

        case .stable:
            AVOStableRegistryView(
                stableStore: stableStore,
                liveSamples: camera.sessionSamples,
                fallbackHorseName: profiles.horseName,
                riderName: profiles.riderName,
                latestLiDARSample: camera.lidarSamples.last,
                liveLiDARPoints: camera.lidarPointCloud2D,
                fusedLiDARPoints3D: camera.lidarFusedPointCloud3D,
                lidarFusionReport: camera.lidarFusionReport
            )

        case .sensors:
            AVOSensorsFullPage(
                camera: camera,
                sensors: sensors,
                hardware: hardware,
                settings: settings
            )

        case .report:
            AVOReportCenterPage(
                camera: camera,
                store: store,
                profiles: profiles,
                stableStore: stableStore,
                pdfManager: pdfManager
            )

        case .settings:
            AVOSettingsFullPage(
                camera: camera,
                sensors: sensors,
                store: store,
                hardware: hardware,
                settings: settings,
                stableStore: stableStore,
                modelImportStatus: $modelImportStatus
            )

        case .hardware:
            AVOHardwareFullPage(
                hardware: hardware,
                settings: settings,
                sensors: sensors
            )

        case .devices:
            AVODeviceConfigurationPage(
                hardware: hardware,
                settings: settings
            )

        case .review:
            HorseDatasetReviewView(datasetManager: camera.datasetManager)

        case .aiTraining:
            AVOAITrainingSettingsPage(datasetManager: camera.datasetManager)

        case .configHub:
            AVOHubConfigurationPage()
        }
    }
}

extension DashboardMode: Identifiable {
    var id: String { rawValue }
}
