import SwiftUI
import UIKit
import AVFoundation
import AVKit
import UniformTypeIdentifiers
import CoreMedia
import QuartzCore

// MARK: - AVO Professional Video Evidence Editor
// Editor real: abre un vídeo ya grabado en BIOMECH o importado, permite activar capas,
// añadir textos técnicos por segmento y exporta un .mp4 final para enviar al cliente.
// Las capas se guardan separadas en un .avoproject y se componen al exportar.

struct AVOVideoEvidenceProject: Codable, Identifiable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var projectName: String
    var horseName: String
    var sourceVideoPath: String
    var durationSeconds: Double
    var trimStart: Double
    var trimEnd: Double
    var globalShowCamera: Bool
    var globalShowSkeleton: Bool
    var globalShowLiDAR: Bool
    var globalShowSensors: Bool
    var globalShowAI: Bool
    var textOverlays: [AVOVideoTextOverlay]
    var segments: [AVOVideoEvidenceSegment]
    var notes: String
}

struct AVOVideoEvidenceSegment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var startSeconds: Double
    var endSeconds: Double
    var showCamera: Bool
    var showSkeleton: Bool
    var showLiDAR: Bool
    var showSensors: Bool
    var showAI: Bool
    var aiNote: String
}

struct AVOVideoTextOverlay: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var startSeconds: Double
    var endSeconds: Double
    var x: Double
    var y: Double
    var size: Double
}

@MainActor
final class AVOVideoEvidenceEditorStore: ObservableObject {
    @Published var projectName: String = "AVO_CLIENT_EVIDENCE"
    @Published var status: String = "EDITOR READY"
    @Published var sourceVideoURL: URL?
    @Published var exportedVideoURL: URL?
    @Published var timelinePosition: Double = 0
    @Published var durationSeconds: Double = 60
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 60
    @Published var showCameraLayer: Bool = true
    @Published var showSkeletonLayer: Bool = true
    @Published var showLiDARLayer: Bool = false
    @Published var showSensorLayer: Bool = true
    @Published var showAILayer: Bool = true
    @Published var clientNote: String = ""
    @Published var textDraft: String = ""
    @Published var isExporting: Bool = false
    @Published var exportProgressText: String = "EXPORT READY"

    @Published var textOverlays: [AVOVideoTextOverlay] = [
        AVOVideoTextOverlay(text: "Biomechanical evidence", startSeconds: 0, endSeconds: 6, x: 0.06, y: 0.08, size: 34)
    ]

    @Published var segments: [AVOVideoEvidenceSegment] = [
        AVOVideoEvidenceSegment(title: "INTRO", startSeconds: 0, endSeconds: 8, showCamera: true, showSkeleton: false, showLiDAR: false, showSensors: true, showAI: true, aiNote: "Resumen inicial"),
        AVOVideoEvidenceSegment(title: "MAIN GAIT", startSeconds: 8, endSeconds: 38, showCamera: true, showSkeleton: true, showLiDAR: true, showSensors: true, showAI: true, aiNote: "Análisis de marcha"),
        AVOVideoEvidenceSegment(title: "CLIENT SUMMARY", startSeconds: 38, endSeconds: 60, showCamera: true, showSkeleton: false, showLiDAR: false, showSensors: true, showAI: true, aiNote: "Conclusión para cliente")
    ]

    var trimRangeText: String { String(format: "%.1fs - %.1fs", trimStart, trimEnd) }
    var activeLayerCount: Int { [showCameraLayer, showSkeletonLayer, showLiDARLayer, showSensorLayer, showAILayer].filter { $0 }.count }
    var hasVideo: Bool { sourceVideoURL != nil }

    // Compatibility aliases for previous editor snippets / Playgrounds cache.
    // Do not remove: older views may call showLidarLayer or textNotes.
    var showLidarLayer: Bool {
        get { showLiDARLayer }
        set { showLiDARLayer = newValue }
    }

    var textNotes: [AVOVideoTextOverlay] {
        get { textOverlays }
        set { textOverlays = newValue }
    }

    func loadVideo(url: URL) {
        sourceVideoURL = url
        exportedVideoURL = nil
        status = "VIDEO LOADED"
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite && seconds > 0 {
            durationSeconds = seconds
            trimStart = 0
            trimEnd = seconds
            normalizeSegmentsToDuration()
        }
    }

    func loadLatestBiomechSessionVideo() {
        guard let url = findLatestBiomechVideo() else {
            status = "NO BIOMECH VIDEO FOUND"
            return
        }
        loadVideo(url: url)
        status = "BIOMECH VIDEO LOADED"
    }

