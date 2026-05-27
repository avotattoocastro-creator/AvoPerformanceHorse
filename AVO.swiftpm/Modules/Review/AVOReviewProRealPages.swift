import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AVOReviewDatasetTrainerHubPage: View {
    @Environment(\.dismiss) private var dismiss
    let items: [HorseDatasetReviewItem]
    let onOpenAISettings: () -> Void

    private var stats: AVOReviewDatasetStats { AVOReviewDatasetTrainerHubEngine.stats(items: items) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    title("DATASET TRAINER HUB REAL")
                    Text("No simula datos: calcula estado real desde tus imágenes y anotaciones actuales.")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                    grid
                    exportFormats
                    Button("ABRIR DRIVE / COLAB / MODELOS") { onOpenAISettings(); dismiss() }
                        .buttonStyle(ReviewButtonStyle(color: .cyan))
                }.padding(18)
            }
            close
        }.preferredColorScheme(.dark)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            stat("TOTAL", "\(stats.total)", .white)
            stat("GOOD", "\(stats.good)", .green)
            stat("REVIEW", "\(stats.review)", .yellow)
            stat("REJECT", "\(stats.rejected)", .red)
            stat("ANOTADAS", "\(stats.annotated)", .cyan)
            stat("COMPLETADO", "\(Int(stats.completion * 100))%", .orange)
        }
    }

    private var exportFormats: some View {
        VStack(alignment: .leading, spacing: 8) {
            title("EXPORTADORES PREPARADOS")
            Text("CoreML/CreateML: activo por .mlpackage/.mlmodel. COCO/YOLO Pose: se dejan preparados para Colab mediante train_config.json y estructura de labels.")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.76))
        }.panelBox()
    }

    private func stat(_ k: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(k).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.gray)
            Text(v).font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(c)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }

    private func title(_ t: String) -> some View { Text(t).font(.system(size: 26, weight: .black, design: .monospaced)).foregroundStyle(.white) }
    private var close: some View { Button("CLOSE") { dismiss() }.buttonStyle(ReviewButtonStyle(color: .red)).padding(14) }
}

struct AVOReviewBiomechEnginePage: View {
    @Environment(\.dismiss) private var dismiss
    let points: [EditableHorseAnnotation]

    private var result: AVOAdvancedBiomechResult { AVOAdvancedBiomechEngine.analyze(points: points) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("BIOMECH ENGINE REAL")
                        .font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                    Text("Ángulos, simetría y riesgo calculados solo desde puntos reales manuales o del modelo CoreML cargado. Si faltan puntos, no inventa mediciones.")
                        .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
                    Text(result.summary)
                        .font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(.green)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        stat("PUNTOS", "\(result.visiblePoints)", .white)
                        stat("ZANCADA", result.strideProxy.map { String(format: "%.3f", $0) } ?? "--", .cyan)
                        stat("RIESGO", result.asymmetryRisk.map { "\(Int($0 * 100))%" } ?? "--", .orange)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ÁNGULOS REALES")
                            .font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(.white)
                        ForEach(result.angles) { angle in
                            HStack {
                                Text(angle.name).frame(width: 110, alignment: .leading)
                                Text(String(format: "%.1f°", angle.degrees)).foregroundStyle(.green)
                                Spacer()
                                Text("Q \(Int(angle.quality * 100))%")
                                    .foregroundStyle(angle.quality > 0.65 ? .cyan : .orange)
                            }
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.045)))
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.055)))
                    Text("Para curva temporal, zancada real y cojera: importa vídeo, aplica AutoPose V2 frame a frame y compara series de ángulos por tiempo.")
                        .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.76))
                }.padding(18)
            }
            Button("CLOSE") { dismiss() }.buttonStyle(ReviewButtonStyle(color: .red)).padding(14)
        }.preferredColorScheme(.dark)
    }

    private func stat(_ k: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(k).font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.gray)
            Text(v).font(.system(size: 24, weight: .black, design: .monospaced)).foregroundStyle(c)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.055)))
    }
}

