import SwiftUI
import PDFKit
import UIKit
import MapKit
import UniformTypeIdentifiers

struct DashboardView: View {
    init() {}
    @StateObject private var latestExportSharer = LatestExportSharer()
    @State private var showLatestExportShare = false
    @StateObject private var camera = CameraManager()
    @StateObject private var location = LocationManager()
    @StateObject private var sensors = SensorHub()
    @StateObject private var store = SessionStore()
    @StateObject private var profiles = ProfileStore()
    @StateObject private var hardware = AVOHardwareReceiver()
    @StateObject private var settings = HardwareSettings()
    @StateObject private var pdfManager = PDFReportManager()
    @StateObject private var stableStore = AVOStableStore()
    
    @State private var selectedMode: DashboardMode = .live
    @State private var showHomeLauncher = true
    @State private var showStablePage = false
    @State private var showTrainingDashboardPage = false
    @State private var showBiomechPage = false
    @State private var showSettingsPage = false
    @State private var showSensorsPage = false
    @State private var showReportPage = false
    @State private var showReplayPage = false
    @State private var showVideoEditorPage = false
    @State private var showAnalysisPage = false
    @State private var showProfilesPage = false
    @State private var showHardwarePage = false
    @State private var showReviewPage = false
    @State private var showAITrainingSettingsPage = false
    @State private var showConfigHubPage = false
    @State private var showDeviceConfigPage = false
    @State private var modelImportStatus = "HORSE POSE MODEL READY"
    @State private var replayScrubIndex: Double = 0
    
    @State private var horseNameDraft = ""
    @State private var horseAgeDraft = ""
    @State private var horseBreedDraft = ""
    @State private var horseNotesDraft = ""
    
    @State private var riderNameDraft = ""
    @State private var riderLevelDraft = ""
    @State private var riderWeightDraft = ""
    @State private var riderNotesDraft = ""
    
    @State private var lastBiomechSnapshot: UIImage?
    @State private var lastMapSnapshot: UIImage?
    @State private var showDatasetReviewer = false
    @State private var showDatasetExporter = false
    @State private var showAppFolderPicker = false
    