    private func findLatestBiomechVideo() -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        var roots: [URL] = []
        if let session = AVOMasterSessionCore.shared.activeSessionURL {
            roots.append(session.appendingPathComponent("ClientRec", isDirectory: true))
            roots.append(session.appendingPathComponent("BiotechRec", isDirectory: true))
            roots.append(session)
        }
        if let horse = AVOMasterSessionCore.shared.activeHorseFolderURL {
            roots.append(horse.appendingPathComponent("Sessions", isDirectory: true))
            roots.append(horse)
        }
        roots.append(docs.appendingPathComponent("AVO_Horse_App", isDirectory: true))
        roots.append(docs.appendingPathComponent("AVOBiomechVideos", isDirectory: true))
        roots.append(docs.appendingPathComponent("Horses", isDirectory: true))
        roots.append(docs)
        var candidates: [(URL, Date)] = []
        for root in roots where fm.fileExists(atPath: root.path) {
            if let en = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for case let u as URL in en {
                    let name = u.lastPathComponent.lowercased()
                    if name == "video.mov" || name == "camera.mov" || name.hasSuffix(".mp4") || name.hasSuffix(".mov") {
                        let d = (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                        candidates.append((u, d))
                    }
                }
            }
        }
        return candidates.sorted { $0.1 > $1.1 }.first?.0
    }

    func addSegmentFromCurrentLayers() {
        let start = min(timelinePosition, max(durationSeconds - 5, 0))
        let end = min(start + 8, durationSeconds)
        segments.append(AVOVideoEvidenceSegment(
            title: "CUT \(segments.count + 1)",
            startSeconds: start,
            endSeconds: end,
            showCamera: showCameraLayer,
            showSkeleton: showSkeletonLayer,
            showLiDAR: showLiDARLayer,
            showSensors: showSensorLayer,
            showAI: showAILayer,
            aiNote: clientNote.isEmpty ? "Segmento técnico" : clientNote
        ))
        status = "SEGMENT ADDED"
    }

    func addTextOverlay() {
        let text = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { status = "TEXT EMPTY"; return }
        textOverlays.append(AVOVideoTextOverlay(
            text: text,
            startSeconds: timelinePosition,
            endSeconds: min(timelinePosition + 6, durationSeconds),
            x: 0.06,
            y: 0.78,
            size: 28
        ))
        textDraft = ""
        status = "TEXT ADDED"
    }

    func deleteText(_ overlay: AVOVideoTextOverlay) {
        textOverlays.removeAll { $0.id == overlay.id }
        status = "TEXT REMOVED"
    }

    func applySegment(_ segment: AVOVideoEvidenceSegment) {
        timelinePosition = segment.startSeconds
        showCameraLayer = segment.showCamera
        showSkeletonLayer = segment.showSkeleton
        showLiDARLayer = segment.showLiDAR
        showSensorLayer = segment.showSensors
        showAILayer = segment.showAI
        status = "SEGMENT LOADED: \(segment.title)"
    }

    func buildProject(horseName: String) -> AVOVideoEvidenceProject {
        AVOVideoEvidenceProject(
            projectName: projectName,
            horseName: horseName,
            sourceVideoPath: sourceVideoURL?.path ?? "",
            durationSeconds: durationSeconds,
            trimStart: trimStart,
            trimEnd: trimEnd,
            globalShowCamera: showCameraLayer,
            globalShowSkeleton: showSkeletonLayer,
            globalShowLiDAR: showLiDARLayer,
            globalShowSensors: showSensorLayer,
            globalShowAI: showAILayer,
            textOverlays: textOverlays,
            segments: segments,
            notes: clientNote
        )
    }

    @discardableResult
    func saveProject(horseName: String) -> URL? {
        let project = buildProject(horseName: horseName)
        do {
            let folder = try projectFolder()
            let file = folder.appendingPathComponent("\(safeProjectName())_\(timeStamp()).avoproject")
            let data = try JSONEncoder.avoPrettyEncoder.encode(project)
            try data.write(to: file, options: [.atomic])
            status = "PROJECT SAVED"
            return file
        } catch {
            status = "SAVE ERROR: \(error.localizedDescription)"
            return nil
        }
    }

    func exportMP4(horseName: String, sensorText: String, aiText: String) {
        guard let source = sourceVideoURL else { status = "LOAD VIDEO FIRST"; return }
        isExporting = true
        exportProgressText = "EXPORTING..."
        status = "EXPORTING MP4"

        let showSkeleton = showSkeletonLayer
        let showLiDAR = showLiDARLayer
        let showSensors = showSensorLayer
        let showAI = showAILayer
        let overlays = textOverlays
        let segmentsCopy = segments
        let note = clientNote
        let start = max(0, min(trimStart, trimEnd))
        let end = min(durationSeconds, max(trimStart, trimEnd))
        let project = projectName

        Task.detached(priority: .userInitiated) {
            do {
                let out = try AVOVideoMP4Exporter.export(
                    sourceURL: source,
                    projectName: project,
                    horseName: horseName,
                    startSeconds: start,
                    endSeconds: end,
                    showSkeleton: showSkeleton,
                    showLiDAR: showLiDAR,
                    showSensors: showSensors,
                    showAI: showAI,
                    sensorText: sensorText,
                    aiText: aiText,
                    clientNote: note,
                    textOverlays: overlays,
                    segments: segmentsCopy
                )
                await MainActor.run {
                    self.exportedVideoURL = out
                    self.status = "MP4 EXPORTED"
                    self.exportProgressText = out.lastPathComponent
                    self.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.status = "EXPORT ERROR: \(error.localizedDescription)"
                    self.exportProgressText = "EXPORT FAILED"
                    self.isExporting = false
                }
            }
        }
    }

    func normalizeTrim() {
        if trimEnd < trimStart {
            let old = trimStart
            trimStart = trimEnd
            trimEnd = old
        }
        trimStart = max(0, min(trimStart, durationSeconds))
        trimEnd = max(0, min(trimEnd, durationSeconds))
        status = "TRIM APPLIED"
    }

    private func normalizeSegmentsToDuration() {
        if durationSeconds <= 0 { return }
        segments = segments.map { s in
            var n = s
            n.startSeconds = min(max(0, n.startSeconds), durationSeconds)
            n.endSeconds = min(max(n.startSeconds + 1, n.endSeconds), durationSeconds)
            return n
        }
    }

    private func safeProjectName() -> String { projectName.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_") }
    private func timeStamp() -> String { let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"; return f.string(from: Date()) }
    private func projectFolder() throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let folder = docs.appendingPathComponent("AVOVideoEvidenceProjects", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

private extension JSONEncoder {
    static var avoPrettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

struct AVOVideoEvidenceEditorView: View {
    @ObservedObject var camera: CameraManager
    @ObservedObject var sensors: SensorHub
    @ObservedObject var stableStore: AVOStableStore
    @ObservedObject var hardware: AVOHardwareReceiver
    @ObservedObject var settings: HardwareSettings

    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor = AVOVideoEvidenceEditorStore()
    @State private var selectedSegmentID: UUID?
    @State private var showImporter = false
    @State private var showShare = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.005, green: 0.008, blue: 0.010).ignoresSafeArea()
                VStack(spacing: 8) {
                    header.frame(height: 48)
                    HStack(spacing: 8) {
                        previewPanel.frame(width: geo.size.width * 0.64)
                        inspectorPanel
                    }.frame(maxHeight: .infinity)
                    timelinePanel.frame(height: 178)
                }.padding(10)
            }
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { editor.loadVideo(url: url) }
            case .failure(let error):
                editor.status = "IMPORT ERROR: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = editor.exportedVideoURL { AVOShareSheet(items: [url]) }
        }
        .onAppear { editor.loadLatestBiomechSessionVideo() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: { BottomButton("CLOSE", .orange) }
            VStack(alignment: .leading, spacing: 2) {
                Text("PRO VIDEO EDITOR / CLIENT EVIDENCE")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                Text("OPEN BIOMECH VIDEO → EDIT LAYERS / TEXT / TRIM → EXPORT MP4")
                    .foregroundColor(.green.opacity(0.85))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Spacer()
            Text(editor.status)
                .foregroundColor(editor.status.contains("ERROR") ? .red : .green)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.black.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button { editor.saveProject(horseName: stableStore.selectedHorseName) } label: { BottomButton("SAVE PROJECT", .green) }
            Button { editor.exportMP4(horseName: stableStore.selectedHorseName, sensorText: sensorExportText, aiText: aiExportText) } label: { BottomButton("EXPORT MP4", .cyan) }
            if editor.exportedVideoURL != nil { Button { showShare = true } label: { BottomButton("SHARE", .purple) } }
        }
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.78))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.green.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var previewPanel: some View {
        VStack(spacing: 6) {
            previewHeader
            previewCanvas
        }
    }
    
    private var previewHeader: some View {
        HStack {
            Text(editor.hasVideo ? "VIDEO COMPOSER PREVIEW" : "NO VIDEO LOADED")
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .black, design: .monospaced))
            
            Spacer()
            
            Text(timecodeText)
                .foregroundColor(.cyan)
                .font(.system(size: 11, weight: .black, design: .monospaced))
        }
    }
    
    private var timecodeText: String {
        let current = String(format: "%.1f", editor.timelinePosition)
        let total = String(format: "%.0f", editor.durationSeconds)
        return "T \(current)s / \(total)s"
    }
    
    private var previewCanvas: some View {
        ZStack(alignment: .topLeading) {
            videoBaseLayer
            
            if editor.showSkeletonLayer {
                skeletonOverlayLayer
            }
            
            if editor.showLidarLayer {
                lidarOverlayLayer
            }
            
            if editor.showSensorLayer {
                sensorOverlayLayer
            }
            
            if editor.showAILayer {
                aiOverlayLayer
            }
            
            textNotesOverlayLayer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.18), lineWidth: 1)
        )
    }
    
    private var videoBaseLayer: some View {
        Group {
            if let url = editor.sourceVideoURL, editor.showCameraLayer {
                VideoPlayer(player: AVPlayer(url: url))
                    .background(Color.black)
            } else {
                Color.black
                    .overlay(
                        VStack(spacing: 12) {
                            Text(editor.hasVideo ? "CAMERA LAYER OFF" : "OPEN A BIOMECH VIDEO")
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                            
                            Text("Carga una grabación de Biomech para editar capas, textos y exportar MP4.")
                                .foregroundColor(.gray)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                        }
                            .padding()
                    )
            }
        }
    }
    
    private var skeletonOverlayLayer: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .position(x: geo.size.width * 0.40, y: geo.size.height * 0.38)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .position(x: geo.size.width * 0.48, y: geo.size.height * 0.34)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .position(x: geo.size.width * 0.58, y: geo.size.height * 0.40)
                
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width * 0.40, y: geo.size.height * 0.38))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.48, y: geo.size.height * 0.34))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.58, y: geo.size.height * 0.40))
                }
                .stroke(Color.blue, lineWidth: 2)
            }
        }
    }
    
    private var lidarOverlayLayer: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
            .padding(80)
            .overlay(
                Text("LiDAR CONTOUR")
                    .foregroundColor(.cyan)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .padding(90),
                alignment: .topLeading
            )
    }
    
    private var sensorOverlayLayer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIVE SENSOR STRIP")
                .foregroundColor(.green)
            
            Text("HR  \(sensors.heartRateText)")
            Text("SPEED  \(sensors.speedText)")
            Text("RSSI  \(hardware.rssi)")
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .foregroundColor(.white)
        .padding(12)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(12)
    }
    
    private var aiOverlayLayer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("AI EVIDENCE")
                .foregroundColor(.purple)
            
            Text("QUALITY  65%")
            Text("RISK     20%")
            Text("FATIGUE  20%")
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .foregroundColor(.white)
        .padding(12)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
    
    private var textNotesOverlayLayer: some View {
        ForEach(editor.textNotes) { note in
            Text(note.text)
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .padding(8)
                .background(Color.black.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .position(x: note.x, y: note.y)
        }
    }

    private var inspectorPanel: some View {
        VStack(spacing: 8) {
            editorControlPanel
            layerSwitchPanel
            textPanel
            segmentListPanel
        }
    }

    private var editorControlPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("PROJECT / SOURCE VIDEO", .green)
            TextField("Project name", text: $editor.projectName)
                .foregroundColor(.white).font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(8).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 6))
            MiniText(name: "HORSE", value: stableStore.selectedHorseName, color: .green)
            MiniText(name: "SOURCE", value: editor.sourceVideoURL?.lastPathComponent ?? "NO VIDEO", color: editor.hasVideo ? .cyan : .orange)
            MiniText(name: "DURATION", value: String(format: "%.1fs", editor.durationSeconds), color: .white)
            MiniText(name: "TRIM", value: editor.trimRangeText, color: .orange)
            HStack(spacing: 6) {
                Button { editor.loadLatestBiomechSessionVideo() } label: { BottomButton("LOAD BIOMECH", .green) }
                Button { showImporter = true } label: { BottomButton("IMPORT", .cyan) }
                Button { editor.saveProject(horseName: stableStore.selectedHorseName) } label: { BottomButton("SAVE", .green) }
            }
            HStack(spacing: 6) {
                Button { editor.exportMP4(horseName: stableStore.selectedHorseName, sensorText: sensorExportText, aiText: aiExportText) } label: { BottomButton(editor.isExporting ? "EXPORTING" : "EXPORT MP4", .orange) }
                if editor.exportedVideoURL != nil { Button { showShare = true } label: { BottomButton("SEND", .purple) } }
            }
            Text(editor.exportProgressText)
                .foregroundColor(.white.opacity(0.65))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .lineLimit(2)
        }
        .padding(10).background(Color.black.opacity(0.46))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var layerSwitchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("VISIBLE / EXPORT LAYERS", .cyan)
            layerToggle("CAMERA VIDEO", color: .white, isOn: $editor.showCameraLayer)
            layerToggle("SKELETON IA", color: .green, isOn: $editor.showSkeletonLayer)
            layerToggle("LiDAR CONTOUR", color: .cyan, isOn: $editor.showLiDARLayer)
            layerToggle("SENSORS", color: .orange, isOn: $editor.showSensorLayer)
            layerToggle("AI INFO", color: .purple, isOn: $editor.showAILayer)
            MiniText(name: "ACTIVE", value: "\(editor.activeLayerCount) / 5", color: .green)
        }
        .padding(10).background(Color.black.opacity(0.46))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            panelTitle("TEXT / CLIENT NOTES", .orange)
            TextField("Text to show in video", text: $editor.textDraft)
                .foregroundColor(.white).font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(8).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 6))
            TextField("AI/client note", text: $editor.clientNote)
                .foregroundColor(.white).font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(8).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 6))
            HStack { Button { editor.addTextOverlay() } label: { BottomButton("ADD TEXT", .orange) }; Button { editor.addSegmentFromCurrentLayers() } label: { BottomButton("ADD CUT", .cyan) } }
            ScrollView { VStack(spacing: 4) { ForEach(editor.textOverlays) { t in HStack { Text(t.text).foregroundColor(.white).font(.system(size: 9, weight: .bold, design: .monospaced)).lineLimit(1); Spacer(); Button("DEL") { editor.deleteText(t) }.font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(.red) }.padding(6).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 5)) } } }.frame(maxHeight: 72)
        }
        .padding(10).background(Color.black.opacity(0.46))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var segmentListPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("SEGMENTS / LAYER AUTOMATION", .purple)
            ScrollView { VStack(spacing: 6) { ForEach(editor.segments) { segment in
                Button { selectedSegmentID = segment.id; editor.applySegment(segment) } label: {
                    HStack(spacing: 8) { VStack(alignment: .leading, spacing: 2) { Text(segment.title).foregroundColor(.white).font(.system(size: 11, weight: .black, design: .monospaced)); Text(String(format: "%.1fs - %.1fs", segment.startSeconds, segment.endSeconds)).foregroundColor(.cyan).font(.system(size: 9, weight: .bold, design: .monospaced)) }; Spacer(); Text(layerCode(segment)).foregroundColor(.green).font(.system(size: 9, weight: .black, design: .monospaced)) }
                        .padding(8).background(selectedSegmentID == segment.id ? Color.green.opacity(0.18) : Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain)
            } } }
        }
        .padding(10).background(Color.black.opacity(0.46))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { panelTitle("TIMELINE / TRIM / EXPORT RANGE", .green); Spacer(); Text("Output: MP4 with camera + selected overlays + text + sensor/AI evidence").foregroundColor(.white.opacity(0.45)).font(.system(size: 9, weight: .bold, design: .monospaced)) }
            Slider(value: $editor.timelinePosition, in: 0...max(editor.durationSeconds, 1), step: 0.1)
            HStack(spacing: 6) { ForEach(editor.segments) { segment in AVOTimelineSegmentBlock(segment: segment, duration: max(editor.durationSeconds, 1)) { selectedSegmentID = segment.id; editor.applySegment(segment) } } }.frame(height: 38)
            HStack(spacing: 8) {
                VStack(alignment: .leading) { Text("TRIM START").foregroundColor(.white.opacity(0.55)).font(.system(size: 9, weight: .black, design: .monospaced)); Slider(value: $editor.trimStart, in: 0...max(editor.durationSeconds, 1), step: 0.5) }
                VStack(alignment: .leading) { Text("TRIM END").foregroundColor(.white.opacity(0.55)).font(.system(size: 9, weight: .black, design: .monospaced)); Slider(value: $editor.trimEnd, in: 0...max(editor.durationSeconds, 1), step: 0.5) }
                Button { editor.normalizeTrim() } label: { BottomButton("APPLY TRIM", .orange) }
            }
        }
        .padding(10).background(Color.black.opacity(0.72))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sensorOverlay: some View {
        VStack(alignment: .leading, spacing: 5) { Text("SENSOR STRIP").foregroundColor(.green).font(.system(size: 11, weight: .black, design: .monospaced)); MiniText(name: "HORSE", value: stableStore.selectedHorseName, color: .green); MiniText(name: "GAIT", value: camera.gait, color: .cyan); MiniText(name: "ASYM", value: camera.asymmetry, color: .orange); MiniText(name: "HR", value: sensors.pulseStatus, color: .green); MiniText(name: "SPEED", value: sensors.speedStatus, color: .cyan); MiniText(name: "RSSI", value: hardware.rssi, color: .orange) }
            .padding(10).frame(width: 270, alignment: .leading).background(Color.black.opacity(0.76)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.38), lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var aiOverlay: some View {
        VStack(alignment: .leading, spacing: 5) { Text("AI EVIDENCE").foregroundColor(.purple).font(.system(size: 11, weight: .black, design: .monospaced)); MiniText(name: "QUALITY", value: "\(Int(camera.quality * 100))%", color: .green); MiniText(name: "RISK", value: "\(Int(camera.risk * 100))%", color: .red); MiniText(name: "FATIGUE", value: "\(Int(camera.fatigue * 100))%", color: .orange); MiniText(name: "LiDAR", value: camera.lidarSupported ? camera.lidarDistanceText : "OFF", color: camera.lidarSupported ? .cyan : .orange) }
            .padding(10).frame(width: 260, alignment: .leading).background(Color.black.opacity(0.76)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.42), lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sensorExportText: String { "HORSE \(stableStore.selectedHorseName) | GAIT \(camera.gait) | ASYM \(camera.asymmetry) | HR \(sensors.pulseStatus) | SPEED \(sensors.speedStatus) | RSSI \(hardware.rssi)" }
    private var aiExportText: String { "AI QUALITY \(Int(camera.quality * 100))% | RISK \(Int(camera.risk * 100))% | FATIGUE \(Int(camera.fatigue * 100))% | LiDAR \(camera.lidarSupported ? camera.lidarDistanceText : "OFF")" }

    private func panelTitle(_ title: String, _ color: Color) -> some View { Text(title).foregroundColor(color).font(.system(size: 12, weight: .black, design: .monospaced)) }
    private func layerToggle(_ title: String, color: Color, isOn: Binding<Bool>) -> some View { Toggle(isOn: isOn) { Text(title).foregroundColor(color).font(.system(size: 11, weight: .black, design: .monospaced)) }.toggleStyle(SwitchToggleStyle(tint: color)) }
    private func layerCode(_ segment: AVOVideoEvidenceSegment) -> String { var p:[String]=[]; if segment.showCamera {p.append("CAM")}; if segment.showSkeleton {p.append("SKL")}; if segment.showLiDAR {p.append("LID")}; if segment.showSensors {p.append("SNS")}; if segment.showAI {p.append("AI")}; return p.joined(separator: "+") }
}

struct AVOTimelineSegmentBlock: View {
    let segment: AVOVideoEvidenceSegment
    let duration: Double
    let action: () -> Void
    var body: some View {
        Button(action: action) { VStack(alignment: .leading, spacing: 3) { Text(segment.title).foregroundColor(.black).font(.system(size: 9, weight: .black, design: .monospaced)).lineLimit(1); Text(String(format: "%.0fs", segment.endSeconds - segment.startSeconds)).foregroundColor(.black.opacity(0.7)).font(.system(size: 8, weight: .bold, design: .monospaced)) }.padding(.horizontal, 7).frame(width: max(58, CGFloat((segment.endSeconds - segment.startSeconds) / max(duration, 1)) * 620), height: 34, alignment: .leading).background(Color.green).clipShape(RoundedRectangle(cornerRadius: 5)) }.buttonStyle(.plain)
    }
}

struct AVOSkeletonDemoOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width; let h = geo.size.height
                let trainingModels = [CGPoint(x:w*0.25,y:h*0.52), CGPoint(x:w*0.38,y:h*0.42), CGPoint(x:w*0.52,y:h*0.43), CGPoint(x:w*0.67,y:h*0.49), CGPoint(x:w*0.78,y:h*0.42)]
                if let first = trainingModels.first { p.move(to: first); for trainingModel in trainingModels.dropFirst() { p.addLine(to: trainingModel) } }
                p.move(to: CGPoint(x:w*0.38,y:h*0.42)); p.addLine(to: CGPoint(x:w*0.36,y:h*0.72))
                p.move(to: CGPoint(x:w*0.52,y:h*0.43)); p.addLine(to: CGPoint(x:w*0.55,y:h*0.73))
                p.move(to: CGPoint(x:w*0.67,y:h*0.49)); p.addLine(to: CGPoint(x:w*0.70,y:h*0.74))
                p.move(to: CGPoint(x:w*0.28,y:h*0.52)); p.addLine(to: CGPoint(x:w*0.25,y:h*0.76))
            }.stroke(Color.green.opacity(0.95), lineWidth: 3).shadow(color: .green, radius: 5)
            Text("SKELETON IA LAYER").foregroundColor(.green).font(.system(size: 10, weight: .black, design: .monospaced)).padding(7).background(Color.black.opacity(0.62)).clipShape(RoundedRectangle(cornerRadius: 6)).padding(12)
        }.allowsHitTesting(false)
    }
}

