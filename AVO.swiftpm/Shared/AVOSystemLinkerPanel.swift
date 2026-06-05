import SwiftUI

// MARK: - AVO PHASE 107
// SYSTEM LINKER PANEL
//
// Compact diagnostic panel.
// Recommended location: Hub/Settings, not permanently visible on main pages.

@MainActor
public struct AVOSystemLinkerPanel: View {

    @ObservedObject private var bus = AVOSystemDataBus.shared
    @ObservedObject private var registry = AVOSystemRegistry.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVO SYSTEM LINKER")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            HStack {
                box("AREA", bus.activeArea.rawValue.uppercased())
                box("MODE", bus.pipelineMode.rawValue)
                box("FRAME", "\(bus.currentFrameIndex)")
            }

            HStack {
                box("POSE", "\(bus.normalizedPoseTimeline.count)")
                box("BIOTECH", "\(bus.biotechMetrics.count)")
                box("VIDEO", bus.currentVideoName.isEmpty ? "--" : bus.currentVideoName)
            }

            Text(bus.lastSystemMessage)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)

            Divider().background(Color.white.opacity(0.15))

            Text("VISIBLE FEATURES")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))

            ForEach(registry.visibleFeatures(for: bus.activeArea)) { state in
                HStack {
                    Circle()
                        .fill(state.isEnabled ? Color.green : Color.red)
                        .frame(width: 7, height: 7)

                    Text(state.feature.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func box(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