    private let sensorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let replayTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if showHomeLauncher {
                    AVOHomeLauncherView { mode in
                        if mode == .live {
                            showTrainingDashboardPage = true
                        } else if mode == .stable {
                            showStablePage = true
                        } else if mode == .biomech {
                            showBiomechPage = true
                        } else if mode == .settings {
                            showSettingsPage = true
                        } else if mode == .profiles {
                            showProfilesPage = true
                        } else if mode == .replay {
                            showReplayPage = true
                        } else if mode == .videoEditor {
                            showVideoEditorPage = true
                        } else if mode == .analysis {
                            showAnalysisPage = true
                        } else if mode == .sensors {
                            showSensorsPage = true
                        } else if mode == .report {
                            showReportPage = true
                        } else if mode == .hardware {
                            showHardwarePage = true
                        } else if mode == .devices {
                            showDeviceConfigPage = true
                        } else if mode == .review {
                            camera.prepareDatasetForReview()
                            showReviewPage = true
                        } else if mode == .aiTraining {
                            showAITrainingSettingsPage = true
                        } else if mode == .configHub {
                            showConfigHubPage = true
                        } else {
                            selectedMode = mode
                            showHomeLauncher = false
                        }
                    }
                    .transition(.opacity)
                } else {
                    CameraPreview(manager: camera)
                        .ignoresSafeArea()
                        .blur(radius: 8)
                        .opacity(0.22)
                    
                    ZStack(alignment: .leading) {
                        VStack(spacing: 4) {
                            activeScreen
                                .frame(width: geo.size.width, height: max(0, geo.size.height - 52), alignment: .topLeading)
                                .clipped()

                            bottomBar
                                .frame(width: geo.size.width, height: 48)
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)

                        sideMenu
                            .frame(width: 54, height: geo.size.height, alignment: .topLeading)
                            .zIndex(10)
                    }
                    .padding(0)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .background(Color(red: 0.006, green: 0.010, blue: 0.012).ignoresSafeArea())
                }
            }
            .animation(.easeInOut(duration: 0.22), value: showHomeLauncher)
            .ignoresSafeArea()
        }

        .fullScreenCover(isPresented: $showTrainingDashboardPage) {
            AVOLiveTrainingDashboardPage(
                hardware: hardware,
                sensors: sensors,
                camera: camera,
                stableStore: stableStore,
                settings: settings
            )
        }
        .fullScreenCover(isPresented: $showStablePage) {
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
        }
        .fullScreenCover(isPresented: $showReplayPage) {
            AVOReplayFullPage(
                store: store,
                camera: camera,
                stableStore: stableStore
            )
        }
        .fullScreenCover(isPresented: $showVideoEditorPage) {
            AVOVideoEvidenceEditorView(
                camera: camera,
                sensors: sensors,
                stableStore: stableStore,
                hardware: hardware,
                settings: settings
            )
        }

        .fullScreenCover(isPresented: $showAnalysisPage) {
            AVOBiomechAnalysisEngineProPage(
                camera: camera,
                sensors: sensors,
                stableStore: stableStore,
                hardware: hardware,
                settings: settings
            )
        }
        .fullScreenCover(isPresented: $showSensorsPage) {
            AVOSensorsFullPage(
                camera: camera,
                sensors: sensors,
                hardware: hardware,
                settings: settings
            )
        }
        .fullScreenCover(isPresented: $showReportPage) {
            AVOReportCenterPage(
                camera: camera,
                store: store,
                profiles: profiles,
                stableStore: stableStore,
                pdfManager: pdfManager
            )
        }

        .fullScreenCover(isPresented: $showBiomechPage) {
            AVOBiomechFullPage(
                camera: camera,
                sensors: sensors,
                stableStore: stableStore,
                settings: settings,
                onRecord: { camera.toggleSession() },
                onSnap: {
                    camera.reportText = "SNAP..."
                    store.exportStatus = "SNAP CAPTURING..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        lastBiomechSnapshot = renderBiomechSnapshot()
                        lastMapSnapshot = renderMapSnapshot()
                        camera.reportText = "SNAP READY"
                        store.exportStatus = "SNAP READY"
                    }
                },
                onToggleDataset: { camera.toggleDatasetRecording() },
                onReview: {
                    camera.prepareDatasetForReview()
                    showDatasetReviewer = true
                },
                onExport: {
                    camera.prepareDatasetForReview()
                    showDatasetExporter = true
                },
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
        }
        .fullScreenCover(isPresented: $showProfilesPage) {
            AVOProfilesFullPage(
                profiles: profiles,
                stableStore: stableStore,
                hardware: hardware
            )
        }
        .fullScreenCover(isPresented: $showSettingsPage) {
            AVOSettingsFullPage(
                camera: camera,
                sensors: sensors,
                store: store,
                hardware: hardware,
                settings: settings,
                stableStore: stableStore,
                modelImportStatus: $modelImportStatus
            )
        }
        .fullScreenCover(isPresented: $showHardwarePage) {
            AVOHardwareFullPage(
                hardware: hardware,
                settings: settings,
                sensors: sensors
            )
        }
        .fullScreenCover(isPresented: $showReviewPage) {
            HorseDatasetReviewView(datasetManager: camera.datasetManager)
        }
        .fullScreenCover(isPresented: $showAITrainingSettingsPage) {
            AVOAITrainingSettingsPage(datasetManager: camera.datasetManager)
        }
        .fullScreenCover(isPresented: $showConfigHubPage) {
            AVOHubConfigurationPage()
        }
        .fullScreenCover(isPresented: $showDeviceConfigPage) {
            AVODeviceConfigurationPage(
                hardware: hardware,
                settings: settings
            )
        }
        .onReceive(sensorTimer) { _ in
            AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: stableStore.selectedHorseProfile != nil)
            updateLiveData()
        }
        .onReceive(replayTimer) { _ in
            updateReplay()
        }
        .sheet(isPresented: $pdfManager.showPreview) {
            if let url = pdfManager.pdfURL {
                PDFPreview(url: url)
            }
        }
        .fullScreenCover(isPresented: $showDatasetReviewer) {
            HorseDatasetReviewView(datasetManager: camera.datasetManager)
        }
        .fullScreenCover(isPresented: $showDatasetExporter) {
            HorseDatasetExportView(datasetManager: camera.datasetManager)
        }
        .sheet(isPresented: $showLatestExportShare) {
            if let url = latestExportSharer.zipURL {
                LatestExportShareSheet(url: url)
            } else {
                Text("Preparando export...")
            }
        }
        .onAppear {
            AVOAppDataSync.syncAll(profiles: profiles, stableStore: stableStore, preferStable: true)
        }
        .sheet(isPresented: $showAppFolderPicker) {
            AVOFolderPicker { url in
                stableStore.setRootFolder(url)
                showAppFolderPicker = false
            }
        }
    }
    
    var sideMenu: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 8)
            
            ForEach(DashboardMode.allCases.filter { $0 != .hardware && $0 != .review && $0 != .aiTraining && $0 != .configHub }, id: \.rawValue) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    SideMenuButton(title: mode.rawValue, active: selectedMode == mode)
                }
            }
            
            Spacer()
            
            Button {
                settings.toggleMode()
            } label: {
                SideMenuButton(title: settings.commercialMode.rawValue, active: true)
            }
        }
        .frame(width: 54)
    }
    
    @ViewBuilder
    var activeScreen: some View {
        switch selectedMode {
        case .live:
            liveScreen
        case .biomech:
            biomechScreen
        case .replay:
            replayScreen
        case .videoEditor:
            videoEditorScreen
        case .analysis:
            analysisScreen
        case .profiles:
            profilesScreen
        case .stable:
            stableScreen
        case .sensors:
            sensorsScreen
        case .report:
            liveScreen
        case .settings:
            settingsScreen
        case .hardware:
            liveScreen
        case .devices:
            liveScreen
        case .review:
            liveScreen
        case .aiTraining:
            liveScreen
        case .configHub:
            liveScreen
        }
    }
    
    // MARK: - LIVE
    
    var liveScreen: some View {
        VStack(spacing: 4) {
            screenTitle("LIVE / BIOMECH CAMERA")
            ZStack(alignment: .topLeading) {
                CameraPreview(manager: camera)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HorseOverlay(horseBox: camera.horseBox, riderBox: camera.riderBox, riderPosePoints: camera.riderPosePoints, horseKeypoints: camera.horseKeypoints, quality: camera.quality, fatigue: camera.fatigue, risk: camera.risk)
                AVOMiniHUD(horse: stableStore.selectedHorseName, gait: camera.gait, risk: "\(Int(camera.risk * 100))%", fatigue: "\(Int(camera.fatigue * 100))%", hr: sensors.pulseStatus, speed: sensors.speedStatus)
                    .padding(12)
                VStack { Spacer(); liveTelemetryStrip }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.28), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    var liveTelemetryStrip: some View {
        HStack(spacing: 18) {
            MiniText(name: "GAIT", value: camera.gait, color: .cyan)
            MiniText(name: "ASYM", value: camera.asymmetry, color: .green)
            MiniText(name: "RISK", value: "\(Int(camera.risk * 100))%", color: .red)
            MiniText(name: "FATIGUE", value: "\(Int(camera.fatigue * 100))%", color: .orange)
            MiniText(name: "HR", value: sensors.pulseStatus, color: .green)
            MiniText(name: "SPEED", value: sensors.speedStatus, color: .cyan)
            MiniText(name: "LiDAR", value: camera.lidarSupported ? camera.lidarDistanceText : "OFF", color: .cyan)
        }
        .padding(10)
        .background(Color.black.opacity(0.75))
    }
    
    var liveStreamPanel: some View { EmptyView() }
    var telemetryPanel: some View { EmptyView() }
    var telemetryBox: some View { EmptyView() }
    var telemetryQualityBox: some View { EmptyView() }
    var mapPanel: some View { EmptyView() }
    var controlStrip: some View { EmptyView() }
    
    // MARK: - BIOMECH
    
    var biomechScreen: some View {
        VStack(spacing: 4) {
            screenTitle("BIOMECH CAMERA / FULL VIEW")
            ZStack(alignment: .topLeading) {
                CameraPreview(manager: camera)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HorseOverlay(horseBox: camera.horseBox, riderBox: camera.riderBox, riderPosePoints: camera.riderPosePoints, horseKeypoints: camera.horseKeypoints, quality: camera.quality, fatigue: camera.fatigue, risk: camera.risk)
                AVOMiniHUD(horse: stableStore.selectedHorseName, gait: camera.gait, risk: "\(Int(camera.risk * 100))%", fatigue: "\(Int(camera.fatigue * 100))%", hr: sensors.pulseStatus, speed: sensors.speedStatus)
                    .padding(12)
                VStack { Spacer(); liveTelemetryStrip }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.28), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - REPLAY
    
    var replayScreen: some View {
        VStack(spacing: 6) {
            screenTitle("REPLAY / SESSION ANALYSIS")
            
            ProBox("REPLAY PRO ANALYZER") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        replayControlBox
                        replayDataBox1
                        replayDataBox2
                    }
                    .frame(height: 118)
                    
                    if store.replaySamples.isEmpty {
                        Spacer()
                        
                        Text("NO SESSION LOADED")
                            .foregroundColor(.orange)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        
                        Spacer()
                    } else {
                        replayCharts
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var replayControlBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            MiniText(name: "FILE", value: store.selectedSessionName, color: .cyan)
            MiniText(name: "STATUS", value: store.replayStatus, color: .cyan)
            MiniText(name: "INDEX", value: "\(store.replayIndex)", color: .green)
            MiniText(name: "SAMPLES", value: "\(store.replaySamples.count)", color: .green)
            
            HStack(spacing: 5) {
                Button { store.refreshSessions() } label: { BottomButton("LIST", .green) }
                Button { store.loadLastSession(); replayScrubIndex = 0 } label: { BottomButton("LOAD", .cyan) }
                Button { store.replayPaused.toggle() } label: { BottomButton(store.replayPaused ? "PLAY" : "PAUSE", .cyan) }
                Button { store.jumpReplayForward(); replayScrubIndex = Double(store.replayIndex) } label: { BottomButton("SKIP", .cyan) }
                Button { store.stopReplay() } label: { BottomButton("STOP", .orange) }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(store.availableSessions.indices, id: \.self) { index in
                        Button {
                            store.loadSessionAt(index)
                            replayScrubIndex = 0
                        } label: {
                            Text("\(index + 1)")
                                .foregroundColor(.black)
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .frame(width: 22, height: 18)
                                .background(Color.cyan)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .frame(height: 22)
        }
        .frame(width: 315, height: 118)
    }
    
    var replayDataBox1: some View {
        VStack(alignment: .leading, spacing: 4) {
            let sample = selectedReplaySample()
            
            MiniText(name: "TIME", value: sampleTimeText(sample), color: .white)
            MiniText(name: "PULSE", value: sample?.pulse ?? "--", color: .green)
            MiniText(name: "SPEED", value: sample?.speed ?? "--", color: .cyan)
            MiniText(name: "QUALITY", value: samplePercent(sample?.quality), color: .green)
            MiniText(name: "RISK", value: samplePercent(sample?.risk), color: .red)
            MiniText(name: "FATIGUE", value: samplePercent(sample?.fatigue), color: .orange)
        }
        .padding(7)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: 118)
    }
    
    var replayDataBox2: some View {
        VStack(alignment: .leading, spacing: 4) {
            let sample = selectedReplaySample()
            
            MiniText(name: "GAIT", value: sample?.gait ?? "--", color: .cyan)
            MiniText(name: "SCORE", value: sample?.score ?? "--", color: .green)
            MiniText(name: "RSSI", value: sample?.rssi ?? "--", color: .orange)
            MiniText(name: "LAT", value: sample == nil ? "--" : String(format: "%.5f", sample!.latitude), color: .white)
            MiniText(name: "LON", value: sample == nil ? "--" : String(format: "%.5f", sample!.longitude), color: .white)
            MiniText(name: "DIAG", value: camera.vetDiagnosis, color: .orange)
        }
        .padding(7)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: 118)
    }
    
    var replayCharts: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("SESSION TIMELINE")
                    .foregroundColor(.white)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                
                Spacer()
                
                Text("\(Int(replayScrubIndex)) / \(max(store.replaySamples.count - 1, 0))")
                    .foregroundColor(.green)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            
            Slider(
                value: $replayScrubIndex,
                in: 0...Double(max(store.replaySamples.count - 1, 1)),
                step: 1
            )
            .frame(height: 18)
            .onChange(of: replayScrubIndex) { _, newValue in
                let idx = min(max(Int(newValue), 0), store.replaySamples.count - 1)
                store.replayIndex = idx
                camera.applyReplaySample(store.replaySamples[idx])
            }
            
            HStack(spacing: 6) {
                ReplayChartBox(title: "PULSE", valueText: selectedReplaySample()?.pulse ?? "--", color: .green, values: replayPulseValues())
                ReplayChartBox(title: "SPEED", valueText: selectedReplaySample()?.speed ?? "--", color: .cyan, values: replaySpeedValues())
                ReplayChartBox(title: "ACCEL", valueText: String(format: "%.2f", selectedAcceleration()), color: .orange, values: replayAccelerationValues())
            }
            
            HStack(spacing: 6) {
                ReplayChartBox(title: "QUALITY", valueText: samplePercent(selectedReplaySample()?.quality), color: .green, values: store.replaySamples.map { $0.quality })
                ReplayChartBox(title: "RISK", valueText: samplePercent(selectedReplaySample()?.risk), color: .red, values: store.replaySamples.map { $0.risk })
                ReplayChartBox(title: "FATIGUE", valueText: samplePercent(selectedReplaySample()?.fatigue), color: .orange, values: store.replaySamples.map { $0.fatigue })
            }
            
            HStack(spacing: 6) {
                ReplayChartBox(title: "ASYM / SCORE", valueText: selectedReplaySample()?.score ?? "--", color: .purple, values: replayScoreValues())
                ReplayChartBox(title: "GPS LAT", valueText: selectedReplaySample() == nil ? "--" : String(format: "%.5f", selectedReplaySample()!.latitude), color: .white, values: store.replaySamples.map { $0.latitude })
                ReplayChartBox(title: "GPS LON", valueText: selectedReplaySample() == nil ? "--" : String(format: "%.5f", selectedReplaySample()!.longitude), color: .white, values: store.replaySamples.map { $0.longitude })
            }
        }
    }
    

    // MARK: - VIDEO EDITOR

    var videoEditorScreen: some View {
        AVOVideoEvidenceEditorView(
            camera: camera,
            sensors: sensors,
            stableStore: stableStore,
            hardware: hardware,
            settings: settings
        )
    }
    
    // MARK: - ANALYSIS

    var analysisScreen: some View {
        AVOBiomechAnalysisEngineProPage(
            camera: camera,
            sensors: sensors,
            stableStore: stableStore,
            hardware: hardware,
            settings: settings
        )
    }
    
    // MARK: - PROFILES
    
    var profilesScreen: some View {
        VStack(spacing: 8) {
            screenTitle("HORSE / RIDER PROFILES")
            HStack(spacing: 8) {
                AVOPremiumPanel("Horse profiles", accent: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        AVOKPIBox(title: "Active horse", value: profiles.horseName, color: .green)
                        profileField("NAME", text: $horseNameDraft)
                        profileField("AGE", text: $horseAgeDraft)
                        profileField("BREED", text: $horseBreedDraft)
                        profileField("NOTES", text: $horseNotesDraft)
                        HStack { Button { profiles.nextHorse(); loadProfileDrafts() } label: { BottomButton("NEXT", .green) }; Button { saveHorseDraft() } label: { BottomButton("SAVE", .green) }; Button { profiles.deleteSelectedHorse(); loadProfileDrafts() } label: { BottomButton("DELETE", .red) } }
                        Spacer()
                    }.onAppear { loadProfileDrafts() }
                }
                AVOPremiumPanel("Rider profiles", accent: .cyan) {
                    VStack(alignment: .leading, spacing: 8) {
                        AVOKPIBox(title: "Active rider", value: profiles.riderName, color: .cyan)
                        profileField("NAME", text: $riderNameDraft)
                        profileField("LEVEL", text: $riderLevelDraft)
                        profileField("WEIGHT", text: $riderWeightDraft)
                        profileField("NOTES", text: $riderNotesDraft)
                        HStack { Button { profiles.nextRider(); loadProfileDrafts() } label: { BottomButton("NEXT", .cyan) }; Button { saveRiderDraft() } label: { BottomButton("SAVE", .cyan) }; Button { profiles.deleteSelectedRider(); loadProfileDrafts() } label: { BottomButton("DELETE", .red) } }
                        Spacer()
                    }
                }
                AVOPremiumPanel("NFC / identity link", accent: .purple) {
                    VStack(spacing: 10) {
                        AVODenseValue(name: "Horse ID", value: hardware.nfcHorse, color: .green)
                        AVODenseValue(name: "Rider ID", value: hardware.nfcRider, color: .cyan)
                        AVODenseValue(name: "Status", value: profiles.profileStatus, color: .orange)
                        Button { profiles.applyNFC(horseID: hardware.nfcHorse, riderID: hardware.nfcRider); loadProfileDrafts() } label: { BottomButton("LOAD ID", .purple) }
                        Button { profiles.saveProfiles() } label: { BottomButton("SAVE ALL", .green) }
                        Button { profiles.loadProfiles(); loadProfileDrafts() } label: { BottomButton("LOAD ALL", .cyan) }
                        Spacer()
                    }
                }.frame(width: 250)
            }
        }
    }
    
    var horseProfileBox: some View { EmptyView() }
    var riderProfileBox: some View { EmptyView() }
    
    // MARK: - STABLE
    
    var stableScreen: some View {
        VStack(spacing: 8) {
            screenTitle("STABLE / HORSE REGISTRY / AI DATA")
            
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - SENSORS
    
    var sensorsScreen: some View {
        VStack(spacing: 8) {
            screenTitle("HIGH RATE SENSOR PANEL")
            AVOPremiumPanel("ESP32 / UDP / RTK / LORA / IMU", accent: .cyan) {
                VStack(spacing: 8) {
                    AVOTableHeader(columns: ["Sensor", "Type", "Status", "Rate", "Latency", "RSSI", "Source"])
                    AVOTableRow(values: ["UDP Telemetry", "UDP", hardware.udpStatus, "50 Hz", "12 ms", cleanRSSI(), "ESP32"], color: .green)
                    AVOTableRow(values: ["LiDAR Data", "Depth", camera.lidarSupported ? "ON" : "OFF", "30 Hz", "18 ms", "--", "iPad"] , color: .cyan)
                    AVOTableRow(values: ["RTK GPS", "GNSS", sensors.rtkStatus, "10 Hz", "15 ms", "--", "RTK"], color: .green)
                    AVOTableRow(values: ["LoRa Telemetry", "LoRa", sensors.loraStatus, "5 Hz", "120 ms", cleanRSSI(), "LORA"], color: .orange)
                    AVOTableRow(values: ["IMU Batch", "UDP", sensors.batchStatus, "100 Hz", "8 ms", "--", "IMU"], color: .purple)
                    AVOTableRow(values: ["Heart Rate", "BLE", sensors.pulseStatus, "1 Hz", "10 ms", hardware.rssi, "HRM"], color: .green)
                    Spacer()
                    HStack { Button { hardware.startUDP(port: settings.udpPort) } label: { BottomButton("START ALL", .green) }; Button { hardware.stopUDP() } label: { BottomButton("STOP", .red) }; Spacer(); Text("REAL INPUT ONLY · PORT: \(settings.udpPort)").foregroundColor(.green).font(.system(size: 12, weight: .black, design: .monospaced)) }
                }
            }
        }
    }
    
    // MARK: - REPORT
    
    var reportScreen: some View {
        VStack(spacing: 12) {
            screenTitle("REPORT MOVED TO INDEPENDENT MODULE")
            AVOPremiumPanel("Report Center is no longer embedded in DashboardView", accent: .orange) {
                VStack(spacing: 14) {
                    Text("REPORT ahora vive en Modules/Reports/AVOReportCenterPage.swift")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                    Text("El botón REPORT del Launch abre esa página independiente con fullScreenCover.")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.70))
                    Button { showReportPage = true } label: { BottomButton("OPEN REPORT CENTER", .orange) }
                    Spacer()
                }
            }
        }
    }

    // MARK: - SETTINGS
    
    var settingsScreen: some View {
        VStack(spacing: 8) {
            screenTitle("SETTINGS / APP + HARDWARE CONTROL")
            HStack(spacing: 8) {
                AVOPremiumPanel("App mode / safety", accent: .green) {
                    AVODenseValue(name: "Mode", value: settings.commercialMode.rawValue, color: .green)
                    AVODenseValue(name: "Lock UI", value: settings.lockedMode ? "LOCKED" : "UNLOCKED", color: settings.lockedMode ? .red : .green)
                    AVODenseValue(name: "Fullscreen", value: settings.fullscreenMode ? "ON" : "OFF", color: .cyan)
                    HStack { Button { settings.toggleMode() } label: { BottomButton("MODE", .green) }; Button { settings.lockedMode.toggle() } label: { BottomButton("LOCK", .yellow) } }
                    Spacer()
                }
                AVOPremiumPanel("Hardware / network", accent: .cyan) {
                    AVODenseValue(name: "UDP", value: hardware.udpStatus, color: .green)
                    AVODenseValue(name: "UDP Port", value: "\(settings.udpPort)", color: .white)
                    AVODenseValue(name: "Base IP", value: settings.baseIP, color: .white)
                    AVODenseValue(name: "BLE", value: hardware.bleStatus, color: .cyan)
                    HStack { Button { hardware.startUDP(port: settings.udpPort) } label: { BottomButton("UDP", .green) }; Button { hardware.startBLEScan() } label: { BottomButton("BLE", .cyan) }; Button { hardware.stopBLE() } label: { BottomButton("BLE OFF", .orange) } }
                    Spacer()
                }
                AVOPremiumPanel("AI / biomech", accent: .purple) {
                    AVODenseValue(name: "CoreML", value: "MODEL CHECK READY", color: .cyan)
                    AVODenseValue(name: "Camera", value: camera.trackingText, color: .green)
                    AVODenseValue(name: "Quality", value: "\(Int(camera.quality * 100))%", color: .green)
                    AVODenseValue(name: "Risk", value: "\(Int(camera.risk * 100))%", color: .red)
                    HStack { BottomButton("PERMS", .cyan); BottomButton("COREML", .purple); BottomButton("ACK", .orange) }
                    ModelImporterView(modelStatus: $modelImportStatus) {
                        camera.reloadPoseModelFromDocuments()
                    }
                    .scaleEffect(0.78)
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
            }.frame(height: 260)
            HStack(spacing: 8) {
                AVOPremiumPanel("Alert thresholds", accent: .orange) { Slider(value: $settings.alertThresholdRisk, in: 0...1); Slider(value: $settings.alertThresholdFatigue, in: 0...1); AVODenseValue(name: "Current alert", value: compactAlertText(), color: compactAlertColor()) }
                AVOPremiumPanel("Session / storage", accent: .green) { AVODenseValue(name: "Samples", value: "\(camera.sessionSamples.count)", color: .green); AVODenseValue(name: "Saved", value: "\(store.availableSessions.count)", color: .cyan); AVODenseValue(name: "App folder", value: stableStore.rootFolderURL?.lastPathComponent ?? "Mi app", color: .green); HStack { Button { store.saveSession(samples: camera.sessionSamples) } label: { BottomButton("SAVE", .green) }; Button { showAppFolderPicker = true } label: { BottomButton("APP FOLDER", .green) }; Button { stableStore.loadIndex() } label: { BottomButton("SYNC FOLDER", .orange) } } }
                AVOPremiumPanel("Diagnostic", accent: .red) { AVODenseValue(name: "Lora", value: sensors.loraStatus, color: .green); AVODenseValue(name: "Live rate", value: sensors.liveRateText, color: .cyan); AVODenseValue(name: "RTK", value: sensors.rtkStatus, color: .green); AVODenseValue(name: "Battery", value: sensors.remoteBattery, color: .orange) }
            }
        }
    }
    
    // MARK: - HARDWARE
    
    var hardwareScreen: some View {
        VStack(spacing: 8) {
            screenTitle("HARDWARE / BLE DYNAMIC PAIRING")
            
            ProBox("HELTEC MASTER NODE BINDING") {
                HStack(spacing: 12) {
                    hardwareLinkedBox
                    hardwareScannerBox
                    hardwareProtocolBox
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var hardwareLinkedBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LINKED GADGET")
                .foregroundColor(.green)
                .font(.system(size: 14, weight: .black, design: .monospaced))
            
            MiniText(name: "BLE STATUS", value: hardware.bleStatus, color: .cyan)
            MiniText(name: "UDP STATUS", value: hardware.udpStatus, color: .green)
            MiniText(name: "ESP32", value: hardware.esp32Status, color: .green)
            MiniText(name: "PACKETS", value: hardware.packetStatus, color: .cyan)
            MiniText(name: "RSSI", value: hardware.rssi, color: .orange)
            
            Spacer()
            
            HStack {
                Button { hardware.stopBLE() } label: { BottomButton("UNPAIR", .red) }
                Button { hardware.startBLEScan() } label: { BottomButton("RECONNECT", .green) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(Color.black.opacity(0.28))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    var hardwareScannerBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BLE SCANNER")
                .foregroundColor(.cyan)
                .font(.system(size: 14, weight: .black, design: .monospaced))
            
            MiniText(name: "SCAN", value: hardware.bleStatus, color: .cyan)
            MiniText(name: "TARGET", value: "AVO_HORSE_HELTEC", color: .green)
            MiniText(name: "MODE", value: "NOTIFY JSON", color: .purple)
            MiniText(name: "DATA", value: hardware.protocolStatus, color: .cyan)
            
            Spacer()
            
            HStack {
                Button { hardware.startBLEScan() } label: { BottomButton("SCAN HELTEC", .cyan) }
                Button { hardware.stopBLE() } label: { BottomButton("STOP BLE", .orange) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(Color.black.opacity(0.28))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    var hardwareProtocolBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROTOCOL LOG")
                .foregroundColor(.purple)
                .font(.system(size: 14, weight: .black, design: .monospaced))
            
            MiniText(name: "PULSE", value: hardware.pulse, color: .green)
            MiniText(name: "SPEED", value: hardware.speed, color: .cyan)
            MiniText(name: "CADENCE", value: hardware.cadence, color: .white)
            MiniText(name: "BATTERY", value: hardware.remoteBattery, color: .orange)
            MiniText(name: "SEQ", value: hardware.seqStatus, color: .green)
            
            Spacer()
            
            Text("REAL TELEMETRY ONLY")
                .foregroundColor(.green)
                .font(.system(size: 12, weight: .black, design: .monospaced))
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(Color.black.opacity(0.28))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - SHARED UI
    
    func openExportsFolder() {
        
        let fm = FileManager.default
        
        guard let docs =
                fm.urls(for: .documentDirectory,
                        in: .userDomainMask).first else {
            return
        }
        
        let exports =
        docs
            .appendingPathComponent("AVOHorseDatasets")
            .appendingPathComponent("AVOStableHorseDataset")
            .appendingPathComponent("exports")
        
        UIApplication.shared.open(exports)
    }
    
    func screenTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .black, design: .monospaced))
            
            Spacer()
            
            Text(settings.commercialMode.rawValue)
                .foregroundColor(.green)
                .font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
    }
    
    var bottomBar: some View {
        HStack(spacing: 0) {
            BottomStatusBox(title: "RSSI", value: cleanRSSI(), color: .green, width: 120)
            BottomStatusBox(title: "CONNECTION", value: connectionText(), color: connectionColor(), width: 150)
            BottomStatusBox(title: "FREQUENCY", value: sensors.liveRateText.replacingOccurrences(of: "LIVE ", with: ""), color: .cyan, width: 140)
            BottomStatusBox(title: "REC", value: camera.isRecording ? "ACTIVE" : "READY", color: camera.isRecording ? .red : .green, width: 95)
            BottomStatusBox(title: "LiDAR", value: camera.lidarSupported ? camera.lidarDistanceText : "OFF", color: camera.lidarSupported ? .cyan : .orange, width: 105)
            
            HStack(spacing: 7) {
                BottomActionButton(title: camera.isRecording ? "STOP" : "REC", color: camera.isRecording ? .orange : .green) {
                    camera.toggleSession()
                }
                
                BottomActionButton(title: "SNAP", color: .cyan) {
                    camera.reportText = "SNAP..."
                    store.exportStatus = "SNAP CAPTURING..."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        lastBiomechSnapshot = renderBiomechSnapshot()
                        lastMapSnapshot = renderMapSnapshot()
                        camera.reportText = "SNAP READY"
                        store.exportStatus = "SNAP READY"
                    }
                }
                
                BottomActionButton(title: camera.isDatasetRecording ? "DATA OFF" : "DATA", color: camera.isDatasetRecording ? .orange : .purple) {
                    camera.toggleDatasetRecording()
                }

                BottomActionButton(title: "REVIEW", color: .cyan) {
                    camera.prepareDatasetForReview()
                    showDatasetReviewer = true
                }

                BottomActionButton(title: "EXPORT", color: .green) {
                    camera.prepareDatasetForReview()
                    showDatasetExporter = true
                }
                
                BottomActionButton(title: "EXPORTS",
                                   color: .mint) {
                    latestExportSharer.shareLatestExport {
                        showLatestExportShare = true
                    }
                }
                
                BottomActionButton(title: "SAVE", color: .green) {
                    store.saveSession(samples: camera.sessionSamples)
                    stableStore.saveLiveSession(samples: camera.sessionSamples, horseNameFallback: profiles.horseName, riderName: profiles.riderName, lidarSamples: camera.lidarSamples)
                }
                
                BottomActionButton(title: settings.lockedMode ? "OPEN" : "LOCK", color: .yellow) {
                    settings.lockedMode.toggle()
                }
            }
            .frame(width: 500, height: 58)
            .background(Color.black.opacity(0.22))
            .overlay(Rectangle().fill(Color.green.opacity(0.12)).frame(width: 1), alignment: .trailing)
            
            BottomStatusBox(title: "DATASET", value: camera.datasetCountText.replacingOccurrences(of: "DATASET ", with: ""), color: camera.isDatasetRecording ? .purple : .green, width: 165)
            BottomStatusBox(title: "ALERT", value: compactAlertText(), color: compactAlertColor(), width: 105)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - SNAPSHOTS
    
    
    @MainActor
    func renderBiomechSnapshot() -> UIImage {
        let biomechView =
        ZStack {
            CameraPreview(manager: camera)
                .frame(width: 908, height: 470)
                .clipped()
            
            BiomechOverlay(camera: camera)
                .frame(width: 908, height: 470)
        }
        
        let renderer = ImageRenderer(content: biomechView)
        renderer.scale = 2.0
        return renderer.uiImage ?? UIImage()
    }
    
    func renderMapSnapshot() -> UIImage {
        let mapView =
        RealGPSMapView(location: location)
            .frame(width: 908, height: 470)
        
        let renderer = ImageRenderer(content: mapView)
        renderer.scale = 2.0
        return renderer.uiImage ?? UIImage()
    }
    
    // MARK: - DATA UPDATE
    
    func updateLiveData() {
        sensors.updateFromHardware(hardware)
        
        if hardware.hasExternalRTK {
            location.setExternalRTK(
                hardware.externalCoordinate,
                path: hardware.externalPath
            )
        }
        
        location.updateZone(settings: settings)
        
        if settings.autoRecordInsideZone {
            if location.zoneStatus.contains("INSIDE") && !camera.isRecording {
                camera.toggleSession()
            }
            
            if location.zoneStatus.contains("OUTSIDE") && camera.isRecording {
                camera.toggleSession()
                store.saveSession(samples: camera.sessionSamples)
                stableStore.saveLiveSession(samples: camera.sessionSamples, horseNameFallback: profiles.horseName, riderName: profiles.riderName, lidarSamples: camera.lidarSamples)
            }
        }
        
        if camera.risk >= settings.alertThresholdRisk ||
            camera.fatigue >= settings.alertThresholdFatigue {
            camera.audibleAlert = "THRESHOLD ALERT"
        }
        
        camera.updateExternalInputs(coordinate: location.coordinate, sensors: sensors)
    }
    
    func updateReplay() {
        if let sample = store.nextReplaySample() {
            camera.applyReplaySample(sample)
            replayScrubIndex = Double(store.replayIndex)
        }
    }
    
    // MARK: - HELPERS
    
    func selectedReplaySample() -> SessionSample? {
        guard !store.replaySamples.isEmpty else { return nil }
        let idx = min(max(Int(replayScrubIndex), 0), store.replaySamples.count - 1)
        return store.replaySamples[idx]
    }
    
    func samplePercent(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        return "\(Int(value * 100))%"
    }
    
    func sampleTimeText(_ sample: SessionSample?) -> String {
        guard let sample = sample else { return "--" }
        let date = Date(timeIntervalSince1970: sample.time)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func numberFromText(_ text: String) -> Double {
        let clean = text
            .replacingOccurrences(of: "km/h", with: "")
            .replacingOccurrences(of: "BPM", with: "")
            .replacingOccurrences(of: "RSSI", with: "")
            .replacingOccurrences(of: "BAT", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Double(clean) ?? 0
    }
    
    func replayPulseValues() -> [Double] {
        store.replaySamples.map { numberFromText($0.pulse) }
    }
    
    func replaySpeedValues() -> [Double] {
        store.replaySamples.map { numberFromText($0.speed) }
    }
    
    func replayScoreValues() -> [Double] {
        store.replaySamples.map { Double($0.score) ?? 0 }
    }
    
    func replayAccelerationValues() -> [Double] {
        let speeds = replaySpeedValues()
        guard speeds.count > 1 else { return speeds }
        
        var values: [Double] = [0]
        
        for i in 1..<speeds.count {
            values.append(speeds[i] - speeds[i - 1])
        }
        
        return values
    }
    
    func selectedAcceleration() -> Double {
        let values = replayAccelerationValues()
        guard !values.isEmpty else { return 0 }
        let idx = min(max(Int(replayScrubIndex), 0), values.count - 1)
        return values[idx]
    }
    
    func profileField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .frame(width: 70, alignment: .leading)
            
            TextField(title, text: text)
                .foregroundColor(.white)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(6)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }
    
    func loadProfileDrafts() {
        if profiles.horses.indices.contains(profiles.selectedHorseIndex) {
            let horse = profiles.horses[profiles.selectedHorseIndex]
            horseNameDraft = horse.name
            horseAgeDraft = "\(horse.age)"
            horseBreedDraft = horse.breed
            horseNotesDraft = horse.notes
        }
        
        if profiles.riders.indices.contains(profiles.selectedRiderIndex) {
            let rider = profiles.riders[profiles.selectedRiderIndex]
            riderNameDraft = rider.name
            riderLevelDraft = rider.level
            riderWeightDraft = "\(Int(rider.weight))"
            riderNotesDraft = rider.notes
        }
    }
    
    func saveHorseDraft() {
        guard profiles.horses.indices.contains(profiles.selectedHorseIndex) else { return }
        
        profiles.horses[profiles.selectedHorseIndex] = HorseProfile(
            name: horseNameDraft,
            age: Int(horseAgeDraft) ?? 0,
            breed: horseBreedDraft,
            notes: horseNotesDraft
        )
        
        profiles.profileStatus = "HORSE SAVED"
    }
    
    func saveRiderDraft() {
        guard profiles.riders.indices.contains(profiles.selectedRiderIndex) else { return }
        
        profiles.riders[profiles.selectedRiderIndex] = RiderProfile(
            name: riderNameDraft,
            level: riderLevelDraft,
            weight: Double(riderWeightDraft) ?? 0,
            notes: riderNotesDraft
        )
        
        profiles.profileStatus = "RIDER SAVED"
    }
    
    func reportAvgQuality() -> Double {
        guard !camera.sessionSamples.isEmpty else { return camera.quality }
        return camera.sessionSamples.map { $0.quality }.reduce(0, +) / Double(camera.sessionSamples.count)
    }
    
    func reportAvgRisk() -> Double {
        guard !camera.sessionSamples.isEmpty else { return camera.risk }
        return camera.sessionSamples.map { $0.risk }.reduce(0, +) / Double(camera.sessionSamples.count)
    }
    
    func reportAvgFatigue() -> Double {
        guard !camera.sessionSamples.isEmpty else { return camera.fatigue }
        return camera.sessionSamples.map { $0.fatigue }.reduce(0, +) / Double(camera.sessionSamples.count)
    }
    
    func cleanRSSI() -> String {
        let raw = hardware.rssi
            .replacingOccurrences(of: "RSSI", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if raw.isEmpty || raw == "--" {
            return "--"
        }
        
        return "\(raw) dBm"
    }
    
    func connectionText() -> String {
        if hardware.bleStatus.contains("CONNECTED") ||
            hardware.bleStatus.contains("READY") {
            return "BLE"
        }
        
        if sensors.loraStatus.contains("WAIT") {
            return "WAIT"
        }
        
        if sensors.loraStatus.contains("ONLINE") ||
            hardware.esp32Status.contains("ONLINE") {
            return "LIVE"
        }
        
        return "STBY"
    }
    
    func connectionColor() -> Color {
        let text = connectionText()
        
        if text == "LIVE" || text == "BLE" {
            return .green
        }
        
        if text == "WAIT" {
            return .orange
        }
        
        return .white.opacity(0.6)
    }
    
    func compactAlertText() -> String {
        if camera.audibleAlert.contains("NO") {
            return "OK"
        }
        
        if camera.risk > 0.70 || camera.fatigue > 0.70 {
            return "WATCH"
        }
        
        if camera.audibleAlert.contains("VISUAL") {
            return "ALERT"
        }
        
        return "CHECK"
    }
    
    func compactAlertColor() -> Color {
        let alert = compactAlertText()
        
        if alert == "OK" {
            return .green
        }
        
        if alert == "WATCH" {
            return .orange
        }
        
        return .red
    }
}
