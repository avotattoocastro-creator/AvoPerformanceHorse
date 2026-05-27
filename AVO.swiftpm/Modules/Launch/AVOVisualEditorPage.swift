import SwiftUI
import UIKit

struct AVOVisualEditorPage: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = AVOVisualLayoutStore()
    @State private var selectedScreen = "Launch"
    @State private var selectedID: UUID? = nil
    @State private var exportText = ""
    @State private var showExport = false
    @State private var saveFlash = false

    private let screens = ["Launch", "Dashboard", "Biotech", "Review", "Stable", "Video", "Analysis", "Replay"]

    var body: some View {
        ZStack {
            AVOVisualBack()
            VStack(spacing: 12) {
                topBar
                HStack(spacing: 12) {
                    screenList.frame(width: 210)
                    AVOVisualCanvasView(layout: store.layout(for: selectedScreen), selectedID: $selectedID) { id, x, y in
                        store.move(screen: selectedScreen, id: id, x: x, y: y)
                    }
                    inspector.frame(width: 300)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            store.load()
            if selectedID == nil { selectedID = store.layout(for: selectedScreen).elements.first?.id }
        }
        .sheet(isPresented: $showExport) { AVOVisualExportView(text: exportText) }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 18, weight: .black)).foregroundColor(.white)
                    .frame(width: 44, height: 44).background(Color.white.opacity(0.12)).clipShape(Circle())
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text("AVO UI STUDIO").font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text("Editor visual real · arrastra elementos · guardado automático en JSON").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            if saveFlash { Text("GUARDADO ✓").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.green) }
            Button("RESET") { store.reset(screen: selectedScreen); selectedID = store.layout(for: selectedScreen).elements.first?.id }.buttonStyle(AVOVisualButtonStyle(color: .orange))
            Button("EXPORT JSON") { store.save(); exportText = store.exportJSON(); showExport = true }.buttonStyle(AVOVisualButtonStyle(color: .blue))
            Button("GUARDAR") { store.save(); withAnimation { saveFlash = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { saveFlash = false } }.buttonStyle(AVOVisualButtonStyle(color: .green))
        }.padding(.horizontal, 16).padding(.top, 14)
    }

    private var screenList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PANTALLAS").avoVisualTitle()
            ForEach(screens, id: \.self) { item in
                Button {
                    selectedScreen = item
                    selectedID = store.layout(for: item).elements.first?.id
                } label: {
                    HStack { Image(systemName: selectedScreen == item ? "rectangle.fill" : "rectangle"); Text(item.uppercased()); Spacer() }
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(selectedScreen == item ? .green : .white.opacity(0.72))
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(Color.black.opacity(selectedScreen == item ? 0.56 : 0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(selectedScreen == item ? Color.green.opacity(0.50) : Color.white.opacity(0.12), lineWidth: 1))
                }.buttonStyle(.plain)
            }
            Spacer()
            Text("Ahora ves una previsualización real de la pantalla, no cajas genéricas. Al mover o tocar sliders se guarda automáticamente en Documents/AVO_UI_STUDIO/visual_layouts.json.")
                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.48)).lineSpacing(4)
        }.padding(14).avoVisualPanel()
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSPECTOR").avoVisualTitle()
            if let id = selectedID, let element = store.element(screen: selectedScreen, id: id) {
                Text(element.name.uppercased()).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.green)
                AVOVisualSlider(title: "X", value: binding(id, \.x), range: 0...1)
                AVOVisualSlider(title: "Y", value: binding(id, \.y), range: 0...1)
                AVOVisualSlider(title: "WIDTH", value: binding(id, \.width), range: 0.04...0.96)
                AVOVisualSlider(title: "HEIGHT", value: binding(id, \.height), range: 0.03...0.65)
                AVOVisualSlider(title: "FONT", value: binding(id, \.fontSize), range: 8...48)
                AVOVisualSlider(title: "OPACITY", value: binding(id, \.opacity), range: 0.10...1.0)
                AVOVisualSlider(title: "CORNER", value: binding(id, \.cornerRadius), range: 0...32)
            } else {
                Text("Selecciona un elemento de la pantalla para editarlo.").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }.padding(14).avoVisualPanel()
    }

    private func binding(_ id: UUID, _ keyPath: WritableKeyPath<AVOVisualElement, Double>) -> Binding<Double> {
        Binding(get: { store.double(screen: selectedScreen, id: id, keyPath: keyPath) }, set: { value in store.set(screen: selectedScreen, id: id, keyPath: keyPath, value: value) })
    }
}