struct AVOLiDARContourDemoOverlay: View {
    let isRealLiDAR: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    let w = geo.size.width; let h = geo.size.height
                    path.move(to: CGPoint(x: w * 0.16, y: h * 0.54))
                    path.addCurve(to: CGPoint(x: w * 0.34, y: h * 0.36), control1: CGPoint(x: w * 0.20, y: h * 0.38), control2: CGPoint(x: w * 0.27, y: h * 0.34))
                    path.addCurve(to: CGPoint(x: w * 0.70, y: h * 0.38), control1: CGPoint(x: w * 0.46, y: h * 0.27), control2: CGPoint(x: w * 0.61, y: h * 0.30))
                    path.addCurve(to: CGPoint(x: w * 0.86, y: h * 0.55), control1: CGPoint(x: w * 0.77, y: h * 0.42), control2: CGPoint(x: w * 0.84, y: h * 0.47))
                    path.addCurve(to: CGPoint(x: w * 0.64, y: h * 0.65), control1: CGPoint(x: w * 0.78, y: h * 0.64), control2: CGPoint(x: w * 0.72, y: h * 0.66))
                    path.addCurve(to: CGPoint(x: w * 0.24, y: h * 0.66), control1: CGPoint(x: w * 0.50, y: h * 0.72), control2: CGPoint(x: w * 0.36, y: h * 0.70))
                    path.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.54), control1: CGPoint(x: w * 0.18, y: h * 0.64), control2: CGPoint(x: w * 0.15, y: h * 0.59))
                }.stroke(Color.cyan.opacity(0.82), lineWidth: 3).shadow(color: .cyan, radius: 8)
                VStack { HStack { Text(isRealLiDAR ? "LiDAR DEPTH CONTOUR" : "LiDAR CONTOUR PREVIEW").foregroundColor(.cyan).font(.system(size: 10, weight: .black, design: .monospaced)).padding(7).background(Color.black.opacity(0.62)).clipShape(RoundedRectangle(cornerRadius: 6)); Spacer() }; Spacer() }.padding(12)
            }
        }.allowsHitTesting(false)
    }
}

