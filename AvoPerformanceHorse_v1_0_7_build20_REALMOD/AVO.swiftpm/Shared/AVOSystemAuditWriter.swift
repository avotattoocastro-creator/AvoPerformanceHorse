import Foundation

// MARK: - AVO PHASE 108 FIXED
// SYSTEM AUDIT WRITER
//
// Runtime helper to export current system state as TXT/JSON.
// Compile-safe Swift 6 correction:
// no MainActor-isolated static .shared reference in nonisolated default argument.

@MainActor
public final class AVOSystemAuditWriter {

    private let bus: AVOSystemDataBus
    private let registry: AVOSystemRegistry

    public init(bus: AVOSystemDataBus? = nil,
                registry: AVOSystemRegistry? = nil) {
        self.bus = bus ?? AVOSystemDataBus.shared
        self.registry = registry ?? AVOSystemRegistry.shared
    }

    public func buildAuditText() -> String {
        let enabled = registry.features.filter(\.isEnabled)
        let visible = registry.features.filter(\.isVisibleInUI)

        return """
        AVO APP SYSTEM AUDIT — RUNTIME SNAPSHOT

        Active area: \(bus.activeArea.rawValue)
        Pipeline mode: \(bus.pipelineMode.rawValue)
        Current video: \(bus.currentVideoName)
        Current frame: \(bus.currentFrameIndex)

        Pose frames in bus: \(bus.normalizedPoseTimeline.count)
        Biotech metric frames: \(bus.biotechMetrics.count)

        Enabled features: \(enabled.count)
        Visible features: \(visible.count)

        Last message: \(bus.lastSystemMessage)
        Updated: \(bus.lastUpdatedAt)

        Direction:
        REVIEW = IA retraining / dataset / ML quality.
        BIOTECH = biomechanical live/replay/clinical analysis.
        SYSTEM LINKER = connects shared pose, metrics, registry and export.
        """
    }

    public func writeAuditText(to url: URL) throws {
        try buildAuditText().write(to: url, atomically: true, encoding: .utf8)
    }

    public func writeBusJSON(to url: URL) throws {
        try bus.exportStateJSONData().write(to: url)
    }
}
