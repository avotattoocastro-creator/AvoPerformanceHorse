import SwiftUI
import Foundation

// MARK: - AVO Gait Cycle Analyzer

struct AVOGaitCycleReport: Identifiable, Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var analyzedSessionID: UUID?
    var analyzedSessionTitle: String
    var gaitMode: String
    var cyclesDetected: Int
    var cadenceSPM: Double
    var estimatedStrideLengthM: Double
    var regularityScore: Double
    var leftRightSymmetry: Double
    var supportBalanceFront: Double
    var supportBalanceHind: Double
    var aerialPhaseScore: Double
    var irregularityRisk: Double
    var mainAlert: String
    var recommendations: [String]
}

struct AVOGaitCycleAnalyzerEngine {
    static func analyze(profile: StableHorseProfile, session: StableSessionListItem?) -> AVOGaitCycleReport {
        let quality = clamp(session?.avgQuality ?? 0.72)
        let risk = clamp(session?.avgRisk ?? 0.18)
        let fatigue = clamp(session?.avgFatigue ?? 0.20)
        let duration = max(20.0, session?.durationSeconds ?? 90.0)
        let samples = max(1, session?.samplesCount ?? 60)

        let gaitMode: String
        if duration < 45 || samples < 35 {
            gaitMode = "WALK / SHORT SAMPLE"
        } else if fatigue > 0.55 || risk > 0.48 {
            gaitMode = "TROT / IRREGULAR"
        } else if quality > 0.78 && risk < 0.25 {
            gaitMode = "TROT / STABLE"
        } else {
            gaitMode = "MIXED GAIT"
        }

        let cadence = clampRange(72.0 + quality * 32.0 - fatigue * 18.0 + Double(samples % 11), min: 45.0, max: 135.0)
        let cycles = max(1, Int((duration / 60.0) * cadence / 2.0))
        let stride = clampRange(2.15 + quality * 0.95 - fatigue * 0.35 - risk * 0.22, min: 1.30, max: 4.20)
        let regularity = clamp(quality * 0.72 + (1.0 - risk) * 0.18 + (1.0 - fatigue) * 0.10)
        let symmetry = clamp(quality * 0.64 + (1.0 - risk) * 0.24 + (1.0 - fatigue) * 0.12)
        let frontBalance = clamp(0.50 + (risk - fatigue) * 0.10)
        let hindBalance = clamp(0.50 + (fatigue - risk) * 0.08)
        let aerial = clamp(quality * 0.55 + (1.0 - fatigue) * 0.30 + (1.0 - risk) * 0.15)
        let irregularity = clamp(risk * 0.58 + fatigue * 0.28 + (1.0 - quality) * 0.14)

        let alert: String
        if irregularity > 0.62 {
            alert = "HIGH IRREGULARITY - REVIEW LIMB SUPPORT AND VET HISTORY"
        } else if symmetry < 0.68 {
            alert = "SYMMETRY WARNING - COMPARE LEFT / RIGHT SUPPORT"
        } else if fatigue > 0.55 {
            alert = "FATIGUE TREND - REDUCE LOAD OR RECHECK NEXT SESSION"
        } else {
            alert = "GAIT STABLE - CONTINUE MONITORING"
        }

        let recommendations = makeRecommendations(irregularity: irregularity, symmetry: symmetry, fatigue: fatigue, quality: quality)

        return AVOGaitCycleReport(
            id: UUID(),
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: Date(),
            analyzedSessionID: session?.id,
            analyzedSessionTitle: session?.title ?? "No specific session selected",
            gaitMode: gaitMode,
            cyclesDetected: cycles,
            cadenceSPM: cadence,
            estimatedStrideLengthM: stride,
            regularityScore: regularity,
            leftRightSymmetry: symmetry,
            supportBalanceFront: frontBalance,
            supportBalanceHind: hindBalance,
            aerialPhaseScore: aerial,
            irregularityRisk: irregularity,
            mainAlert: alert,
            recommendations: recommendations
        )
    }

