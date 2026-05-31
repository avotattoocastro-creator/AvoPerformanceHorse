import SwiftUI

// MARK: - BIOTECH PHASE 117
// DATA ON/OFF BUTTON
//
// This is the exact button needed in BIOTECH bottom red/overlay bar.
// Place it where the current DATA button is.

@MainActor
public struct BiotechDataToggleButton: View {

    @ObservedObject private var bridge = BiotechDataToReviewBridge.shared

    public var requestedFPS: Int

    public init(requestedFPS: Int = 120) {
        self.requestedFPS = requestedFPS
    }

    public var body: some View {
        Button {
            bridge.toggleData(requestedFPS: requestedFPS)
        } label: {
            VStack(spacing: 3) {
                Text("DATA")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))

                Text(bridge.isDataOn ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .foregroundStyle(bridge.isDataOn ? Color.black : Color.white)
            .frame(minWidth: 64, minHeight: 42)
            .background(bridge.isDataOn ? Color.green : Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(bridge.isDataOn ? Color.white.opacity(0.65) : Color.purple.opacity(0.85), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bridge.isDataOn ? "DATA ON, sending frames to REVIEW" : "DATA OFF")
    }
}

@MainActor
public struct BiotechDataStatusBadge: View {

    @ObservedObject private var bridge = BiotechDataToReviewBridge.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(bridge.isDataOn ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(bridge.shortHUD)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            if bridge.isDataOn {
                Text("\(bridge.requestedFPS)FPS → REVIEW")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
