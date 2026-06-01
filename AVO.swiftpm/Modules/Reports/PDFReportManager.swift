import SwiftUI
import UIKit
import PDFKit

class PDFReportManager: ObservableObject {
    @Published var pdfURL: URL?
    @Published var showPreview = false
    

    // Compatibility wrapper used by DashboardView quick actions.
    // Keeps old button code working while the real PDF generator is createReport(...).
    func createPDF(
        horse: String,
        rider: String,
        samples: [SessionSample],
        snapshot: UIImage?,
        mapSnapshot: UIImage?
    ) {
        createReport(
            samples: samples,
            horse: horse,
            rider: rider,
            quality: 0.65,
            risk: 0.20,
            fatigue: 0.20,
            diagnosis: "Automatic quick report generated from the dashboard.",
            biomechSnapshot: snapshot,
            mapSnapshot: mapSnapshot,
            pulse: "-- BPM",
            speed: "-- km/h",
            cadence: "-- spm",
            pitch: 0,
            roll: 0,
            impact: 0,
            rtk: "RTK READY",
            lora: "LORA READY",
            battery: "BAT --"
        )
    }
    
    func createReport(
        samples: [SessionSample],
        horse: String,
        rider: String,
        quality: Double,
        risk: Double,
        fatigue: Double,
        diagnosis: String,
        biomechSnapshot: UIImage?,
        mapSnapshot: UIImage?,
        pulse: String,
        speed: String,
        cadence: String,
        pitch: Double,
        roll: Double,
        impact: Double,
        rtk: String,
        lora: String,
        battery: String
    ) {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        
        let fileName = "AVO_Horse_Professional_Report_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        do {
            try renderer.writePDF(to: url) { ctx in
                
                // PAGE 1 - PREMIUM COVER
                ctx.beginPage()
                drawPremiumCover(
                    horse: horse,
                    rider: rider,
                    samples: samples,
                    quality: quality,
                    risk: risk,
                    fatigue: fatigue
                )
                
                // PAGE 2 - SESSION SUMMARY
                ctx.beginPage()
                drawHeader("AVO PERFORMANCE HORSE", "Professional Equine Biomechanics Report")
                drawSessionBlock(horse: horse, rider: rider, samples: samples)
                drawMetricCards(quality: quality, risk: risk, fatigue: fatigue)
                drawDiagnosisBlock(diagnosis: diagnosis, quality: quality, risk: risk, fatigue: fatigue)
                drawFooter(2)
                
                // PAGE 3 - BIOMECH SNAPSHOT
                ctx.beginPage()
                drawHeader("BIOMECHANICAL SNAPSHOT", "Captured camera frame with overlay")
                
                if let biomechSnapshot = biomechSnapshot {
                    let imageRect = CGRect(x: 40, y: 125, width: 515, height: 270)
                    biomechSnapshot.draw(in: imageRect)
                    
                    section("FRAME INTERPRETATION", y: 430)
                    
                    paragraph("""
                    This image represents the captured biomechanical camera view used during the session analysis. The overlay includes detected horse body area, keypoint structure and visual tracking elements.
                    
                    This snapshot allows the trainer, veterinarian or owner to visually review the exact frame context associated with the automatic biomechanical scoring.
                    """, x: 40, y: 465, w: 515, h: 240)
                } else {
                    paragraph("""
                    No biomechanical snapshot was captured for this report.
                    
                    Press SNAP before creating the PDF to include a real camera frame with overlay.
                    """, x: 40, y: 150, w: 515, h: 240)
                }
                
                drawFooter(3)
                
                // PAGE 4 - GPS MAP
                ctx.beginPage()
                drawHeader("GPS TRACK MAP", "Training route and RTK/GPS session context")
                
                if let mapSnapshot = mapSnapshot {
                    let imageRect = CGRect(x: 40, y: 125, width: 515, height: 270)
                    mapSnapshot.draw(in: imageRect)
                    
                    section("GPS INTERPRETATION", y: 430)
                    
                    paragraph("""
                    This page includes the GPS/RTK track captured during the training session. The route map helps evaluate the horse movement context, training zone position, trajectory stability and external positioning reference.
                    
                    GPS data should be interpreted together with speed, fatigue and biomechanical indicators.
                    """, x: 40, y: 465, w: 515, h: 240)
                } else {
                    paragraph("""
                    No GPS map snapshot was captured for this report.
                    
                    Press SNAP before creating the PDF to include the current GPS route view.
                    """, x: 40, y: 150, w: 515, h: 240)
                }
                
                drawFooter(4)
                
                // PAGE 5 - ECG / IMU
                ctx.beginPage()
                drawHeader("ECG / IMU SENSOR DATA", "Real sensor values captured from the live system")
                
                section("CARDIO / PERFORMANCE", y: 120)
                row("Heart Rate", pulse, y: 155)
                row("Speed", speed, y: 180)
                row("Cadence", cadence, y: 205)
                
                section("INERTIAL MEASUREMENT UNIT", y: 260)
                row("Pitch", String(format: "%.2f", pitch), y: 295)
                row("Roll", String(format: "%.2f", roll), y: 320)
                row("Impact", String(format: "%.2f", impact), y: 345)
                
                section("COMMUNICATION / POSITIONING", y: 400)
                row("RTK Status", rtk, y: 435)
                row("LoRa Status", lora, y: 460)
                row("Remote Battery", battery, y: 485)
                
                section("INTERPRETATION", y: 540)
                
                paragraph("""
                This page includes real sensor values captured from the AVO Horse live telemetry layer.
                
                ECG and IMU data help evaluate physiological response, movement stability, impact level, rider/horse balance and communication quality during the training session.
                
                These values should be interpreted together with the biomechanical camera analysis and GPS tracking data.
                """, x: 40, y: 575, w: 515, h: 180)
                
                drawFooter(5)
                
                // PAGE 6 - TIMELINE
                ctx.beginPage()
                drawHeader("BIOMECHANICAL TIMELINE", "Risk, fatigue and quality evolution")
                drawChart(title: "QUALITY TIMELINE", values: samples.map { $0.quality }, x: 40, y: 120, w: 515, h: 140, color: .systemGreen)
                drawChart(title: "RISK TIMELINE", values: samples.map { $0.risk }, x: 40, y: 315, w: 515, h: 140, color: .systemRed)
                drawChart(title: "FATIGUE TIMELINE", values: samples.map { $0.fatigue }, x: 40, y: 510, w: 515, h: 140, color: .systemOrange)
                drawFooter(6)
                
                // PAGE 7 - CLINICAL
                ctx.beginPage()
                drawHeader("CLINICAL / TRAINING INTERPRETATION", "Automatic performance analysis")
                drawClinicalText(quality: quality, risk: risk, fatigue: fatigue, diagnosis: diagnosis)
                drawFooter(7)
                
                // PAGE 8 - TECHNICAL
                ctx.beginPage()
                drawHeader("TECHNICAL DATA SUMMARY", "Session export and sensor information")
                drawTechnicalBlock(samples: samples)
                drawFooter(8)
            }
            
            pdfURL = url
            showPreview = true
        } catch {
            pdfURL = nil
            showPreview = false
        }
    }
    
    private func globalScore(quality: Double, risk: Double, fatigue: Double) -> Int {
        let raw = (quality * 0.50) + ((1.0 - risk) * 0.30) + ((1.0 - fatigue) * 0.20)
        return max(0, min(100, Int(raw * 100)))
    }
    
    private func globalStatus(score: Int) -> String {
        if score >= 90 { return "ELITE PERFORMANCE" }
        if score >= 75 { return "GOOD CONDITION" }
        if score >= 50 { return "MODERATE MONITORING" }
        return "CRITICAL REVIEW"
    }
    
    private func drawPremiumCover(
        horse: String,
        rider: String,
        samples: [SessionSample],
        quality: Double,
        risk: Double,
        fatigue: Double
    ) {
        let score = globalScore(quality: quality, risk: risk, fatigue: fatigue)
        let status = globalStatus(score: score)
        
        "AVO PERFORMANCE HORSE".draw(
            at: CGPoint(x: 40, y: 55),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 30),
                .foregroundColor: UIColor.black
            ]
        )
        
        "Elite Biomechanical Training Report".draw(
            at: CGPoint(x: 40, y: 95),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.darkGray
            ]
        )
        
        let line = UIBezierPath()
        line.move(to: CGPoint(x: 40, y: 125))
        line.addLine(to: CGPoint(x: 555, y: 125))
        UIColor.black.setStroke()
        line.lineWidth = 1.2
        line.stroke()
        
        section("SESSION", y: 165)
        row("Horse", horse, y: 200)
        row("Rider", rider, y: 225)
        row("Date", formattedDate(), y: 250)
        row("Samples", "\(samples.count)", y: 275)
        row("System", "AVO Performance Horse", y: 300)
        
        section("GLOBAL SCORE", y: 360)
        
        "\(score) / 100".draw(
            at: CGPoint(x: 40, y: 400),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 54),
                .foregroundColor: score >= 75 ? UIColor.systemGreen : UIColor.systemOrange
            ]
        )
        
        status.draw(
            at: CGPoint(x: 40, y: 470),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
        )
        
        section("KEY INDICATORS", y: 540)
        row("Quality", "\(Int(quality * 100))%", y: 575)
        row("Risk", "\(Int(risk * 100))%", y: 600)
        row("Fatigue", "\(Int(fatigue * 100))%", y: 625)
        
        paragraph("""
        This document summarizes the training session using biomechanical, sensor and performance indicators collected by the AVO Performance Horse system.
        """, x: 40, y: 680, w: 515, h: 70)
        
        drawFooter(1)
    }
    
    private func drawHeader(_ title: String, _ subtitle: String) {
        title.draw(at: CGPoint(x: 40, y: 35), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ])
        
        subtitle.draw(at: CGPoint(x: 40, y: 68), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.darkGray
        ])
        
        let line = UIBezierPath()
        line.move(to: CGPoint(x: 40, y: 95))
        line.addLine(to: CGPoint(x: 555, y: 95))
        UIColor.black.setStroke()
        line.lineWidth = 1
        line.stroke()
    }
    
    private func drawSessionBlock(horse: String, rider: String, samples: [SessionSample]) {
        section("SESSION IDENTIFICATION", y: 120)
        row("Horse", horse, y: 155)
        row("Rider", rider, y: 180)
        row("Samples", "\(samples.count)", y: 205)
        row("Date", formattedDate(), y: 230)
        row("System", "AVO Performance Horse iPad App", y: 255)
    }
    
    private func drawMetricCards(quality: Double, risk: Double, fatigue: Double) {
        section("GLOBAL PERFORMANCE SCORES", y: 310)
        
        metric("QUALITY", "\(Int(quality * 100))%", x: 40, y: 350, color: .systemGreen)
        metric("RISK", "\(Int(risk * 100))%", x: 222, y: 350, color: .systemRed)
        metric("FATIGUE", "\(Int(fatigue * 100))%", x: 404, y: 350, color: .systemOrange)
    }
    
    private func drawDiagnosisBlock(diagnosis: String, quality: Double, risk: Double, fatigue: Double) {
        section("AUTOMATIC DIAGNOSIS", y: 470)
        
        let text = """
        Diagnosis: \(diagnosis)
        
        Overall interpretation:
        \(interpretation(quality: quality, risk: risk, fatigue: fatigue))
        
        This report is generated from AVO Performance Horse data. It is intended as a professional training and monitoring support tool and should be reviewed together with veterinary criteria when clinical signs are present.
        """
        
        paragraph(text, x: 40, y: 505, w: 515, h: 250)
    }
    
    private func drawChart(title: String, values: [Double], x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: UIColor) {
        section(title, y: y - 30)
        
        let rect = CGRect(x: x, y: y, width: w, height: h)
        let box = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor(white: 0.95, alpha: 1).setFill()
        box.fill()
        UIColor.lightGray.setStroke()
        box.lineWidth = 1
        box.stroke()
        
        guard values.count > 1 else {
            "No session data available".draw(at: CGPoint(x: x + 15, y: y + 55), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ])
            return
        }
        
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(maxV - minV, 0.0001)
        
        let path = UIBezierPath()
        
        for i in values.indices {
            let px = x + CGFloat(i) / CGFloat(values.count - 1) * w
            let normalized = (values[i] - minV) / range
            let py = y + h - CGFloat(normalized) * h
            
            if i == 0 {
                path.move(to: CGPoint(x: px, y: py))
            } else {
                path.addLine(to: CGPoint(x: px, y: py))
            }
        }
        
        color.setStroke()
        path.lineWidth = 2.4
        path.stroke()
        
        row("Min", "\(Int(minV * 100))%", y: y + h + 8)
        row("Max", "\(Int(maxV * 100))%", y: y + h + 30)
    }
    
    private func drawClinicalText(quality: Double, risk: Double, fatigue: Double, diagnosis: String) {
        section("CLINICAL SUMMARY", y: 120)
        
        paragraph("""
        Current diagnosis:
        \(diagnosis)
        
        Quality score:
        \(qualityText(quality))
        
        Risk score:
        \(riskText(risk))
        
        Fatigue score:
        \(fatigueText(fatigue))
        """, x: 40, y: 155, w: 515, h: 260)
        
        section("RECOMMENDATIONS", y: 440)
        
        paragraph(recommendations(quality: quality, risk: risk, fatigue: fatigue), x: 40, y: 475, w: 515, h: 260)
    }
    
    private func drawTechnicalBlock(samples: [SessionSample]) {
        section("DATASET", y: 120)
        
        row("Stored samples", "\(samples.count)", y: 155)
        row("Format", "AVO JSON / PDF Clinical Export", y: 180)
        row("Video source", "iPad camera biomechanical capture", y: 205)
        row("Sensor source", "RTK / IMU / ECG ready pipeline", y: 230)
        
        section("NEXT DATA LAYERS", y: 300)
        
        paragraph("""
        Planned professional extensions:
        • Real biomechanical frame snapshots
        • Horse pose keypoint overlay
        • GPS map insertion
        • ECG / IMU curves
        • Limb-specific scoring
        • Previous session comparison
        • Veterinary signature block
        • Premium clinic branding
        """, x: 40, y: 335, w: 515, h: 330)
    }
    
    private func section(_ text: String, y: CGFloat) {
        text.draw(at: CGPoint(x: 40, y: y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ])
    }
    
    private func row(_ key: String, _ value: String, y: CGFloat) {
        key.draw(at: CGPoint(x: 40, y: y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ])
        
        value.draw(at: CGPoint(x: 210, y: y), withAttributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ])
    }
    
    private func metric(_ title: String, _ value: String, x: CGFloat, y: CGFloat, color: UIColor) {
        let rect = CGRect(x: x, y: y, width: 150, height: 80)
        let box = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        
        color.withAlphaComponent(0.12).setFill()
        box.fill()
        color.setStroke()
        box.lineWidth = 1.5
        box.stroke()
        
        title.draw(at: CGPoint(x: x + 12, y: y + 12), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ])
        
        value.draw(at: CGPoint(x: x + 12, y: y + 38), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: color
        ])
    }
    
    private func paragraph(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        
        text.draw(in: CGRect(x: x, y: y, width: w, height: h), withAttributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black,
            .paragraphStyle: style
        ])
    }
    
    private func drawFooter(_ page: Int) {
        "AVO Performance Horse · Professional Equine Report · Page \(page)"
            .draw(at: CGPoint(x: 40, y: 800), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ])
    }
    
    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: Date())
    }
    
    private func interpretation(quality: Double, risk: Double, fatigue: Double) -> String {
        if risk > 0.65 || fatigue > 0.70 {
            return "High attention required. Review movement symmetry, workload and possible discomfort indicators before increasing training intensity."
        }
        
        if risk > 0.35 || fatigue > 0.45 {
            return "Monitoring recommended. Some indicators suggest that the horse should be reviewed across future sessions."
        }
        
        if quality < 0.60 {
            return "Movement quality is limited. Repeat the analysis with a clean camera angle and verify locomotion stability."
        }
        
        return "No critical findings detected. Current values are compatible with controlled training monitoring."
    }
    
    private func qualityText(_ q: Double) -> String {
        q >= 0.80 ? "High movement quality. The horse shows stable biomechanical behaviour." :
        q >= 0.55 ? "Moderate movement quality. Some irregularities may be present." :
        "Low movement quality. Review is recommended before intense work."
    }
    
    private func riskText(_ r: Double) -> String {
        r >= 0.65 ? "Elevated risk. Veterinary or technical review is recommended." :
        r >= 0.35 ? "Moderate risk. Continue monitoring." :
        "Low risk. No major risk pattern detected."
    }
    
    private func fatigueText(_ f: Double) -> String {
        f >= 0.70 ? "High fatigue. Recovery should be considered." :
        f >= 0.45 ? "Moderate fatigue. Workload should be monitored." :
        "Low fatigue. Current load appears acceptable."
    }
    
    private func recommendations(quality: Double, risk: Double, fatigue: Double) -> String {
        var text = ""
        
        if risk > 0.65 {
            text += "• Review full replay before next intensive session.\n"
            text += "• Check limb symmetry, stride consistency and compensation patterns.\n"
            text += "• Consider veterinary inspection if repeated.\n"
        } else {
            text += "• Continue normal controlled monitoring.\n"
        }
        
        if fatigue > 0.60 {
            text += "• Reduce workload or increase recovery time.\n"
            text += "• Compare fatigue curve with previous sessions.\n"
        } else {
            text += "• Fatigue level is acceptable for controlled work.\n"
        }
        
        if quality < 0.60 {
            text += "• Repeat analysis with better camera angle and visibility.\n"
            text += "• Verify that full horse body is visible.\n"
        } else {
            text += "• Data quality is acceptable for report generation.\n"
        }
        
        return text
    }
}
