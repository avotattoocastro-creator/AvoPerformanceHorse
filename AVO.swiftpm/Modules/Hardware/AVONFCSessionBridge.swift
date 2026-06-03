import Foundation
import SwiftUI

// MARK: - HARDWARE PHASE 127
// NFC SESSION ID BRIDGE
//
// Lightweight app-side bridge for horse/rider NFC IDs.
// Real CoreNFC scan can call registerHorseTag/registerRiderTag.

@MainActor
public final class AVONFCSessionBridge: ObservableObject {

    public static let shared = AVONFCSessionBridge()

    @Published public private(set) var horseTag: String = ""
    @Published public private(set) var riderTag: String = ""
    @Published public private(set) var status: String = "NFC READY"

    private init() {}

    public func registerHorseTag(_ tag: String, displayName: String? = nil) {
        horseTag = tag
        let horseName = displayName?.isEmpty == false ? displayName! : tag
        AVOHardwareTelemetryHub.shared.selectHorse(name: horseName, horseId: tag)
        BiotechCompleteSystemController.shared.prepare(horseName: horseName)
        ReviewCompleteSystemController.shared.startReviewSession(horseName: horseName)
        status = "HORSE NFC: \(horseName)"
    }

    public func registerRiderTag(_ tag: String) {
        riderTag = tag
        AVOHardwareTelemetryHub.shared.selectRider(id: tag)
        status = "RIDER NFC: \(tag)"
    }

    public func clear() {
        horseTag = ""
        riderTag = ""
        status = "NFC CLEARED"
    }
}

@MainActor
public struct AVONFCSessionBridgePanel: View {

    @ObservedObject private var bridge = AVONFCSessionBridge.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("NFC HORSE/RIDER")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            Text("HORSE: \(bridge.horseTag.isEmpty ? "--" : bridge.horseTag)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))

            Text("RIDER: \(bridge.riderTag.isEmpty ? "--" : bridge.riderTag)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))

            Text(bridge.status)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(12)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.22), lineWidth: 1))
    }
}
