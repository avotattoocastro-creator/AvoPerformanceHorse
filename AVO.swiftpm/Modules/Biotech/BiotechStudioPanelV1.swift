import SwiftUI

// MARK: - BIOTECH PHASE 106
// Biotech Studio Panel V1
//
// Compact professional panel for BIOTECH page.
// Keep it collapsible in your existing UI to avoid screen overload.

public struct BiotechStudioPanelV1: View {

    public var metrics: [BiotechBiomechFrameMetrics]
    public var depthReport: BiotechDepthFusionReport?

    public init(metrics: [BiotechBiomechFrameMetrics],
                depthReport: BiotechDepthFusionReport? = nil) {
        self.metrics = metrics
        self.depthReport = depthReport
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BIOTECH STUDIO")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            HStack {
                metricBox("FRAMES", "\(metrics.count)")
                metricBox("SYM", String(format: "%.2f", avg(metrics.map(\.symmetry))))
                metricBox("RISK", String(format: "%.2f", avg(metrics.map(\.risk))))
            }

            if let depthReport {
                HStack {
                    metricBox("DIST", String(format: "%.2fm", depthReport.estimatedHorseDistance))
                    metricBox("DEPTH", String(format: "%.2f", depthReport.usableDepthConfidence))
                    metricBox("SPREAD", String(format: "%.2f", depthReport.bodyDepthSpread))
                }
            }

            Text("HIGH RISK: \(metrics.filter { $0.risk > 0.65 }.count)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.orange)
        }
        .padding(12)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func metricBox(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func avg(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