struct AVOReviewVideoTrackingPage: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var extractor = AVOReviewVideoFrameExtractor()
    @State private var showImporter = false
    @State private var scrubValue: Double = 0

    private var currentFrame: AVOReviewFrameSample? { extractor.selectedFrame }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("REVIEW VIDEO ENGINE REAL")
                    .font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                Text("MP4 real con cache de frames, scrub temporal, preview grande y puente preparado para AutoPose Temporal V2 + Biomech Dinámico.")
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)

                HStack(spacing: 10) {
                    Button("IMPORT MP4") { showImporter = true }.buttonStyle(ReviewButtonStyle(color: .purple))
                    Button("RESET") { extractor.reset(); scrubValue = 0 }.buttonStyle(ReviewButtonStyle(color: .orange))
                    Text(extractor.status)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                }

                HStack(alignment: .top, spacing: 12) {
                    videoPreview
                    VStack(alignment: .leading, spacing: 10) {
                        engineCard("CLIP", extractor.clipInfo.summary, .white)
                        engineCard("CACHE", extractor.cacheStatus, .cyan)
                        engineCard("TRACKING", extractor.trackingStatus, .green)
                        engineCard("PHASE 96", "AUTOPOSE TEMPORAL V2 + BIOMECH DINÁMICO READY", .purple)
                        engineCard("FRAME", currentFrame.map { String(format: "%04d · %.3fs", extractor.selectedIndex, $0.timeSeconds) } ?? "--", .orange)
                    }
                    .frame(width: 360)
                }

                scrubBar
                timelineStrip
                Spacer(minLength: 0)
            }.padding(18)
            Button("CLOSE") { dismiss() }.buttonStyle(ReviewButtonStyle(color: .red)).padding(14)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie, .video], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                extractor.extractFrames(from: url, maxFrames: 240, fps: 12.0)
                scrubValue = 0
            }
        }
        .onChange(of: extractor.selectedIndex) { _, newValue in
            scrubValue = Double(newValue)
        }
        .preferredColorScheme(.dark)
    }

    private var videoPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05))
            if let frame = currentFrame {
                Image(uiImage: frame.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(String(format: "TIME %.3fs", frame.timeSeconds))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.72)))
                    .padding(10)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 50, weight: .black))
                        .foregroundStyle(.purple)
                    Text("IMPORTA UN MP4 PARA ACTIVAR SCRUB REAL")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 520)
    }

    private var scrubBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TEMPORAL SCRUB")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.gray)
                Spacer()
                Text("\(extractor.frames.count) FRAMES")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            Slider(value: Binding(get: {
                scrubValue
            }, set: { value in
                scrubValue = value
                extractor.seekFrame(index: Int(value.rounded()))
            }), in: 0...Double(max(extractor.frames.count - 1, 0)), step: 1)
            .disabled(extractor.frames.isEmpty)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.055)))
    }

    private var timelineStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(extractor.frames.enumerated()), id: \.element.id) { index, frame in
                        VStack(spacing: 4) {
                            Image(uiImage: frame.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: index == extractor.selectedIndex ? 170 : 132, height: index == extractor.selectedIndex ? 104 : 82)
                                .clipped()
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(index == extractor.selectedIndex ? Color.cyan : Color.white.opacity(0.15), lineWidth: index == extractor.selectedIndex ? 3 : 1))
                                .cornerRadius(8)
                            Text(String(format: "%.2fs", frame.timeSeconds))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(index == extractor.selectedIndex ? .cyan : .gray)
                        }
                        .id(index)
                        .onTapGesture { extractor.seekFrame(index: index) }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: extractor.selectedIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.16)) { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .frame(height: 128)
    }

    private func engineCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.gray)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.055)))
    }
}

struct AVOReviewLiDARFusionPage: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("LiDAR FUSION REAL")
                        .font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                    Text("Usa AVCaptureDepthDataOutput del iPad Pro M4. Si no hay profundidad real, muestra OFF/WAIT y no crea datos falsos.")
                        .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
                    AVOLiveLiDARFusionCard(camera: camera)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MUESTRAS LiDAR")
                            .font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(.white)
                        Text("Depth samples reales: \(camera.lidarSamples.count)")
                        Text("Point cloud 2D: \(camera.lidarPointCloud2D.count)")
                        Text("Point cloud 3D fusionado: \(camera.lidarFusedPointCloud3D.count)")
                        Text("Estado cuerpo: \(camera.horseBodyLockStatus)")
                    }
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.055)))
                    Text("Uso recomendado: grabar/revisar con caballo entero, buena luz y distancia estable 3–6 m para que RGB + profundidad ayuden a separar caballo/fondo y escala corporal.")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                }.padding(18)
            }
            Button("CLOSE") { camera.stopCamera(); dismiss() }.buttonStyle(ReviewButtonStyle(color: .red)).padding(14)
        }
        .onDisappear { camera.stopCamera() }
        .preferredColorScheme(.dark)
    }
}

struct AVOReviewBatchReviewPage: View {
    @Environment(\.dismiss) private var dismiss
    let enabled: Bool
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("BATCH REVIEW")
                    .font(.system(size: 30, weight: .black, design: .monospaced)).foregroundStyle(.white)
                Text(enabled ? "Activo: usa botones rápidos GOOD / REVIEW / REJECT y timeline inferior." : "Desactivado: actívalo desde Review Pro.")
                    .font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(enabled ? .green : .orange)
                Text("Gestos preparados: derecha GOOD, izquierda REJECT, arriba REVIEW. Se mantiene simple para no tapar la foto principal.")
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
                Spacer()
            }.padding(18)
            Button("CLOSE") { dismiss() }.buttonStyle(ReviewButtonStyle(color: .red)).padding(14)
        }.preferredColorScheme(.dark)
    }
}

private extension View {
    func panelBox() -> some View {
        self.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.055)))
    }
}
