import SwiftUI
import AVFoundation
import Vision
import CoreML
import CoreLocation

enum AVOBiomechRecordingMode: String, CaseIterable, Identifiable {
    case client = "CLIENT VIDEO"
    case biomechSlow = "BIOMECH VIDEO"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .client: return "CLIENT"
        case .biomechSlow: return "BIOMECH"
        }
    }

    var filePrefix: String {
        switch self {
        case .client: return "client"
        case .biomechSlow: return "biomech_slow"
        }
    }

    var targetFPS: Int {
        switch self {
        // Stable capture for iPad/indoor lights. 240 fps produced constant flicker
        // under 50 Hz lighting and also forced camera format changes while recording.
        case .client: return 30
        case .biomechSlow: return 50
        }
    }
}

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate, AVCaptureFileOutputRecordingDelegate {
    
    let session = AVCaptureSession()
    
    @Published var fpsText = "FPS --"
    @Published var visionText = "VISION WAITING"
    @Published var trackingText = "CAMERA INIT"
    @Published var confidenceText = "CONF --"

    @Published var lidarStatusText = "LiDAR WAIT"
    @Published var lidarDistanceText = "DEPTH --"
    @Published var lidarQualityText = "DEPTH Q --"
    @Published var lidarSupported = false
    @Published var lidarDistanceMeters: Double = 0
    @Published var lidarQuality: Double = 0
    @Published var lidarPointCloud2D: [AVOLiDARPoint2D] = []
    @Published var lidarPointCloudStatus = "POINT CLOUD WAIT"
    @Published var lidarFusedPointCloud3D: [AVOLiDARPoint3D] = []
    @Published var lidarFusionReport: AVOLiDARFusionReport? = nil
    @Published var lidarFusionStatus = "FUSION WAIT"
    @Published var horseBodyLockStatus = "BODY LOCK WAIT"
    var lidarSamples: [AVOLiDARDepthSample] = []
    
    @Published var horseBox = CGRect(x: 0.22, y: 0.28, width: 0.52, height: 0.42)
    
    @Published var riderBox = CGRect(x: 0.45, y: 0.18, width: 0.18, height: 0.32)
    
    @Published var riderPosePoints: [CGPoint] = []
    @Published var horseKeypoints: [CGPoint] = []
    @Published var realHorseKeypoints: [HorseKeypoint] = []
    @Published var trackedHorseJoints: [TrackedHorseJoint] = []
    @Published var anatomyTrackingText = "ANATOMY TRACK WAIT"
    @Published var anatomyTrackingQualityText = "TRACK Q --"
    @Published var trackingGateStatusText = "GATE WAIT"
    @Published var trackingGateScoreText = "GATE --"
    @Published var trackingGateReasonText = "SIDE VIEW WAIT"
    @Published var bodyOrientationText = "BODY UNKNOWN"
    @Published var bodyPersistenceText = "PERSIST --"
    @Published var bodyPhaseText = "PHASE --"
    @Published var bodyHeatmapText = "HEATMAP --"
    @Published var trainingFrameRankText = "RANK --"
    @Published var hasActiveObjectLock = false
    
    @Published var gait = "WAIT"
    @Published var lameness = "NO MODEL"
    @Published var asymmetry = "--"
    @Published var biomechScore = "--"
    @Published var biomechStatusText = "BIOMECH WAIT"
    @Published var frontSymmetryText = "FRONT SYM --"
    @Published var hindSymmetryText = "HIND SYM --"
    @Published var lamenessRiskText = "LAME RISK --"
    @Published var strideText = "STRIDE --"
    @Published var headNodText = "HEAD NOD --"
    @Published var biomechAIStatusText = "AI BIOMECH WAIT"
    @Published var biomechAISuspicionText = "SUSPICION --"
    @Published var gaitEngineText = "GAIT ENGINE READY"
    @Published var bodyMapStatusText = "BODY MAP READY"
    @Published var vetRiskLevelText = "VET RISK LOW"
    @Published var autoDatasetV2Text = "AUTO DATASET V2 READY"
    @Published var biomechAISupportText = "SUPPORT --"
    @Published var hipHikeText = "HIP HIKE --"
    @Published var pushOffText = "PUSH OFF --"
    
    @Published var datasetStatusText = "DATASET READY"
    @Published var datasetCountText = "DATASET 0"
    @Published var datasetModeText = "DATASET OFF"
    @Published var isDatasetRecording = false
    
    @Published var vetAlert = "VET AI READY"
    @Published var vetDiagnosis = "DIAGNOSIS READY"
    
    @Published var coreMLStatus = "HORSE DETECTOR LOADING"
    @Published var horsePoseStatus = "POSE MODEL NOT CONNECTED"
    @Published var horseDetectionLabel = "NO HORSE"
    
    @Published var quality = 0.65
    @Published var fatigue = 0.20
    @Published var risk = 0.20
    
    @Published var isRecording = false
    @Published var autoRecEnabled = false
    @Published var autoRecStatus = "AUTO REC OFF"
    @Published var autoRecGateText = "AUTO WAIT"
    @Published var biomechVideoStatus = "VIDEO READY"
    @Published var videoRecordMode: AVOBiomechRecordingMode = .client
    @Published var videoModeStatus = "CLIENT 30FPS STABLE"
    @Published var lastBiomechVideoURL: URL? = nil
    @Published var sessionText = "STANDBY"
    @Published var reportText = "REPORT READY"
    @Published var audibleAlert = "ALERT READY"
    
    var currentCoordinate = CLLocationCoordinate2D(latitude: 43.4145, longitude: -3.4168)
    
    var pulseForSession = "41 BPM"
    var speedForSession = "14.6 km/h"
    var rssiForSession = "RSSI --"
    
    var sessionSamples: [SessionSample] = []
    
    private let queue = DispatchQueue(label: "AVO.camera")
    private let depthOutput = AVCaptureDepthDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var activeVideoDevice: AVCaptureDevice?
    private var lastDepthSampleTime: TimeInterval = 0
    private let lidarFusionEngine = AVOLiDARTemporalFusionEngine()
    private var configured = false
    private var frameCounter = 0
    private var lastFpsTime = Date()
    private var frameSkip = 0
    private var trackerObservation: VNDetectedObjectObservation?
    private var lastHorseCenter = CGPoint.zero
    private let horseDetector = HorseDetectorCoreML()
    private let horsePoseDetector = HorsePoseCoreML()
    private let anatomyTracker = HorseAnatomyTemporalTracker()
    private let biomechAnalyzer = HorseBiomechAnalyzer()
    private let biomechAIEngine = AVOHorseBiomechAIEngine()
    private let trackingGate = AVOHorseTrackingQualityGate()
    private let bodyStateEngine = AVOHorseBodyStateEngine()
    let datasetManager = HorseDatasetManager()
    private var lastPoseKeypoints: [HorseKeypoint] = []
    private var poseMissingFrames: Int = 0
    private var lastPoseConfidence: Double = 0
    private var lastGateAllowsTrainingFrame: Bool = false
    private var datasetFrameInterval = 18
    private var lastHorseConfidence: Double = 0
    private var autoRecGoodFrames: Int = 0
    private var autoRecLostFrames: Int = 0
    private var autoRecOwnsCurrentRecording: Bool = false
    private var autoRecLastDecision = Date.distantPast
    
    override init() {
        super.init()
        requestCameraPermissionAndStart()
    }
    
    func requestCameraPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            
        case .authorized:
            trackingText = "CAMERA AUTHORIZED"
            visionText = "STARTING CAMERA"
            
            queue.async {
                self.setupCamera()
            }
            
        case .notDetermined:
            trackingText = "CAMERA PERMISSION"
            
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.trackingText = "CAMERA READY"
                        self.visionText = "STARTING CAMERA"
                        
                        self.queue.async {
                            self.setupCamera()
                        }
                    } else {
                        self.trackingText = "CAMERA DENIED"
                        self.visionText = "NO CAMERA ACCESS"
                    }
                }
            }
            
        case .denied:
            trackingText = "CAMERA BLOCKED"
            visionText = "ENABLE CAMERA IN SETTINGS"
            
        case .restricted:
            trackingText = "CAMERA RESTRICTED"
            visionText = "NO CAMERA ACCESS"
            
        @unknown default:
            trackingText = "CAMERA ERROR"
            visionText = "UNKNOWN CAMERA STATE"
        }
    }
    
    func setupCamera() {
        if configured {
            if !session.isRunning {
                session.startRunning()
            }
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        for input in session.inputs {
            session.removeInput(input)
        }
        
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        let preferredDevice: AVCaptureDevice?
        if #available(iOS 15.4, *) {
            preferredDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back)
        } else {
            preferredDevice = nil
        }

        guard let device = preferredDevice ?? AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            DispatchQueue.main.async {
                self.trackingText = "NO BACK CAMERA"
                self.visionText = "CAMERA ERROR"
            }
            session.commitConfiguration()
            return
        }
        
        do {
            if !device.activeFormat.supportedDepthDataFormats.isEmpty {
                try? device.lockForConfiguration()
                if let bestDepth = device.activeFormat.supportedDepthDataFormats.first {
                    device.activeDepthDataFormat = bestDepth
                }
                device.unlockForConfiguration()
            }

            let input = try AVCaptureDeviceInput(device: device)
            self.activeVideoDevice = device
            applyVideoConfiguration(device: device, mode: videoRecordMode)
            
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                DispatchQueue.main.async {
                    self.trackingText = "CAMERA INPUT FAIL"
                    self.visionText = "INPUT NOT ADDED"
                }
                session.commitConfiguration()
                return
            }
            
        } catch {
            DispatchQueue.main.async {
                self.trackingText = "CAMERA INPUT ERROR"
                self.visionText = error.localizedDescription
            }
            session.commitConfiguration()
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        output.setSampleBufferDelegate(self, queue: queue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            DispatchQueue.main.async {
                self.trackingText = "CAMERA OUTPUT FAIL"
                self.visionText = "OUTPUT NOT ADDED"
            }
            session.commitConfiguration()
            return
        }
        
        if let connection = output.connection(with: .video) {
            configureBiomechVideoConnection(connection)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            if let movieConnection = movieOutput.connection(with: .video) {
                configureBiomechVideoConnection(movieConnection)
            }
            DispatchQueue.main.async {
                self.biomechVideoStatus = "VIDEO REC READY"
            }
        } else {
            DispatchQueue.main.async {
                self.biomechVideoStatus = "VIDEO OUTPUT OFF"
            }
        }

        if !device.activeFormat.supportedDepthDataFormats.isEmpty && session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = true
            depthOutput.setDelegate(self, callbackQueue: queue)
            if let depthConnection = depthOutput.connection(with: .depthData) {
                configureBiomechVideoConnection(depthConnection)
            }
            DispatchQueue.main.async {
                self.lidarSupported = true
                self.lidarStatusText = "LiDAR DEPTH LIVE"
            }
        } else {
            DispatchQueue.main.async {
                self.lidarSupported = false
                self.lidarStatusText = "LiDAR NOT AVAILABLE"
                self.lidarDistanceText = "DEPTH --"
                self.lidarQualityText = "DEPTH Q --"
            }
        }
        
        session.commitConfiguration()
        
        configured = true
        
        if !session.isRunning {
            session.startRunning()
        }
        
        DispatchQueue.main.async {
            self.trackingText = "CAMERA RUNNING"
            self.visionText = "VISION LIVE"
        }
    }
    
    func stopCamera() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            
            DispatchQueue.main.async {
                self.trackingText = "CAMERA STOPPED"
                self.visionText = "VISION PAUSED"
                self.hasActiveObjectLock = false
            }
        }
    }
    

    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let map = converted.depthDataMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }

        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        guard width > 4, height > 4, let base = CVPixelBufferGetBaseAddress(map) else { return }

        let rowBytes = CVPixelBufferGetBytesPerRow(map)
        let centerX = width / 2
        let centerY = height / 2
        let depthRowPointer = base.advanced(by: centerY * rowBytes).assumingMemoryBound(to: Float32.self)
        let centerDepth = Double(depthRowPointer[centerX])
        guard centerDepth.isFinite, centerDepth > 0 else { return }

        let now = Date().timeIntervalSince1970
        let clampedDistance = min(30.0, max(0.0, centerDepth))
        let idealDistance = 4.0
        let distancePenalty = min(1.0, abs(clampedDistance - idealDistance) / 6.0)
        let q = max(0.0, min(1.0, 1.0 - distancePenalty))

        if now - lastDepthSampleTime > 0.30 {
            lastDepthSampleTime = now
            let cloud = extractDepthPointCloud2D(from: map, width: width, height: height, rowBytes: rowBytes, base: base)
            let fusion = lidarFusionEngine.fuse(points2D: cloud, referenceDistance: clampedDistance, quality: q, timestamp: now)
            let sample = AVOLiDARDepthSample(
                time: now,
                distanceMeters: clampedDistance,
                quality: q,
                width: width,
                height: height,
                source: "AVCaptureDepthDataOutput + LiDAR point cloud"
            )
            DispatchQueue.main.async {
                self.lidarDistanceMeters = clampedDistance
                self.lidarQuality = q
                self.lidarDistanceText = String(format: "%.2f m", clampedDistance)
                self.lidarQualityText = q > 0.72 ? "DEPTH Q GOOD" : (q > 0.45 ? "DEPTH Q MID" : "DEPTH Q LOW")
                self.lidarStatusText = cloud.isEmpty ? "LiDAR DEPTH LIVE" : "LiDAR POINT CLOUD LIVE"
                self.lidarPointCloudStatus = cloud.isEmpty ? "POINT CLOUD WAIT" : "POINTS \(cloud.count)"
                self.lidarPointCloud2D = cloud
                self.lidarFusedPointCloud3D = fusion.points
                self.lidarFusionReport = fusion.report
                self.lidarFusionStatus = fusion.report.bodyBoxLocked ? "3D FUSION BODY LOCK" : "3D FUSION SEARCH"
                self.horseBodyLockStatus = fusion.report.bodyBoxLocked ? "HORSE BODY LOCKED" : "HORSE BODY SEARCH"
                self.lidarSamples.append(sample)
                if self.lidarSamples.count > 1200 {
                    self.lidarSamples.removeFirst(self.lidarSamples.count - 1200)
                }
                if self.movieOutput.isRecording && self.videoRecordMode == .biomechSlow {
                    AVOBiomechRealRecordingEngine.shared.recordLiDAR(
                        sample: sample,
                        points2D: cloud,
                        fusedPoints3D: fusion.points,
                        mediaTime: CACurrentMediaTime()
                    )
                }
            }
        }
    }



    private func extractDepthPointCloud2D(from map: CVPixelBuffer,
                                          width: Int,
                                          height: Int,
                                          rowBytes: Int,
                                          base: UnsafeMutableRawPointer) -> [AVOLiDARPoint2D] {
        let stepX = max(3, width / 42)
        let stepY = max(3, height / 30)
        var points: [AVOLiDARPoint2D] = []
        points.reserveCapacity(1300)

        var minDepth: Double = 99
        var maxDepth: Double = 0

        var y = stepY
        while y < height - stepY {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            var x = stepX
            while x < width - stepX {
                let d = Double(row[x])
                if d.isFinite && d > 0.20 && d < 12.0 {
                    minDepth = min(minDepth, d)
                    maxDepth = max(maxDepth, d)
                    let normalizedConfidence = max(0.05, min(1.0, 1.0 - abs(d - lidarDistanceMeters) / 5.0))
                    points.append(AVOLiDARPoint2D(
                        x: Double(x) / Double(max(1, width - 1)),
                        y: Double(y) / Double(max(1, height - 1)),
                        z: d,
                        confidence: normalizedConfidence
                    ))
                }
                x += stepX
            }
            y += stepY
        }

        if points.count > 1200 {
            let stride = max(1, points.count / 1200)
            points = points.enumerated().compactMap { idx, p in idx % stride == 0 ? p : nil }
        }

        return points
    }


    func latestLiDARFrameDictionary() -> [String: Double] {
        [
            "time": Date().timeIntervalSince1970,
            "distanceMeters": lidarDistanceMeters,
            "depthQuality": lidarQuality,
            "lidarSupported": lidarSupported ? 1.0 : 0.0
        ]
    }

    func updateExternalInputs(coordinate: CLLocationCoordinate2D, sensors: SensorHub) {
        currentCoordinate = coordinate
        pulseForSession = sensors.pulseStatus
        speedForSession = sensors.speedStatus
        rssiForSession = sensors.loraStatus
    }
    
    func toggleSession() {
        if isRecording {
            isRecording = false
            sessionText = "SAVED \(sessionSamples.count)"
            generateSessionReport()
            stopVideoRecording()
        } else {
            isRecording = true
            sessionSamples.removeAll()
            sessionText = "REC"
            reportText = "REPORT BUILDING"
            startVideoRecording(mode: videoRecordMode)
        }
    }

    private func biomechVideoFolder() throws -> URL {
        // MASTER SESSION CORE: every video is saved inside the active horse/session.
        if AVOMasterSessionCore.shared.activeHorseName == "SIN_CABALLO" {
            AVOMasterSessionCore.shared.setActiveHorse(name: BiotechHorseSessionRecorder.shared.selectedHorseName)
        }
        _ = try AVOMasterSessionCore.shared.ensureSession()
        switch videoRecordMode {
        case .client:
            return try AVOMasterSessionCore.shared.folder(for: .clientRec)
        case .biomechSlow:
            return try AVOMasterSessionCore.shared.folder(for: .biotechRec)
        }
    }

    func setVideoRecordMode(_ mode: AVOBiomechRecordingMode) {
        if movieOutput.isRecording { return }
        videoRecordMode = mode
        videoModeStatus = mode == .client ? "CLIENT 30FPS STABLE" : "BIOMECH 50FPS STABLE"
        if let device = activeVideoDevice {
            queue.async {
                self.applyVideoConfiguration(device: device, mode: mode)
            }
        }
    }

    func toggleSelectedVideoRecording() {
        autoRecOwnsCurrentRecording = false
        if movieOutput.isRecording {
            stopVideoRecording()
        } else {
            startVideoRecording(mode: videoRecordMode)
        }
    }

    func toggleClientVideoRecording() {
        autoRecOwnsCurrentRecording = false
        if movieOutput.isRecording && videoRecordMode == .client {
            stopVideoRecording()
        } else if !movieOutput.isRecording {
            setVideoRecordMode(.client)
            startVideoRecording(mode: .client)
        }
    }

    func toggleBiomechSlowVideoRecording() {
        autoRecOwnsCurrentRecording = false
        if movieOutput.isRecording && videoRecordMode == .biomechSlow {
            stopVideoRecording()
        } else if !movieOutput.isRecording {
            setVideoRecordMode(.biomechSlow)
            startVideoRecording(mode: .biomechSlow)
        }
    }


    func toggleAutoRecMode() {
        autoRecEnabled.toggle()
        autoRecGoodFrames = 0
        autoRecLostFrames = 0
        autoRecGateText = autoRecEnabled ? "AUTO ARMED" : "AUTO WAIT"
        autoRecStatus = autoRecEnabled ? "AUTO REC ARMED" : "AUTO REC OFF"

        if !autoRecEnabled && autoRecOwnsCurrentRecording && movieOutput.isRecording {
            stopVideoRecording()
        }
    }

    private func evaluateAutoRecGate() {
        guard autoRecEnabled else { return }

        let trackQ = anatomyTracker.trackingQuality()
        let hasEnoughJoints = trackedHorseJoints.count >= 10
        let gateOk = hasActiveObjectLock && lastGateAllowsTrainingFrame && hasEnoughJoints && trackQ >= 0.46
        let now = Date()

        if gateOk {
            autoRecGoodFrames += 1
            autoRecLostFrames = 0
        } else {
            autoRecLostFrames += 1
            autoRecGoodFrames = max(0, autoRecGoodFrames - 1)
        }

        DispatchQueue.main.async {
            self.autoRecGateText = gateOk ? "AUTO GATE OK" : "AUTO WAIT"
            if self.autoRecEnabled && !self.isRecording {
                self.autoRecStatus = gateOk ? "AUTO READY" : "AUTO ARMED"
            }
        }

        // Debounce start/stop decisions to avoid rapid toggling.
        guard now.timeIntervalSince(autoRecLastDecision) > 1.5 else { return }

        if !movieOutput.isRecording && autoRecGoodFrames >= 12 {
            autoRecLastDecision = now
            autoRecOwnsCurrentRecording = true
            DispatchQueue.main.async {
                self.autoRecStatus = "AUTO REC START"
            }
            startVideoRecording(mode: .client)
        }

        if movieOutput.isRecording && autoRecOwnsCurrentRecording && autoRecLostFrames >= 75 {
            autoRecLastDecision = now
            DispatchQueue.main.async {
                self.autoRecStatus = "AUTO REC STOP"
            }
            stopVideoRecording()
        }
    }


    private func phase34SpeedValue() -> Double {
        let raw = speedForSession
            .replacingOccurrences(of: "km/h", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(raw) ?? 0.0
    }

    private func updatePhase34BiomechEngine() {
        let jointCount = trackedHorseJoints.count
        let trackQ = anatomyTracker.trackingQuality()
        let stable = hasActiveObjectLock && jointCount >= 10 && trackQ > 0.45

        let gaitLabel: String
        let currentSpeed = phase34SpeedValue()
        if currentSpeed < 1.0 {
            gaitLabel = "STATIC"
        } else if currentSpeed < 7.0 {
            gaitLabel = "WALK"
        } else if currentSpeed < 18.0 {
            gaitLabel = "TROT"
        } else {
            gaitLabel = "CANTER"
        }

        let riskLevel: String
        if risk > 0.70 {
            riskLevel = "CRITICAL"
        } else if risk > 0.50 {
            riskLevel = "HIGH"
        } else if risk > 0.28 {
            riskLevel = "MEDIUM"
        } else {
            riskLevel = "LOW"
        }

        DispatchQueue.main.async {
            self.gaitEngineText = "GAIT \(gaitLabel) · Q \(Int(trackQ * 100))%"
            self.bodyMapStatusText = stable ? "BODY MAP LOCK · \(jointCount) PTS" : "BODY MAP WAIT · \(jointCount) PTS"
            self.vetRiskLevelText = "VET RISK \(riskLevel)"
            self.autoDatasetV2Text = stable ? "AUTO DATASET V2 CLEAN" : "AUTO DATASET V2 WAIT"
            if stable {
                self.quality = min(0.99, max(self.quality, trackQ))
            }
        }
    }

    private func applyVideoConfiguration(device: AVCaptureDevice, mode: AVOBiomechRecordingMode) {
        // IMPORTANT:
        // Do not switch the camera to 240 fps for REC BIOMECH. On iPad, especially indoors
        // under 50 Hz lights, that creates visible pulsing/flicker in the recorded movie.
        // Keep one stable capture clock and only use formats that can run at the requested
        // safe FPS. This also avoids the preview/video blackout when REC starts.
        do {
            try device.lockForConfiguration()

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }

            let target = Double(mode.targetFPS)
            var selectedFormat: AVCaptureDevice.Format? = nil
            var selectedScore: Double = 0

            for format in device.formats {
                guard let range = format.videoSupportedFrameRateRanges.first else { continue }
                guard range.maxFrameRate >= target && range.minFrameRate <= target else { continue }

                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let width = Int(dims.width)
                let height = Int(dims.height)

                // Prefer 1080p/4K stable video over exotic high-fps formats.
                let pixels = Double(width * height)
                let fpsPenalty = abs(range.maxFrameRate - target) * 10.0
                let score = pixels - fpsPenalty
                if score > selectedScore {
                    selectedScore = score
                    selectedFormat = format
                }
            }

            if let selected = selectedFormat {
                device.activeFormat = selected
            }

            let duration = CMTime(value: 1, timescale: CMTimeScale(mode.targetFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration

            device.unlockForConfiguration()
            DispatchQueue.main.async {
                if mode == .client {
                    self.videoModeStatus = "CLIENT 30FPS STABLE"
                } else {
                    self.videoModeStatus = "BIOMECH 50FPS STABLE"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.videoModeStatus = "FPS LOCK ERROR"
            }
        }
    }

    private func configureBiomechVideoConnection(_ connection: AVCaptureConnection) {
        // iPad BIOTECH runs in landscape. Forcing portrait/90º produced sideways videos.
        // Keep preview, movie and depth in the same landscape orientation.
        if #available(iOS 17.0, *) {
            connection.videoRotationAngle = 0
        } else {
            connection.videoOrientation = .landscapeRight
        }
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = false
        }
    }

    private func startVideoRecording(mode: AVOBiomechRecordingMode) {
        guard !movieOutput.isRecording else { return }
        videoRecordMode = mode
        if let device = activeVideoDevice {
            applyVideoConfiguration(device: device, mode: mode)
        }
        do {
            let folder = try biomechVideoFolder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let stamp = formatter.string(from: Date())
            let file = folder.appendingPathComponent("\(mode.filePrefix)_\(stamp).mov")
            if FileManager.default.fileExists(atPath: file.path) {
                try? FileManager.default.removeItem(at: file)
            }
            lastBiomechVideoURL = file
            isRecording = true
            sessionText = mode == .client ? "CLIENT REC" : "BIOMECH REC"
            biomechVideoStatus = mode == .client ? "CLIENT REC STABLE" : "BIOMECH REC STABLE"
            if let movieConnection = movieOutput.connection(with: .video) {
                configureBiomechVideoConnection(movieConnection)
            }
            if mode == .biomechSlow {
                AVOBiomechRealRecordingEngine.shared.begin(videoURL: file, mode: mode)
                biomechVideoStatus = "BIOMECH TOTAL CAPTURE"
            }
            movieOutput.startRecording(to: file, recordingDelegate: self)
        } catch {
            isRecording = false
            biomechVideoStatus = "VIDEO ERROR"
            reportText = "VIDEO ERROR: \(error.localizedDescription)"
        }
    }

    private func stopVideoRecording() {
        if movieOutput.isRecording {
            if videoRecordMode == .biomechSlow {
                AVOBiomechRealRecordingEngine.shared.finish(videoURL: lastBiomechVideoURL)
                biomechVideoStatus = "SAVING VIDEO + TRACKS"
            } else {
                biomechVideoStatus = "VIDEO SAVING"
            }
            movieOutput.stopRecording()
        } else if lastBiomechVideoURL != nil {
            isRecording = false
            sessionText = "SAVED"
            biomechVideoStatus = "VIDEO SAVED"
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.autoRecOwnsCurrentRecording = false
            if let error = error {
                self.sessionText = "VIDEO ERROR"
                self.biomechVideoStatus = "VIDEO ERROR"
                self.reportText = error.localizedDescription
            } else {
                self.lastBiomechVideoURL = outputFileURL
                if self.videoRecordMode == .biomechSlow {
                    AVOBiomechRealRecordingEngine.shared.finish(videoURL: outputFileURL)
                }
                self.writeVideoSessionManifest(videoURL: outputFileURL, mode: self.videoRecordMode)
                self.sessionText = self.videoRecordMode == .client ? "CLIENT SAVED" : "BIOMECH SAVED"
                self.biomechVideoStatus = self.videoRecordMode == .client ? "CLIENT VIDEO SAVED" : "BIOMECH VIDEO SAVED"
                self.reportText = "VIDEO SAVED: \(outputFileURL.lastPathComponent)"
            }
        }
    }
    
    private func writeVideoSessionManifest(videoURL: URL, mode: AVOBiomechRecordingMode) {
        let area = mode == .client ? "ClientRec" : "BiotechRec"
        let sessionId = AVOMasterSessionCore.shared.activeSessionId
        let horse = AVOMasterSessionCore.shared.activeHorseName
        let text = """
        {
          "type": "video_recording",
          "mode": "\(mode.rawValue)",
          "area": "\(area)",
          "horse": "\(horse)",
          "sessionId": "\(sessionId)",
          "file": "\(videoURL.lastPathComponent)",
          "path": "\(videoURL.path)",
          "createdAt": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
        do {
            _ = try AVOMasterSessionCore.shared.writeText(text, area: .manifests, fileName: "last_video_recording.json")
        } catch {
            // Keep recording flow safe. Manifest failure must never break video recording.
        }
    }

    func toggleDatasetRecording() {
        isDatasetRecording.toggle()

        do {
            try datasetManager.prepareDataset(name: "AVOStableHorseDataset")
            try datasetManager.exportTrainingReadme()
        } catch {
            datasetStatusText = "DATASET ERROR: \(error.localizedDescription)"
        }

        if isDatasetRecording {
            datasetModeText = "DATASET AUTO"
            datasetStatusText = "AUTO CAPTURE ACTIVE"
        } else {
            datasetModeText = "DATASET OFF"
            datasetStatusText = "AUTO CAPTURE STOPPED"
        }
        refreshDatasetCounters()
    }


    func datasetRootPathText() -> String {
        datasetManager.activeDatasetURL.path
    }

    func prepareDatasetForReview() {
        do {
            try datasetManager.prepareDataset(name: "AVOStableHorseDataset")
            try datasetManager.exportTrainingReadme()
            refreshDatasetCounters()
            datasetStatusText = "REVIEW DATASET READY"
        } catch {
            datasetStatusText = "REVIEW ERROR"
        }
    }

    func markNextFrameAsNegative() {
        datasetStatusText = "NEXT NEGATIVE SAMPLE"
        datasetModeText = "DATASET NEG"
    }

    func refreshDatasetCounters() {
        let total = datasetManager.records.count
        let positive = datasetManager.records.filter { $0.horseVisible }.count
        let anatomical = datasetManager.records.filter { !$0.keypoints.isEmpty }.count
        datasetCountText = "DATASET \(total) / H \(positive) / P \(anatomical)"
    }

    func saveDatasetFrame(_ sampleBuffer: CMSampleBuffer, label: String, forceNegative: Bool = false) {
        let visible = hasActiveObjectLock && !forceNegative
        let joints = forceNegative ? [] : trackedHorseJoints
        let box = visible ? horseBox : nil
        let coordinate = CLLocationCoordinate2D(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)

        do {
            let record = try datasetManager.saveFrame(
                sampleBuffer: sampleBuffer,
                label: label,
                horseVisible: visible,
                horseBox: box,
                horseConfidence: lastHorseConfidence,
                joints: joints,
                trackingQuality: anatomyTracker.trackingQuality(),
                gait: gait,
                lameness: lameness,
                coordinate: coordinate,
                notes: forceNegative ? "negative/no horse or low body-state rank" : "real iPad frame / persistent body-state approved"
            )

            DispatchQueue.main.async {
                self.datasetStatusText = "SAVED \(record.frameId)"
                self.datasetModeText = visible ? "DATASET HORSE" : "DATASET NEG"
                self.refreshDatasetCounters()
            }
        } catch {
            DispatchQueue.main.async {
                self.datasetStatusText = "DATASET SAVE ERROR"
            }
        }
    }

    func generateSessionReport() {
        guard !sessionSamples.isEmpty else {
            reportText = "REPORT EMPTY"
            return
        }
        
        let avgQ = sessionSamples.map { $0.quality }.reduce(0, +) / Double(sessionSamples.count)
        let avgR = sessionSamples.map { $0.risk }.reduce(0, +) / Double(sessionSamples.count)
        let avgF = sessionSamples.map { $0.fatigue }.reduce(0, +) / Double(sessionSamples.count)
        
        reportText = "Q \(Int(avgQ * 100))% / R \(Int(avgR * 100))% / F \(Int(avgF * 100))%"
    }
    
    func applyReplaySample(_ sample: SessionSample) {
        quality = sample.quality
        risk = sample.risk
        fatigue = sample.fatigue
        gait = sample.gait
        biomechScore = sample.score
        
        currentCoordinate = CLLocationCoordinate2D(
            latitude: sample.latitude,
            longitude: sample.longitude
        )
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCounter += 1
        frameSkip += 1
        
        let now = Date()
        
        if now.timeIntervalSince(lastFpsTime) >= 1 {
            let fps = frameCounter
            frameCounter = 0
            lastFpsTime = now
            
            DispatchQueue.main.async {
                self.fpsText = "FPS \(fps)"
            }
        }
        
        if trackerObservation == nil || frameSkip % 12 == 0 {
            acquireHorse(sampleBuffer)
        } else {
            trackHorse(sampleBuffer)
        }
        
        if frameSkip % 4 == 0 {
            detectRiderPose(sampleBuffer)
        }
        
        if frameSkip % 2 == 0 {
            detectHorsePose(sampleBuffer)
        }

        if isDatasetRecording && frameSkip % datasetFrameInterval == 0 {
            let shouldSaveHorseFrame = hasActiveObjectLock && lastGateAllowsTrainingFrame
            let label = shouldSaveHorseFrame ? "horse" : "negative"
            saveDatasetFrame(sampleBuffer, label: label, forceNegative: !shouldSaveHorseFrame)
        }

        // REC DATA -> REVIEW: lightweight metadata stream.
        // Do NOT build UIImage on every camera frame; that was freezing BIOTECH menus on iPad.
        let dataBridge = BiotechDataToReviewBridge.shared
        if dataBridge.isDataOn {
            let q = anatomyTracker.trackingQuality()
            let tag = (hasActiveObjectLock && lastGateAllowsTrainingFrame) ? "horse-lock-q-\(Int(q * 100))" : "raw-q-\(Int(q * 100))"
            let requested = min(max(1, dataBridge.requestedFPS), 30)
            let stride = max(2, Int(60.0 / Double(requested)))
            if frameSkip % stride == 0 {
                var w = 0
                var h = 0
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    w = CVPixelBufferGetWidth(pixelBuffer)
                    h = CVPixelBufferGetHeight(pixelBuffer)
                }
                let time = CACurrentMediaTime()
                let reviewImage = imageFromSampleBuffer(sampleBuffer)
                DispatchQueue.main.async {
                    dataBridge.acceptFrame(
                        image: reviewImage,
                        source: "biotech-camera-live",
                        timeSeconds: time,
                        width: w,
                        height: h,
                        qualityTag: tag
                    )
                }
            }
        }

        if movieOutput.isRecording && videoRecordMode == .biomechSlow && frameSkip % 2 == 0 {
            let joints = trackedHorseJoints
            let q = anatomyTracker.trackingQuality()
            let box = horseBox
            let mediaTime = CACurrentMediaTime()
            AVOBiomechRealRecordingEngine.shared.recordSkeleton(
                frameCounter: frameSkip,
                joints: joints,
                quality: q,
                horseBox: box,
                mediaTime: mediaTime
            )
            AVOBiomechRealRecordingEngine.shared.recordTelemetry(
                heartRate: pulseForSession,
                speed: speedForSession,
                cadence: "CAD --",
                imuPitch: 0,
                imuRoll: 0,
                imuImpact: 0,
                rssi: rssiForSession,
                battery: "BAT --",
                mediaTime: mediaTime
            )
        }

        if frameSkip % 3 == 0 {
            evaluateAutoRecGate()
            updatePhase34BiomechEngine()
        }
    }
    
    func acquireHorse(_ sampleBuffer: CMSampleBuffer) {
        if let result = horseDetector.detectHorse(in: sampleBuffer) {
            let newObservation = VNDetectedObjectObservation(boundingBox: result.boundingBox)
            trackerObservation = newObservation

            DispatchQueue.main.async {
                self.horseBox = self.smooth(
                    old: self.horseBox,
                    new: result.boundingBox,
                    factor: 0.28
                )

                self.trackingText = "HORSE DETECTOR LOCK"
                self.hasActiveObjectLock = true
                if self.trackedHorseJoints.isEmpty {
                    self.coreMLStatus = self.horseDetector.statusText
                    self.horseDetectionLabel = result.label.uppercased()
                }

                self.lastHorseConfidence = Double(result.confidence)
                self.confidenceText = String(
                    format: "HORSE %.0f%%",
                    result.confidence * 100
                )
            }

            analyze(horse: result.boundingBox)
            return
        }

        trackerObservation = nil

        DispatchQueue.main.async {
            self.hasActiveObjectLock = false
            self.coreMLStatus = self.horseDetector.statusText
            self.trackingText = "NO REAL HORSE LOCK"
            self.horseDetectionLabel = "NO HORSE"
            self.lastHorseConfidence = 0
            self.confidenceText = "HORSE --"
            self.realHorseKeypoints.removeAll()
            self.trackedHorseJoints.removeAll()
            self.horseKeypoints.removeAll()
            self.biomechAnalyzer.reset()
            self.autoRecGateText = "AUTO NO HORSE"
            if self.autoRecEnabled && !self.isRecording { self.autoRecStatus = "AUTO ARMED" }
            self.clearBiomechAnalysis(reason: "NO REAL HORSE")
        }
    }

    func trackHorse(_ sampleBuffer: CMSampleBuffer) {
        guard let observation = trackerObservation else { return }
        
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .accurate
        
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .right,
            options: [:]
        )
        
        do {
            try handler.perform([request])
            
            guard let result = request.results?.first as? VNDetectedObjectObservation else {
                trackerObservation = nil
                return
            }
            
            trackerObservation = result
            
            DispatchQueue.main.async {
                self.horseBox = self.smooth(
                    old: self.horseBox,
                    new: result.boundingBox,
                    factor: 0.24
                )
                
                self.trackingText = result.confidence > 0.55 ? "HORSE TRACK STABLE" : "HORSE TRACK WEAK"
                self.hasActiveObjectLock = result.confidence > 0.20
                
                self.lastHorseConfidence = Double(result.confidence)
                self.confidenceText = String(
                    format: "CONF %.0f%%",
                    result.confidence * 100
                )
            }
            
            analyze(horse: result.boundingBox)
            
        } catch {
            trackerObservation = nil
        }
    }
    
    func detectRiderPose(_ sampleBuffer: CMSampleBuffer) {
        let request = VNDetectHumanBodyPoseRequest()
        
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .right,
            options: [:]
        )
        
        do {
            try handler.perform([request])
            
            if let body = request.results?.first {
                let points = try body.recognizedPoints(.all)
                
                let wanted: [VNHumanBodyPoseObservation.JointName] = [
                    .nose,
                    .neck,
                    .leftShoulder,
                    .rightShoulder,
                    .leftHip,
                    .rightHip,
                    .leftKnee,
                    .rightKnee,
                    .leftAnkle,
                    .rightAnkle
                ]
                
                var normalized: [CGPoint] = []
                
                for joint in wanted {
                    if let point = points[joint], point.confidence > 0.25 {
                        normalized.append(
                            CGPoint(
                                x: point.location.x,
                                y: point.location.y
                            )
                        )
                    }
                }
                
                DispatchQueue.main.async {
                    self.riderPosePoints = normalized
                }
            }
            
        } catch { }
    }
    
    func reloadHorsePoseModel() {
        horsePoseDetector.reload()
        DispatchQueue.main.async {
            self.coreMLStatus = self.horsePoseDetector.statusText
            self.horsePoseStatus = self.horsePoseDetector.statusText
            self.vetDiagnosis = self.horsePoseDetector.isReady ? "HORSE POSE MODEL READY" : "WAITING HORSE POSE MODEL"
        }
    }

    func detectHorsePose(_ sampleBuffer: CMSampleBuffer) {
        // AVOHorsePose es un YOLOv8 Pose completo: detecta caja + puntos en la imagen.
        // No lo bloqueamos detrás del detector antiguo, porque ese detector puede no existir todavía.
        // Primero usamos la caja actual si hay tracking; si no, analizamos imagen completa.
        let roi = expandedHorseROI(hasActiveObjectLock ? horseBox : CGRect(x: 0, y: 0, width: 1, height: 1), margin: 0.18)

        guard let poseImage = imageFromSampleBuffer(sampleBuffer),
              let result = horsePoseDetector.detectPose(in: poseImage, horseBox: roi) else {
            poseMissingFrames += 1
            let held = anatomyTracker.trackedJoints()
            DispatchQueue.main.async {
                self.horsePoseStatus = self.horsePoseDetector.statusText
                self.realHorseKeypoints = self.anatomyTracker.stableHorseKeypoints()
                self.trackedHorseJoints = held
                self.horseKeypoints = self.realHorseKeypoints.map { CGPoint(x: $0.x, y: $0.y) }
                self.anatomyTrackingText = held.isEmpty ? "NO ANATOMY TRACK" : "PREDICTIVE TRACK HOLD"
                self.anatomyTrackingQualityText = String(format: "TRACK Q %.0f%%", self.anatomyTracker.trackingQuality() * 100)
                self.trackingGateStatusText = held.isEmpty ? "GATE WAIT" : "GATE HOLD"
                self.trackingGateScoreText = String(format: "GATE %.0f%%", self.anatomyTracker.trackingQuality() * 100)
                self.trackingGateReasonText = held.isEmpty ? "NO POINTS" : "TEMPORAL HOLD"
                self.bodyPersistenceText = held.isEmpty ? "PERSIST --" : "PERSIST HOLD"
                self.bodyPhaseText = held.isEmpty ? "PHASE --" : "PHASE HOLD"
                self.bodyHeatmapText = held.isEmpty ? "HEATMAP --" : "HEATMAP HOLD"
                self.trainingFrameRankText = held.isEmpty ? "RANK --" : "RANK HOLD"
                self.vetAlert = held.isEmpty ? "NO ANATOMY LOCK" : "POSE HOLD"
                self.vetDiagnosis = held.isEmpty ? "WAITING HORSE POSE MODEL" : "Temporal anatomy hold active. Keep horse lateral and centered."
                if held.isEmpty {
                    self.coreMLStatus = self.horsePoseDetector.statusText
                }
            }
            return
        }

        if result.keypoints.count < 8 || result.confidence < 0.12 {
            poseMissingFrames += 1
            let held = anatomyTracker.update(with: [])
            let heldPoints = anatomyTracker.stableHorseKeypoints()
            DispatchQueue.main.async {
                self.horsePoseStatus = String(format: "POSE HOLD %d PTS", result.keypoints.count)
                self.realHorseKeypoints = heldPoints
                self.trackedHorseJoints = held
                self.horseKeypoints = heldPoints.map { CGPoint(x: $0.x, y: $0.y) }
                self.anatomyTrackingText = held.isEmpty ? "NO ANATOMY TRACK" : "STABLE POSE HOLD"
                self.anatomyTrackingQualityText = String(format: "TRACK Q %.0f%%", self.anatomyTracker.trackingQuality() * 100)
                self.trackingGateStatusText = held.isEmpty ? "GATE WAIT" : "GATE HOLD"
                self.trackingGateReasonText = "LOW POSE INPUT"
                self.vetAlert = held.isEmpty ? "NO ANATOMY LOCK" : "POSE STABILIZED"
                self.vetDiagnosis = held.isEmpty ? "Waiting horse pose model." : "Low-confidence frame ignored. Holding stable anatomy to prevent flicker."
            }
            return
        }

        poseMissingFrames = 0
        lastPoseConfidence = result.confidence

        let tracked = anatomyTracker.update(with: result.keypoints)
        let stablePoints = anatomyTracker.stableHorseKeypoints()
        lastPoseKeypoints = stablePoints

        let poseBox = self.boundingBox(from: stablePoints)
        let gate = trackingGate.evaluate(
            joints: tracked,
            horseBox: poseBox ?? self.horseBox,
            trackingQuality: anatomyTracker.trackingQuality(),
            poseConfidence: result.confidence
        )
        let bodyState = bodyStateEngine.update(tracked: tracked, gateScore: gate.score)
        lastGateAllowsTrainingFrame = gate.shouldSaveTrainingFrame && bodyState.eliteFrameRank != "REJECTED"

        DispatchQueue.main.async {
            self.hasActiveObjectLock = true
            self.coreMLStatus = "AVOHorsePose REAL"
            self.trackingText = "AVOHORSEPOSE LOCK"
            self.horseDetectionLabel = "HORSE POSE"
            if let poseBox {
                self.horseBox = self.smooth(old: self.horseBox, new: poseBox, factor: 0.35)
            }
            self.confidenceText = String(format: "POSE %.0f%%", result.confidence * 100)
            self.horsePoseStatus = String(format: "POSE %d PTS %.0f%%", result.keypoints.count, result.confidence * 100)
            self.anatomyTrackingText = self.anatomyTracker.trackingStatusText()
            self.anatomyTrackingQualityText = String(format: "TRACK Q %.0f%%", self.anatomyTracker.trackingQuality() * 100)
            self.trackingGateStatusText = gate.status
            self.trackingGateScoreText = String(format: "GATE %.0f%%", gate.score * 100)
            self.trackingGateReasonText = gate.reason.uppercased()
            self.bodyOrientationText = "BODY " + bodyState.orientation.rawValue
            self.bodyPersistenceText = String(format: "PERSIST %.0f%%", bodyState.persistentScore * 100)
            self.bodyPhaseText = bodyState.gaitPhaseHint
            self.bodyHeatmapText = bodyState.heatmapSummary
            self.trainingFrameRankText = "RANK " + bodyState.eliteFrameRank
            self.trackedHorseJoints = tracked
            self.realHorseKeypoints = stablePoints
            self.horseKeypoints = stablePoints.map { CGPoint(x: $0.x, y: $0.y) }
            self.analyzePose(stablePoints)
            self.analyzeBiomechanics(tracked)
        }
    }

    private func expandedHorseROI(_ rect: CGRect, margin: CGFloat) -> CGRect {
        let x = max(0, rect.minX - rect.width * margin)
        let y = max(0, rect.minY - rect.height * margin)
        let maxX = min(1, rect.maxX + rect.width * margin)
        let maxY = min(1, rect.maxY + rect.height * margin)
        return CGRect(x: x, y: y, width: max(0.05, maxX - x), height: max(0.05, maxY - y))
    }

    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let screen = UIScreen.main.bounds
        let screenIsLandscape = screen.width > screen.height
        let bufferIsPortrait = ciImage.extent.height > ciImage.extent.width
        if screenIsLandscape && bufferIsPortrait {
            ciImage = ciImage.oriented(.right)
        }

        let context = CIContext(options: nil)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }

    private func boundingBox(from points: [HorseKeypoint]) -> CGRect? {
        let valid = points.filter { $0.confidence > 0.10 }
        guard valid.count >= 2 else { return nil }
        let xs = valid.map { CGFloat($0.x) }
        let ys = valid.map { CGFloat($0.y) }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        let marginX = max(0.04, (maxX - minX) * 0.22)
        let marginY = max(0.04, (maxY - minY) * 0.22)
        let x = max(0, minX - marginX)
        let y = max(0, minY - marginY)
        let w = min(1 - x, (maxX - minX) + marginX * 2)
        let h = min(1 - y, (maxY - minY) + marginY * 2)
        return CGRect(x: x, y: y, width: max(0.05, w), height: max(0.05, h))
    }

    func clearBiomechAnalysis(reason: String) {
        biomechStatusText = reason
        frontSymmetryText = "FRONT SYM --"
        hindSymmetryText = "HIND SYM --"
        lamenessRiskText = "LAME RISK --"
        strideText = "STRIDE --"
        headNodText = "HEAD NOD --"
        asymmetry = "--"
        lameness = "NO ANALYSIS"
        biomechScore = "--"
        vetAlert = reason
        vetDiagnosis = "WAITING REAL ANATOMY"
    }

    func analyzeBiomechanics(_ joints: [TrackedHorseJoint]) {
        let trackQ = anatomyTracker.trackingQuality()
        let metrics = biomechAnalyzer.update(joints: joints, trackingQuality: trackQ)
        let ai = biomechAIEngine.update(
            joints: joints,
            trackingQuality: trackQ,
            bodyRank: trainingFrameRankText
        )

        gait = metrics.gaitHint
        biomechStatusText = metrics.status
        biomechAIStatusText = "AI " + ai.alertLevel
        biomechAISuspicionText = ai.primarySuspicion
        biomechAISupportText = ai.supportPhase
        hipHikeText = String(format: "HIP HIKE %.0f%%", ai.hipHikeScore * 100)
        pushOffText = String(format: "PUSH OFF %.0f%%", ai.pushOffAsymmetry * 100)

        if let front = metrics.frontSymmetryScore {
            frontSymmetryText = String(format: "FRONT SYM %.0f%%", front * 100)
        } else {
            frontSymmetryText = "FRONT SYM --"
        }

        if let hind = metrics.hindSymmetryScore {
            hindSymmetryText = String(format: "HIND SYM %.0f%%", hind * 100)
        } else {
            hindSymmetryText = "HIND SYM --"
        }

        if let global = metrics.globalSymmetryScore {
            asymmetry = String(format: "SYM %.0f%%", global * 100)
            biomechScore = String(format: "BIO %.0f%%", global * 100)
        } else {
            asymmetry = "SYM --"
            biomechScore = "BIO PARTIAL"
        }

        let finalRisk = max(metrics.lamenessSuspicion, ai.risk)
        lamenessRiskText = String(format: "LAME RISK %.0f%%", finalRisk * 100)
        lameness = finalRisk >= 0.70 ? "HIGH REVIEW" : finalRisk >= 0.42 ? "POSSIBLE" : "LOW"

        let lf = metrics.leftFrontStride.map { String(format: "LF %.2f", $0 * 100) } ?? "LF --"
        let rf = metrics.rightFrontStride.map { String(format: "RF %.2f", $0 * 100) } ?? "RF --"
        let lh = metrics.leftHindStride.map { String(format: "LH %.2f", $0 * 100) } ?? "LH --"
        let rh = metrics.rightHindStride.map { String(format: "RH %.2f", $0 * 100) } ?? "RH --"
        strideText = "\(lf)  \(rf)  \(lh)  \(rh)"

        if let nod = metrics.headNodIndex {
            headNodText = String(format: "HEAD NOD %.1f%%", nod * 100)
        } else {
            headNodText = "HEAD NOD --"
        }

        risk = max(risk * 0.82, max(metrics.lamenessSuspicion, ai.risk))
        quality = max(0, min(1, (metrics.globalSymmetryScore ?? trackQ) * 0.70 + trackQ * 0.30))
        fatigue = max(0, min(1, fatigue * 0.86 + metrics.lamenessSuspicion * 0.14))

        if max(metrics.lamenessSuspicion, ai.risk) >= 0.70 {
            vetAlert = "HIGH ASYMMETRY"
            vetDiagnosis = ai.clinicalNote
            audibleAlert = "CHECK HORSE"
        } else if max(metrics.lamenessSuspicion, ai.risk) >= 0.42 {
            vetAlert = "POSSIBLE ASYMMETRY"
            vetDiagnosis = ai.clinicalNote
            audibleAlert = "REVIEW GAIT"
        } else {
            vetAlert = "NO CRITICAL FINDINGS"
            vetDiagnosis = "Real anatomical tracking active. Continue recording."
            audibleAlert = "NO VET ALERT"
        }
    }

    func analyzePose(_ points: [HorseKeypoint]) {
        let map = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })

        let leftFront = map[.leftHoof]?.y
        let rightFront = map[.rightHoof]?.y
        let leftHind = map[.leftHindHoof]?.y
        let rightHind = map[.rightHindHoof]?.y

        if let lf = leftFront, let rf = rightFront {
            let diff = abs(lf - rf)
            asymmetry = String(format: "FRONT %.1f%%", diff * 100)
            if diff > 0.055 {
                vetAlert = "ASYMMETRY FRONT"
                risk = min(1.0, risk + 0.18)
            } else {
                vetAlert = "NO CRITICAL FINDINGS"
            }
        }

        if let lh = leftHind, let rh = rightHind {
            let diff = abs(lh - rh)
            if diff > 0.060 {
                vetAlert = "ASYMMETRY HIND"
                risk = min(1.0, risk + 0.20)
            }
        }

        if map[.withers] != nil && map[.croup] != nil {
            biomechScore = "ANATOMY LOCK"
            vetDiagnosis = "REAL POSE TRACKING ACTIVE"
        } else {
            biomechScore = "PARTIAL POSE"
            vetDiagnosis = "PARTIAL ANATOMY POINTS"
        }
    }

    func smoothKeypoints(old: [HorseKeypoint], new: [HorseKeypoint], factor: Double) -> [HorseKeypoint] {
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { ($0.joint, $0) })

        return new.map { point in
            guard let previous = oldMap[point.joint] else { return point }

            let x = previous.x + (point.x - previous.x) * factor
            let y = previous.y + (point.y - previous.y) * factor
            let confidence = previous.confidence + (point.confidence - previous.confidence) * factor

            return HorseKeypoint(
                joint: point.joint,
                x: x,
                y: y,
                confidence: confidence
            )
        }
    }
    
    func analyze(horse: CGRect) {
        let center = CGPoint(x: horse.midX, y: horse.midY)
        
        if lastHorseCenter != .zero {
            let dx = center.x - lastHorseCenter.x
            let dy = center.y - lastHorseCenter.y
            let motion = sqrt(dx * dx + dy * dy)
            
            let q = max(0, min(1, 1.0 - Double(abs(dy) * 18)))
            let f = max(0, min(1, Double(abs(dy) * 16 + motion * 6)))
            let r = max(0, min(1, Double(abs(dx) * 12 + abs(dy) * 18)))
            
            DispatchQueue.main.async {
                self.quality = q
                self.fatigue = f
                self.risk = r
                
                self.gait = motion < 0.002 ? "STATIC" :
                motion < 0.006 ? "WALK" :
                motion < 0.015 ? "TROT" : "GALLOP"
                
                if self.realHorseKeypoints.isEmpty {
                    self.asymmetry = "--"
                    self.biomechScore = self.hasActiveObjectLock ? "HORSE LOCK" : "--"
                    self.vetAlert = "NO POSE MODEL"
                    self.vetDiagnosis = "WAITING HORSE POSE MODEL"
                    self.audibleAlert = "NO VET ALERT"
                }
                
                if self.isRecording {
                    self.sessionSamples.append(
                        SessionSample(
                            time: Date().timeIntervalSince1970,
                            quality: q,
                            risk: r,
                            fatigue: f,
                            latitude: self.currentCoordinate.latitude,
                            longitude: self.currentCoordinate.longitude,
                            gait: self.gait,
                            score: self.biomechScore,
                            pulse: self.pulseForSession,
                            speed: self.speedForSession,
                            rssi: self.rssiForSession
                        )
                    )
                }
            }
        }
        
        lastHorseCenter = center
    }
    
    func smooth(old: CGRect, new: CGRect, factor: CGFloat) -> CGRect {
        CGRect(
            x: old.origin.x + (new.origin.x - old.origin.x) * factor,
            y: old.origin.y + (new.origin.y - old.origin.y) * factor,
            width: old.width + (new.width - old.width) * factor,
            height: old.height + (new.height - old.height) * factor
        )
    }
}


extension CameraManager {
    func reloadPoseModelFromDocuments() {
        NotificationCenter.default.post(name: .avoHorsePoseModelUpdated, object: nil)
    }
    func switchCamera() {
        // Placeholder for front/back camera toggle in Playgrounds-safe build.
        // The camera session remains active; real AVCapture device switching can be wired here later.
    }


}
