import SwiftUI

// MARK: - REVIEW PRO PHASE 104
// BIOMECH CHARTS PANEL
//
// Functional SwiftUI panel for biomech curves without requiring Charts framework.
// Shows symmetry/risk time-series and angle samples.

public struct ReviewProBiomechChartsPanel: View {

    public var reports: [ReviewProBiomechFrameReport]

    public init(reports: [ReviewProBiomechFrameReport]) {
        self.reports = reports
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BIOMECH CURVES")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            ReviewProMiniCurveView(
                title: "SYMMETRY",
                values: reports.map(\.symmetryScore)
            )

            ReviewProMiniCurveView(
                title: "LOCOMOTION RISK",
                values: reports.map(\.locomotionRisk)
            )

            if let angleName = firstAngleName {
                ReviewProMiniCurveView(
                    title: angleName.uppercased(),
                    values: angleValues(named: angleName)
                )
            }

            summaryTable
        }
        .padding(12)
        .background(Color(white: 0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var firstAngleName: String? {
        reports.flatMap(\.angles).first?.name
    }

    private func angleValues(named name: String) -> [Double] {
        reports.compactMap { report in
            report.angles.first(where: { $0.name == name })?.degrees
        }
    }

    private var summaryTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SUMMARY")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            Text("Frames: \(reports.count)")
            Text("Avg Symmetry: \(String(format: "%.3f", avg(reports.map(\.symmetryScore))))")
            Text("Avg Risk: \(String(format: "%.3f", avg(reports.map(\.locomotionRisk))))")
            Text("High Risk Frames: \(reports.filter { $0.locomotionRisk > 0.65 }.count)")
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.white.opacity(0.7))
    }

    private func avg(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

public struct ReviewProMiniCurveView: View {

    public var title: String
    public var values: [Double]

    public init(title: String, values: [Double]) {
        self.title = title
        self.values = values
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.35))

                    Path { path in
                        guard values.count > 1 else { return }

                        let minV = values.min() ?? 0
                        let maxV = values.max() ?? 1
                        let range = max(0.0001, maxV - minV)

                        for i in values.indices {
                            let x = CGFloat(i) / CGFloat(max(1, values.count - 1)) * geo.size.width
                            let normalized = (values[i] - minV) / range
                            let y = geo.size.height - CGFloat(normalized) * geo.size.height

                            if i == values.startIndex {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.cyan, lineWidth: 2)
                }
            }
            .frame(height: 54)
        }
    }
}
