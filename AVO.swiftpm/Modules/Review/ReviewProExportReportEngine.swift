import Foundation
import UIKit
import PDFKit

// MARK: - REVIEW PRO PHASE 102
// EXPORT REPORT ENGINE
//
// Additive module.
// Purpose:
// - Export biomech CSV.
// - Export timeline JSON.
// - Create basic professional PDF report.
// - Does not replace existing report systems.

public final class ReviewProExportReportEngine {

    public init() {}

    public func writeCSV(_ csv: String, to url: URL) throws {
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    public func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
    }

    public func makeBiomechPDF(title: String,
                               subtitle: String,
                               reports: [ReviewProBiomechFrameReport]) -> PDFDocument {
        let pdf = PDFDocument()
        let page = makeSummaryPage(title: title, subtitle: subtitle, reports: reports)
        if let pdfPage = PDFPage(image: page) {
            pdf.insert(pdfPage, at: 0)
        }
        return pdf
    }

    private func makeSummaryPage(title: String,
                                 subtitle: String,
                                 reports: [ReviewProBiomechFrameReport]) -> UIImage {
        let size = CGSize(width: 1240, height: 1754)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white
            ]

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26),
                .foregroundColor: UIColor.lightGray
            ]

            title.draw(at: CGPoint(x: 70, y: 70), withAttributes: titleAttrs)
            subtitle.draw(at: CGPoint(x: 70, y: 135), withAttributes: subAttrs)

            let avgRisk = reports.isEmpty ? 0 : reports.map(\.locomotionRisk).reduce(0,+) / Double(reports.count)
            let avgSym = reports.isEmpty ? 0 : reports.map(\.symmetryScore).reduce(0,+) / Double(reports.count)
            let frames = reports.count

            let body = """
            REVIEW PRO BIOMECH SUMMARY

            Frames analyzed: \(frames)
            Average symmetry: \(String(format: "%.3f", avgSym))
            Average locomotion risk: \(String(format: "%.3f", avgRisk))

            Notes:
            - This report is generated from temporal pose and biomech frame reports.
            - Use with professional veterinary/sport evaluation context.
            - Phase 102 adds CSV/JSON/PDF export pipeline.
            """

            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.white
            ]

            body.draw(in: CGRect(x: 70, y: 240, width: 1100, height: 1000), withAttributes: bodyAttrs)
        }
    }
}
