import SwiftUI

enum AVOCommercialTheme {
    static let background = Color(red: 0.006, green: 0.010, blue: 0.012)
    static let panel = Color(red: 0.022, green: 0.034, blue: 0.038)
    static let panelDeep = Color(red: 0.010, green: 0.018, blue: 0.021)
    static let neonGreen = Color(red: 0.16, green: 1.00, blue: 0.46)
    static let neonCyan = Color(red: 0.12, green: 0.86, blue: 1.00)
    static let neonOrange = Color(red: 1.00, green: 0.62, blue: 0.12)
    static let neonRed = Color(red: 1.00, green: 0.18, blue: 0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.64)
    static let corner: CGFloat = 14
    static let smallCorner: CGFloat = 10
    static let pagePadding: CGFloat = 14
    static let gap: CGFloat = 10

    static func statusColor(connected: Bool, degraded: Bool = false) -> Color {
        if !connected { return neonRed }
        return degraded ? neonOrange : neonGreen
    }
}

struct AVOCommercialCloseButton: View {
    var title: String = "CERRAR"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .black))
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(minWidth: 104, minHeight: 44)
            .padding(.horizontal, 8)
            .background(LinearGradient(colors: [AVOCommercialTheme.neonRed.opacity(0.95), Color.red.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner).stroke(AVOCommercialTheme.neonRed.opacity(0.70), lineWidth: 1.2))
            .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner))
            .shadow(color: AVOCommercialTheme.neonRed.opacity(0.28), radius: 10, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
}

struct AVOCommercialHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    var accent: Color = AVOCommercialTheme.neonGreen
    var onClose: () -> Void
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: AVOCommercialTheme.gap) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(AVOCommercialTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                if !subtitle.isEmpty {
                    Text(subtitle.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.60)
                }
            }
            Spacer(minLength: 8)
            actions
            AVOCommercialCloseButton(action: onClose)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 62)
        .background(AVOCommercialTheme.panelDeep.opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: AVOCommercialTheme.corner).stroke(accent.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.corner))
    }
}

struct AVOCommercialCard<Content: View>: View {
    let title: String
    var accent: Color = AVOCommercialTheme.neonCyan
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer()
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LinearGradient(colors: [AVOCommercialTheme.panel.opacity(0.96), AVOCommercialTheme.panelDeep.opacity(0.96)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: AVOCommercialTheme.corner).stroke(accent.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.corner))
        .shadow(color: accent.opacity(0.08), radius: 14, x: 0, y: 0)
    }
}

struct AVOCommercialStatusPill: View {
    let title: String
    let value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
            Text(value.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 108, minHeight: 44, alignment: .leading)
        .background(Color.black.opacity(0.50))
        .overlay(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner).stroke(color.opacity(0.32), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner))
    }
}

extension View {
    func avoCommercialPagePadding() -> some View {
        self.padding(.horizontal, AVOCommercialTheme.pagePadding).padding(.vertical, 10)
    }

    func avoResponsiveFrame() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
