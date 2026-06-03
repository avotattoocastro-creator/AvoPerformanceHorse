import SwiftUI
import Foundation

// MARK: - AVO Lameness Early Warning System

struct AVOLamenessReport: Identifiable, Codable, Hashable {
    var id: UUID
    var horseID: UUID
    var horseName: String
    var generatedAt: Date
    var sessionsAnalyzed: Int
    var vetRecordsAnalyzed: Int
    var baselineSessionTitle: String
    var latestSessionTitle: String
    var alertLevel: String
    var suspectedZone: String
    var lamenessRisk: Double
    var verticalAsymmetryScore: Double
    var impactImbalanceScore: Double
    var rhythmLossScore: Double
    var trendWorseningScore: Double
    var clinicalCorrelationScore: Double
    var explanation: String
    var recommendations: [String]
}

struct AVOLamenessMonitorEngine {
    static func analyze(profile: StableHorseProfile, sessions: [StableSessionListItem], vetRecords: [StableVetRecordListItem], aiReport: StableAIAnalysisReport?) -> AVOLamenessReport {
        let sortedSessions = sessions.sorted { $0.date < $1.date }
        let baseline = sortedSessions.first
        let latest = sortedSessions.last
        let recent = Array(sortedSessions.suffix(5))

        let baselineRisk = baseline?.avgRisk ?? 0.18
        let latestRisk = latest?.avgRisk ?? baselineRisk
        let baselineQuality = baseline?.avgQuality ?? 0.74
        let latestQuality = latest?.avgQuality ?? baselineQuality
        let latestFatigue = latest?.avgFatigue ?? 0.20

        let recentRisk = average(recent.map { $0.avgRisk }, fallback: latestRisk)
        let recentQuality = average(recent.map { $0.avgQuality }, fallback: latestQuality)
        let recentFatigue = average(recent.map { $0.avgFatigue }, fallback: latestFatigue)

        let severeVetCount = vetRecords.filter { $0.severity == .severe || $0.severity == .critical }.count
        let moderateVetCount = vetRecords.filter { $0.severity == .moderate }.count
        let vetWeight = min(1.0, Double(severeVetCount) * 0.28 + Double(moderateVetCount) * 0.12)

        let verticalAsymmetry = clamp((1.0 - latestQuality) * 0.52 + latestRisk * 0.32 + recentFatigue * 0.16)
        let impactImbalance = clamp(latestRisk * 0.55 + recentRisk * 0.25 + latestFatigue * 0.20)
        let rhythmLoss = clamp((1.0 - recentQuality) * 0.55 + recentFatigue * 0.30 + recentRisk * 0.15)
        let trendWorsening = clamp(max(0.0, latestRisk - baselineRisk) * 1.35 + max(0.0, baselineQuality - latestQuality) * 0.90)
        let clinicalCorrelation = clamp(vetWeight + (aiReport?.globalRisk ?? 0.0) * 0.30)

        let lamenessRisk = clamp(
            verticalAsymmetry * 0.25 +
            impactImbalance * 0.25 +
            rhythmLoss * 0.18 +
            trendWorsening * 0.17 +
            clinicalCorrelation * 0.15
        )

        let suspectedZone = inferZone(vetRecords: vetRecords, aiReport: aiReport, risk: lamenessRisk, fatigue: latestFatigue)
        let alertLevel: String
        if lamenessRisk >= 0.72 { alertLevel = "ALTA" }
        else if lamenessRisk >= 0.48 { alertLevel = "MODERADA" }
        else if lamenessRisk >= 0.30 { alertLevel = "VIGILAR" }
        else { alertLevel = "BAJA" }

        let explanation = makeExplanation(alertLevel: alertLevel, zone: suspectedZone, vertical: verticalAsymmetry, impact: impactImbalance, rhythm: rhythmLoss, trend: trendWorsening, clinical: clinicalCorrelation)
        let recommendations = makeRecommendations(level: alertLevel, zone: suspectedZone, risk: lamenessRisk, trend: trendWorsening, clinical: clinicalCorrelation)

        return AVOLamenessReport(
            id: UUID(),
            horseID: profile.id,
            horseName: profile.name,
            generatedAt: Date(),
            sessionsAnalyzed: sessions.count,
            vetRecordsAnalyzed: vetRecords.count,
            baselineSessionTitle: baseline?.title ?? "No baseline session",
            latestSessionTitle: latest?.title ?? "No recent session",
            alertLevel: alertLevel,
            suspectedZone: suspectedZone,
            lamenessRisk: lamenessRisk,
            verticalAsymmetryScore: verticalAsymmetry,
            impactImbalanceScore: impactImbalance,
            rhythmLossScore: rhythmLoss,
            trendWorseningScore: trendWorsening,
            clinicalCorrelationScore: clinicalCorrelation,
            explanation: explanation,
            recommendations: recommendations
        )
    }