private struct AVOVisualCanvasView: View {
    let layout: AVOVisualScreenLayout
    @Binding var selectedID: UUID?
    let onMove: (UUID, Double, Double) -> Void
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.42)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.green.opacity(0.22), lineWidth: 1))
                AVOVisualRealPreview(layout: layout)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .allowsHitTesting(false)
                AVOVisualGrid()
                VStack { Text(layout.screen.uppercased()).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.50)).padding(.top, 14); Spacer() }
                ForEach(layout.elements) { item in
                    AVOVisualDraggableItem(element: item, selected: selectedID == item.id, canvas: geo.size, onSelect: { selectedID = item.id }, onMove: { x, y in onMove(item.id, x, y) })
                }
            }.contentShape(Rectangle()).onTapGesture { selectedID = nil }
        }
    }
}

private struct AVOVisualRealPreview: View {
    let layout: AVOVisualScreenLayout
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if layout.screen == "Launch" {
                    AVOVisualLaunchPreview(layout: layout, size: geo.size)
                } else {
                    AVOVisualGenericScreenPreview(layout: layout.screen, size: geo.size)
                }
            }
        }
    }
}

private struct AVOVisualLaunchPreview: View {
    let layout: AVOVisualScreenLayout
    let size: CGSize
    var body: some View {
        ZStack {
            if let image = AVOHomeImageLoader.load() {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).frame(width: size.width, height: size.height).clipped()
            } else {
                AVOFallbackCarbonBackground()
            }
            Color.black.opacity(0.18)
            ForEach(layout.elements) { element in
                AVOVisualRealElementMock(element: element, screen: "Launch", canvas: size)
            }
        }
    }
}

private struct AVOVisualGenericScreenPreview: View {
    let layout: String
    let size: CGSize
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.green.opacity(0.10), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12) {
                HStack { Text("AVO PERFORMANCE · \(layout.uppercased())").font(.system(size: 18, weight: .black, design: .monospaced)); Spacer(); Circle().fill(Color.green).frame(width: 10, height: 10) }.padding(18).background(Color.black.opacity(0.55))
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.45))
                    RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.38))
                }.padding(.horizontal, 18)
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.45)).frame(height: 90).padding(.horizontal, 18)
            }.foregroundColor(.white.opacity(0.80))
        }
    }
}

private struct AVOVisualRealElementMock: View {
    let element: AVOVisualElement
    let screen: String
    let canvas: CGSize
    var body: some View {
        let w = max(30, canvas.width * CGFloat(element.width))
        let h = max(24, canvas.height * CGFloat(element.height))
        let px = canvas.width * CGFloat(element.x)
        let py = canvas.height * CGFloat(element.y)
        Group {
            switch element.name.uppercased() {
            case "VERSION":
                Text("VERSION 1.1.2")
                    .font(.system(size: max(8, CGFloat(element.fontSize)), weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius)))
            case "HORSE EDITION":
                HStack(spacing: 18) { Rectangle().fill(Color.red).frame(width: w * 0.18, height: 3); Text("HORSE EDITION").tracking(8); Rectangle().fill(Color.red).frame(width: w * 0.18, height: 3) }
                    .font(.system(size: max(10, CGFloat(element.fontSize)), weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.82))
            case "MENU BAR":
                HStack(spacing: 4) { ForEach(["DASH", "BIO", "REV", "AI", "VID", "ANA", "REP", "STB"], id: \.self) { t in Text(t).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundColor(.green).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.42)).clipShape(RoundedRectangle(cornerRadius: 5)) } }
                    .padding(6).background(Color.black.opacity(0.58)).clipShape(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius))).overlay(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius)).stroke(Color.red.opacity(0.42)))
            case "LOGO AREA":
                HStack(spacing: 12) { Image(systemName: "horse").font(.system(size: max(18, CGFloat(element.fontSize)), weight: .black)); Text("AVO PERFORMANCE HORSE").font(.system(size: max(9, CGFloat(element.fontSize * 0.58)), weight: .black, design: .monospaced)); Text("READY").foregroundColor(.green).font(.system(size: max(9, CGFloat(element.fontSize * 0.58)), weight: .black, design: .monospaced)) }
                    .foregroundColor(.white.opacity(0.90)).padding(8).background(Color.black.opacity(0.56)).clipShape(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius))).overlay(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius)).stroke(Color.white.opacity(0.20)))
            case "STATUS BAR":
                HStack { ForEach(["SERVIDOR", "CHALECO", "CUADRA", "RTE"], id: \.self) { t in HStack { Circle().fill(Color.green).frame(width: 6, height: 6); Text(t).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(.green) }.frame(maxWidth: .infinity) } }
                    .padding(10).background(Color.black.opacity(0.56)).clipShape(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius))).overlay(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius)).stroke(Color.white.opacity(0.20)))
            default:
                EmptyView()
            }
        }
        .frame(width: w, height: h)
        .opacity(element.opacity)
        .position(x: px, y: py)
    }
}

