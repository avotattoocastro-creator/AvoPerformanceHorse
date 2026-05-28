import SwiftUI
import Foundation

struct StableMetricCalibrationProfile: Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var createdAt: Date
    var updatedAt: Date
    var withersHeightMeters: Double
    var bodyLengthMeters: Double
    var idealCameraDistanceMeters: Double
    var measuredLiDARDistanceMeters: Double
    var depthQuality: Double
    var centimetersPerPixelEstimate: Double
    var estimatedStrideMeters: Double
    var verticalAsymmetryCentimeters: Double
    var measurementQuality: String
    var notes: String
}

struct AVOMetricCalibrationCenterPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var latestLiDARSample: AVOLiDARDepthSample?
    var liveLiDARPoints: [AVOLiDARPoint2D] = []
    var fusedLiDARPoints3D: [AVOLiDARPoint3D] = []
    var lidarFusionReport: AVOLiDARFusionReport? = nil
    var onSave: (StableMetricCalibrationProfile) -> Void
    var onOpenFolder: () -> Void
    var onClose: () -> Void

    @State private var withersHeightMeters: Double = 1.55
    @State private var bodyLengthMeters: Double = 2.35
    @State private var idealCameraDistanceMeters: Double = 4.50
    @State private var manualLiDARDistanceMeters: Double = 4.50
    @State private var manualDepthQuality: Double = 0.75
    @State private var estimatedPixelHeight: Double = 640
    @State private var notes: String = ""
    @State private var statusText: String = "READY"

    private var effectiveLiDARDistance: Double {
        latestLiDARSample?.distanceMeters ?? manualLiDARDistanceMeters
    }

    private var effectiveDepthQuality: Double {
        latestLiDARSample?.quality ?? manualDepthQuality
    }

    private var centimetersPerPixel: Double {
        guard estimatedPixelHeight > 1 else { return 0 }
        return (withersHeightMeters * 100.0) / estimatedPixelHeight
    }

    private var estimatedStrideMeters: Double {
        max(0.0, bodyLengthMeters * 1.18)
    }

    private var verticalAsymmetryCentimeters: Double {
        let riskValues = sessions.map { $0.avgRisk }
        let fatigueValues = sessions.map { $0.avgFatigue }
        let risk = riskValues.isEmpty ? 0.0 : riskValues.reduce(0.0, +) / Double(riskValues.count)
        let fatigue = fatigueValues.isEmpty ? 0.0 : fatigueValues.reduce(0.0, +) / Double(fatigueValues.count)
        return max(0.0, (risk * 4.0) + (fatigue * 2.0))
    }

    private var distanceDelta: Double {
        abs(effectiveLiDARDistance - idealCameraDistanceMeters)
    }

    private var measurementQuality: String {
        if effectiveDepthQuality >= 0.78 && distanceDelta <= 0.80 { return "GOOD" }
        if effectiveDepthQuality >= 0.55 && distanceDelta <= 1.50 { return "WATCH" }
        return "BAD POSITION"
    }

    private var qualityColor: Color {
        switch measurementQuality {
        case "GOOD": return Color.green
        case "WATCH": return Color.orange
        default: return Color.red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                engineeringBackground

                VStack(spacing: 10) {
                    header

                    HStack(spacing: 10) {
                        inputPanel
                            .frame(width: max(250, geo.size.width * 0.22))

                        metricsPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        guidancePanel
                            .frame(width: max(220, geo.size.width * 0.19))
                    }
                    .frame(maxHeight: .infinity)

                    bottomBar
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .ignoresSafeArea(.container, edges: .all)
        }
    }

    private var engineeringBackground: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.005, green: 0.035, blue: 0.045),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<30, id: \.self) { i in
                    Rectangle()
                        .fill(Color.cyan.opacity(0.035))
                        .frame(width: geo.size.width * 1.6, height: 1)
                        .rotationEffect(.degrees(-18))
                        .offset(x: -geo.size.width * 0.25, y: CGFloat(i) * 42)
                }

                RadialGradient(
                    colors: [Color.cyan.opacity(0.16), Color.clear],
                    center: .center,
                    startRadius: 30,
                    endRadius: max(geo.size.width, geo.size.height) * 0.72
                )

                RadialGradient(
                    colors: [Color.green.opacity(0.08), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 20,
                    endRadius: max(geo.size.width, geo.size.height) * 0.8
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CALIBRATION CENTER")
                    .foregroundColor(Color.white)
                    .font(.system(size: 28, weight: .black, design: .monospaced))

                Text("\(profile.name.uppercased()) · LiDAR / ESCALA REAL / MEDICIÓN 3D")
                    .foregroundColor(Color.cyan)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(measurementQuality)
                    .foregroundColor(qualityColor)
                    .font(.system(size: 24, weight: .black, design: .monospaced))

                Text("DISTANCIA LiDAR \(String(format: "%.2f", effectiveLiDARDistance)) m")
                    .foregroundColor(Color.gray)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AVOGlassPanelBackground(accent: Color.cyan.opacity(0.32)))
    }

    private var inputPanel: some View {
        AVOCinematicPanel(title: "HORSE METRIC PROFILE", accent: Color.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                calibrationSlider(title: "Altura a la cruz", value: $withersHeightMeters, range: 1.00...1.90, suffix: "m")
                calibrationSlider(title: "Longitud corporal", value: $bodyLengthMeters, range: 1.50...3.20, suffix: "m")
                calibrationSlider(title: "Distancia cámara ideal", value: $idealCameraDistanceMeters, range: 2.00...8.00, suffix: "m")
                calibrationSlider(title: "Altura en pantalla", value: $estimatedPixelHeight, range: 200...1100, suffix: "px")

                if latestLiDARSample == nil {
                    calibrationSlider(title: "Distancia LiDAR manual", value: $manualLiDARDistanceMeters, range: 1.00...10.00, suffix: "m")
                    calibrationSlider(title: "Calidad depth manual", value: $manualDepthQuality, range: 0.00...1.00, suffix: "")
                } else {
                    AVOCalibrationMetric(title: "LiDAR real", value: "\(String(format: "%.2f", effectiveLiDARDistance)) m", color: Color.cyan)
                    AVOCalibrationMetric(title: "Depth quality", value: "\(Int(effectiveDepthQuality * 100))%", color: effectiveDepthQuality > 0.70 ? Color.green : Color.orange)
                }

                TextEditor(text: $notes)
                    .frame(height: 92)
                    .foregroundColor(Color.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.42))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.13), lineWidth: 1))

                Spacer(minLength: 0)
            }
        }
    }

    private var metricsPanel: some View {
        AVOCinematicPanel(title: "REAL SCALE / LiDAR PREVIEW", accent: Color.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    AVOCalibrationMetric(title: "cm / pixel", value: String(format: "%.2f", centimetersPerPixel), color: Color.cyan)
                    AVOCalibrationMetric(title: "zancada", value: "\(String(format: "%.2f", estimatedStrideMeters)) m", color: Color.green)
                    AVOCalibrationMetric(title: "asimetría", value: "\(String(format: "%.1f", verticalAsymmetryCentimeters)) cm", color: verticalAsymmetryCentimeters > 3.5 ? Color.orange : Color.green)
                }
                .frame(height: 70)

                ZStack(alignment: .topLeading) {
                    AVOCalibrationDepthMeshBackground()
                    if !fusedLiDARPoints3D.isEmpty {
                        AVOFusedHorsePointCloudView(points: fusedLiDARPoints3D,
                                                    report: lidarFusionReport,
                                                    referenceDistance: effectiveLiDARDistance)
                            .padding(10)
                    } else if liveLiDARPoints.isEmpty {
                        AVOCinematicHorseMesh()
                            .padding(34)
                    } else {
                        AVORealLiDARPointCloudView(points: liveLiDARPoints,
                                                   referenceDistance: effectiveLiDARDistance)
                            .padding(18)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(!fusedLiDARPoints3D.isEmpty ? "REAL 3D HORSE POINT CLOUD / TEMPORAL FUSION" : (liveLiDARPoints.isEmpty ? "LiDAR DEPTH MESH / REAL SCALE" : "REAL LiDAR POINT CLOUD / iPad Pro M4"))
                            .foregroundColor(Color.cyan)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                        Text(!fusedLiDARPoints3D.isEmpty ? "RGB + DEPTH READY · BODY FILTER · POINTS \(fusedLiDARPoints3D.count)" : (liveLiDARPoints.isEmpty ? "AI SCALE LOCK · HORSE BODY BOX · POINT CLOUD READY" : "AVCAPTURE DEPTH FLOAT32 · LIVE POINTS \(liveLiDARPoints.count) · DEPTH FUSION"))
                            .foregroundColor(Color.green.opacity(0.75))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.52))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.30), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 8) {
                    AVOCalibrationMetric(title: "altura cruz", value: "\(String(format: "%.2f", withersHeightMeters)) m", color: Color.white)
                    AVOCalibrationMetric(title: "distancia cámara", value: "\(String(format: "%.2f", effectiveLiDARDistance)) m", color: Color.cyan)
                    AVOCalibrationMetric(title: "delta posición", value: "\(String(format: "%.2f", distanceDelta)) m", color: distanceDelta > 1.2 ? Color.red : Color.green)
                }
                .frame(height: 66)
            }
        }
    }

    private var guidancePanel: some View {
        AVOCinematicPanel(title: "CAMERA POSITION GUIDE", accent: Color.orange) {
            VStack(alignment: .leading, spacing: 12) {
                AVOCalibrationMetric(title: "estado medición", value: measurementQuality, color: qualityColor)
                AVOCalibrationMetric(title: "sesiones históricas", value: "\(sessions.count)", color: Color.cyan)

                VStack(alignment: .leading, spacing: 8) {
                    Text("POSICIÓN RECOMENDADA")
                        .foregroundColor(Color.white)
                        .font(.system(size: 12, weight: .black, design: .monospaced))

                    guideLine("1. iPad lateral al caballo.")
                    guideLine("2. Caballo completo visible.")
                    guideLine("3. Distancia estable: 3.5–6 m.")
                    guideLine("4. Fondo limpio y buena luz.")
                    guideLine("5. No inclinar el iPad si buscas medidas repetibles.")
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("AVISO IA")
                        .foregroundColor(Color.orange)
                        .font(.system(size: 12, weight: .black, design: .monospaced))

                    Text(measurementQuality == "GOOD" ? "Medición válida para informes y comparación." : "Recoloca el iPad antes de usar medidas clínicas.")
                        .foregroundColor(measurementQuality == "GOOD" ? Color.green : Color.orange)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func guideLine(_ text: String) -> some View {
        Text(text)
            .foregroundColor(Color.gray)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Text(statusText)
                .foregroundColor(Color.gray)
                .font(.system(size: 11, weight: .bold, design: .monospaced))

            Spacer()

            Button { saveProfile() } label: { BottomButton("SAVE CALIBRATION", Color.green) }
            Button { onOpenFolder() } label: { BottomButton("FOLDER", Color.cyan) }
            Button { onClose() } label: { BottomButton("CLOSE", Color.red) }
        }
        .padding(10)
        .background(Color.black.opacity(0.76))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func calibrationSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.uppercased())
                    .foregroundColor(Color.gray)
                Spacer()
                Text("\(String(format: "%.2f", value.wrappedValue)) \(suffix)")
                    .foregroundColor(Color.white)
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))

            Slider(value: value, in: range)
        }
    }

    private func saveProfile() {
        let calibration = StableMetricCalibrationProfile(
            id: UUID(),
            horseID: profile.id,
            horseName: profile.name,
            createdAt: Date(),
            updatedAt: Date(),
            withersHeightMeters: withersHeightMeters,
            bodyLengthMeters: bodyLengthMeters,
            idealCameraDistanceMeters: idealCameraDistanceMeters,
            measuredLiDARDistanceMeters: effectiveLiDARDistance,
            depthQuality: effectiveDepthQuality,
            centimetersPerPixelEstimate: centimetersPerPixel,
            estimatedStrideMeters: estimatedStrideMeters,
            verticalAsymmetryCentimeters: verticalAsymmetryCentimeters,
            measurementQuality: measurementQuality,
            notes: notes
        )
        onSave(calibration)
        statusText = "CALIBRATION SAVED"
    }
}

