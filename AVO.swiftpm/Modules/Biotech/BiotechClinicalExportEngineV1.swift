import Foundation
import PDFKit
import UIKit

// MARK: - BIOTECH PHASE 106
// Clinical Export Engine V1
//
// BIOTECH-specific report export. REVIEW export remains ML/dataset focused.

public final class BiotechClinicalExportEngineV1 {

    public init() {}

    public func csv(metrics: [BiotechBiomechFrameMetrics]) -> String {
        var rows = ["frame,time,topline,forelimb,hindlimb,symmetry,stability,risk"]

        for m in metrics {
            rows.append("\(m.frameIndex),\(m.timeSeconds),\(m.toplineAngle),\(m.forelimbAngle),\(m.hindlimbAngle),\(m.symmetry),\(m.stability),\(m.risk)")
        }

        return rows.joined(separator: "\n")
    }

    public func makePDF(title: String,
                        horseName: String,
                        metrics: [BiotechBiomechFrameMetrics]) -> PDFDocument {
        let pdf = PDFDocument()
        let img = renderPage(title: title, horseName: horseName, metrics: metrics)
        if let page = PDFPage(image: img) {
            pdf.insert(page, at: 0)
        }
        return pdf
    }

    private func renderPage(title: String,
                            horseName: String,
                            metrics: [BiotechBiomechFrameMetrics]) -> UIImage {
        let size = CGSize(width: 1240, height: 1754)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            UIColor(red: 0.035, green: 0.035, blue: 0.04, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 44),
                .foregroundColor: UIColor.white
            ]

            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.white
            ]

            title.draw(at: CGPoint(x: 70, y: 70), withAttributes: titleAttrs)

            let avgRisk = metrics.isEmpty ? 0 : metrics.map(\.risk).reduce(0, +) / Double(metrics.count)
            let avgSym = metrics.isEmpty ? 0 : metrics.map(\.symmetry).reduce(0, +) / Double(metrics.count)
            let highRisk = metrics.filter { $0.risk > 0.65 }.count

            let body = """
            HORSE: \(horseName)
            FRAMES ANALYZED: \(metrics.count)

            AVERAGE SYMMETRY: \(String(format: "%.3f", avgSym))
            AVERAGE RISK: \(String(format: "%.3f", avgRisk))
            HIGH RISK FRAMES: \(highRisk)

            BIOTECH PHASE 106
            - biomechanical studio metrics
            - temporal replay markers
            - LiDAR/depth fusion ready
            - clinical export pipeline
            """

            body.draw(in: CGRect(x: 70, y: 170, width: 1100, height: 900), withAttributes: bodyAttrs)
        }
    }
}