private struct AVOVisualDraggableItem: View {
    let element: AVOVisualElement
    let selected: Bool
    let canvas: CGSize
    let onSelect: () -> Void
    let onMove: (Double, Double) -> Void
    @State private var startX: Double? = nil
    @State private var startY: Double? = nil

    var body: some View {
        let w = max(30, canvas.width * CGFloat(element.width))
        let h = max(24, canvas.height * CGFloat(element.height))
        let px = canvas.width * CGFloat(element.x)
        let py = canvas.height * CGFloat(element.y)
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius))
                .fill(Color.black.opacity(selected ? 0.16 : 0.035))
                .overlay(RoundedRectangle(cornerRadius: CGFloat(element.cornerRadius)).stroke(selected ? Color.green : Color.white.opacity(0.25), style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: selected ? [] : [7, 5])))
            if selected {
                VStack(spacing: 3) {
                    Image(systemName: element.icon).font(.system(size: 12, weight: .black)).foregroundColor(.green)
                    Text(element.name).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.90)).lineLimit(1).minimumScaleFactor(0.45)
                }
                .padding(5)
                .background(Color.black.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(width: w, height: h).position(x: px, y: py).onTapGesture { onSelect() }
        .gesture(DragGesture(minimumDistance: 1).onChanged { value in
            onSelect()
            if startX == nil { startX = element.x; startY = element.y }
            let nx = min(1, max(0, (startX ?? element.x) + Double(value.translation.width / canvas.width)))
            let ny = min(1, max(0, (startY ?? element.y) + Double(value.translation.height / canvas.height)))
            onMove(nx, ny)
        }.onEnded { _ in
            startX = nil
            startY = nil
        })
    }
}

private struct AVOVisualGrid: View {
    var body: some View { GeometryReader { geo in Path { path in
        var x: CGFloat = 0; while x <= geo.size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geo.size.height)); x += 32 }
        var y: CGFloat = 0; while y <= geo.size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geo.size.width, y: y)); y += 32 }
    }.stroke(Color.white.opacity(0.045), lineWidth: 1) }.allowsHitTesting(false) }
}

private struct AVOVisualSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var body: some View { VStack(alignment: .leading, spacing: 5) { HStack { Text(title).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.55)); Spacer(); Text(String(format: "%.3f", value)).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.green) }; Slider(value: $value, in: range) } }
}

private struct AVOVisualExportView: View {
    @Environment(\.dismiss) private var dismiss
    let text: String
    var body: some View { NavigationView { ScrollView { Text(text).font(.system(size: 11, weight: .regular, design: .monospaced)).foregroundColor(.white).textSelection(.enabled).padding().frame(maxWidth: .infinity, alignment: .leading) }.background(Color.black).navigationTitle("visual_layouts.json").toolbar { Button("Cerrar") { dismiss() } } }.preferredColorScheme(.dark) }
}

private struct AVOVisualBack: View { var body: some View { ZStack { Color.black.ignoresSafeArea(); LinearGradient(colors: [Color.green.opacity(0.16), Color.clear, Color.red.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() } } }
private struct AVOVisualButtonStyle: ButtonStyle { let color: Color; func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(.black).padding(.horizontal, 18).frame(height: 40).background(color.opacity(configuration.isPressed ? 0.75 : 1.0)).clipShape(RoundedRectangle(cornerRadius: 10)) } }
private extension View { func avoVisualPanel() -> some View { background(Color.black.opacity(0.48)).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1)) }; func avoVisualTitle() -> some View { font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.55)) } }

struct AVOVisualScreenLayout: Identifiable, Codable { var id: String { screen }; var screen: String; var elements: [AVOVisualElement] }
struct AVOVisualElement: Identifiable, Codable { var id: UUID; var name: String; var icon: String; var x: Double; var y: Double; var width: Double; var height: Double; var fontSize: Double; var opacity: Double; var cornerRadius: Double }

