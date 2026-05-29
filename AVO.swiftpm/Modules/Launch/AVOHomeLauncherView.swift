import SwiftUI
import UIKit

struct AVOHomeLauncherView: View {
    @ObservedObject var hardware: AVOHardwareReceiver
    var onSelect: (DashboardMode) -> Void
    @State private var showUIStudio = false
    @StateObject private var uiLayoutStore = AVOVisualLayoutStore()

    private let appVersionText = "VERSION 1.3.0"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                homeBackground
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.06), Color.black.opacity(0.02), Color.black.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                liveEditableLaunchLayer(geo: geo)
            }
        }
        .onAppear { uiLayoutStore.load() }
        .fullScreenCover(isPresented: $showUIStudio, onDismiss: { uiLayoutStore.load() }) {
            AVOVisualEditorPage()
        }
    }


    private var launchLayout: AVOVisualScreenLayout {
        uiLayoutStore.layout(for: "Launch")
    }

    private func visualElement(_ name: String) -> AVOVisualElement? {
        launchLayout.elements.first { $0.name.uppercased() == name.uppercased() }
    }

    private func liveEditableLaunchLayer(geo: GeometryProxy) -> some View {
        ZStack {
            if let e = visualElement("VERSION") { versionBadgeEditable(geo: geo, e: e) } else { versionBadge(geo: geo) }
            if let e = visualElement("HORSE EDITION") { horseEditionEditable(geo: geo, e: e) } else { horseEditionTitle(geo: geo) }
            if let e = visualElement("MENU BAR") { launchMenuBar(geo: geo).visualPlaced(e, geo: geo) }
            if let e = visualElement("LOGO AREA") { launchLogoStatusEditable(geo: geo, e: e) }
            if let e = visualElement("STATUS BAR") { launchStatusEditable(geo: geo, e: e) }
        }
    }

    private func versionBadgeEditable(geo: GeometryProxy, e: AVOVisualElement) -> some View {
        HStack(spacing: 8) {
            Text(appVersionText)
                .font(.system(size: max(8, CGFloat(e.fontSize)), weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.93))
                .lineLimit(1)
            Circle().fill(Color.green).frame(width: 6, height: 6).shadow(color: Color.green.opacity(0.85), radius: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.44))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(e.cornerRadius)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(e.cornerRadius)).stroke(Color.white.opacity(0.34), lineWidth: 1))
        .visualPlaced(e, geo: geo)
    }

    private func horseEditionEditable(geo: GeometryProxy, e: AVOVisualElement) -> some View {
        HStack(spacing: max(10, geo.size.width * 0.016)) {
            Rectangle().fill(Color.red.opacity(0.88)).frame(width: geo.size.width * CGFloat(e.width) * 0.16, height: 4)
            Text("HORSE EDITION")
                .font(.system(size: max(10, CGFloat(e.fontSize)), weight: .black, design: .monospaced))
                .tracking(max(1, CGFloat(e.fontSize) * 0.32))
                .foregroundStyle(Color.white.opacity(0.80))
                .shadow(color: Color.black.opacity(0.95), radius: 5, x: 0, y: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
            Rectangle().fill(Color.red.opacity(0.88)).frame(width: geo.size.width * CGFloat(e.width) * 0.16, height: 4)
        }
        .visualPlaced(e, geo: geo)
    }

    private func launchLogoStatusEditable(geo: GeometryProxy, e: AVOVisualElement) -> some View {
        HStack(spacing: 18) {
            AVOHorseLogoTile()
            Text("AVO PERFORMANCE HORSE")
                .font(.system(size: max(9, CGFloat(e.fontSize)), weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.93))
                .lineLimit(1)
                .minimumScaleFactor(0.40)
            Rectangle().fill(Color.white.opacity(0.34)).frame(width: 1, height: max(24, geo.size.height * CGFloat(e.height) * 0.58)).padding(.leading, 8)
            Text("READY")
                .font(.system(size: max(9, CGFloat(e.fontSize)), weight: .black, design: .monospaced))
                .foregroundStyle(Color.green)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(e.cornerRadius)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(e.cornerRadius)).stroke(Color.white.opacity(0.20), lineWidth: 1))
        .visualPlaced(e, geo: geo)
    }

    private func launchStatusEditable(geo: GeometryProxy, e: AVOVisualElement) -> some View {
        HStack(spacing: 0) {
            launchStatusTile(icon: "server.rack", title: "SERVIDOR", value: launchServerValue, color: launchServerColor, geo: geo)
            launchStatusDivider
            launchStatusTile(icon: "figure.equestrian.sports", title: "CHALECO", value: launchVestValue, color: launchVestColor, geo: geo)
            launchStatusDivider
            launchStatusTile(icon: "house.lodge", title: "CUADRA", value: hardware.activeVestHorse == "NO HORSE" ? "SIN CABALLO" : hardware.activeVestHorse, color: .green, geo: geo)
            launchStatusDivider
            launchStatusTile(icon: "antenna.radiowaves.left.and.right", title: "RTK", value: hardware.gpsNTRIP ? "NTRIP ON" : hardware.gpsFix, color: launchRTKColor, geo: geo)
        }
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(e.cornerRadius)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(e.cornerRadius)).stroke(Color.white.opacity(0.20), lineWidth: 1))
        .visualPlaced(e, geo: geo)
    }

    private var launchServerValue: String {
        let s = hardware.cloudStatus.uppercased()
        if s.contains("ONLINE") { return "ONLINE" }
        if s.contains("FROZEN") || s.contains("DEGRADED") { return "FROZEN" }
        if hardware.cloudLastHTTPCode == 200 { return "HTTP 200" }
        return "OFFLINE"
    }

    private var launchServerColor: Color {
        let v = launchServerValue
        if v.contains("ONLINE") || v.contains("200") { return .green }
        if v.contains("FROZEN") { return .orange }
        return .red
    }

    private var launchVestValue: String {
        let s = hardware.vestConnectionState.uppercased()
        if s.contains("FROZEN") { return "FROZEN" }
        if hardware.vestIsConnected { return "CONECTADO" }
        if s.contains("OFFLINE") || s.contains("DISCONNECTED") { return "OFFLINE" }
        return "WAITING"
    }

    private var launchVestColor: Color {
        let v = launchVestValue
        if v == "CONECTADO" { return .green }
        if v == "FROZEN" { return .orange }
        return .red
    }

    private var launchRTKColor: Color {
        let fix = hardware.gpsFix.uppercased()
        if hardware.gpsNTRIP || fix.contains("FIXED") || fix.contains("RTK") { return .green }
        if fix.contains("GPS") || fix.contains("3D") || fix.contains("NMEA") { return .orange }
        return .red
    }

    private var homeBackground: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = AVOHomeImageLoader.load() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    AVOFallbackCarbonBackground()
                        .ignoresSafeArea()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    private func versionBadge(geo: GeometryProxy) -> some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Text(appVersionText)
                        .font(.system(size: max(14, geo.size.width * 0.013), weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.93))

                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.green.opacity(0.85), radius: 5)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.44))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )
                .padding(.top, max(28, geo.size.height * 0.035))
                .padding(.trailing, max(36, geo.size.width * 0.033))
            }
            Spacer()
        }
    }

    private func horseEditionTitle(geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 24) {
                Rectangle()
                    .fill(Color.red.opacity(0.88))
                    .frame(width: max(50, geo.size.width * 0.058), height: 4)
                Text("HORSE EDITION")
                    .font(.system(size: max(25, geo.size.width * 0.032), weight: .black, design: .monospaced))
                    .tracking(9)
                    .foregroundStyle(Color.white.opacity(0.80))
                    .shadow(color: Color.black.opacity(0.95), radius: 5, x: 0, y: 3)
                Rectangle()
                    .fill(Color.red.opacity(0.88))
                    .frame(width: max(50, geo.size.width * 0.058), height: 4)
            }
            .padding(.bottom, max(258, geo.size.height * 0.300))
        }
    }

    private func launchMenuBar(geo: GeometryProxy) -> some View {
        HStack(spacing: 5) {
            launchMenuButton(title: "DASHBOARD", icon: "gauge.medium", mode: .live, geo: geo)
            launchMenuButton(title: "BIOMECH", icon: "hare.fill", mode: .biomech, geo: geo)
            launchMenuButton(title: "REVIEW", icon: "point.3.connected.trianglepath.dotted", mode: .review, geo: geo)
            launchMenuButton(title: "AI TRAIN", icon: "brain.head.profile", mode: .aiTraining, geo: geo)
            launchMenuButton(title: "VIDEO", icon: "film", mode: .videoEditor, geo: geo)
            launchMenuButton(title: "ANALYSIS", icon: "waveform.path.ecg.rectangle", mode: .analysis, geo: geo)
            launchMenuButton(title: "REPLAY", icon: "play.circle", mode: .replay, geo: geo)
            launchMenuButton(title: "PROFILES", icon: "person.fill", mode: .profiles, geo: geo)
            launchMenuButton(title: "STABLE", icon: "list.bullet", mode: .stable, geo: geo)
            launchMenuButton(title: "SENSORS", icon: "antenna.radiowaves.left.and.right", mode: .sensors, geo: geo)
            launchMenuButton(title: "REPORT", icon: "doc.text", mode: .report, geo: geo)
            launchMenuButton(title: "SETTINGS", icon: "gearshape", mode: .settings, geo: geo)
            launchMenuButton(title: "HARDWARE", icon: "gearshape.fill", mode: .hardware, geo: geo)
            launchMenuButton(title: "DEVICES", icon: "binoculars", mode: .devices, geo: geo)
            launchMenuButton(title: "SERVER", icon: "server.rack", mode: .configHub, geo: geo)
            launchUIStudioButton(geo: geo)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.red.opacity(0.44), lineWidth: 1.0)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func launchUIStudioButton(geo: GeometryProxy) -> some View {
        let buttonWidth = max(58, min(76, geo.size.width * 0.050))
        return Button {
            showUIStudio = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.green)
                    .frame(height: 20)

                Text("UI STUDIO")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(Color.green)
            }
            .frame(width: buttonWidth, height: 52)
            .background(Color.black.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.green.opacity(0.24), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func launchMenuButton(title: String, icon: String, mode: DashboardMode, geo: GeometryProxy) -> some View {
        let buttonWidth = max(58, min(76, geo.size.width * 0.050))
        return Button {
            onSelect(mode)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.green)
                    .frame(height: 20)

                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(Color.green)
            }
            .frame(width: buttonWidth, height: 52)
            .background(Color.black.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.green.opacity(0.24), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bottomStatusArea(geo: GeometryProxy) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 18) {
                AVOHorseLogoTile()

                Text("AVO PERFORMANCE HORSE")
                    .font(.system(size: max(16, geo.size.width * 0.016), weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.93))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Rectangle()
                    .fill(Color.white.opacity(0.34))
                    .frame(width: 1, height: 48)
                    .padding(.leading, 8)

                Text("READY")
                    .font(.system(size: max(18, geo.size.width * 0.016), weight: .black, design: .monospaced))
                    .foregroundStyle(Color.green)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(width: geo.size.width * 0.38, height: 84, alignment: .leading)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )

            HStack(spacing: 0) {
                launchStatusTile(icon: "server.rack", title: "SERVIDOR", value: launchServerValue, color: launchServerColor, geo: geo)
                launchStatusDivider
                launchStatusTile(icon: "figure.equestrian.sports", title: "CHALECO", value: launchVestValue, color: launchVestColor, geo: geo)
                launchStatusDivider
                launchStatusTile(icon: "house.lodge", title: "CUADRA", value: hardware.activeVestHorse == "NO HORSE" ? "SIN CABALLO" : hardware.activeVestHorse, color: .green, geo: geo)
                launchStatusDivider
                launchStatusTile(icon: "antenna.radiowaves.left.and.right", title: "RTK", value: hardware.gpsNTRIP ? "NTRIP ON" : hardware.gpsFix, color: launchRTKColor, geo: geo)
            }
            .padding(.horizontal, 16)
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
        }
    }

    private var launchStatusDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.36))
            .frame(width: 1, height: 50)
            .padding(.horizontal, 12)
    }

    private func launchStatusTile(icon: String, title: String, value: String, color: Color = .green, geo: GeometryProxy) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: max(24, geo.size.width * 0.028), weight: .black))
                .foregroundStyle(color)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: max(10, geo.size.width * 0.0095), weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.64))
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: max(10, geo.size.width * 0.0095), weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                    .lineLimit(1)
            }

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.9), radius: 6)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}


