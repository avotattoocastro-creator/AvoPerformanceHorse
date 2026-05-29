import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - V25 SUPER FAST REVIEW PRO · TYPECHECK SAFE

struct EditableHorseAnnotation: Identifiable, Hashable {
    var id: HorseJoint { joint }
    var joint: HorseJoint
    
    var x: Double
    var y: Double
    var confidence: Double
    
    var isPredicted: Bool
    var isManual: Bool
    
    var originalPredictedX: Double? = nil
    var originalPredictedY: Double? = nil
    
    var correctionDistance: Double {
        guard let ox = originalPredictedX, let oy = originalPredictedY else { return 0 }
        let dx = x - ox
        let dy = y - oy
        return sqrt(dx * dx + dy * dy)
    }
    
    var correctionState: String {
        if originalPredictedX == nil { return "IA" }
        if correctionDistance > 0.003 { return "CORREGIDO" }
        return "SIN CAMBIO"
    }
}

struct HorseDatasetReviewItem: Identifiable, Hashable {
    var id: String { record.frameId }
    var record: HorseDatasetFrameRecord
    var annotationURL: URL
    var imageURL: URL
}

enum BoxResizeHandle: CaseIterable, Hashable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

private func v25Clamp(_ value: Double) -> Double {
    min(max(value, 0.0), 1.0)
}

private func v25ClampRect(_ rect: CGRect) -> CGRect {
    let w = min(max(rect.width, 0.025), 1.0)
    let h = min(max(rect.height, 0.025), 1.0)
    let x = min(max(rect.minX, 0.0), 1.0 - w)
    let y = min(max(rect.minY, 0.0), 1.0 - h)
    return CGRect(x: x, y: y, width: w, height: h)
}

private func v25Downsample(_ image: UIImage, maxPixel: CGFloat = 1150) -> UIImage {
    let longest = max(image.size.width, image.size.height)
    guard longest > maxPixel, longest > 0 else { return image }
    
    let scale = maxPixel / longest
    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    
    UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let out = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return out ?? image
}

// MARK: - MAIN VIEW

struct HorseDatasetReviewView: View {
    let datasetManager: HorseDatasetManager
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var items: [HorseDatasetReviewItem] = []
    @State private var allItems: [HorseDatasetReviewItem] = []
    @State private var selectedIndex: Int = 0
    
    @State private var image: UIImage?
    @State private var editableBox: CGRect?
    @State private var editablePoints: [EditableHorseAnnotation] = []
    @State private var selectedJoint: HorseJoint = .withers
    
    @State private var status: String = "REVIEW READY"
    @State private var showSkeleton: Bool = true
    @State private var showPredicted: Bool = true
    @State private var lockViewTransform: Bool = true
    @State private var autoLockZoomOnEdit: Bool = true
    @State private var showDatasetTimeline: Bool = true
    @State private var showAdvancedEditTools: Bool = false
    @State private var showReviewProHub: Bool = false
    @State private var batchReviewMode: Bool = false
    @State private var autoPoseV2Enabled: Bool = true
    @State private var videoTrackingEnabled: Bool = false
    @State private var anatomyAdvancedEnabled: Bool = false
    @State private var lidarFusionEnabled: Bool = false
    @State private var overlayHeatmapEnabled: Bool = false
    @State private var overlayErrorsEnabled: Bool = false
    @State private var manualConfidence: Double = 1.0
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    
    @State private var datasetFilter: DatasetClass = .all
    @State private var qualityReport: DatasetQualityReport?
    @State private var showImporter: Bool = false
    @State private var showAITrainingSettingsPage: Bool = false
    @State private var showDatasetTrainerHubPage: Bool = false
    @State private var showVideoTrackingPage: Bool = false
    @State private var showBiomechEnginePage: Bool = false
    @State private var showLiDARFusionPage: Bool = false
    @State private var showBatchReviewPage: Bool = false
    @State private var showFullScreenEditor: Bool = false
    @State private var isRunningAutoPose: Bool = false
    @State private var isExportingDataset: Bool = false
    @State private var exportReport: HorseDatasetExportReport? = nil
    @StateObject private var latestExportSharer = LatestExportSharer()
    @State private var showLatestExportShare: Bool = false
    @State private var poseModel: HorsePoseCoreML? = nil
    @StateObject private var autoPoseV2Engine = AVOAutoPoseV2Engine()
    @StateObject private var autoCorrectionLearning = ReviewAutoCorrectionLearningEngine()
    @ObservedObject private var reviewCompleteSystem = ReviewCompleteSystemController.shared
    @State private var lastAutoPosePredictedPoints: [ReviewCorrectionPointInput] = []
    @State private var lastAutoCorrectionSummary: String = "AUTO CORREGIR READY"
    
    @StateObject private var subjectSegmenter = HorseSubjectSegmenter()
    @State private var lastSegmentation: HorseSegmentationResult?
    