    private static func inferZone(vetRecords: [StableVetRecordListItem], aiReport: StableAIAnalysisReport?, risk: Double, fatigue: Double) -> String {
        if let first = vetRecords.first, !first.injuryZone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return first.injuryZone
        }
        if let ai = aiReport, !ai.mainRiskZone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ai.mainRiskZone
        }
        if fatigue > 0.55 { return "Posterior / carga muscular" }
        if risk > 0.55 { return "Anterior / apoyo" }
        return "Sin zona clara - seguimiento general"
    }

    private static func makeExplanation(alertLevel: String, zone: String, vertical: Double, impact: Double, rhythm: Double, trend: Double, clinical: Double) -> String {
        var parts: [String] = []
        parts.append("Nivel \(alertLevel) en \(zone).")
        if vertical > 0.45 { parts.append("Asimetría vertical elevada.") }
        if impact > 0.45 { parts.append("Desequilibrio de impacto detectado.") }
        if rhythm > 0.45 { parts.append("Pérdida de ritmo o regularidad.") }
        if trend > 0.35 { parts.append("Empeoramiento frente a línea base.") }
        if clinical > 0.35 { parts.append("Coincidencia con historial veterinario o IA previa.") }
        if parts.count == 1 { parts.append("No hay señales fuertes, mantener baseline y seguimiento por sesiones.") }
        return parts.joined(separator: " ")
    }

    private static func makeRecommendations(level: String, zone: String, risk: Double, trend: Double, clinical: Double) -> [String] {
        var output: [String] = []
        if level == "ALTA" {
            output.append("Detener aumento de carga y solicitar revisión veterinaria de \(zone).")
            output.append("Comparar vídeo, LiDAR e impacto con la mejor sesión sana disponible.")
        } else if level == "MODERADA" {
            output.append("Reducir carga de entrenamiento y repetir medición en condiciones controladas.")
            output.append("Marcar la zona \(zone) para revisión visual y veterinaria si se repite.")
        } else if level == "VIGILAR" {
            output.append("Mantener seguimiento. Revisar tendencia en las próximas 2-3 sesiones.")
        } else {
            output.append("Sin alerta fuerte. Mantener baseline sano y continuar registro longitudinal.")
        }
        if trend > 0.35 { output.append("Crear comparación A/B con sesión baseline y última sesión.") }
        if clinical > 0.35 { output.append("Vincular registros veterinarios e imágenes médicas al análisis IA.") }
        output.append("Exportar lameness_report.json para entrenamiento IA futuro.")
        return output
    }

    private static func average(_ values: [Double], fallback: Double) -> Double {
        guard !values.isEmpty else { return fallback }
        return values.reduce(0.0, +) / Double(values.count)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

extension AVOStableStore {
    func exportLamenessReport(_ report: AVOLamenessReport) {
        guard let root = rootFolderURL,
              let selectedID = selectedHorseID,
              let item = horsesIndex.first(where: { $0.id == selectedID }) else {
            status = "NO HORSE SELECTED"
            return
        }

        let horseFolder = root.appendingPathComponent("Horses").appendingPathComponent(item.folderName)
        let aiFolder = horseFolder.appendingPathComponent("AITraining")
        try? FileManager.default.createDirectory(at: aiFolder, withIntermediateDirectories: true)

        do {
            try JSONEncoder.avo.encode(report).write(to: aiFolder.appendingPathComponent("lameness_report.json"), options: .atomic)
            try Self.makeLamenessText(report).data(using: .utf8)?.write(to: aiFolder.appendingPathComponent("lameness_report.txt"), options: .atomic)
            status = "LAMENESS REPORT EXPORTED"
        } catch {
            status = "LAMENESS EXPORT ERROR"
        }
    }

    private static func makeLamenessText(_ report: AVOLamenessReport) -> String {
        var lines: [String] = []
        lines.append("AVO PERFORMANCE HORSE - LAMENESS EARLY WARNING")
        lines.append("Horse: \(report.horseName)")
        lines.append("Generated: \(report.generatedAt)")
        lines.append("")
        lines.append("ALERT: \(report.alertLevel)")
        lines.append("Suspected zone: \(report.suspectedZone)")
        lines.append("Risk: \(Int(report.lamenessRisk * 100))%")
        lines.append("Vertical asymmetry: \(Int(report.verticalAsymmetryScore * 100))%")
        lines.append("Impact imbalance: \(Int(report.impactImbalanceScore * 100))%")
        lines.append("Rhythm loss: \(Int(report.rhythmLossScore * 100))%")
        lines.append("Trend worsening: \(Int(report.trendWorseningScore * 100))%")
        lines.append("Clinical correlation: \(Int(report.clinicalCorrelationScore * 100))%")
        lines.append("")
        lines.append("EXPLANATION")
        lines.append(report.explanation)
        lines.append("")
        lines.append("RECOMMENDATIONS")
        lines.append(contentsOf: report.recommendations)
        return lines.joined(separator: "\n")
    }
}

struct AVOLamenessMonitorPage: View {
    var profile: StableHorseProfile
    var sessions: [StableSessionListItem]
    var vetRecords: [StableVetRecordListItem]
    var aiReport: StableAIAnalysisReport?
    var onClose: () -> Void
    var onExport: (AVOLamenessReport) -> Void
    var onOpenFolder: () -> Void

    @State private var report: AVOLamenessReport?
    @State private var status = "READY"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                header
                if let report = report {
                    reportBody(report)
                } else {
                    emptyState
                }
                footer
            }
            .padding(16)
        }
        .onAppear { runAnalysis() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LAMENESS EARLY WARNING")
                    .foregroundColor(.red)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                Text(profile.name.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
            }
            Spacer()
            Button { onClose() } label: { BottomButton("CLOSE", .red) }
        }
    }

    private var emptyState: some View {
        ProBox("LAMENESS MONITOR") {
            VStack(spacing: 12) {
                Text("Analizando sesiones, baseline, impacto, fatiga, simetría e historial veterinario.")
                    .foregroundColor(.gray)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Button { runAnalysis() } label: { BottomButton("RUN LAMENESS ANALYSIS", .red) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func reportBody(_ report: AVOLamenessReport) -> some View {
        HStack(spacing: 10) {
            ProBox("ALERT SUMMARY") {
                VStack(alignment: .leading, spacing: 10) {
                    metricCard("ALERT", report.alertLevel, alertColor(report.alertLevel))
                    metricCard("ZONE", report.suspectedZone, .orange)
                    metricCard("RISK", "\(Int(report.lamenessRisk * 100))%", alertColor(report.alertLevel))
                    metricCard("BASELINE", report.baselineSessionTitle, .cyan)
                    metricCard("LATEST", report.latestSessionTitle, .green)
                }
            }
            .frame(width: 300)

            ProBox("RISK FACTORS") {
                VStack(alignment: .leading, spacing: 10) {
                    scoreLine("Vertical asymmetry", report.verticalAsymmetryScore, .red)
                    scoreLine("Impact imbalance", report.impactImbalanceScore, .orange)
                    scoreLine("Rhythm loss", report.rhythmLossScore, .yellow)
                    scoreLine("Trend worsening", report.trendWorseningScore, .purple)
                    scoreLine("Clinical correlation", report.clinicalCorrelationScore, .cyan)
                    Text(report.explanation)
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.top, 8)
                    Spacer()
                }
            }

            ProBox("RECOMMENDATIONS") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.recommendations, id: \.self) { recommendation in
                            Text("• \(recommendation)")
                                .foregroundColor(.white)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(width: 340)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            MiniText(name: "STATUS", value: status, color: .orange)
            Spacer()
            Button { runAnalysis() } label: { BottomButton("RUN AGAIN", .orange) }
            Button {
                if let report = report { onExport(report); status = "EXPORTED" }
            } label: { BottomButton("EXPORT LAMENESS REPORT", .green) }
            Button { onOpenFolder() } label: { BottomButton("OPEN FOLDER", .cyan) }
        }
    }

    private func runAnalysis() {
        report = AVOLamenessMonitorEngine.analyze(profile: profile, sessions: sessions, vetRecords: vetRecords, aiReport: aiReport)
        status = "ANALYSIS READY"
    }

    private func metricCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scoreLine(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.uppercased())
                    .foregroundColor(.white)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                Text("\(Int(value * 100))%")
                    .foregroundColor(color)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.10))
                    Rectangle().fill(color.opacity(0.85)).frame(width: max(0, geometry.size.width * CGFloat(value)))
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func alertColor(_ level: String) -> Color {
        if level == "ALTA" { return .red }
        if level == "MODERADA" { return .orange }
        if level == "VIGILAR" { return .yellow }
        return .green
    }
}
