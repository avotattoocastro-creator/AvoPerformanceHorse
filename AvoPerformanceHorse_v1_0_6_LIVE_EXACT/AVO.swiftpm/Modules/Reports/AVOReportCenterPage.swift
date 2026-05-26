import SwiftUI
import UIKit

struct AVOReportCenterPage: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var camera: CameraManager
    @ObservedObject var store: SessionStore
    @ObservedObject var profiles: ProfileStore
    @ObservedObject var stableStore: AVOStableStore
    @ObservedObject var pdfManager: PDFReportManager

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.006, green: 0.010, blue: 0.012).ignoresSafeArea()
                VStack(spacing: 10) {
                    topBar
                    reportHero
                        .frame(height: 118)
                    HStack(spacing: 10) {
                        liveReportPanel
                        stableHistoryPanel
                    }
                    .frame(maxHeight: .infinity)
                    bottomActions
                }
                .padding(14)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("REPORT CENTER")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)
                Text("Cliente · Veterinario · Sesión · Histórico · IA")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.56))
            }

            Spacer()

            Text(stableStore.selectedHorseName.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Color.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.35), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(height: 44)
    }

    private var reportHero: some View {
        HStack(spacing: 10) {
            metricBox("LIVE SAMPLES", "\(camera.sessionSamples.count)", .green)
            metricBox("SAVED SESSIONS", "\(stableStore.selectedSessions.count)", .cyan)
            metricBox("AVG QUALITY", percent(avgQuality), .green)
            metricBox("AVG RISK", percent(avgRisk), avgRisk >= 0.55 ? .red : .orange)
            metricBox("ALERTS", alertText, alertColor)
        }
    }

    private var liveReportPanel: some View {
        AVOPremiumPanel("Live report package", accent: .green) {
            VStack(alignment: .leading, spacing: 9) {
                AVODenseValue(name: "Horse", value: activeHorseName, color: .green)
                AVODenseValue(name: "Rider", value: profiles.riderName.isEmpty ? "NO RIDER" : profiles.riderName, color: .cyan)
                AVODenseValue(name: "Tracking", value: camera.trackingText, color: .green)
                AVODenseValue(name: "Quality", value: percent(Double(camera.quality)), color: .green)
                AVODenseValue(name: "Risk", value: percent(Double(camera.risk)), color: Double(camera.risk) > 0.55 ? .red : .orange)
                AVODenseValue(name: "Fatigue", value: percent(Double(camera.fatigue)), color: .orange)
                Divider().background(Color.white.opacity(0.18))
                Text("Genera el informe de la sesión live sin depender de DashboardView. Esta página usa directamente CameraManager, StableStore y PDFReportManager.")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack(spacing: 8) {
                    Button { saveLiveJSON() } label: { BottomButton("SAVE JSON", .green) }
                    Button { createLivePDF() } label: { BottomButton("CREATE PDF", .orange) }
                }
            }
        }
    }

    private var stableHistoryPanel: some View {
        AVOPremiumPanel("Finished training reports", accent: .orange) {
            VStack(spacing: 8) {
                AVOTableHeader(columns: ["Fecha", "Caballo", "Tipo", "Calidad", "Riesgo", "Fatiga", "AI", "Vídeo"])
                if stableStore.selectedSessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(stableStore.selectedSessions.prefix(16)) { session in
                                AVOTableRow(values: [
                                    shortDate(session.date),
                                    stableStore.selectedHorseName,
                                    session.title,
                                    percent(session.avgQuality),
                                    percent(session.avgRisk),
                                    percent(session.avgFatigue),
                                    session.aiSummaryRelativePath == nil ? "--" : "✓",
                                    session.videoRelativePath == nil ? "--" : "✓"
                                ], color: session.avgRisk >= 0.60 ? .red : .green)
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button { stableStore.loadIndex() } label: { BottomButton("REFRESH", .cyan) }
                    Button { stableStore.exportPerformanceDashboardReport() } label: { BottomButton("EXPORT STABLE", .green) }
                    Spacer()
                    Text(stableStore.status)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.88))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Color.orange)
            Text("NO FINISHED TRAINING REPORTS")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white)
            Text("Guarda una sesión desde Biotech/Dashboard para generar histórico real del caballo.")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.58))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var bottomActions: some View {
        HStack(spacing: 8) {
            Text("INDEPENDENT REPORT MODULE · NOT DASHBOARDVIEW")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.52))
            Spacer()
            Button { stableStore.exportPerformanceDashboardReport() } label: { BottomButton("EXPORT JSON/TXT", .cyan) }
            Button { createLivePDF() } label: { BottomButton("PDF CLIENT", .orange) }
        }
        .frame(height: 44)
    }

    private func metricBox(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.58))
            Text(value)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.36))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.36), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveLiveJSON() {
        store.saveSession(samples: camera.sessionSamples)
        stableStore.saveLiveSession(samples: camera.sessionSamples, horseNameFallback: profiles.horseName, riderName: profiles.riderName, lidarSamples: camera.lidarSamples)
    }

    private func createLivePDF() {
        pdfManager.createPDF(horse: activeHorseName, rider: profiles.riderName, samples: camera.sessionSamples, snapshot: nil, mapSnapshot: nil)
    }

    private var activeHorseName: String {
        if stableStore.selectedHorseName != "NO HORSE" { return stableStore.selectedHorseName }
        return profiles.horseName.isEmpty ? "NO HORSE" : profiles.horseName
    }

    private var avgQuality: Double { stableStore.selectedSessions.map { $0.avgQuality }.avoAverage }
    private var avgRisk: Double { stableStore.selectedSessions.map { $0.avgRisk }.avoAverage }
    private var avgFatigue: Double { stableStore.selectedSessions.map { $0.avgFatigue }.avoAverage }

    private var alertText: String {
        if avgRisk >= 0.70 { return "HIGH" }
        if avgRisk >= 0.40 || avgFatigue >= 0.60 { return "WATCH" }
        return "OK"
    }

    private var alertColor: Color {
        if avgRisk >= 0.70 { return .red }
        if avgRisk >= 0.40 || avgFatigue >= 0.60 { return .orange }
        return .green
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value.isFinite ? value : 0) * 100))%"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
}

private extension Array where Element == Double {
    var avoAverage: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