    @State private var detectorScaleHorizontal: Double = 1.0
    @State private var detectorScaleVertical: Double = 1.0
    @State private var keepDetectorAspect: Bool = false
    @State private var isDragging: Bool = false
    @State private var previousZoomLockBeforeEdit: Bool? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            rootContent
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .onAppear {
            loadItems()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item, .folder],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fullScreenCover(isPresented: $showAITrainingSettingsPage) {
            AVOAITrainingSettingsPage(datasetManager: datasetManager)
        }
        .fullScreenCover(isPresented: $showDatasetTrainerHubPage) {
            AVOReviewDatasetTrainerHubPage(items: allItems.isEmpty ? items : allItems) {
                showAITrainingSettingsPage = true
            }
        }
        .fullScreenCover(isPresented: $showVideoTrackingPage) {
            AVOReviewVideoTrackingPage()
        }
        .fullScreenCover(isPresented: $showBiomechEnginePage) {
            AVOReviewBiomechEnginePage(points: editablePoints)
        }
        .fullScreenCover(isPresented: $showLiDARFusionPage) {
            AVOReviewLiDARFusionPage()
        }
        .fullScreenCover(isPresented: $showBatchReviewPage) {
            AVOReviewBatchReviewPage(enabled: batchReviewMode)
        }
        .fullScreenCover(isPresented: $showFullScreenEditor) {
            AVOFullScreenPointEditorV25(
                image: image,
                box: $editableBox,
                points: $editablePoints,
                selectedJoint: $selectedJoint,
                showSkeleton: $showSkeleton,
                showPredicted: $showPredicted,
                manualConfidence: manualConfidence,
                autoLockZoomOnEdit: autoLockZoomOnEdit,
                onDeletePoint: removeSelectedPoint,
                onSave: { saveCurrentAnnotation() },
                onClose: { showFullScreenEditor = false }
            )
        }
        .sheet(isPresented: $showLatestExportShare) {
            if let url = latestExportSharer.zipURL {
                LatestExportShareSheet(url: url)
            } else {
                Text("Preparando export...")
            }
        }
    }
    
    private var rootContent: some View {
        VStack(spacing: 10) {
            header
            
            HStack(spacing: 8) {
                frameList
                    .frame(width: 300)
                
                editorPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(2)
                
                jointPanel
                    .frame(width: 350)
            }
            .padding(.horizontal, 10)

            if showDatasetTimeline {
                datasetTimeline
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("REVIEW IA · EDICIÓN DE PUNTOS")
                        .font(.system(size: 27, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Text("Edita puntos, limpia tandas, elimina imágenes malas y exporta dataset para reentrenar.")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                
                Spacer()
                
                Text(status)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.35), lineWidth: 1))
            }
            
            HStack(spacing: 12) {
                Button("IMPORT") { showImporter = true }
                    .buttonStyle(ReviewButtonStyle(color: .purple))
                
                Button(isExportingDataset ? "EXPORTANDO" : "EXPORT") { exportTrainingDataset() }
                    .buttonStyle(ReviewButtonStyle(color: .green))
                    .disabled(isExportingDataset)

                Button("AUTO COLAB") { exportColabTrainingPackage() }
                    .buttonStyle(ReviewButtonStyle(color: .cyan))
                    .disabled(isExportingDataset)

                Button("AI SETTINGS") { showAITrainingSettingsPage = true }
                    .buttonStyle(ReviewButtonStyle(color: .blue))
                
                Button("EXPORTS") { shareLatestTrainingExport() }
                    .buttonStyle(ReviewButtonStyle(color: .cyan))
                
                Button("RESET LISTA") { resetImageBatchList() }
                    .buttonStyle(ReviewButtonStyle(color: .red))
                
                Spacer()
                
                Button("CERRAR") { dismiss() }
                    .buttonStyle(ReviewButtonStyle(color: .orange))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }
    
    private var frameList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CAPTURAS")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            
            datasetStatsView
            
            Picker("Filtro", selection: $datasetFilter) {
                ForEach(DatasetClass.allCases) { cls in
                    Text(cls.rawValue).tag(cls)
                }
            }
            .pickerStyle(.menu)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .onChange(of: datasetFilter) {
                applyDatasetFilter()
            }
            
            ScrollView {
                VStack(spacing: 5) {
                    
                ForEach(items.indices, id: \.self) { index in
                        frameRow(index: index)
                    }
                }
            }
            
            HStack(spacing: 6) {
                Button("RECARGAR") { loadItems() }
                    .buttonStyle(ReviewButtonStyle(color: .purple))

                Button("ELIMINAR IMAGEN") { deleteCurrentImage() }
                    .buttonStyle(ReviewButtonStyle(color: .red))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
    
    private func frameRow(index: Int) -> some View {
        let item = items[index]
        let selected = index == selectedIndex
        
        return Button {
            selectedIndex = index
            loadSelectedItem()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(selected ? Color.green : Color.green.opacity(0.75))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.record.frameId)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .lineLimit(1)
                    
                    Text("\(item.record.label.uppercased()) · P:\(item.record.keypoints.count)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .foregroundStyle(selected ? Color.white : Color.cyan)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.cyan.opacity(0.35) : Color.white.opacity(0.055)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.cyan.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1))
        }
    }
    

    private var datasetTimeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(Array(items.indices), id: \.self) { index in
                    timelineButton(for: index)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 48)
        .background(timelineBackground)
        .overlay(timelineBorder)
    }

    private func timelineButton(for index: Int) -> some View {
        let isSelected = index == selectedIndex
        return Button {
            selectedIndex = index
            loadSelectedItem()
        } label: {
            VStack(spacing: 4) {
                timelineStatusBar(for: index)
                timelineIndexText(for: index, selected: isSelected)
            }
            .padding(6)
            .background(timelineButtonBackground(selected: isSelected))
            .overlay(timelineButtonBorder(selected: isSelected))
        }
    }

    private func timelineStatusBar(for index: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(timelineColor(for: items[index].record))
            .frame(width: 58, height: 8)
    }

    private func timelineIndexText(for index: Int, selected: Bool) -> some View {
        Text("\(index + 1)")
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(selected ? Color.white : Color.gray)
    }

    private func timelineButtonBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(selected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.045))
    }

    private func timelineButtonBorder(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(selected ? Color.cyan.opacity(0.9) : Color.white.opacity(0.08), lineWidth: 1)
    }

    private var timelineBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.045))
    }

    private var timelineBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.10), lineWidth: 1)
    }

    private func timelineColor(for record: HorseDatasetFrameRecord) -> Color {
        let label = record.label.lowercased()
        if label.contains("reject") || label.contains("bad") { return .red }
        if label.contains("good") || label.contains("manual_reviewed") { return .green }
        if !record.keypoints.isEmpty { return .blue }
        if label.contains("review") { return .yellow }
        return .gray
    }

    private var datasetStatsView: some View {
        let stats = DatasetQualityManager.stats(for: allItems.map { $0.record })
        
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("TOTAL \(stats.total)")
                Text("GOOD \(stats.good)")
                Text("REVIEW \(stats.review)")
            }
            
            HStack {
                Text("NEG \(stats.negative)")
                Text("REJECT \(stats.rejected)")
                Text("ANOT \(stats.annotated)")
            }
        }
        .font(.system(size: 16, weight: .black, design: .monospaced))
        .foregroundStyle(.cyan)
    }
    
    private var editorPanel: some View {
        VStack(spacing: 6) {
            topTools
            if showReviewProHub { reviewProStatusStrip }
            imageEditor
                .layoutPriority(3)
            bottomBar
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
    
    private var topTools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("EDITAR PUNTOS + EXPORT COLAB")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .padding(.trailing, 4)

                Button("PUNTOS") { showPredicted.toggle() }
                    .buttonStyle(ReviewButtonStyle(color: showPredicted ? .green : .gray))

                Button("ESQUELETO") { showSkeleton.toggle() }
                    .buttonStyle(ReviewOutlineButtonStyle())

                Button(lockViewTransform ? "ZOOM BLOQ" : "ZOOM LIBRE") { toggleZoomLock() }
                    .buttonStyle(ReviewButtonStyle(color: lockViewTransform ? .orange : .cyan))

                Button(autoLockZoomOnEdit ? "AUTO BLOQ ON" : "AUTO BLOQ OFF") {
                    autoLockZoomOnEdit.toggle()
                    status = autoLockZoomOnEdit ? "AUTO BLOQUEO ZOOM ACTIVO" : "AUTO BLOQUEO ZOOM DESACTIVADO"
                }
                .buttonStyle(ReviewButtonStyle(color: autoLockZoomOnEdit ? .green : .gray))

                Button(showDatasetTimeline ? "TIMELINE ON" : "TIMELINE OFF") { showDatasetTimeline.toggle() }
                    .buttonStyle(ReviewOutlineButtonStyle())

                Button(showAdvancedEditTools ? "OCULTAR AJUSTES" : "AJUSTES") { showAdvancedEditTools.toggle() }
                    .buttonStyle(ReviewOutlineButtonStyle())

                if showAdvancedEditTools {
                    Divider().frame(height: 34).background(Color.white.opacity(0.18))

                    Button("AÑADIR") { addSelectedPointAtCenter() }
                        .buttonStyle(ReviewButtonStyle(color: .yellow))
                    Button("MOVER") { status = "MOVER PUNTOS ACTIVO · AUTO BLOQ SOLO MIENTRAS ARRASTRAS" }
                        .buttonStyle(ReviewButtonStyle(color: .orange))
                    Button("HORSE ONLY") { saveHorseOnlyCleanCrop() }
                        .buttonStyle(ReviewButtonStyle(color: .cyan))
                    Button("ORIGINAL") { restoreOriginalImageFromBackup() }
                        .buttonStyle(ReviewButtonStyle(color: .purple))
                    Button("CROP") { cropCurrentToHorseBox() }
                        .buttonStyle(ReviewButtonStyle(color: .orange))
                    Button("LIMPIAR") { saveCleanedSegmentation() }
                        .buttonStyle(ReviewButtonStyle(color: .green))
                    Button("REVIEW PRO") { showReviewProHub.toggle(); status = showReviewProHub ? "REVIEW PRO HUB VISIBLE" : "REVIEW PRO HUB OCULTO" }
                        .buttonStyle(ReviewButtonStyle(color: .blue))
                    Button(autoPoseV2Enabled ? "AUTOPOSE V2 ON" : "AUTOPOSE V2 OFF") { autoPoseV2Enabled.toggle(); status = autoPoseV2Enabled ? "AUTOPOSE V2 ACTIVO" : "AUTOPOSE V2 DESACTIVADO" }
                        .buttonStyle(ReviewButtonStyle(color: autoPoseV2Enabled ? .green : .gray))
                    Button(batchReviewMode ? "BATCH ON" : "BATCH OFF") { batchReviewMode.toggle(); showBatchReviewPage = true; status = batchReviewMode ? "BATCH REVIEW ACTIVO" : "BATCH REVIEW OFF" }
                        .buttonStyle(ReviewButtonStyle(color: batchReviewMode ? .orange : .gray))
                    Button("DATASET HUB") { showDatasetTrainerHubPage = true; status = "DATASET TRAINER HUB REAL" }
                        .buttonStyle(ReviewButtonStyle(color: .cyan))
                    Button(videoTrackingEnabled ? "VIDEO ON" : "VIDEO OFF") { videoTrackingEnabled.toggle(); showVideoTrackingPage = true; status = videoTrackingEnabled ? "VIDEO TRACKING REAL" : "VIDEO TRACKING OFF" }
                        .buttonStyle(ReviewButtonStyle(color: videoTrackingEnabled ? .green : .gray))
                    Button(anatomyAdvancedEnabled ? "ANATOMÍA ON" : "ANATOMÍA OFF") { anatomyAdvancedEnabled.toggle(); showBiomechEnginePage = true; status = anatomyAdvancedEnabled ? AVOAdvancedBiomechEngine.analyze(points: editablePoints).summary : "ANATOMÍA AVANZADA OFF" }
                        .buttonStyle(ReviewButtonStyle(color: anatomyAdvancedEnabled ? .purple : .gray))
                    Button(lidarFusionEnabled ? "LiDAR ON" : "LiDAR OFF") { lidarFusionEnabled.toggle(); showLiDARFusionPage = true; status = lidarFusionEnabled ? "LiDAR FUSION REAL" : "LiDAR FUSION OFF" }
                        .buttonStyle(ReviewButtonStyle(color: lidarFusionEnabled ? .green : .gray))
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: showAdvancedEditTools ? 54 : 48)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.30)))
    }

    private var reviewProStatusStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                proChip("AUTOPOSE V2", autoPoseV2Enabled, .green)
                proChip("BATCH REVIEW", batchReviewMode, .orange)
                proChip("VIDEO TRACKING", videoTrackingEnabled, .cyan)
                proChip("ANATOMÍA", anatomyAdvancedEnabled, .purple)
                proChip("LiDAR FUSION", lidarFusionEnabled, .green)
                proChip("HEATMAP", overlayHeatmapEnabled, .yellow)
                proChip("ERRORES IA", overlayErrorsEnabled, .red)
                Text("El HUB es compacto: no reduce el tamaño de la foto y solo aparece si lo activas.")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private func proChip(_ title: String, _ enabled: Bool, _ color: Color) -> some View {
        Text(enabled ? "✓ \(title)" : "– \(title)")
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(enabled ? color : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(enabled ? 0.08 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke((enabled ? color : Color.gray).opacity(0.25), lineWidth: 1))
    }

    private var scaleTools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
            ScaleBox(title: "ESCALA HORIZONTAL", value: detectorScaleHorizontal) { newValue in
                setDetectorScale(axis: .horizontal, value: newValue)
            }
            
            ScaleBox(title: "ESCALA VERTICAL", value: detectorScaleVertical) { newValue in
                setDetectorScale(axis: .vertical, value: newValue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("MANTENER ASPECTO")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                
                Toggle("", isOn: $keepDetectorAspect)
                    .toggleStyle(.switch)
                    .frame(width: 58)
                
                Button("RESET ESCALA") { resetDetectorScaleControls() }
                    .buttonStyle(ReviewButtonStyle(color: .cyan))
                
                Divider().background(Color.white.opacity(0.2))
                
                Text("LOCK VIEW")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.orange)
                
                Toggle("", isOn: $lockViewTransform)
                    .toggleStyle(.switch)
                    .frame(width: 58)
            }
            .padding(8)
            .frame(width: 220, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.42)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.25)))
        }
    }
    
    private var guideText: some View {
        Text("GUÍA: GOOD = caballo claro + puntos válidos. REVIEW = pendiente. NEGATIVE = imagen buena sin caballo. REJECT = borrosa/cortada/lejana.")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(.yellow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
    
    private var imageEditor: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
            
            if let image {
                FastImageEditorV25(
                    image: image,
                    box: $editableBox,
                    points: $editablePoints,
                    selectedJoint: $selectedJoint,
                    showSkeleton: showSkeleton && !isDragging,
                    showPredicted: showPredicted,
                    manualConfidence: manualConfidence,
                    zoomScale: $zoomScale,
                    panOffset: $panOffset,
                    lockViewTransform: $lockViewTransform,
                    autoLockZoomOnEdit: autoLockZoomOnEdit,
                    isDragging: $isDragging,
                    previousZoomLockBeforeEdit: $previousZoomLockBeforeEdit
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Sin capturas. Pulsa DATA/REC/SNAP o importa un dataset.")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showFullScreenEditor = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 40)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.72)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                    }
                    .padding(12)
                    .disabled(image == nil)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var bottomBar: some View {
        VStack(spacing: 6) {
            annotationLegendBar
            qualityBox

            HStack(spacing: 8) {
                ReviewCompactSystemsDock()
                
                Button("AUTO POSE") { autoPoseCurrent() }.buttonStyle(ReviewButtonStyle(color: .cyan))
                Button("AUTO CORREGIR") { autoCorrectCurrentPointsFromLearning() }
                    .buttonStyle(ReviewButtonStyle(color: autoCorrectionLearning.lastStats.totalSamples > 0 ? .green : .gray))
                    .disabled(editablePoints.isEmpty)
                Button("GUARDAR CORRECCIÓN") { saveCurrentAutoCorrectionLearning() }
                    .buttonStyle(ReviewButtonStyle(color: editablePoints.isEmpty ? .gray : .purple))
                    .disabled(editablePoints.isEmpty)
                Button("CENTER") { autoCenterOnHorseBox() }.buttonStyle(ReviewButtonStyle(color: .cyan))
                Button("RESET PUNTOS") { editablePoints = []; status = "PUNTOS RESETEADOS" }.buttonStyle(ReviewButtonStyle(color: .orange))

                Spacer(minLength: 6)

                Button("✅ GOOD") { classifyCurrent(.good) }.buttonStyle(ReviewButtonStyle(color: .green))
                Button("⏳ REVIEW") { classifyCurrent(.review) }.buttonStyle(ReviewButtonStyle(color: .yellow))
                Button("❌ REJECT") { classifyCurrent(.rejected) }.buttonStyle(ReviewButtonStyle(color: .red))
            }
        }
    }
    

    private var annotationLegendBar: some View {
        HStack(spacing: 14) {
            legendChip(color: .green, text: "IA")
            legendChip(color: .orange, text: "CORRECCIÓN")
            legendChip(color: .cyan, text: "SIN CAMBIO")
            legendChip(color: .white, text: "ESQUELETO")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.48)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func legendChip(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(text)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var qualityBox: some View {
        HStack(spacing: 8) {
            if let q = qualityReport {
                Text("Q \(q.qualityPercent)%").foregroundStyle(q.color)
                Text("ÁREA \(Int(q.horseArea * 100))%")
                Text("PTS \(Int(q.pointRatio * 100))%")
                Text("BLUR \(Int(q.blurRisk * 100))%")
                Text(q.recommendation).foregroundStyle(q.color)
            } else {
                Text("QUALITY --")
            }
        }
        .font(.system(size: 16, weight: .black, design: .monospaced))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
    
    private var jointPanel: some View {
        JointPanelV25(
            selectedJoint: $selectedJoint,
            manualConfidence: $manualConfidence,
            editablePoints: $editablePoints,
            frameId: items.indices.contains(selectedIndex) ? items[selectedIndex].record.frameId : "--",
            onAddCenter: addSelectedPointAtCenter,
            onRemove: removeSelectedPoint,
            onSave: {
                saveCurrentAnnotation()
            }
        )
    }
    
    private enum ScaleAxis { case horizontal, vertical }
    
    private func toggleZoomLock() {
        lockViewTransform.toggle()
        status = lockViewTransform ? "ZOOM BLOQUEADO · EDITA PUNTOS" : "ZOOM LIBRE · PINZA Y ARRASTRA"
    }

    private func resetZoom() {
        zoomScale = 1.0
        panOffset = .zero
        status = "VISTA RESET"
    }

    private func autoSaveCurrentEdit(reason: String) {
        guard items.indices.contains(selectedIndex) else { return }
        guard editableBox != nil || !editablePoints.isEmpty else { return }
        saveCurrentAnnotation(extraNote: " | autosave_review_pro")
        status = reason
    }
    
    private func createDefaultHorseBox() {
        editableBox = CGRect(x: 0.18, y: 0.20, width: 0.64, height: 0.58)
        status = "CAJA CREADA"
    }
    
    private func scaleHorseBox(_ factor: Double) {
        guard let b = editableBox else {
            createDefaultHorseBox()
            return
        }
        
        let cx = b.midX
        let cy = b.midY
        let nw = min(max(b.width * factor, 0.04), 1.0)
        let nh = min(max(b.height * factor, 0.04), 1.0)
        
        editableBox = v25ClampRect(CGRect(x: cx - nw / 2, y: cy - nh / 2, width: nw, height: nh))
        status = "CAJA ESCALADA"
    }
    
    private func resetDetectorScaleControls() {
        detectorScaleHorizontal = 1.0
        detectorScaleVertical = 1.0
        status = "ESCALA RESET"
    }
    
    private func setDetectorScale(axis: ScaleAxis, value: Double) {
        guard let b = editableBox else {
            createDefaultHorseBox()
            return
        }
        
        let oldH = detectorScaleHorizontal
        let oldV = detectorScaleVertical
        var newBox = b
        
        switch axis {
        case .horizontal:
            detectorScaleHorizontal = value
            let factor = value / max(oldH, 0.01)
            let cx = b.midX
            let nw = min(max(b.width * factor, 0.03), 1.0)
            newBox = CGRect(x: cx - nw / 2, y: b.minY, width: nw, height: b.height)
            if keepDetectorAspect { detectorScaleVertical = value }
            
        case .vertical:
            detectorScaleVertical = value
            let factor = value / max(oldV, 0.01)
            let cy = b.midY
            let nh = min(max(b.height * factor, 0.03), 1.0)
            newBox = CGRect(x: b.minX, y: cy - nh / 2, width: b.width, height: nh)
            if keepDetectorAspect { detectorScaleHorizontal = value }
        }
        
        if keepDetectorAspect {
            let cx = b.midX
            let cy = b.midY
            let nw = min(max(b.width * value / max(oldH, 0.01), 0.03), 1.0)
            let nh = min(max(b.height * value / max(oldV, 0.01), 0.03), 1.0)
            newBox = CGRect(x: cx - nw / 2, y: cy - nh / 2, width: nw, height: nh)
        }
        
        editableBox = v25ClampRect(newBox)
        status = "ESCALA \(Int(value * 100))%"
    }
    
    private func autoCenterOnHorseBox() {
        guard let b = editableBox else {
            status = "CENTRAR: SIN CAJA"
            return
        }
        
        let target: CGFloat = 0.70
        let side = CGFloat(max(b.width, b.height))
        let newZoom = min(max(target / max(side, 0.05), 1.0), 5.0)
        
        zoomScale = newZoom
        panOffset = CGSize(
            width: CGFloat(0.5 - b.midX) * 480.0 * newZoom,
            height: CGFloat(0.5 - b.midY) * 300.0 * newZoom
        )
        
        status = "CABALLO CENTRADO · ZOOM \(String(format: "%.1f", newZoom))x"
    }
    
    private func addSelectedPointAtCenter() {
        editablePoints.removeAll { $0.joint == selectedJoint }
        
        editablePoints.append(
            EditableHorseAnnotation(
                joint: selectedJoint,
                x: 0.5,
                y: 0.5,
                confidence: manualConfidence,
                isPredicted: false,
                isManual: true,
                originalPredictedX: nil,
                originalPredictedY: nil
            )
        )
        
        status = "PUNTO AÑADIDO: \(selectedJoint.spanishName)"
    }
    
    private func removeSelectedPoint() {
        editablePoints.removeAll { $0.joint == selectedJoint }
        status = "PUNTO BORRADO"
    }
    
    private func markNegative() {
        editableBox = nil
        editablePoints = []
        saveCurrentAnnotation(forceNegative: true, forcedLabel: "negative_manual", extraNote: " | dataset_class_negative")
    }
    
    private func classifyCurrent(_ cls: DatasetClass) {
        switch cls {
        case .good:
            saveCurrentAnnotation(forcedLabel: "good_manual", extraNote: " | dataset_class_good")
        case .review:
            saveCurrentAnnotation(forcedLabel: "review_pending", extraNote: " | dataset_class_review")
        case .negative:
            saveCurrentAnnotation(forceNegative: true, forcedLabel: "negative_manual", extraNote: " | dataset_class_negative")
        case .rejected:
            saveCurrentAnnotation(forceNegative: true, forcedLabel: "rejected_bad_quality", extraNote: " | dataset_class_rejected")
        default:
            break
        }
    }
    
    private func autoClassifyCurrent() {
        guard let q = qualityReport else {
            classifyCurrent(.review)
            return
        }
        
        if editableBox != nil || !editablePoints.isEmpty {
            classifyCurrent(q.quality >= 0.70 && !editablePoints.isEmpty ? .good : .review)
        } else if q.recommendation.contains("REJECT") {
            classifyCurrent(.rejected)
        } else {
            classifyCurrent(.negative)
        }
    }
    
    private func temporalSmooth(points: [EditableHorseAnnotation]) -> [EditableHorseAnnotation] {
        // V2 ligero y real en app: suaviza micro-saltos manteniendo la corrección manual.
        // La continuidad completa entre vídeo/frames queda preparada sin simular mediciones.
        points.map { p in
            var out = p
            if p.isManual { out.confidence = max(p.confidence, manualConfidence) }
            return out
        }
    }

    private func applyBatchGesture(_ direction: String) {
        guard batchReviewMode else { return }
        switch direction {
        case "left": classifyCurrent(.rejected)
        case "right": classifyCurrent(.good)
        case "up": classifyCurrent(.review)
        default: break
        }
    }


    private func reviewCorrectionInputs(from points: [EditableHorseAnnotation]) -> [ReviewCorrectionPointInput] {
        points.map {
            ReviewCorrectionPointInput(
                jointName: $0.joint.rawValue,
                x: $0.x,
                y: $0.y,
                confidence: $0.confidence
            )
        }
    }


    private func predictedCorrectionInputsFallback() -> [ReviewCorrectionPointInput] {
        editablePoints.compactMap { point in
            if let px = point.originalPredictedX, let py = point.originalPredictedY {
                return ReviewCorrectionPointInput(
                    jointName: point.joint.rawValue,
                    x: px,
                    y: py,
                    confidence: point.confidence
                )
            }

            // If no original prediction exists, use the current position as neutral baseline.
            // This allows the button to give visible feedback instead of doing nothing.
            return ReviewCorrectionPointInput(
                jointName: point.joint.rawValue,
                x: point.x,
                y: point.y,
                confidence: point.confidence
            )
        }
    }

    private func saveCurrentAutoCorrectionLearning() {
        guard !editablePoints.isEmpty else {
            status = "AUTO CORRECCIÓN: NO HAY PUNTOS EDITADOS"
            return
        }

        let predictedBase: [ReviewCorrectionPointInput]
        if !lastAutoPosePredictedPoints.isEmpty {
            predictedBase = lastAutoPosePredictedPoints
        } else {
            predictedBase = predictedCorrectionInputsFallback()
        }

        guard !predictedBase.isEmpty else {
            status = "AUTO CORRECCIÓN: NO HAY PREDICCIÓN BASE"
            return
        }

        let box = editableBox ?? CGRect(x: 0, y: 0, width: 1, height: 1)

        let before = autoCorrectionLearning.lastStats.totalSamples

        autoCorrectionLearning.learn(
            predicted: predictedBase,
            corrected: reviewCorrectionInputs(from: editablePoints),
            horseBoxWidth: Double(max(0.0001, box.width)),
            horseBoxHeight: Double(max(0.0001, box.height)),
            viewTag: "review",
            modelName: "current"
        )

        let after = autoCorrectionLearning.lastStats.totalSamples
        let learnedNow = max(0, after - before)

        reviewCompleteSystem.learnCorrection(
            predicted: predictedBase,
            corrected: reviewCorrectionInputs(from: editablePoints),
            horseBoxWidth: Double(max(0.0001, box.width)),
            horseBoxHeight: Double(max(0.0001, box.height)),
            frameIndex: selectedIndex,
            modelName: "current"
        )

        lastAutoPosePredictedPoints = reviewCorrectionInputs(from: editablePoints)
        lastAutoCorrectionSummary = autoCorrectionLearning.status

        if learnedNow > 0 {
            status = "GUARDADO: \(learnedNow) CORRECCIONES · TOTAL \(after)"
        } else {
            status = "GUARDAR CORRECCIÓN: SIN CAMBIOS NUEVOS · TOTAL \(after)"
        }
    }

    private func autoCorrectCurrentPointsFromLearning() {
        guard !editablePoints.isEmpty else {
            status = "AUTO CORREGIR: NO HAY PUNTOS"
            return
        }

        let box = editableBox ?? CGRect(x: 0, y: 0, width: 1, height: 1)

        let results = autoCorrectionLearning.autoCorrect(
            points: reviewCorrectionInputs(from: editablePoints),
            horseBoxWidth: Double(box.width),
            horseBoxHeight: Double(box.height),
            viewTag: "review"
        )

        guard !results.isEmpty else {
            status = "AUTO CORREGIR: SIN RESULTADOS"
            return
        }

        let resultByJoint = Dictionary(uniqueKeysWithValues: results.map { ($0.jointName, $0) })

        editablePoints = editablePoints.map { point in
            guard let result = resultByJoint[point.joint.rawValue] else { return point }

            var updated = point
            updated.x = result.correctedX
            updated.y = result.correctedY
            updated.confidence = max(point.confidence, result.confidence)
            updated.isManual = true
            updated.isPredicted = point.isPredicted
            if updated.originalPredictedX == nil { updated.originalPredictedX = point.x }
            if updated.originalPredictedY == nil { updated.originalPredictedY = point.y }
            return updated
        }

        let applied = results.filter {
            abs($0.appliedDeltaX) > 0.00001 || abs($0.appliedDeltaY) > 0.00001
        }.count

        lastAutoCorrectionSummary = ReviewAutoCorrectDataAdapter.resultsSummary(results)
        refreshQualityPreview()
        status = "AUTO CORREGIR: \(applied) PUNTOS AJUSTADOS"
    }

    private func autoPoseCurrent() {
        guard !isRunningAutoPose else {
            status = "AUTO POSE YA EN PROCESO"
            return
        }
        
        guard let currentImage = image else {
            status = "AUTO POSE: NO IMAGE"
            return
        }
        
        isRunningAutoPose = true
        status = autoPoseV2Enabled ? "AUTOPOSE V2: TRACKING + SUAVIZADO" : "AUTO POSE: CARGANDO MODELO..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let localModel = HorsePoseCoreML()
            let roi = editableBox ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            let result = localModel.detectPose(in: currentImage, horseBox: roi)
            
            DispatchQueue.main.async {
                defer {
                    self.poseModel = nil
                    self.isRunningAutoPose = false
                }
                
                guard let result else {
                    self.status = "AUTO POSE: SIN PUNTOS / MODELO DESCARGADO"
                    return
                }
                
                let autoPoints = result.keypoints.map { kp in
                    EditableHorseAnnotation(
                        joint: kp.joint,
                        x: kp.x,
                        y: kp.y,
                        confidence: kp.confidence,
                        isPredicted: true,
                        isManual: false,
                        originalPredictedX: kp.x,
                        originalPredictedY: kp.y
                    )
                }
                
                guard !autoPoints.isEmpty else {
                    self.status = "AUTO POSE: 0 PUNTOS / MODELO DESCARGADO"
                    return
                }
                
                let previousEditablePoints = self.editablePoints
                self.editablePoints = autoPoints
                self.editableBox = self.autoBox(from: autoPoints) ?? self.editableBox
                
                if self.items.indices.contains(self.selectedIndex) {
                    self.qualityReport = DatasetQualityManager.analyze(
                        image: self.image,
                        record: self.previewRecord(from: self.items[self.selectedIndex].record)
                    )
                }
                
                
                if self.autoPoseV2Enabled {
                    let frameId = self.items.indices.contains(self.selectedIndex) ? self.items[self.selectedIndex].record.frameId : "frame_\(self.selectedIndex)"
                    self.editablePoints = self.autoPoseV2Engine.process(
                        frameId: frameId,
                        rawPredicted: autoPoints,
                        currentManual: previousEditablePoints,
                        imageBox: self.editableBox
                    )
                    self.editableBox = self.autoBox(from: self.editablePoints) ?? self.editableBox
                    self.saveCurrentAnnotation(extraNote: " | autopose_v2_real_model_temporal")
                    self.status = self.autoPoseV2Engine.status + " · AUTOSAVE"
                } else {
                    self.status = "AUTO POSE: \(autoPoints.count) PUNTOS · IA DESCARGADA"
                }
            }
        }
    }
    
    private func autoBox(from points: [EditableHorseAnnotation]) -> CGRect? {
        let visible = points.filter { $0.confidence > 0 }
        guard visible.count >= 2 else { return nil }
        
        let minX = visible.map { $0.x }.min() ?? 0
        let maxX = visible.map { $0.x }.max() ?? 1
        let minY = visible.map { $0.y }.min() ?? 0
        let maxY = visible.map { $0.y }.max() ?? 1
        let padX = max((maxX - minX) * 0.24, 0.04)
        let padY = max((maxY - minY) * 0.30, 0.06)
        
        return v25ClampRect(
            CGRect(
                x: minX - padX,
                y: minY - padY,
                width: (maxX - minX) + padX * 2,
                height: (maxY - minY) + padY * 2
            )
        )
    }
    
    private func segmentCurrentSubject() {
        guard items.indices.contains(selectedIndex), let currentImage = image else {
            status = "SEGMENT: SIN IMAGEN"
            return
        }
        
        let item = items[selectedIndex]
        
        guard let result = subjectSegmenter.segmentSubject(in: currentImage, frameId: item.record.frameId, datasetManager: datasetManager) else {
            status = subjectSegmenter.status
            return
        }
        
        lastSegmentation = result
        if let box = result.subjectBox { editableBox = box }
        refreshQualityPreview()
        status = subjectSegmenter.status
    }
    
    private func saveCleanedSegmentation() {
        guard items.indices.contains(selectedIndex), let cleaned = lastSegmentation?.cleanedImage else {
            status = "LIMPIAR: PRIMERO SEGMENT"
            return
        }
        
        let item = items[selectedIndex]
        guard let data = cleaned.jpegData(compressionQuality: 0.90) else { return }
        
        do {
            try backupOriginalIfNeeded(item)
            try data.write(to: item.imageURL, options: [.atomic])
            image = v25Downsample(cleaned)
            saveCurrentAnnotation(extraNote: " | background_cleaned")
            status = "FONDO LIMPIO GUARDADO"
        } catch {
            status = "LIMPIAR ERROR"
        }
    }
    
    private func saveHorseOnlyCleanCrop() {
        guard items.indices.contains(selectedIndex), let currentImage = image, let box = editableBox else {
            status = "HORSE ONLY: SIN IMAGEN/CAJA"
            return
        }
        
        let cropBox = padded(box, padding: 0.10)
        
        guard let cropped = crop(currentImage, normalizedBox: cropBox) else {
            status = "HORSE ONLY: CROP ERROR"
            return
        }
        
        let normalized = fitOnBlackCanvas(cropped, size: CGSize(width: 1280, height: 720))
        let item = items[selectedIndex]
        
        guard let data = normalized.jpegData(compressionQuality: 0.90) else { return }
        
        do {
            try backupOriginalIfNeeded(item)
            try data.write(to: item.imageURL, options: [.atomic])
            image = v25Downsample(normalized)
            editablePoints = reprojectToCrop(points: editablePoints, crop: cropBox)
            editableBox = CGRect(x: 0.05, y: 0.08, width: 0.90, height: 0.84)
            resetZoom()
            saveCurrentAnnotation(extraNote: " | horse_only_crop")
            status = "HORSE ONLY GUARDADO"
        } catch {
            status = "HORSE ONLY SAVE ERROR"
        }
    }
    
    private func cropCurrentToHorseBox() {
        guard items.indices.contains(selectedIndex), let currentImage = image, let box = editableBox else {
            status = "CROP: SIN IMAGEN/CAJA"
            return
        }
        
        let cropBox = padded(box, padding: 0.12)
        
        guard let cropped = crop(currentImage, normalizedBox: cropBox),
              let data = cropped.jpegData(compressionQuality: 0.90) else {
            status = "CROP ERROR"
            return
        }
        
        let item = items[selectedIndex]
        
        do {
            try backupOriginalIfNeeded(item)
            try data.write(to: item.imageURL, options: [.atomic])
            image = v25Downsample(cropped)
            editablePoints = reprojectToCrop(points: editablePoints, crop: cropBox)
            editableBox = CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.92)
            resetZoom()
            saveCurrentAnnotation(extraNote: " | tight_crop")
            status = "CROP GUARDADO"
        } catch {
            status = "CROP SAVE ERROR"
        }
    }
    
    private func normalizeCurrentHorseScale() {
        guard items.indices.contains(selectedIndex), let currentImage = image else {
            status = "SCALE: SIN IMAGEN"
            return
        }
        
        let normalized = fitOnBlackCanvas(currentImage, size: CGSize(width: 1280, height: 720))
        guard let data = normalized.jpegData(compressionQuality: 0.90) else { return }
        
        let item = items[selectedIndex]
        
        do {
            try backupOriginalIfNeeded(item)
            try data.write(to: item.imageURL, options: [.atomic])
            image = v25Downsample(normalized)
            resetZoom()
            saveCurrentAnnotation(extraNote: " | normalized_1280x720")
            status = "SCALE 1280x720 GUARDADO"
        } catch {
            status = "SCALE SAVE ERROR"
        }
    }
    
    private func rotateCurrentImage(degrees: Int) {
        guard items.indices.contains(selectedIndex), let current = image else { return }
        guard let rotated = current.rotatedRightV25(degrees: degrees) else { return }
        
        transformAnnotationsForRotation(degrees: degrees)
        
        let item = items[selectedIndex]
        if let data = rotated.jpegData(compressionQuality: 0.90) {
            try? data.write(to: item.imageURL, options: [.atomic])
        }
        
        image = v25Downsample(rotated)
        resetZoom()
        saveCurrentAnnotation(extraNote: " | rotated_\(degrees)")
        status = "IMAGEN GIRADA"
    }
    
    private func transformAnnotationsForRotation(degrees: Int) {
        let normalized = ((degrees % 360) + 360) % 360
        
        switch normalized {
        case 90:
            editablePoints = editablePoints.map { p in
                EditableHorseAnnotation(
                    joint: p.joint,
                    x: 1.0 - p.y,
                    y: p.x,
                    confidence: p.confidence,
                    isPredicted: false,
                    isManual: true,
                    originalPredictedX: p.originalPredictedX,
                    originalPredictedY: p.originalPredictedY
                )
            }
            if let b = editableBox { editableBox = rotateRect90CW(b) }
            
        case 180:
            editablePoints = editablePoints.map { p in
                EditableHorseAnnotation(
                    joint: p.joint,
                    x: 1.0 - p.x,
                    y: 1.0 - p.y,
                    confidence: p.confidence,
                    isPredicted: false,
                    isManual: true,
                    originalPredictedX: p.originalPredictedX,
                    originalPredictedY: p.originalPredictedY
                )
            }
            if let b = editableBox {
                editableBox = v25ClampRect(CGRect(x: 1.0 - b.maxX, y: 1.0 - b.maxY, width: b.width, height: b.height))
            }
            
        case 270:
            editablePoints = editablePoints.map { p in
                EditableHorseAnnotation(
                    joint: p.joint,
                    x: p.y,
                    y: 1.0 - p.x,
                    confidence: p.confidence,
                    isPredicted: false,
                    isManual: true,
                    originalPredictedX: p.originalPredictedX,
                    originalPredictedY: p.originalPredictedY
                )
            }
            if let b = editableBox { editableBox = rotateRect270CW(b) }
            
        default:
            break
        }
    }
    
    private func rotateRect90CW(_ rect: CGRect) -> CGRect {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ].map { CGPoint(x: 1.0 - $0.y, y: $0.x) }
        
        return rectFromCorners(corners)
    }
    
    private func rotateRect270CW(_ rect: CGRect) -> CGRect {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ].map { CGPoint(x: $0.y, y: 1.0 - $0.x) }
        
        return rectFromCorners(corners)
    }
    
    private func rectFromCorners(_ corners: [CGPoint]) -> CGRect {
        let minX = corners.map { $0.x }.min() ?? 0
        let maxX = corners.map { $0.x }.max() ?? 1
        let minY = corners.map { $0.y }.min() ?? 0
        let maxY = corners.map { $0.y }.max() ?? 1
        
        return v25ClampRect(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
    }
    
    private func exportTrainingDataset() {
        guard !isExportingDataset else { return }
        do { try rebuildManifestFromReviewedJSON() } catch {}
        isExportingDataset = true
        status = "EXPORT REENTRENO: PREPARANDO..."
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try HorseDatasetExporter().exportAll(from: datasetManager)
                DispatchQueue.main.async {
                    self.exportReport = result
                    self.isExportingDataset = false
                    self.latestExportSharer.shareExport(at: URL(fileURLWithPath: result.exportPath)) {
                        self.showLatestExportShare = true
                    }
                    self.status = "EXPORT ZIP OK · TOTAL \(result.totalRecords) · POSE \(result.poseRecords)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExportingDataset = false
                    self.status = "EXPORT ERROR: \(error.localizedDescription)"
                }
            }
        }
    }


    private func exportColabTrainingPackage() {
        guard !isExportingDataset else { return }
        do { try rebuildManifestFromReviewedJSON() } catch {}
        isExportingDataset = true
        status = "AUTO COLAB: SOLO GOOD/HORSE + NOTEBOOK..."
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try HorseDatasetExporter().exportPoseColabPack(from: datasetManager)
                try AVOAITrainingPipelineWriter.writeColabPackFiles(exportFolder: URL(fileURLWithPath: result.exportPath), report: result)
                DispatchQueue.main.async {
                    self.exportReport = result
                    self.isExportingDataset = false
                    self.latestExportSharer.shareExport(at: URL(fileURLWithPath: result.exportPath)) {
                        self.showLatestExportShare = true
                    }
                    self.status = "AUTO COLAB OK · PREFLIGHT PASS · ZIP + NOTEBOOK"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExportingDataset = false
                    self.status = "COLAB ZIP ERROR: \(error.localizedDescription)"
                }
            }
        }
    }

    private func shareLatestTrainingExport() {
        status = "BUSCANDO ÚLTIMO EXPORT..."
        latestExportSharer.shareLatestExport {
            showLatestExportShare = true
            status = latestExportSharer.status
        }
    }

    private func resetImageBatchList() {
        do {
            try datasetManager.prepareDataset(name: "AVOStableHorseDataset")
            let fm = FileManager.default
            let imageFiles = (try? fm.contentsOfDirectory(at: datasetManager.imagesURL, includingPropertiesForKeys: nil)) ?? []
            let annotationFiles = (try? fm.contentsOfDirectory(at: datasetManager.annotationsURL, includingPropertiesForKeys: nil)) ?? []

            for url in imageFiles { try? fm.removeItem(at: url) }
            for url in annotationFiles { try? fm.removeItem(at: url) }
            if fm.fileExists(atPath: datasetManager.manifestURL.path) { try? fm.removeItem(at: datasetManager.manifestURL) }

            items = []
            allItems = []
            selectedIndex = 0
            image = nil
            editableBox = nil
            editablePoints = []
            qualityReport = nil
            exportReport = nil
            status = "LISTA DE IMÁGENES RESETEADA · LISTA PARA NUEVA TANDA"
        } catch {
            status = "RESET ERROR: \(error.localizedDescription)"
        }
    }

    private func deleteCurrentImage() {
        guard items.indices.contains(selectedIndex) else {
            status = "ELIMINAR: SIN IMAGEN"
            return
        }

        let item = items[selectedIndex]
        let fm = FileManager.default
        try? fm.removeItem(at: item.imageURL)
        try? fm.removeItem(at: item.annotationURL)

        allItems.removeAll { $0.id == item.id }
        items.remove(at: selectedIndex)
        selectedIndex = min(selectedIndex, max(items.count - 1, 0))

        do { try rebuildManifestFromReviewedJSON() } catch {}

        if items.isEmpty {
            image = nil
            editableBox = nil
            editablePoints = []
            qualityReport = nil
            status = "IMAGEN ELIMINADA · LISTA VACÍA"
        } else {
            loadSelectedItem()
            status = "IMAGEN ELIMINADA"
        }
    }

    private func loadItems() {
        do { try datasetManager.prepareDataset(name: "AVOStableHorseDataset") } catch {}
        
        let files = (try? FileManager.default.contentsOfDirectory(at: datasetManager.annotationsURL, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        
        let loaded: [HorseDatasetReviewItem] = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let record = try? decoder.decode(HorseDatasetFrameRecord.self, from: data) else {
                    return nil
                }
                
                return HorseDatasetReviewItem(
                    record: record,
                    annotationURL: url,
                    imageURL: datasetManager.imagesURL.appendingPathComponent(record.imageFile)
                )
            }
            .sorted { $0.record.createdAt > $1.record.createdAt }
        
        allItems = loaded
        applyDatasetFilter(keepSelection: false)
        status = loaded.isEmpty ? "NO DATASET FRAMES" : "LOADED \(loaded.count) FRAMES"
        loadSelectedItem()
    }
    
    private func loadSelectedItem() {
        guard items.indices.contains(selectedIndex) else {
            image = nil
            editableBox = nil
            editablePoints = []
            qualityReport = nil
            return
        }
        
        let item = items[selectedIndex]
        
        if let loaded = UIImage(contentsOfFile: item.imageURL.path) {
            image = v25Downsample(loaded)
        } else {
            image = nil
        }
        
        if let b = item.record.horseBox {
            editableBox = CGRect(x: b.boxX, y: b.boxY, width: b.boxW, height: b.boxH)
        } else {
            editableBox = nil
        }
        
        editablePoints = item.record.keypoints.map {
            EditableHorseAnnotation(
                joint: $0.joint,
                x: $0.x,
                y: $0.y,
                confidence: $0.confidence,
                isPredicted: $0.isPredicted,
                isManual: !$0.isPredicted,
                originalPredictedX: $0.isPredicted ? $0.x : nil,
                originalPredictedY: $0.isPredicted ? $0.y : nil
            )
        }
        
        lastSegmentation = nil
        refreshQualityPreview(base: item.record)
        resetZoom()
        status = "EDITING \(item.record.frameId)"
    }
    
    private func applyDatasetFilter(keepSelection: Bool = true) {
        let currentId = keepSelection && items.indices.contains(selectedIndex) ? items[selectedIndex].id : nil
        
        items = DatasetQualityManager.filter(allItems, by: datasetFilter)
        
        if let currentId, let found = items.firstIndex(where: { $0.id == currentId }) {
            selectedIndex = found
        } else {
            selectedIndex = min(selectedIndex, max(items.count - 1, 0))
        }
    }
    
    private func refreshQualityPreview(base: HorseDatasetFrameRecord? = nil) {
        guard items.indices.contains(selectedIndex) else { return }
        let source = base ?? items[selectedIndex].record
        qualityReport = DatasetQualityManager.analyze(image: image, record: previewRecord(from: source))
    }
    
    private func previewRecord(from base: HorseDatasetFrameRecord) -> HorseDatasetFrameRecord {
        let detection = editableBox.map {
            HorseDetection(
                boxX: Double($0.minX),
                boxY: Double($0.minY),
                boxW: Double($0.width),
                boxH: Double($0.height),
                confidence: 1.0,
                source: "manual_iPad_review"
            )
        }
        
        let keypoints = editablePoints.map {
            HorseDatasetAnnotation(
                joint: $0.joint,
                x: $0.x,
                y: $0.y,
                confidence: $0.confidence,
                isPredicted: $0.isPredicted
            )
        }
        
        return HorseDatasetFrameRecord(
            frameId: base.frameId,
            createdAt: base.createdAt,
            imageFile: base.imageFile,
            label: base.label,
            split: base.split,
            horseVisible: detection != nil,
            horseBox: detection,
            keypoints: keypoints,
            trackingQuality: base.trackingQuality,
            gait: base.gait,
            lameness: base.lameness,
            latitude: base.latitude,
            longitude: base.longitude,
            notes: base.notes
        )
    }
    
    private func saveCurrentAnnotation(forceNegative: Bool = false, forcedLabel: String? = nil, extraNote: String = "") {
        guard items.indices.contains(selectedIndex) else { return }
        
        let item = items[selectedIndex]
        let old = item.record
        
        let detection: HorseDetection?
        if let b = editableBox, !forceNegative {
            detection = HorseDetection(
                boxX: Double(b.minX),
                boxY: Double(b.minY),
                boxW: Double(b.width),
                boxH: Double(b.height),
                confidence: old.horseBox?.confidence ?? 1.0,
                source: "manual_iPad_review_v25"
            )
        } else {
            detection = nil
        }
        
        let keypoints: [HorseDatasetAnnotation] = forceNegative ? [] : editablePoints.map {
            HorseDatasetAnnotation(
                joint: $0.joint,
                x: $0.x,
                y: $0.y,
                confidence: $0.confidence,
                isPredicted: false
            )
        }
        
        let correctedCount = editablePoints.filter { $0.correctionDistance > 0.003 }.count
        let avgCorrection = editablePoints.isEmpty ? 0 : editablePoints.map { $0.correctionDistance }.reduce(0, +) / Double(editablePoints.count)
        let maxCorrection = editablePoints.map { $0.correctionDistance }.max() ?? 0
        
        let auditNote =
        " | reviewed_v25_fast" +
        " | corrected_points:\(correctedCount)" +
        " | avg_correction:\(String(format: "%.4f", avgCorrection))" +
        " | max_correction:\(String(format: "%.4f", maxCorrection))" +
        extraNote
        
        let updated = HorseDatasetFrameRecord(
            frameId: old.frameId,
            createdAt: old.createdAt,
            imageFile: old.imageFile,
            label: forcedLabel ?? (forceNegative ? "negative_manual" : "horse_manual_reviewed"),
            split: old.split,
            horseVisible: detection != nil,
            horseBox: detection,
            keypoints: keypoints,
            trackingQuality: old.trackingQuality,
            gait: old.gait,
            lameness: old.lameness,
            latitude: old.latitude,
            longitude: old.longitude,
            notes: old.notes + auditNote
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            try encoder.encode(updated).write(to: item.annotationURL, options: [.atomic])
            
            let newItem = HorseDatasetReviewItem(
                record: updated,
                annotationURL: item.annotationURL,
                imageURL: item.imageURL
            )
            
            items[selectedIndex] = newItem
            
            if let g = allItems.firstIndex(where: { $0.id == newItem.id }) {
                allItems[g] = newItem
            }
            
            refreshQualityPreview(base: updated)
            try rebuildManifestFromReviewedJSON()
            
            status = "SAVED \(updated.label.uppercased())"
        } catch {
            status = "SAVE ERROR: \(error.localizedDescription)"
        }
    }
    
    private func rebuildManifestFromReviewedJSON() throws {
        let urls = (try? FileManager.default.contentsOfDirectory(at: datasetManager.annotationsURL, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        
        let records = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> HorseDatasetFrameRecord? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(HorseDatasetFrameRecord.self, from: data)
            }
            .sorted { $0.createdAt < $1.createdAt }
        
        let manifest = HorseDatasetManifest(
            name: "AVOStableHorseDataset",
            createdAt: Date().timeIntervalSince1970,
            version: 25,
            totalFrames: records.count,
            positiveFrames: records.filter { $0.horseVisible }.count,
            negativeFrames: records.filter { !$0.horseVisible }.count,
            anatomicalFrames: records.filter { !$0.keypoints.isEmpty }.count,
            records: records
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        try encoder.encode(manifest).write(to: datasetManager.manifestURL, options: [.atomic])
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            
            let foundModel = findModelPackage(startingAt: url)
            
            if let modelURL = foundModel {
                try importModelPackage(modelURL)
                status = "MODEL IMPORTED · AUTO POSE LISTO"
                return
            }
            
            let copied = try DatasetFolderImporter.importFolder(url, into: datasetManager)
            status = "IMPORTED \(copied) DATASET FILES"
            loadItems()
        } catch {
            status = "IMPORT ERROR: \(error.localizedDescription)"
        }
    }
    
    private func findModelPackage(startingAt url: URL) -> URL? {
        let fm = FileManager.default
        
        if ["mlpackage", "mlmodelc", "mlmodel"].contains(url.pathExtension.lowercased()) {
            return url
        }
        
        if url.lastPathComponent.lowercased().contains("mlpackage") {
            return url
        }
        
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "mlpackage" || ext == "mlmodelc" || ext == "mlmodel" {
                    return fileURL
                }
            }
        }
        
        return nil
    }
    
    private func importModelPackage(_ source: URL) throws {
        let fm = FileManager.default
        
        let access = source.startAccessingSecurityScopedResource()
        defer {
            if access {
                source.stopAccessingSecurityScopedResource()
            }
        }
        
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsFolder = docs.appendingPathComponent("Models", isDirectory: true)
        
        try fm.createDirectory(
            at: modelsFolder,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let targetName: String
        let ext = source.pathExtension.lowercased()
        
        if ext == "mlmodelc" {
            targetName = "AVOHorsePose.mlmodelc"
        } else if ext == "mlmodel" {
            targetName = "AVOHorsePose.mlmodel"
        } else {
            targetName = "AVOHorsePose.mlpackage"
        }
        
        let target = modelsFolder.appendingPathComponent(
            targetName,
            isDirectory: ext != "mlmodel"
        )
        
        let alternatives = [
            modelsFolder.appendingPathComponent("AVOHorsePose.mlpackage", isDirectory: true),
            modelsFolder.appendingPathComponent("AVOHorsePose.mlmodelc", isDirectory: true),
            modelsFolder.appendingPathComponent("AVOHorsePose.mlmodel", isDirectory: false)
        ]
        
        for old in alternatives {
            if fm.fileExists(atPath: old.path) {
                try? fm.removeItem(at: old)
            }
        }
        
        if fm.fileExists(atPath: target.path) {
            try? fm.removeItem(at: target)
        }
        
        try fm.copyItem(at: source, to: target)
        
        NotificationCenter.default.post(
            name: .avoHorsePoseModelUpdated,
            object: nil
        )
    }
    
    private func restoreOriginalImageFromBackup() {
        guard items.indices.contains(selectedIndex) else {
            status = "ORIGINAL: SIN IMAGEN"
            return
        }
        let item = items[selectedIndex]
        let originals = datasetManager.rootURL.appendingPathComponent("originals", isDirectory: true)
        let backup = originals.appendingPathComponent(item.record.imageFile)
        guard FileManager.default.fileExists(atPath: backup.path) else {
            status = "ORIGINAL: NO HAY BACKUP"
            return
        }
        do {
            try FileManager.default.copyItemReplacing(at: backup, to: item.imageURL)
            loadSelectedItem()
            saveCurrentAnnotation(extraNote: " | restored_original_image")
            status = "IMAGEN ORIGINAL RESTAURADA"
        } catch {
            status = "ORIGINAL ERROR: \(error.localizedDescription)"
        }
    }

    private func backupOriginalIfNeeded(_ item: HorseDatasetReviewItem) throws {
        let originals = datasetManager.rootURL.appendingPathComponent("originals", isDirectory: true)
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        
        let backup = originals.appendingPathComponent(item.record.imageFile)
        
        if !FileManager.default.fileExists(atPath: backup.path) {
            try? FileManager.default.copyItem(at: item.imageURL, to: backup)
        }
    }
    
    private func padded(_ box: CGRect, padding: Double) -> CGRect {
        v25ClampRect(
            CGRect(
                x: box.minX - box.width * padding,
                y: box.minY - box.height * padding,
                width: box.width * (1 + padding * 2),
                height: box.height * (1 + padding * 2)
            )
        )
    }
    
    private func crop(_ image: UIImage, normalizedBox: CGRect) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        
        let rect = CGRect(
            x: normalizedBox.minX * w,
            y: normalizedBox.minY * h,
            width: normalizedBox.width * w,
            height: normalizedBox.height * h
        ).integral
        
        guard let cropped = cg.cropping(to: rect) else { return nil }
        
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }
    
    private func fitOnBlackCanvas(_ image: UIImage, size: CGSize) -> UIImage {
        let aspect = image.size.width / max(image.size.height, 1)
        let targetAspect = size.width / max(size.height, 1)
        
        let drawSize: CGSize
        
        if aspect > targetAspect {
            drawSize = CGSize(width: size.width, height: size.width / aspect)
        } else {
            drawSize = CGSize(width: size.height * aspect, height: size.height)
        }
        
        let origin = CGPoint(
            x: (size.width - drawSize.width) / 2,
            y: (size.height - drawSize.height) / 2
        )
        
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        
        image.draw(in: CGRect(origin: origin, size: drawSize))
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result ?? image
    }
    
    private func reprojectToCrop(points: [EditableHorseAnnotation], crop: CGRect) -> [EditableHorseAnnotation] {
        points.compactMap { p in
            let nx = (p.x - crop.minX) / max(crop.width, 0.001)
            let ny = (p.y - crop.minY) / max(crop.height, 0.001)
            
            guard nx >= 0, nx <= 1, ny >= 0, ny <= 1 else { return nil }
            
            return EditableHorseAnnotation(
                joint: p.joint,
                x: nx,
                y: ny,
                confidence: p.confidence,
                isPredicted: false,
                isManual: true,
                originalPredictedX: p.originalPredictedX,
                originalPredictedY: p.originalPredictedY
            )
        }
    }
}

