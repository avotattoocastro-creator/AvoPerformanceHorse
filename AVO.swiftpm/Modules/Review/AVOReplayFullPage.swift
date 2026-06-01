
import SwiftUI
import UIKit

struct AVOReplayFullPage: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: SessionStore
    @ObservedObject var camera: CameraManager
    @ObservedObject var stableStore: AVOStableStore

    @State private var replayScrubIndex: Double = 0

    private let replayTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    header

                    AVOReplayPanel(title: "REPLAY PRO ANALYZER", accent: .cyan) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                replayControlBox
                                    .frame(width: max(360, geo.size.width * 0.31), height: 142)

                                replayDataBox1
                                    .frame(maxWidth: .infinity, maxHeight: 142)

                                replayDataBox2
                                    .frame(width: max(230, geo.size.width * 0.18), height: 142)
                            }

                            if store.replaySamples.isEmpty {
                                Spacer()
                                VStack(spacing: 12) {
                                    Text("NO SESSION LOADED")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 24, weight: .black, design: .monospaced))
                                    Text("Pulsa LIST o LOAD para cargar una sesión real guardada y reproducir el análisis.")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity)
                                Spacer()
                            } else {
                                replayCharts
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            store.refreshSessions()
            replayScrubIndex = Double(store.replayIndex)
        }
        .onReceive(replayTimer) { _ in
            if let sample = store.nextReplaySample() {
                camera.applyReplaySample(sample)
                replayScrubIndex = Double(max(0, store.replayIndex - 1))
            }
        }
    }

    private var header: some View {
        AVOUnifiedPageHeader(
            title: "Replay",
            subtitle: "Session analysis · biomech/sensor history",
            status: stableStore.selectedHorseName.uppercased(),
            accent: .cyan,
            onClose: { dismiss() }
        ) {
            AVOUnifiedHeaderActionButton(title: "LOAD", color: .cyan) {
                store.loadLastSession()
                replayScrubIndex = 0
            }
        }
    }


    private var replayControlBox: some View {
        AVOReplaySmallBox(title: "REPLAY PRO ANALYZER", accent: .cyan) {
            VStack(alignment: .leading, spacing: 6) {
                MiniText(name: "FILE", value: store.selectedSessionName, color: .white)
                MiniText(name: "STATUS", value: store.replayStatus, color: .green)
                MiniText(name: "INDEX", value: "\(store.replayIndex) / \(max(store.replaySamples.count - 1, 0))", color: .green)
                MiniText(name: "TIME", value: sampleTimeText(selectedReplaySample()), color: .cyan)
                MiniText(name: "SPEED", value: selectedReplaySample()?.speed ?? "--", color: .green)
                MiniText(name: "PULSE", value: selectedReplaySample()?.pulse ?? "--", color: .green)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button { store.refreshSessions() } label: { AVOReplayMiniButton("LIST", .green) }
                        Button { store.loadLastSession(); replayScrubIndex = 0 } label: { AVOReplayMiniButton("LOAD", .cyan) }
                        Button { store.replayPaused.toggle() } label: { AVOReplayMiniButton(store.replayPaused ? "PLAY" : "PAUSE", .green) }
                        Button { store.jumpReplayForward(); replayScrubIndex = Double(store.replayIndex) } label: { AVOReplayMiniButton("SKIP", .cyan) }
                        Button { store.stopReplay() } label: { AVOReplayMiniButton("STOP", .red) }
                        Button { store.replayPaused = true } label: { AVOReplayMiniButton("1X", .gray) }
                    }
                }
            }
        }
    }

    private var replayDataBox1: some View {
        AVOReplaySmallBox(title: "GAIT", accent: .orange) {
            let sample = selectedReplaySample()

            VStack(alignment: .leading, spacing: 8) {
                MiniText(name: "GAIT", value: sample?.gait.uppercased() ?? "--", color: .orange)
                MiniText(name: "SCORE", value: sample?.score ?? "--", color: .green)
                MiniText(name: "RSSI", value: sample?.rssi ?? "--", color: .orange)
                MiniText(name: "LAT", value: sample == nil ? "--" : String(format: "%.5f", sample!.latitude), color: .white)
                MiniText(name: "LON", value: sample == nil ? "--" : String(format: "%.5f", sample!.longitude), color: .white)
                MiniText(name: "DIAG", value: camera.vetDiagnosis.isEmpty ? "NO ALERTS" : camera.vetDiagnosis, color: .cyan)
            }
        }
    }

    private var replayDataBox2: some View {
        AVOReplaySmallBox(title: "CURRENT", accent: .green) {
            let sample = selectedReplaySample()

            VStack(alignment: .leading, spacing: 8) {
                MiniText(name: "QUALITY", value: samplePercent(sample?.quality), color: .green)
                MiniText(name: "RISK", value: samplePercent(sample?.risk), color: .red)
                MiniText(name: "FATIGUE", value: samplePercent(sample?.fatigue), color: .orange)
                MiniText(name: "ACCEL", value: String(format: "%.2f G", selectedAcceleration()), color: .orange)
                MiniText(name: "SAMPLES", value: "\(store.replaySamples.count)", color: .cyan)
                MiniText(name: "HORSE", value: stableStore.selectedHorseName, color: .green)
            }
        }
    }

    private var replayCharts: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SESSION TIMELINE")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .black, design: .monospaced))

                Spacer()

                Text("\(Int(replayScrubIndex)) / \(max(store.replaySamples.count - 1, 0))")
                    .foregroundColor(.green)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            }

            Slider(
                value: $replayScrubIndex,
                in: 0...Double(max(store.replaySamples.count - 1, 1)),
                step: 1
            )
            .frame(height: 24)
            .onChange(of: replayScrubIndex) { _, newValue in
                let idx = min(max(Int(newValue), 0), store.replaySamples.count - 1)
                store.replayIndex = idx
                camera.applyReplaySample(store.replaySamples[idx])
            }

            HStack(spacing: 8) {
                ReplayChartBox(title: "PULSE", valueText: selectedReplaySample()?.pulse ?? "--", color: .green, values: replayWindowValues(replayPulseValues()), currentIndex: replayWindowValues(replayPulseValues()).count - 1)
                ReplayChartBox(title: "SPEED", valueText: selectedReplaySample()?.speed ?? "--", color: .cyan, values: replayWindowValues(replaySpeedValues()), currentIndex: replayWindowValues(replaySpeedValues()).count - 1)
                ReplayChartBox(title: "ACCEL", valueText: String(format: "%.2f", selectedAcceleration()), color: .orange, values: replayWindowValues(replayAccelerationValues()), currentIndex: replayWindowValues(replayAccelerationValues()).count - 1)
            }

            HStack(spacing: 8) {
                ReplayChartBox(title: "QUALITY", valueText: samplePercent(selectedReplaySample()?.quality), color: .green, values: replayWindowValues(store.replaySamples.map { $0.quality }), currentIndex: replayWindowValues(store.replaySamples.map { $0.quality }).count - 1)
                ReplayChartBox(title: "RISK", valueText: samplePercent(selectedReplaySample()?.risk), color: .red, values: replayWindowValues(store.replaySamples.map { $0.risk }), currentIndex: replayWindowValues(store.replaySamples.map { $0.risk }).count - 1)
                ReplayChartBox(title: "FATIGUE", valueText: samplePercent(selectedReplaySample()?.fatigue), color: .orange, values: replayWindowValues(store.replaySamples.map { $0.fatigue }), currentIndex: replayWindowValues(store.replaySamples.map { $0.fatigue }).count - 1)
                ReplayChartBox(title: "ASYM SCORE", valueText: selectedReplaySample()?.score ?? "--", color: .purple, values: replayWindowValues(replayScoreValues()), currentIndex: replayWindowValues(replayScoreValues()).count - 1)
            }
        }
    }

    private func selectedReplaySample() -> SessionSample? {
        guard !store.replaySamples.isEmpty else { return nil }
        let idx = min(max(Int(replayScrubIndex), 0), store.replaySamples.count - 1)
        return store.replaySamples[idx]
    }

    private func samplePercent(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        return "\(Int(value * 100))%"
    }

    private func sampleTimeText(_ sample: SessionSample?) -> String {
        guard let sample = sample else { return "--" }
        let date = Date(timeIntervalSince1970: sample.time)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func numberFromText(_ text: String) -> Double {
        let clean = text
            .replacingOccurrences(of: "km/h", with: "")
            .replacingOccurrences(of: "BPM", with: "")
            .replacingOccurrences(of: "RSSI", with: "")
            .replacingOccurrences(of: "BAT", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(clean) ?? 0
    }

    private func replayWindowValues(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }

        let idx = min(max(Int(replayScrubIndex), 0), values.count - 1)
        let window = 90
        let start = max(0, idx - window + 1)
        return Array(values[start...idx])
    }

    private func replayPulseValues() -> [Double] {
        store.replaySamples.map { numberFromText($0.pulse) }
    }

    private func replaySpeedValues() -> [Double] {
        store.replaySamples.map { numberFromText($0.speed) }
    }

    private func replayScoreValues() -> [Double] {
        store.replaySamples.map { Double($0.score) ?? 0 }
    }

    private func replayAccelerationValues() -> [Double] {
        let speeds = replaySpeedValues()
        guard speeds.count > 1 else { return speeds }

        var values: [Double] = [0]

        for i in 1..<speeds.count {
            values.append(speeds[i] - speeds[i - 1])
        }

        return values
    }

    private func selectedAcceleration() -> Double {
        let values = replayAccelerationValues()
        guard !values.isEmpty else { return 0 }
        let idx = min(max(Int(replayScrubIndex), 0), values.count - 1)
        return values[idx]
    }
}

struct AVOReplayPanel<Content: View>: View {
    var title: String
    var accent: Color
    @ViewBuilder var content: Content

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.01, green: 0.025, blue: 0.03).opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.26), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct AVOReplaySmallBox<Content: View>: View {
    var title: String
    var accent: Color
    @ViewBuilder var content: Content

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(accent)
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.32))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(accent.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct AVOReplayButtonText: View {
    var title: String
    var color: Color

    init(_ title: String, _ color: Color) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundColor(color == .yellow ? .black : .white)
            .frame(minWidth: 110)
            .frame(height: 42)
            .background(color.opacity(color == .red ? 0.82 : 0.70))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.9), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct AVOReplayMiniButton: View {
    var title: String
    var color: Color

    init(_ title: String, _ color: Color) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(color == .yellow ? .black : .white)
            .frame(width: 54, height: 30)
            .background(color.opacity(color == .gray ? 0.40 : 0.78))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