private extension View {
    func visualPlaced(_ e: AVOVisualElement, geo: GeometryProxy) -> some View {
        let w = max(20, geo.size.width * CGFloat(e.width))
        let h = max(20, geo.size.height * CGFloat(e.height))
        return self
            .frame(width: w, height: h)
            .opacity(e.opacity)
            .position(x: geo.size.width * CGFloat(e.x), y: geo.size.height * CGFloat(e.y))
    }
}

private struct AVOHorseLogoTile: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )

            VStack(spacing: 3) {
                Image(systemName: "horse")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text("AVO")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
        }
        .frame(width: 72, height: 72)
    }
}

struct AVOHomeImageLoader {
    static func load() -> UIImage? {
        if let image = UIImage(named: "avo_home_background") { return image }
        if let image = UIImage(named: "avo_home_background.jpeg") { return image }
        if let image = UIImage(named: "avo_home_background.jpg") { return image }
        if let image = UIImage(named: "Resources/avo_home_background") { return image }
        if let image = UIImage(named: "Resources/avo_home_background.jpeg") { return image }

        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        let names = ["avo_home_background", "Resources/avo_home_background"]
        let exts = ["jpeg", "jpg", "png"]

        for bundle in bundles {
            for name in names {
                for ext in exts {
                    if let url = bundle.url(forResource: name, withExtension: ext),
                       let image = UIImage(contentsOfFile: url.path) {
                        return image
                    }
                }
            }

            if let resourcePath = bundle.resourcePath {
                for ext in exts {
                    let direct = URL(fileURLWithPath: resourcePath).appendingPathComponent("avo_home_background.\(ext)")
                    if let image = UIImage(contentsOfFile: direct.path) { return image }
                    let nested = URL(fileURLWithPath: resourcePath).appendingPathComponent("Resources/avo_home_background.\(ext)")
                    if let image = UIImage(contentsOfFile: nested.path) { return image }
                }
            }
        }

        return nil
    }
}

struct AVOFallbackCarbonBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.02, green: 0.03, blue: 0.04), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<34, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(i % 2 == 0 ? 0.030 : 0.015))
                    .frame(height: 2)
                    .rotationEffect(.degrees(-18))
                    .offset(y: CGFloat(i * 34 - 540))
            }

            Rectangle()
                .fill(Color.red.opacity(0.82))
                .frame(height: 5)
                .offset(y: 255)
        }
    }
}