// MARK: - JOINT PANEL SAFE

private struct JointPanelV25: View {
    @Binding var selectedJoint: HorseJoint
    @Binding var manualConfidence: Double
    @Binding var editablePoints: [EditableHorseAnnotation]
    
    let frameId: String
    let onAddCenter: () -> Void
    let onRemove: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                title
                jointPicker
                confidenceControl
                actionButtons
                pointCounter
                correctionTable
                CorrectionSummaryPanel(points: editablePoints)
                metadataPanel
            }
            .padding(16)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
    
    private var title: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PUNTOS ANATÓMICOS")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            
            Text("EDICIÓN FINA")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.cyan)
        }
    }
    
    private var jointPicker: some View {
        Picker("Punto", selection: $selectedJoint) {
            ForEach(HorseJoint.allCases, id: \.self) { joint in
                Text(joint.spanishName).tag(joint)
            }
        }
        .pickerStyle(.menu)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
    
    private var confidenceControl: some View {
        HStack {
            Text("CONF")
            Slider(value: $manualConfidence, in: 0.5...1.0)
            Text(String(format: "%.2f", manualConfidence))
        }
        .font(.system(size: 17, weight: .bold, design: .monospaced))
        .foregroundColor(.white)
    }
    
    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("AÑADIR / MOVER AL CENTRO") {
                onAddCenter()
            }
            .buttonStyle(ReviewOutlineButtonStyle())
            
            HStack {
                Button("BORRAR PUNTO") {
                    onRemove()
                }
                .buttonStyle(ReviewOutlineButtonStyle())
                
                Button("GUARDAR") {
                    onSave()
                }
                .buttonStyle(ReviewOutlineButtonStyle())
            }
        }
    }
    
    private var pointCounter: some View {
        Text("Puntos marcados: \(editablePoints.count)")
            .font(.system(size: 16, weight: .black, design: .monospaced))
            .foregroundColor(.green)
    }
    
    private var correctionTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            CorrectionHeaderRow()
            
            ForEach(Array(editablePoints.prefix(10)), id: \.id) { p in
                CorrectionPointRow(
                    point: p,
                    isSelected: p.joint == selectedJoint
                )
            }
            
            if editablePoints.count > 10 {
                Text("+ \(editablePoints.count - 10) puntos más")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
    
    private var metadataPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("METADATOS")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            
            Text("Frame ID: \(frameId)")
            Text("Revisado por: Usuario")
            Text("Notas: reviewed_v25_fast")
        }
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .foregroundColor(.white.opacity(0.75))
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - SMALL COMPONENTS