final class AVOVideoMP4Exporter {
    static func export(sourceURL: URL, projectName: String, horseName: String, startSeconds: Double, endSeconds: Double, showSkeleton: Bool, showLiDAR: Bool, showSensors: Bool, showAI: Bool, sensorText: String, aiText: String, clientNote: String, textOverlays: [AVOVideoTextOverlay], segments: [AVOVideoEvidenceSegment]) throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { throw NSError(domain: "AVOExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"]) }
        let duration = max(1, endSeconds - startSeconds)
        let range = CMTimeRange(start: CMTime(seconds: startSeconds, preferredTimescale: 600), duration: CMTime(seconds: duration, preferredTimescale: 600))
        let composition = AVMutableComposition()
        guard let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw NSError(domain: "AVOExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create video track"]) }
        try compVideo.insertTimeRange(range, of: videoTrack, at: .zero)
        compVideo.preferredTransform = videoTrack.preferredTransform
        if let audioTrack = asset.tracks(withMediaType: .audio).first, let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) { try? compAudio.insertTimeRange(range, of: audioTrack, at: .zero) }
        let natural = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let renderSize = CGSize(width: abs(natural.width), height: abs(natural.height))
        let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: renderSize)
        let videoLayer = CALayer(); videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)
        let overlay = CALayer(); overlay.frame = parent.frame; parent.addSublayer(overlay)
        addBaseTitle(to: overlay, size: renderSize, horseName: horseName, projectName: projectName)
        if showSensors { addText(sensorText, to: overlay, frame: CGRect(x: 24, y: 24, width: renderSize.width * 0.60, height: 78), font: 28, color: UIColor.systemGreen.cgColor) }
        if showAI { addText(aiText + (clientNote.isEmpty ? "" : " | " + clientNote), to: overlay, frame: CGRect(x: 24, y: renderSize.height - 112, width: renderSize.width * 0.78, height: 88), font: 28, color: UIColor.systemPurple.cgColor) }
        if showSkeleton { addSkeleton(to: overlay, size: renderSize) }
        if showLiDAR { addLiDAR(to: overlay, size: renderSize) }
        for t in textOverlays { addTimedText(t, to: overlay, size: renderSize, offset: startSeconds) }
        addSegmentBar(segments: segments, to: overlay, size: renderSize, duration: duration, startOffset: startSeconds)
        let instruction = AVMutableVideoCompositionInstruction(); instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideo)
        instruction.layerInstructions = [layerInstruction]
        let videoComposition = AVMutableVideoComposition(); videoComposition.instructions = [instruction]; videoComposition.frameDuration = CMTime(value: 1, timescale: 30); videoComposition.renderSize = renderSize
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
        let out = try outputURL(projectName: projectName)
        if FileManager.default.fileExists(atPath: out.path) { try? FileManager.default.removeItem(at: out) }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw NSError(domain: "AVOExport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"]) }
        session.outputURL = out; session.outputFileType = .mp4; session.videoComposition = videoComposition; session.shouldOptimizeForNetworkUse = true
        let sem = DispatchSemaphore(value: 0)
        var exportError: Error?
        session.exportAsynchronously { exportError = session.error; sem.signal() }
        sem.wait()
        if let e = exportError { throw e }
        if session.status != .completed { throw NSError(domain: "AVOExport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export not completed"]) }
        return out
    }

    private static func outputURL(projectName: String) throws -> URL { let fm = FileManager.default; let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory; let folder = docs.appendingPathComponent("AVOVideoEvidenceExports", isDirectory: true); try fm.createDirectory(at: folder, withIntermediateDirectories: true); let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"; let safe = projectName.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_"); return folder.appendingPathComponent("\(safe)_\(f.string(from: Date())).mp4") }
    private static func addBaseTitle(to layer: CALayer, size: CGSize, horseName: String, projectName: String) { addText("AVO HORSE BIOMECH  •  \(horseName)  •  \(projectName)", to: layer, frame: CGRect(x: 24, y: size.height - 56, width: size.width - 48, height: 36), font: 22, color: UIColor.white.cgColor) }
    private static func addText(_ text: String, to layer: CALayer, frame: CGRect, font: CGFloat, color: CGColor) { let bg = CALayer(); bg.frame = frame.insetBy(dx: -10, dy: -8); bg.backgroundColor = UIColor.black.withAlphaComponent(0.58).cgColor; bg.cornerRadius = 10; layer.addSublayer(bg); let t = CATextLayer(); t.string = text; t.frame = frame; t.foregroundColor = color; t.font = UIFont.monospacedSystemFont(ofSize: font, weight: .bold); t.fontSize = font; t.alignmentMode = .left; t.contentsScale = UIScreen.main.scale; t.isWrapped = true; layer.addSublayer(t) }
    private static func addTimedText(_ o: AVOVideoTextOverlay, to layer: CALayer, size: CGSize, offset: Double) { let frame = CGRect(x: size.width * o.x, y: size.height * o.y, width: size.width * 0.70, height: max(60, o.size * 2.3)); let t = CATextLayer(); t.string = o.text; t.frame = frame; t.foregroundColor = UIColor.white.cgColor; t.font = UIFont.monospacedSystemFont(ofSize: CGFloat(o.size), weight: .black); t.fontSize = CGFloat(o.size); t.contentsScale = UIScreen.main.scale; t.shadowOpacity = 0.9; t.shadowRadius = 5; t.backgroundColor = UIColor.black.withAlphaComponent(0.50).cgColor; t.cornerRadius = 8; let start = max(0, o.startSeconds - offset); let dur = max(0.5, o.endSeconds - o.startSeconds); let a = CAKeyframeAnimation(keyPath: "opacity"); a.values = [0,1,1,0]; a.keyTimes = [0,0.08,0.92,1]; a.beginTime = AVCoreAnimationBeginTimeAtZero + start; a.duration = dur; a.fillMode = .both; a.isRemovedOnCompletion = false; t.add(a, forKey: "timedOpacity"); layer.addSublayer(t) }
    private static func addSkeleton(to layer: CALayer, size: CGSize) { let shape = CAShapeLayer(); let p = UIBezierPath(); let w=size.width, h=size.height; p.move(to: CGPoint(x:w*0.25,y:h*0.52)); p.addLine(to: CGPoint(x:w*0.38,y:h*0.42)); p.addLine(to: CGPoint(x:w*0.52,y:h*0.43)); p.addLine(to: CGPoint(x:w*0.67,y:h*0.49)); p.addLine(to: CGPoint(x:w*0.78,y:h*0.42)); p.move(to: CGPoint(x:w*0.38,y:h*0.42)); p.addLine(to: CGPoint(x:w*0.36,y:h*0.72)); p.move(to: CGPoint(x:w*0.52,y:h*0.43)); p.addLine(to: CGPoint(x:w*0.55,y:h*0.73)); p.move(to: CGPoint(x:w*0.67,y:h*0.49)); p.addLine(to: CGPoint(x:w*0.70,y:h*0.74)); p.move(to: CGPoint(x:w*0.28,y:h*0.52)); p.addLine(to: CGPoint(x:w*0.25,y:h*0.76)); shape.path = p.cgPath; shape.strokeColor = UIColor.systemGreen.cgColor; shape.fillColor = UIColor.clear.cgColor; shape.lineWidth = 5; shape.shadowColor = UIColor.systemGreen.cgColor; shape.shadowOpacity = 0.8; shape.shadowRadius = 7; layer.addSublayer(shape) }
    private static func addLiDAR(to layer: CALayer, size: CGSize) { let shape = CAShapeLayer(); let p = UIBezierPath(ovalIn: CGRect(x: size.width*0.18, y: size.height*0.35, width: size.width*0.64, height: size.height*0.28)); shape.path = p.cgPath; shape.strokeColor = UIColor.systemCyan.cgColor; shape.fillColor = UIColor.clear.cgColor; shape.lineWidth = 5; shape.lineDashPattern = [14,10]; shape.shadowColor = UIColor.systemCyan.cgColor; shape.shadowOpacity = 0.9; shape.shadowRadius = 8; layer.addSublayer(shape) }
    private static func addSegmentBar(segments: [AVOVideoEvidenceSegment], to layer: CALayer, size: CGSize, duration: Double, startOffset: Double) { let y = size.height - 96; for s in segments { let st = max(0, s.startSeconds - startOffset); let en = max(st, s.endSeconds - startOffset); let x = 24 + CGFloat(st / max(duration,1)) * (size.width - 48); let w = max(4, CGFloat((en-st) / max(duration,1)) * (size.width - 48)); let bar = CALayer(); bar.frame = CGRect(x:x,y:y,width:w,height:10); bar.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.82).cgColor; bar.cornerRadius = 5; layer.addSublayer(bar) } }
}

// MARK: - Compatibility helpers for older overlay snippets
extension SensorHub {
    var heartRateText: String { pulseStatus }
    var speedText: String { speedStatus }
}

struct AVOShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
