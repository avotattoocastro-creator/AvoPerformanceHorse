import Foundation
import SwiftUI

// MARK: - BIOMECH PHASE 125
// SCIENCE SYSTEM CONTROLLER
//
// Connects BIOTECH normalized pose / system bus to science analysis.

@MainActor
public final class BiomechScienceSystemController: ObservableObject {

    public static let shared = BiomechScienceSystemController()

    @Published public private(set) var status: String = "SCIENCE SYSTEM READY"
    @Published public private(set) var lastReport: BiomechScienceSessionReport?
    @Published public private(set) var lastExportURL: URL?

    private let engine = BiomechScienceCompleteEngine()
    private let storage = AVOStorageEngine.shared
    private let bus = AVOSystemDataBus.shared

    private init() {}

    public func runFromSystemBus(horseName: String) {
        let frames = bus.normalizedPoseTimeline.map { frame in
            BiomechScienceFrame(
                frameIndex: frame.frameIndex,
                timeSeconds: frame.timeSeconds,
                points: frame.keypoints.map {
                    BiomechSciencePoint(
                        name: $0.name,
                        x: $0.x,
                        y: $0.y,
                        confidence: $0.confidence
                    )
                }
            )
        }

        run(frames: frames, horseName: horseName)
    }

    public func run(frames: [BiomechScienceFrame], horseName: String) {
        let report = engine.analyze(frames: frames, horseName: horseName)
        lastReport = report
        status = "SCIENCE DONE · \(report.frameCount) FRAMES"
    }

    public func exportReport(horseName: String) {
        guard let lastReport else {
            status = "SCIENCE EXPORT: NO REPORT"
            return
        }

        do {
            let folder = try storage.folder(for: .analytics, horseName: horseName)
            let url = folder.appendingPathComponent("biomech_science_report.json")
            try storage.writeJSON(lastReport, to: url)

            let csv = exportCSV(report: lastReport)
            _ = try storage.writeText(csv, area: .analytics, horseName: horseName, fileName: "biomech_science_curves.csv")

            lastExportURL = url
            status = "SCIENCE REPORT EXPORTED"
        } catch {
            status = "SCIENCE EXPORT ERROR: \(error.localizedDescription)"
        }
    }

    public func exportCSV(report: BiomechScienceSessionReport) -> String {
        var rows = ["frame,time,topline,forelimb,hindlimb,neck,pelvis,symmetry,stability,stride,gait,risk,confidence,notes"]

        for m in report.metrics {
            rows.append([
                String(m.frameIndex),
                String(m.timeSeconds),
                String(m.angles.topline),
                String(m.angles.forelimb),
                String(m.angles.hindlimb),
                String(m.angles.neck),
                String(m.angles.pelvis),
                String(m.symmetry),
                String(m.temporalStability),
                String(m.strideCandidate),
                m.gaitPhase.rawValue,
                String(m.lamenessRisk),
                String(m.confidence),
                m.notes.joined(separator: "|")
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }
}

@MainActor
public struct BiomechScienceSystemPanel: View {

    @ObservedObject private var controller = BiomechScienceSystemController.shared
    @ObservedObject private var recorder = BiotechHorseSessionRecorder.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BiomechScienceCompletePanel(report: controller.lastReport)

            HStack {
                Button("RUN SCIENCE") {
                    controller.runFromSystemBus(horseName: recorder.selectedHorseName)
                }
                .buttonStyle(.borderedProminent)

                Button("EXPORT") {
                    controller.exportReport(horseName: recorder.selectedHorseName)
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 10, weight: .bold))

            Text(controller.status)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}