private struct CorrectionSummaryPanel: View {
    let points: [EditableHorseAnnotation]
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RESUMEN DE CORRECCIONES")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("Puntos totales: \(points.count)")
                Text("Puntos corregidos: \(corrected)")
                Text("Cambio medio: \(String(format: "%.3f", avgCorrection))")
                Text("Cambio máximo: \(String(format: "%.3f", maxCorrection))")
                Text("Estado: GOOD PARA ENTRENAR")
                    .foregroundColor(.green)
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            
            Spacer()
            
            MiniCorrectionBars(points: points)
                .frame(width: 115, height: 82)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
    
    private var corrected: Int {
        points.filter { $0.correctionDistance > 0.003 }.count
    }
    
    private var avgCorrection: Double {
        guard !points.isEmpty else { return 0 }
        return points.map { $0.correctionDistance }.reduce(0, +) / Double(points.count)
    }
    
    private var maxCorrection: Double {
        points.map { $0.correctionDistance }.max() ?? 0
    }
}

private struct CorrectionHeaderRow: View {
    var body: some View {
        HStack {
            Text("PUNTO").frame(width: 78, alignment: .leading)
            Text("IA (X,Y)").frame(width: 62, alignment: .leading)
            Text("TÚ (X,Y)").frame(width: 62, alignment: .leading)
            Text("Δ").frame(width: 32, alignment: .leading)
            Text("ORIGEN").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 13, weight: .black, design: .monospaced))
        .foregroundColor(.white.opacity(0.85))
    }
}