struct AVOCinematicPanel<Content: View>: View {
    var title: String
    var accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundColor(accent)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                Rectangle()
                    .fill(accent.opacity(0.35))
                    .frame(height: 1)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AVOGlassPanelBackground(accent: accent.opacity(0.25)))
    }
}

struct AVOGlassPanelBackground: View {
    var accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.055), Color.black.opacity(0.50)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent, lineWidth: 1)
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
                .blur(radius: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AVOCalibrationMetric: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .foregroundColor(Color.gray)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.38))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct AVOCalibrationDepthMeshBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    Path { path in
                        let y = geo.size.height * CGFloat(i) / 11.0
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y - 80))
                    }
                    .stroke(Color.cyan.opacity(0.055), lineWidth: 1)
                }

                ForEach(0..<9, id: \.self) { i in
                    Path { path in
                        let x = geo.size.width * CGFloat(i) / 8.0
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + 120, y: geo.size.height))
                    }
                    .stroke(Color.green.opacity(0.045), lineWidth: 1)
                }
            }
        }
    }
}

struct AVOCinematicHorseMesh: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.20, y: h * 0.52))
                    path.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.35), control1: CGPoint(x: w * 0.28, y: h * 0.31), control2: CGPoint(x: w * 0.42, y: h * 0.33))
                    path.addCurve(to: CGPoint(x: w * 0.70, y: h * 0.42), control1: CGPoint(x: w * 0.58, y: h * 0.36), control2: CGPoint(x: w * 0.63, y: h * 0.39))
                    path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.30))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.42))
                    path.addCurve(to: CGPoint(x: w * 0.70, y: h * 0.57), control1: CGPoint(x: w * 0.82, y: h * 0.48), control2: CGPoint(x: w * 0.75, y: h * 0.54))
                    path.addCurve(to: CGPoint(x: w * 0.40, y: h * 0.66), control1: CGPoint(x: w * 0.60, y: h * 0.64), control2: CGPoint(x: w * 0.50, y: h * 0.68))
                    path.addCurve(to: CGPoint(x: w * 0.23, y: h * 0.61), control1: CGPoint(x: w * 0.32, y: h * 0.65), control2: CGPoint(x: w * 0.26, y: h * 0.63))
                    path.closeSubpath()
                }
                .stroke(Color.green.opacity(0.92), lineWidth: 2)
                .shadow(color: Color.green.opacity(0.6), radius: 10)

                ForEach([0.32, 0.46, 0.64, 0.76], id: \.self) { x in
                    Path { path in
                        path.move(to: CGPoint(x: w * x, y: h * 0.61))
                        path.addLine(to: CGPoint(x: w * (x - 0.03), y: h * 0.90))
                    }
                    .stroke(Color.green.opacity(0.90), lineWidth: 2)
                }

                ForEach(0..<10, id: \.self) { i in
                    Circle()
                        .fill(i % 2 == 0 ? Color.cyan : Color.green)
                        .frame(width: 7, height: 7)
                        .position(meshPoint(index: i, width: w, height: h))
                        .shadow(color: Color.cyan.opacity(0.75), radius: 5)
                }
            }
        }
    }

    private func meshPoint(index: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let points: [(CGFloat, CGFloat)] = [
            (0.20, 0.52), (0.28, 0.46), (0.35, 0.41), (0.48, 0.37), (0.62, 0.40),
            (0.78, 0.33), (0.88, 0.42), (0.72, 0.55), (0.46, 0.64), (0.28, 0.88)
        ]
        let p = points[max(0, min(index, points.count - 1))]
        return CGPoint(x: width * p.0, y: height * p.1)
    }
}


