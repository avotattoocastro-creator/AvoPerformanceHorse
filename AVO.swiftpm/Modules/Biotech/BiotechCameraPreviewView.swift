import SwiftUI
import AVFoundation
import UIKit

// MARK: - BIOTECH PHASE 116
// REAL CAMERA PREVIEW FIX
//
// This gives BIOTECH a real AVCaptureSession preview instead of a black fake layer.
// It is additive and safe. Use BiotechCameraPreviewView inside AVOBiomechFullPage.

@MainActor
public final class BiotechCameraManager: NSObject, ObservableObject {

    @Published public private(set) var session = AVCaptureSession()
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published public private(set) var statusText: String = "CAMERA READY"
    @Published public private(set) var lastError: String?

    private var isConfigured = false
    private let ownership = AVOCameraOwnershipCoordinator.shared

    public override init() {
        super.init()
    }

    public func requestAndStart() {
        ownership.claim(.biotech)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status

        switch status {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    if granted {
                        self.configureAndStart()
                    } else {
                        self.statusText = "CAMERA PERMISSION DENIED"
                        self.lastError = "Activa cámara en Ajustes > Privacidad > Cámara."
                    }
                }
            }
        case .denied, .restricted:
            statusText = "CAMERA BLOCKED"
            lastError = "Sin permiso de cámara. Revisa Ajustes del iPad."
        @unknown default:
            statusText = "CAMERA UNKNOWN PERMISSION"
            lastError = "Estado de permisos desconocido."
        }
    }

    public func configureAndStart() {
        statusText = "CONFIGURING CAMERA"

        do {
            if !isConfigured {
                try configureSession()
            }

            if !session.isRunning {
                session.startRunning()
            }

            isRunning = session.isRunning
            statusText = session.isRunning ? "CAMERA LIVE" : "CAMERA NOT RUNNING"
            lastError = session.isRunning ? nil : "AVCaptureSession no arrancó."
        } catch {
            statusText = "CAMERA ERROR"
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    public func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        isRunning = false
        statusText = "CAMERA STOPPED"
        ownership.release(.biotech)
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        for input in session.inputs {
            session.removeInput(input)
        }

        for output in session.outputs {
            session.removeOutput(output)
        }

        let device =
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
            AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) ??
            AVCaptureDevice.default(for: .video)

        guard let camera = device else {
            session.commitConfiguration()
            throw NSError(domain: "BiotechCameraManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No se encontró cámara disponible."
            ])
        }

        let input = try AVCaptureDeviceInput(device: camera)

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw NSError(domain: "BiotechCameraManager", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "No se pudo añadir input de cámara."
            ])
        }

        session.addInput(input)

        let dataOutput = BiotechCameraFrameOutputHook.shared.makeVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
        }

        session.commitConfiguration()
        isConfigured = true
    }
}

public final class BiotechCameraPreviewUIView: UIView {

    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    public var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    public func attach(session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .landscapeRight
    }
}

public struct BiotechCameraPreviewRepresentable: UIViewRepresentable {

    public let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> BiotechCameraPreviewUIView {
        let view = BiotechCameraPreviewUIView()
        view.attach(session: session)
        return view
    }

    public func updateUIView(_ uiView: BiotechCameraPreviewUIView, context: Context) {
        uiView.attach(session: session)
    }
}

public struct BiotechCameraPreviewView: View {

    @StateObject private var camera = BiotechCameraManager()

    public init() {}

    public var body: some View {
        ZStack(alignment: .topLeading) {
            BiotechCameraPreviewRepresentable(session: camera.session)
                .ignoresSafeArea()

            if camera.permissionStatus != .authorized || !camera.isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    Text(camera.statusText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)

                    if let error = camera.lastError {
                        Text(error)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Button("ACTIVAR CÁMARA") {
                        camera.requestAndStart()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(14)
                .background(Color.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(12)
            }

            VStack {
                Spacer()
                HStack {
                    Circle()
                        .fill(camera.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(camera.isRunning ? "CAM LIVE" : "CAM OFF")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(10)
                .background(Color.black.opacity(0.42))
            }
        }
        .onAppear {
            camera.requestAndStart()
        }
        .onDisappear {
            camera.stop()
        }
    }
}