private struct CorrectionPointRow: View {
    let point: EditableHorseAnnotation
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(point.correctionState == "CORREGIDO" ? Color.orange : Color.green)
                .frame(width: 7, height: 7)
            
            Text(point.joint.spanishShort)
                .frame(width: 67, alignment: .leading)
            
            Text(aiText)
                .frame(width: 62, alignment: .leading)
            
            Text(userText)
                .frame(width: 62, alignment: .leading)
            
            Text(String(format: "%.3f", point.correctionDistance))
                .frame(width: 32, alignment: .leading)
            
            Text(point.correctionState)
                .foregroundColor(point.correctionState == "CORREGIDO" ? .green : .purple)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 13, weight: .black, design: .monospaced))
        .foregroundColor(.white)
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.blue.opacity(0.80) : Color.clear)
        )
    }
    
    private var aiText: String {
        let x = point.originalPredictedX ?? point.x
        let y = point.originalPredictedY ?? point.y
        return "\(String(format: "%.2f", x)),\(String(format: "%.2f", y))"
    }
    
    private var userText: String {
        "\(String(format: "%.2f", point.x)),\(String(format: "%.2f", point.y))"
    }
}

private struct SmallToolBox<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)
            
            HStack(spacing: 10) {
                content
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

private struct ScaleBox: View {
    let title: String
    let value: Double
    let onSet: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(.green)
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            
            Slider(value: Binding(get: { value }, set: { onSet($0) }), in: 0.50...1.50, step: 0.05)
            
            HStack(spacing: 5) {
                Button("-50%") { onSet(0.50) }.buttonStyle(ReviewButtonStyle(color: .cyan))
                Button("-25%") { onSet(0.75) }.buttonStyle(ReviewButtonStyle(color: .cyan))
                Button("100%") { onSet(1.00) }.buttonStyle(ReviewButtonStyle(color: .cyan))
                Button("+25%") { onSet(1.25) }.buttonStyle(ReviewButtonStyle(color: .cyan))
                Button("+50%") { onSet(1.50) }.buttonStyle(ReviewButtonStyle(color: .cyan))
            }
        }
        .padding(8)
        .frame(width: 360, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

private struct ReviewOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.55 : 0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 42)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.25)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.16), lineWidth: 1))
    }
}