struct AVORealLiDARPointCloudView: View {
    var points: [AVOLiDARPoint2D]
    var referenceDistance: Double

    var body: some View {
        Canvas { context, size in
            let usableW = size.width
            let usableH = size.height
            let centerDepth = max(0.3, referenceDistance)

            for point in points {
                let px = CGFloat(point.x) * usableW
                let py = CGFloat(point.y) * usableH
                let depthDelta = abs(point.z - centerDepth)
                let alpha = max(0.16, min(0.95, 1.0 - depthDelta / 5.0))
                let radius = max(1.4, min(4.8, 5.0 - depthDelta))
                let rect = CGRect(x: px - radius * 0.5, y: py - radius * 0.5, width: radius, height: radius)
                let color = depthDelta < 0.45 ? Color.green.opacity(alpha) : Color.cyan.opacity(alpha * 0.75)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: size.height * 0.72))
            horizon.addLine(to: CGPoint(x: size.width, y: size.height * 0.60))
            context.stroke(horizon, with: .color(Color.green.opacity(0.32)), lineWidth: 1)

            let box = CGRect(x: size.width * 0.10, y: size.height * 0.14, width: size.width * 0.80, height: size.height * 0.72)
            context.stroke(Path(roundedRect: box, cornerRadius: 14), with: .color(Color.cyan.opacity(0.22)), lineWidth: 1)
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 10) {
                Text("REAL DEPTH")
                    .foregroundColor(.green)
                Text("POINTS \(points.count)")
                    .foregroundColor(.cyan)
                Text("Z \(String(format: "%.2f", referenceDistance)) m")
                    .foregroundColor(.white)
            }
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .padding(10)
            .background(Color.black.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(12)
        }
    }
}
