import SwiftUI

// MARK: - PHASE131
// BIOTECH REC PANEL V4
//
// Compact REC panel. Includes:
// REC CLIENT
// REC BIOMECH
// REC DATA
// DATA ON/OFF is explicitly inside the REC panel.

@MainActor
struct BiotechRecFloatingPanelV4: View {

    @ObservedObject private var complete = BiotechCompleteSystemController.shared
    @ObservedObject private var dataBridge = BiotechDataToReviewBridge.shared
    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared

    @ObservedObject var camera: CameraManager

    var selectedHorseName: String
    var requestedFPS: Int

    init(camera: CameraManager, selectedHorseName: String = "SIN_CABALLO", requestedFPS: Int = 120) {
        self.camera = camera
        self.selectedHorseName = selectedHorseName
        self.requestedFPS = requestedFPS
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                modeChip("CLIENT", active: camera.isRecording && camera.videoRecordMode == .client)
                modeChip("BIOMECH", active: camera.isRecording && camera.videoRecordMode == .biomechSlow)
                modeChip("DATA", active: dataBridge.isDataOn || camera.isDatasetRecording)
            }

            HStack(spacing: 8) {
                Button {
                    prepare()
                    try? recorder.ensureSession()
                    camera.toggleClientVideoRecording()
                    complete.prepare(horseName: selectedHorseName)
                } label: {
                    recLabel((camera.isRecording && camera.videoRecordMode == .client) ? "STOP CLIENT" : "REC CLIENT", color: .green)
                }
                .buttonStyle(.plain)

                Button {
                    prepare()
                    try? recorder.ensureSession()
                    camera.toggleBiomechSlowVideoRecording()
                    complete.prepare(horseName: selectedHorseName)
                } label: {
                    recLabel((camera.isRecording && camera.videoRecordMode == .biomechSlow) ? "STOP BIOMECH" : "REC BIOMECH", color: .orange)
                }
                .buttonStyle(.plain)
            }

            Button {
                prepareLight()
                toggleRealDatasetAndReviewStream()
            } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill((dataBridge.isDataOn || camera.isDatasetRecording) ? Color.green : Color.white)
                        .frame(width: 9, height: 9)

                    Text((dataBridge.isDataOn || camera.isDatasetRecording) ? "REC DATA ON → REVIEW" : "REC DATA OFF")
                        .font(.system(size: 11, weight: .black, design: .monospaced))

                    Spacer()

                    Text((dataBridge.isDataOn || camera.isDatasetRecording) ? "\(dataBridge.requestedFPS)FPS" : "DATA")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background((dataBridge.isDataOn || camera.isDatasetRecording) ? Color.green.opacity(0.22) : Color.purple.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke((dataBridge.isDataOn || camera.isDatasetRecording) ? Color.green.opacity(0.75) : Color.purple.opacity(0.85), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button("OPEN SESSION") {
                    prepare()
                    complete.openTrainingSession()
                }
                .buttonStyle(.borderedProminent)

                Button("CLOSE SESSION") {
                    if camera.isRecording { camera.toggleSelectedVideoRecording() }
                    if camera.isDatasetRecording { camera.toggleDatasetRecording() }
                    if dataBridge.isDataOn { dataBridge.setDataOn(false, requestedFPS: min(requestedFPS, 30)) }
                    complete.closeTrainingSession()
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))

            HStack(spacing: 8) {
                Button("FULL") {
                    prepareLight()
                    try? recorder.ensureSession()
                    if !camera.isRecording { camera.toggleClientVideoRecording() }
                    if !camera.isDatasetRecording { camera.toggleDatasetRecording() }
                    if !dataBridge.isDataOn { dataBridge.setDataOn(true, requestedFPS: min(requestedFPS, 30)) }
                }
                .buttonStyle(.borderedProminent)

                Button("STOP REC") {
                    if camera.isRecording { camera.toggleSelectedVideoRecording() }
                    if camera.isDatasetRecording { camera.toggleDatasetRecording() }
                    if dataBridge.isDataOn { dataBridge.setDataOn(false, requestedFPS: min(requestedFPS, 30)) }
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
                Text(displayHorse)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)

                Spacer()

                Text(complete.status)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: 370)
        .background(Color.black.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .onAppear {
            prepareLight()
        }
    }

    private func prepare() {
        recorder.setSelectedHorse(selectedHorseName)
        complete.prepare(horseName: selectedHorseName)
    }

    private func prepareLight() {
        // Light preparation only: do not force-release camera ownership while the live camera is running.
        recorder.setSelectedHorse(selectedHorseName)
        try? recorder.ensureSession()
    }

    private func toggleRealDatasetAndReviewStream() {
        let fps = min(requestedFPS, 30)
        if camera.isDatasetRecording || dataBridge.isDataOn {
            if camera.isDatasetRecording { camera.toggleDatasetRecording() }
            if dataBridge.isDataOn { dataBridge.setDataOn(false, requestedFPS: fps) }
        } else {
            camera.prepareDatasetForReview()
            camera.toggleDatasetRecording()
            dataBridge.clearBuffer()
            dataBridge.setDataOn(true, requestedFPS: fps)
        }
    }

    private var displayHorse: String {
        let value = recorder.selectedHorseName
        if value.isEmpty || value == "SIN_CABALLO" {
            return "SIN CABALLO"
        }
        return value
    }

    private func recLabel(_ title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color.white).frame(width: 9, height: 9)
            Text(title).font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(color.opacity(0.23))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.8), lineWidth: 1))
    }

    private func modeChip(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(active ? Color.black : Color.white.opacity(0.85))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(active ? Color.green : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