struct ReviewButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(configuration.isPressed ? 0.65 : 1.0))
            )
    }
}

private struct MiniCorrectionBars: View {
    let points: [EditableHorseAnnotation]
    
    var body: some View {
        let values = bucketValues()
        
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(values.indices, id: \.self) { i in
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 14, height: CGFloat(values[i]) * 5 + 4)
                    
                    Text(label(for: i))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
    
    private func bucketValues() -> [Int] {
        var buckets = [0, 0, 0, 0, 0]
        
        for p in points {
            let d = p.correctionDistance
            
            if d <= 0.005 {
                buckets[0] += 1
            } else if d <= 0.01 {
                buckets[1] += 1
            } else if d <= 0.02 {
                buckets[2] += 1
            } else if d <= 0.05 {
                buckets[3] += 1
            } else {
                buckets[4] += 1
            }
        }
        
        return buckets
    }
    
    private func label(for index: Int) -> String {
        switch index {
        case 0: return "0"
        case 1: return ".01"
        case 2: return ".02"
        case 3: return ".05"
        default: return "+.05"
        }
    }
}


// MARK: - FULL SCREEN POINT EDITOR

private struct AVOFullScreenPointEditorV25: View {
    let image: UIImage?
    @Binding var box: CGRect?
    @Binding var points: [EditableHorseAnnotation]
    @Binding var selectedJoint: HorseJoint
    @Binding var showSkeleton: Bool
    @Binding var showPredicted: Bool
    let manualConfidence: Double
    let autoLockZoomOnEdit: Bool
    let onDeletePoint: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lockViewTransform: Bool = false
    @State private var isDragging: Bool = false
    @State private var previousZoomLockBeforeEdit: Bool? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                FastImageEditorV25(
                    image: image,
                    box: $box,
                    points: $points,
                    selectedJoint: $selectedJoint,
                    showSkeleton: showSkeleton && !isDragging,
                    showPredicted: showPredicted,
                    manualConfidence: manualConfidence,
                    zoomScale: $zoomScale,
                    panOffset: $panOffset,
                    lockViewTransform: $lockViewTransform,
                    autoLockZoomOnEdit: autoLockZoomOnEdit,
                    isDragging: $isDragging,
                    previousZoomLockBeforeEdit: $previousZoomLockBeforeEdit
                )
                .ignoresSafeArea()
            } else {
                Text("SIN IMAGEN")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.gray)
            }

            fullScreenHUD
        }
        .statusBar(hidden: true)
    }

    private var fullScreenHUD: some View {
        VStack {
            HStack(alignment: .top) {
                Text(selectedJoint.spanishName.uppercased())
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.72)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.45), lineWidth: 1))

                Spacer()

                Button {
                    onDeletePoint()
                } label: {
                    Label("BORRAR PUNTO", systemImage: "trash")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.86)))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Spacer()

            HStack(alignment: .bottom) {
                Button {
                    onSave()
                } label: {
                    Label("GUARDAR", systemImage: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Label("CERRAR FULL", systemImage: "xmark")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .allowsHitTesting(true)
    }
}

// MARK: - IMAGE EDITOR

private struct FastImageEditorV25: View {
    let image: UIImage
    
    @Binding var box: CGRect?
    @Binding var points: [EditableHorseAnnotation]
    @Binding var selectedJoint: HorseJoint
    
    let showSkeleton: Bool
    let showPredicted: Bool
    let manualConfidence: Double
    
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize
    @Binding var lockViewTransform: Bool
    let autoLockZoomOnEdit: Bool
    @Binding var isDragging: Bool
    
    @State private var startScale: CGFloat = 1.0
    @State private var startOffset: CGSize = .zero
    @Binding var previousZoomLockBeforeEdit: Bool?
    
    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedRect(imageSize: image.size, container: geo.size)
            let drawRect = transformedRect(imageRect, scale: zoomScale, offset: panOffset)
            
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoomScale, anchor: .center)
                    .offset(panOffset)
                
                FastAnnotationLayerV25(
                    drawRect: drawRect,
                    box: $box,
                    points: $points,
                    selectedJoint: $selectedJoint,
                    showSkeleton: showSkeleton,
                    showPredicted: showPredicted,
                    manualConfidence: manualConfidence,
                    lockViewTransform: $lockViewTransform,
                    autoLockZoomOnEdit: autoLockZoomOnEdit,
                    isDragging: $isDragging,
                    previousZoomLockBeforeEdit: $previousZoomLockBeforeEdit
                )

                if zoomScale > 1.05 {
                    ReviewMiniMap(zoomScale: zoomScale, panOffset: panOffset)
                        .frame(width: 112, height: 72)
                        .position(x: geo.size.width - 72, y: 50)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        guard !lockViewTransform else { return }
                        if zoomScale > 1.05 {
                            zoomScale = 1.0
                            panOffset = .zero
                            startScale = 1.0
                            startOffset = .zero
                        } else {
                            zoomScale = 2.2
                            startScale = 2.2
                        }
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        guard !lockViewTransform else { return }
                        zoomScale = min(max(startScale * value, 1.0), 6.0)
                    }
                    .onEnded { _ in
                        guard !lockViewTransform else { return }
                        startScale = zoomScale
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard !lockViewTransform, zoomScale > 1.01 else { return }
                        
                        panOffset = CGSize(
                            width: startOffset.width + value.translation.width,
                            height: startOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        guard !lockViewTransform else { return }
                        startOffset = panOffset
                    }
            )
        }
    }
    
    private func fittedRect(imageSize: CGSize, container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else {
            return .zero
        }
        
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height
        
        let size: CGSize
        
        if imageAspect > containerAspect {
            size = CGSize(width: container.width, height: container.width / imageAspect)
        } else {
            size = CGSize(width: container.height * imageAspect, height: container.height)
        }
        
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
    
    private func transformedRect(_ rect: CGRect, scale: CGFloat, offset: CGSize) -> CGRect {
        let w = rect.width * scale
        let h = rect.height * scale
        
        return CGRect(
            x: rect.midX - w / 2 + offset.width,
            y: rect.midY - h / 2 + offset.height,
            width: w,
            height: h
        )
    }
}

