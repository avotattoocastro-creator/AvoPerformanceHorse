import SwiftUI

struct AVOUnifiedPageHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    let status: String?
    let accent: Color
    let closeTitle: String
    let onClose: () -> Void
    let actions: Actions

    init(
        title: String,
        subtitle: String = "",
        status: String? = nil,
        accent: Color = .green,
        closeTitle: String = "CERRAR",
        onClose: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.accent = accent
        self.closeTitle = closeTitle
        self.onClose = onClose
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }

            Spacer(minLength: 10)

            actions

            if let status = status, !status.isEmpty {
                Text(status.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color.black.opacity(0.68))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.34), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            AVOCommercialCloseButton(title: closeTitle, action: onClose)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(AVOCommercialTheme.panelDeep.opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: AVOCommercialTheme.corner).stroke(accent.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.corner))
    }
}

struct AVOUnifiedHeaderActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

struct AVOUnifiedPanelBackground: ViewModifier {
    let accent: Color
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.22), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.corner))
    }
}