final class AVOVisualLayoutStore: ObservableObject {
    @Published var layouts: [AVOVisualScreenLayout] = []
    private var fileURL: URL { let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!; let folder = docs.appendingPathComponent("AVO_UI_STUDIO", isDirectory: true); try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); return folder.appendingPathComponent("visual_layouts.json") }
    func layout(for screen: String) -> AVOVisualScreenLayout { layouts.first(where: { $0.screen == screen }) ?? Self.defaultLayout(screen: screen) }
    func element(screen: String, id: UUID) -> AVOVisualElement? { layout(for: screen).elements.first(where: { $0.id == id }) }
    func double(screen: String, id: UUID, keyPath: KeyPath<AVOVisualElement, Double>) -> Double { element(screen: screen, id: id)?[keyPath: keyPath] ?? 0 }
    func set(screen: String, id: UUID, keyPath: WritableKeyPath<AVOVisualElement, Double>, value: Double) { update(screen: screen, id: id) { $0[keyPath: keyPath] = value }; save() }
    func move(screen: String, id: UUID, x: Double, y: Double) { update(screen: screen, id: id) { $0.x = x; $0.y = y }; save() }
    private func update(screen: String, id: UUID, edit: (inout AVOVisualElement) -> Void) { ensure(screen); guard let li = layouts.firstIndex(where: { $0.screen == screen }), let ei = layouts[li].elements.firstIndex(where: { $0.id == id }) else { return }; edit(&layouts[li].elements[ei]) }
    private func ensure(_ screen: String) { if !layouts.contains(where: { $0.screen == screen }) { layouts.append(Self.defaultLayout(screen: screen)) } }
    func save() { do { let data = try Self.encoder.encode(layouts); try data.write(to: fileURL, options: [.atomic]) } catch { print("AVO UI Studio save error:", error.localizedDescription) } }
    func load() { do { let data = try Data(contentsOf: fileURL); layouts = try Self.decoder.decode([AVOVisualScreenLayout].self, from: data); normalize() } catch { layouts = Self.defaultScreens(); save() } }
    private func normalize() {
        for s in Self.screenNames { ensure(s) }

        // MUY IMPORTANTE:
        // En la versión anterior esta función reseteaba automáticamente el Launch si detectaba
        // HORSE EDITION por encima de 0.62 o MENU BAR por encima de 0.78.
        // Eso destruía justo las posiciones que el usuario acababa de guardar en UI Studio.
        // Ahora normalize() solo asegura que existan las pantallas, pero NUNCA sobrescribe
        // posiciones editadas ni resetea elementos del Launch.
        save()
    }
    func exportJSON() -> String { do { let data = try Self.encoder.encode(layouts); return String(data: data, encoding: .utf8) ?? "{}" } catch { return "{}" } }
    func reset(screen: String) { let fresh = Self.defaultLayout(screen: screen); if let i = layouts.firstIndex(where: { $0.screen == screen }) { layouts[i] = fresh } else { layouts.append(fresh) }; save() }
    static let screenNames = ["Launch", "Dashboard", "Biotech", "Review", "Stable", "Video", "Analysis", "Replay"]
    static func defaultScreens() -> [AVOVisualScreenLayout] { screenNames.map { defaultLayout(screen: $0) } }
    static func defaultLayout(screen: String) -> AVOVisualScreenLayout {
        if screen == "Launch" {
            return AVOVisualScreenLayout(screen: screen, elements: [
                // Valores base fijados desde el JSON colocado manualmente por el usuario.
                // RESET vuelve exactamente a esta disposición.
                AVOVisualElement(id: UUID(), name: "VERSION", icon: "number", x: 0.9252469135802469, y: 0.032338618346545875, width: 0.145, height: 0.055, fontSize: 15, opacity: 0.6224264562129974, cornerRadius: 10),
                AVOVisualElement(id: UUID(), name: "HORSE EDITION", icon: "textformat", x: 0.45802469135802465, y: 0.5659909399773498, width: 0.48, height: 0.075, fontSize: 27, opacity: 0.82, cornerRadius: 8),
                AVOVisualElement(id: UUID(), name: "MENU BAR", icon: "square.grid.3x2", x: 0.4487654320987655, y: 0.7793148357870894, width: 0.6652941298484802, height: 0.2170220685005188, fontSize: 18, opacity: 0.8699264883995056, cornerRadius: 11),
                AVOVisualElement(id: UUID(), name: "LOGO AREA", icon: "horse", x: 0.4791975308641975, y: 0.9074462061155154, width: 0.385, height: 0.085, fontSize: 21, opacity: 0.86, cornerRadius: 10),
                AVOVisualElement(id: UUID(), name: "STATUS BAR", icon: "server.rack", x: 0.28820987654320984, y: 0.03315402038505097, width: 0.565, height: 0.085, fontSize: 17, opacity: 0.5969485282897949, cornerRadius: 10)
            ])
        }
        return AVOVisualScreenLayout(screen: screen, elements: [
            AVOVisualElement(id: UUID(), name: "TITLE", icon: "textformat", x: 0.50, y: 0.14, width: 0.52, height: 0.09, fontSize: 24, opacity: 0.80, cornerRadius: 12),
            AVOVisualElement(id: UUID(), name: "MAIN PANEL", icon: "rectangle.3.group", x: 0.50, y: 0.48, width: 0.76, height: 0.46, fontSize: 18, opacity: 0.75, cornerRadius: 14),
            AVOVisualElement(id: UUID(), name: "BOTTOM DOCK", icon: "server.rack", x: 0.50, y: 0.86, width: 0.72, height: 0.13, fontSize: 18, opacity: 0.75, cornerRadius: 14)
        ])
    }
    private static var encoder: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }
    private static var decoder: JSONDecoder { JSONDecoder() }
}