private struct FastAnnotationLayerV25: View {
    let drawRect: CGRect
    
    @Binding var box: CGRect?
    @Binding var points: [EditableHorseAnnotation]
    @Binding var selectedJoint: HorseJoint
    
    let showSkeleton: Bool
    let showPredicted: Bool
    let manualConfidence: Double
    @Binding var lockViewTransform: Bool
    let autoLockZoomOnEdit: Bool
    
    @Binding var isDragging: Bool
    @Binding var previousZoomLockBeforeEdit: Bool?
    
    var body: some View {
        ZStack {
            if let b = box {
                boxShape(b)
            }
            
            if showSkeleton {
                skeletonShape
            }
            
            ForEach(points.indices, id: \.self) { i in
                pointDot(index: i)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            guard drawRect.contains(location) else { return }
            let nx = v25Clamp(Double((location.x - drawRect.minX) / max(drawRect.width, 1)))
            let ny = v25Clamp(Double((location.y - drawRect.minY) / max(drawRect.height, 1)))
            
            points.removeAll { $0.joint == selectedJoint }
            
            points.append(
                EditableHorseAnnotation(
                    joint: selectedJoint,
                    x: nx,
                    y: ny,
                    confidence: manualConfidence,
                    isPredicted: false,
                    isManual: true,
                    originalPredictedX: nil,
                    originalPredictedY: nil
                )
            )
        }
    }
    
    private var legendOverlay: some View {
        VStack(alignment: .leading, spacing: 9) {
            legendRow(color: .green, text: "PREDICCIÓN MODELO (IA)")
            legendRow(color: .orange, text: "CORRECCIÓN HUMANA")
            legendRow(color: .cyan, text: "SIN CAMBIO")
            
            HStack {
                Text("╌")
                    .foregroundColor(.white)
                
                Text("ESQUELETO")
                    .foregroundColor(.white)
            }
            .font(.system(size: 18, weight: .black, design: .monospaced))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.62)))
        .position(x: drawRect.minX + 155, y: drawRect.minY + 105)
    }
    
    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(text)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
    }
    
    private func boxShape(_ b: CGRect) -> some View {
        let r = denormalize(b)
        
        return ZStack {
            BoxMainRect(
                rect: r,
                drawRect: drawRect,
                box: $box,
                sourceBox: b,
                lockViewTransform: $lockViewTransform,
                autoLockZoomOnEdit: autoLockZoomOnEdit,
                isDragging: $isDragging,
                previousZoomLockBeforeEdit: $previousZoomLockBeforeEdit
            )
            
            ForEach(BoxResizeHandle.allCases, id: \.self) { handle in
                resizeHandle(handle: handle, rect: b)
            }
        }
    }
    
    private var skeletonShape: some View {
        Path { path in
            for edge in HorseJoint.skeletonEdges {
                guard let a = point(edge.from), let b = point(edge.to) else { continue }
                if !showPredicted && (a.isPredicted || b.isPredicted) { continue }
                
                path.move(to: pointPosition(a))
                path.addLine(to: pointPosition(b))
            }
        }
        .stroke(Color.white.opacity(0.78), style: StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
    }
    
    private func pointDot(index: Int) -> some View {
        let p = points[index]
        let visible = showPredicted || !p.isPredicted
        let pos = pointPosition(p)
        let size: CGFloat = p.joint == selectedJoint ? 17 : 13
        
        let pointColor: Color = p.correctionState == "CORREGIDO" ? .orange : .green
        
        return Group {
            if visible {
                Circle()
                    .fill(pointColor)
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                    .frame(width: size, height: size)
                    .position(pos)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                beginTemporaryEditLock()
                                isDragging = true
                                
                                if points[index].originalPredictedX == nil {
                                    points[index].originalPredictedX = points[index].x
                                    points[index].originalPredictedY = points[index].y
                                }
                                
                                let nx = v25Clamp(Double((value.location.x - drawRect.minX) / max(drawRect.width, 1)))
                                let ny = v25Clamp(Double((value.location.y - drawRect.minY) / max(drawRect.height, 1)))
                                
                                points[index].x = nx
                                points[index].y = ny
                                points[index].confidence = manualConfidence
                                points[index].isPredicted = false
                                points[index].isManual = true
                                selectedJoint = points[index].joint
                            }
                            .onEnded { _ in
                                isDragging = false
                                endTemporaryEditLock()
                            }
                    )
            }
        }
    }
    
    private func resizeHandle(handle: BoxResizeHandle, rect: CGRect) -> some View {
        let r = denormalize(rect)
        let p = handlePosition(handle, rect: r)
        
        return Circle()
            .fill(Color.white.opacity(0.95))
            .overlay(Circle().stroke(Color.green, lineWidth: 1.5))
            .frame(width: 18, height: 18)
            .position(p)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        beginTemporaryEditLock()
                        isDragging = true
                        box = resizedBox(rect, handle: handle, location: value.location)
                    }
                    .onEnded { _ in
                        isDragging = false
                        endTemporaryEditLock()
                    }
            )
    }
    

    private func beginTemporaryEditLock() {
        guard autoLockZoomOnEdit else { return }
        if previousZoomLockBeforeEdit == nil {
            previousZoomLockBeforeEdit = lockViewTransform
        }
        lockViewTransform = true
    }
    
    private func endTemporaryEditLock() {
        guard autoLockZoomOnEdit else { return }
        if let previous = previousZoomLockBeforeEdit {
            lockViewTransform = previous
        }
        previousZoomLockBeforeEdit = nil
    }
    
    private func resizedBox(_ rect: CGRect, handle: BoxResizeHandle, location: CGPoint) -> CGRect {
        let px = v25Clamp(Double((location.x - drawRect.minX) / max(drawRect.width, 1)))
        let py = v25Clamp(Double((location.y - drawRect.minY) / max(drawRect.height, 1)))
        
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY
        
        switch handle {
        case .topLeft:
            minX = px
            minY = py
        case .top:
            minY = py
        case .topRight:
            maxX = px
            minY = py
        case .right:
            maxX = px
        case .bottomRight:
            maxX = px
            maxY = py
        case .bottom:
            maxY = py
        case .bottomLeft:
            minX = px
            maxY = py
        case .left:
            minX = px
        }
        
        let minimum = 0.03
        
        if maxX - minX < minimum { maxX = minX + minimum }
        if maxY - minY < minimum { maxY = minY + minimum }
        
        return v25ClampRect(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
    }
    
    private func point(_ joint: HorseJoint) -> EditableHorseAnnotation? {
        points.first { $0.joint == joint }
    }
    
    private func pointPosition(_ point: EditableHorseAnnotation) -> CGPoint {
        CGPoint(
            x: drawRect.minX + CGFloat(point.x) * drawRect.width,
            y: drawRect.minY + CGFloat(point.y) * drawRect.height
        )
    }
    
    private func denormalize(_ rect: CGRect) -> CGRect {
        CGRect(
            x: drawRect.minX + rect.minX * drawRect.width,
            y: drawRect.minY + rect.minY * drawRect.height,
            width: rect.width * drawRect.width,
            height: rect.height * drawRect.height
        )
    }
    
    private func handlePosition(_ handle: BoxResizeHandle, rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .right:
            return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .left:
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

private struct BoxMainRect: View {
    let rect: CGRect
    let drawRect: CGRect
    @Binding var box: CGRect?
    let sourceBox: CGRect
    @Binding var lockViewTransform: Bool
    let autoLockZoomOnEdit: Bool
    @Binding var isDragging: Bool
    @Binding var previousZoomLockBeforeEdit: Bool?
    
    var body: some View {
        Rectangle()
            .stroke(Color.green, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        beginTemporaryEditLock()
                        isDragging = true
                        
                        let nx = v25Clamp(
                            Double((value.location.x - drawRect.minX) / max(drawRect.width, 1)) - sourceBox.width / 2
                        )
                        
                        let ny = v25Clamp(
                            Double((value.location.y - drawRect.minY) / max(drawRect.height, 1)) - sourceBox.height / 2
                        )
                        
                        box = v25ClampRect(
                            CGRect(
                                x: nx,
                                y: ny,
                                width: sourceBox.width,
                                height: sourceBox.height
                            )
                        )
                    }
                    .onEnded { _ in
                        isDragging = false
                        endTemporaryEditLock()
                    }
            )
    }
    
    private func beginTemporaryEditLock() {
        guard autoLockZoomOnEdit else { return }
        if previousZoomLockBeforeEdit == nil {
            previousZoomLockBeforeEdit = lockViewTransform
        }
        lockViewTransform = true
    }
    
    private func endTemporaryEditLock() {
        guard autoLockZoomOnEdit else { return }
        if let previous = previousZoomLockBeforeEdit {
            lockViewTransform = previous
        }
        previousZoomLockBeforeEdit = nil
    }
}


private struct ReviewMiniMap: View {
    let zoomScale: CGFloat
    let panOffset: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.62))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.35), lineWidth: 1))

            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.50), lineWidth: 1)
                .padding(8)

            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.green, lineWidth: 2)
                .frame(width: max(24, 86 / max(zoomScale, 1.0)), height: max(16, 50 / max(zoomScale, 1.0)))
                .offset(x: -panOffset.width * 0.035, y: -panOffset.height * 0.035)
        }
        .allowsHitTesting(false)
    }
}

extension UIImage {
    func rotatedRightV25(degrees: Int) -> UIImage? {
        let normalized = ((degrees % 360) + 360) % 360
        
        if normalized == 0 { return self }
        
        let radians = CGFloat(normalized) * .pi / 180
        
        var newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral
            .size
        
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        ctx.rotate(by: radians)
        
        draw(
            in: CGRect(
                x: -size.width / 2,
                y: -size.height / 2,
                width: size.width,
                height: size.height
            )
        )
        
        let rotated = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotated
    }
}


extension FileManager {
    func copyItemReplacing(at source: URL, to destination: URL) throws {
        if fileExists(atPath: destination.path) { try removeItem(at: destination) }
        try createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try copyItem(at: source, to: destination)
    }
}
