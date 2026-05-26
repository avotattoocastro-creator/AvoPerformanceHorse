import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - REVIEW PRO PHASE 103
// Integrated SwiftUI panel
//
// Use this view from your existing REVIEW page.
// It gives the app a complete connected flow:
// import video -> scrub -> run analysis -> export.

public struct ReviewProPhase103IntegratedPanel: View {

    @StateObject private var workflow = ReviewProWorkflowController()
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var scrubValue: Double = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 10) {
            topBar

            videoArea

            timelineControls

            analysisBar

            exportBar

            statusBar
        }
        .padding(12)
        .background(Color.black.opacity(0.92))
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                workflow.loadVideo(url: url)
                scrubValue = 0
            case .failure(let error):
                print("IMPORT ERROR:", error.localizedDescription)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: ReviewProPhase103ExportDocument(text: workflow.analysisSummaryText),
            contentType: .plainText,
            defaultFilename: "review_pro_phase103_summary.txt"
        ) { _ in }
    }

    private var topBar: some View {
        HStack {
            Text("REVIEW PRO PHASE 103")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()

            Button("IMPORT VIDEO") {
                showImporter = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var videoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            if let image = workflow.currentFrameImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .topLeading) {
                        poseOverlay
                    }
            } else {
                VStack(spacing: 8) {
                    Text("NO VIDEO LOADED")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Import MP4/MOV to start real video review")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(minHeight: 320)
    }

    private var poseOverlay: some View {
        GeometryReader { geo in
            if let pose = workflow.currentPose {
                ForEach(pose.points, id: \.name) { point in
                    Circle()
                        .fill(point.isOcclusionRecovered ? Color.orange : Color.cyan)
                        .frame(width: 9, height: 9)
                        .position(
                            x: CGFloat(point.x) * geo.size.width,
                            y: CGFloat(point.y) * geo.size.height
                        )
                }
            }
        }
    }

    private var timelineControls: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { scrubValue },
                    set: { newValue in
                        scrubValue = newValue
                        workflow.scrub(to: Int(newValue))
                    }
                ),
                in: 0...Double(max(1, workflow.totalFrames - 1)),
                step: 1
            )

            HStack {
                Button("◀︎ FRAME") {
                    let next = max(0, workflow.currentFrameIndex - 1)
                    scrubValue = Double(next)
                    workflow.scrub(to: next)
                }

                Text(workflow.progressText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))

                Button("FRAME ▶︎") {
                    let next = min(max(0, workflow.totalFrames - 1), workflow.currentFrameIndex + 1)
                    scrubValue = Double(next)
                    workflow.scrub(to: next)
                }

                Spacer()

                Text(workflow.loadedVideoName)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var analysisBar: some View {
        HStack {
            Button("RUN TEMPORAL AUTOPOSE") {
                workflow.runTemporalAutoPose()
            }

            Button("RUN BIOMECH") {
                workflow.runBiomechAnalysis()
            }

            Button("RUN FULL ANALYSIS") {
                workflow.runFullAnalysis()
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Text(workflow.analysisSummaryText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.green)
        }
    }

    private var exportBar: some View {
        HStack {
            Button("EXPORT SUMMARY") {
                showExporter = true
            }

            Spacer()

            if let report = workflow.currentBiomechReport {
                Text("SYM \(String(format: "%.2f", report.symmetryScore)) | RISK \(String(format: "%.2f", report.locomotionRisk))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(report.locomotionRisk > 0.6 ? .red : .white)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text(workflow.status)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            if let error = workflow.lastError {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}

public struct ReviewProPhase103ExportDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.plainText] }

    public var text: String

    public init(text: String) {
        self.text = text
    }

    public init(configuration: ReadConfiguration) throws {
        text = ""
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