    private static func makeRecommendations(irregularity: Double, symmetry: Double, fatigue: Double, quality: Double) -> [String] {
        var output: [String] = []
        if irregularity > 0.62 { output.append("Revisar apoyos por extremidad y comparar con la sesión anterior.") }
        if symmetry < 0.70 { output.append("Marcar la sesión para comparación A/B y revisión veterinaria si se repite.") }
        if fatigue > 0.55 { output.append("Reducir carga de trabajo y repetir medición con misma distancia de cámara.") }
        if quality < 0.65 { output.append("Repetir grabación con mejor encuadre, iluminación y distancia LiDAR estable.") }
        if output.isEmpty { output.append("Patrón de marcha estable. Mantener seguimiento longitudinal.") }
        output.append("Guardar este gait_report.json junto a la sesión para entrenamiento IA futuro.")
        return output
    }

    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private static func clampRange(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        min(maxValue, max(minValue, value))
    }
}

extension AVOStableStore {
    func exportGaitCycleReport(_ report: AVOGaitCycleReport) {
        guard let root = rootFolderURL,
              let selectedID = selectedHorseID,
              let item = horsesIndex.first(where: { $0.id == selectedID }) else {
            status = "NO HORSE SELECTED"
            return
        }

        let horseFolder = root.appendingPathComponent("Horses").appendingPathComponent(item.folderName)
        let gaitFolder = horseFolder.appendingPathComponent("GaitAnalysis")
        try? FileManager.default.createDirectory(at: gaitFolder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: report.generatedAt)

        do {
            let jsonURL = gaitFolder.appendingPathComponent("gait_report_\(stamp).json")
            try JSONEncoder.avo.encode(report).write(to: jsonURL, options: [.atomic])

            let textURL = gaitFolder.appendingPathComponent("gait_report_\(stamp).txt")
            try makeGaitText(report).data(using: String.Encoding.utf8)?.write(to: textURL, options: [.atomic])

            status = "GAIT REPORT EXPORTED"
        } catch {
            status = "GAIT EXPORT ERROR"
        }
    }

    private func makeGaitText(_ report: AVOGaitCycleReport) -> String {
        var lines: [String] = []
        lines.append("AVO PERFORMANCE HORSE - GAIT CYCLE REPORT")
        lines.append("Horse: \(report.horseName)")
        lines.append("Session: \(report.analyzedSessionTitle)")
        lines.append("Gait mode: \(report.gaitMode)")
        lines.append("Cycles detected: \(report.cyclesDetected)")
        lines.append(String(format: "Cadence: %.1f spm", report.cadenceSPM))
        lines.append(String(format: "Estimated stride: %.2f m", report.estimatedStrideLengthM))
        lines.append(String(format: "Regularity: %.0f%%", report.regularityScore * 100.0))
        lines.append(String(format: "Left/right symmetry: %.0f%%", report.leftRightSymmetry * 100.0))
        lines.append(String(format: "Irregularity risk: %.0f%%", report.irregularityRisk * 100.0))
        lines.append("Alert: \(report.mainAlert)")
        lines.append("")
        lines.append("Recommendations:")
        for item in report.recommendations { lines.append("- \(item)") }
        return lines.joined(separator: "\n")
    }
}

struct AVOGaitCycleAnalyzerPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var onClose: () -> Void
    var onExport: (AVOGaitCycleReport) -> Void
    var onOpenFolder: () -> Void

    @State private var selectedSessionID: UUID?
    @State private var currentReport: AVOGaitCycleReport?

    private var selectedSession: StableSessionListItem? {
        if let id = selectedSessionID {
            return sessions.first(where: { $0.id == id })
        }
        return sessions.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                header
                HStack(spacing: 10) {
                    sessionList.frame(width: 280)
                    analysisPanel.frame(maxWidth: .infinity, maxHeight: .infinity)
                    recommendationPanel.frame(width: 300)
                }
                footer
            }
            .padding(12)
        }
        .onAppear {
            if selectedSessionID == nil { selectedSessionID = sessions.first?.id }
            runAnalysis()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("GAIT CYCLE ANALYZER")
                    .foregroundColor(.white)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                Text("\(profile.name.uppercased()) · apoyos · cadencia · zancada · simetría · irregularidad")
                    .foregroundColor(.cyan)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            Spacer()
            Text(currentReport?.mainAlert ?? "READY")
                .foregroundColor((currentReport?.irregularityRisk ?? 0) > 0.55 ? .orange : .green)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var sessionList: some View {
        ProBox("SESSIONS") {
            ScrollView {
                VStack(spacing: 7) {
                    if sessions.isEmpty {
                        Text("NO SESSIONS SAVED")
                            .foregroundColor(.orange)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    ForEach(sessions) { session in
                        Button {
                            selectedSessionID = session.id
                            runAnalysis(for: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .foregroundColor(.white)
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .lineLimit(1)
                                Text(shortDate(session.date))
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                Text("Q \(Int(session.avgQuality * 100))% · RISK \(Int(session.avgRisk * 100))% · FAT \(Int(session.avgFatigue * 100))%")
                                    .foregroundColor(.green)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedSessionID == session.id ? Color.green.opacity(0.25) : Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var analysisPanel: some View {
        ProBox("GAIT ANALYSIS") {
            VStack(spacing: 10) {
                if let report = currentReport {
                    HStack(spacing: 10) {
                        metricCard("GAIT", report.gaitMode, .cyan)
                        metricCard("CYCLES", "\(report.cyclesDetected)", .green)
                        metricCard("CADENCE", String(format: "%.1f spm", report.cadenceSPM), .orange)
                        metricCard("STRIDE", String(format: "%.2f m", report.estimatedStrideLengthM), .purple)
                    }

                    HStack(spacing: 10) {
                        VStack(spacing: 10) {
                            StableMetricBar(title: "REGULARITY", value: report.regularityScore, color: .green)
                            StableMetricBar(title: "LEFT / RIGHT SYMMETRY", value: report.leftRightSymmetry, color: .cyan)
                            StableMetricBar(title: "AERIAL PHASE", value: report.aerialPhaseScore, color: .purple)
                            StableMetricBar(title: "IRREGULARITY RISK", value: report.irregularityRisk, color: report.irregularityRisk > 0.55 ? .orange : .green)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("SUPPORT BALANCE")
                                .foregroundColor(.white)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                            MiniText(name: "FRONT", value: String(format: "%.0f / %.0f", report.supportBalanceFront * 100.0, (1.0 - report.supportBalanceFront) * 100.0), color: .cyan)
                            MiniText(name: "HIND", value: String(format: "%.0f / %.0f", report.supportBalanceHind * 100.0, (1.0 - report.supportBalanceHind) * 100.0), color: .green)
                            MiniText(name: "SESSION", value: report.analyzedSessionTitle, color: .orange)
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Text(report.mainAlert)
                        .foregroundColor(report.irregularityRisk > 0.55 ? .orange : .green)
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("Select a session and run gait analysis")
                        .foregroundColor(.orange)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var recommendationPanel: some View {
        ProBox("RECOMMENDATIONS") {
            VStack(alignment: .leading, spacing: 8) {
                if let report = currentReport {
                    ForEach(Array(report.recommendations.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .foregroundColor(.white.opacity(0.88))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                    Button { onExport(report) } label: { BottomButton("EXPORT GAIT REPORT", .green) }
                } else {
                    Text("No analysis yet")
                        .foregroundColor(.gray)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { runAnalysis() } label: { BottomButton("RUN GAIT ANALYSIS", .orange) }
            Button { if let report = currentReport { onExport(report) } } label: { BottomButton("EXPORT", .green) }
            Button { onOpenFolder() } label: { BottomButton("OPEN FOLDER", .cyan) }
            Spacer()
            Button { onClose() } label: { BottomButton("CLOSE", .red) }
        }
    }

    private func metricCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func runAnalysis() {
        runAnalysis(for: selectedSession)
    }

    private func runAnalysis(for session: StableSessionListItem?) {
        currentReport = AVOGaitCycleAnalyzerEngine.analyze(profile: profile, session: session)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
