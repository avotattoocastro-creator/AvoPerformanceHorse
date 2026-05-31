import Foundation
import SwiftUI

// MARK: - AVO PHASE 107
// SYSTEM REGISTRY
//
// Central feature registry.
// Goal: avoid screens becoming overloaded.
// Every advanced feature should be enabled/disabled from one place.

public enum AVOSystemFeature: String, Codable, CaseIterable, Identifiable, Hashable {
    public var id: String { rawValue }

    case reviewDatasetQuality
    case reviewBatchReview
    case reviewModelBenchmark
    case reviewTemporalAutoPose
    case reviewExportColab

    case biotechLiveBiomech
    case biotechReplay
    case biotechDepthFusion
    case biotechClinicalExport
    case biotechAdvancedHUD

    case hardwareTelemetry
    case hardwareLiDAR
    case hardwareNFC
    case hardwareExternalSensors

    case gpuMetalRenderer
    case coreMLAsyncInference
    case annotatedVideoExport
    case systemAuditLog
}

public struct AVOSystemFeatureState: Codable, Hashable, Identifiable {
    public var id: String { feature.rawValue }
    public var feature: AVOSystemFeature
    public var isEnabled: Bool
    public var isVisibleInUI: Bool
    public var area: AVOAppArea
    public var note: String

    public init(feature: AVOSystemFeature,
                isEnabled: Bool,
                isVisibleInUI: Bool,
                area: AVOAppArea,
                note: String) {
        self.feature = feature
        self.isEnabled = isEnabled
        self.isVisibleInUI = isVisibleInUI
        self.area = area
        self.note = note
    }
}

@MainActor
public final class AVOSystemRegistry: ObservableObject {

    public static let shared = AVOSystemRegistry()

    @Published public private(set) var features: [AVOSystemFeatureState] = AVOSystemRegistry.defaultFeatures()

    private init() {}

    public func setEnabled(_ feature: AVOSystemFeature, enabled: Bool) {
        guard let idx = features.firstIndex(where: { $0.feature == feature }) else { return }
        features[idx].isEnabled = enabled
    }

    public func setVisible(_ feature: AVOSystemFeature, visible: Bool) {
        guard let idx = features.firstIndex(where: { $0.feature == feature }) else { return }
        features[idx].isVisibleInUI = visible
    }

    public func enabledFeatures(for area: AVOAppArea) -> [AVOSystemFeatureState] {
        features.filter { $0.area == area && $0.isEnabled }
    }

    public func visibleFeatures(for area: AVOAppArea) -> [AVOSystemFeatureState] {
        features.filter { $0.area == area && $0.isEnabled && $0.isVisibleInUI }
    }

    public func resetDefaults() {
        features = AVOSystemRegistry.defaultFeatures()
    }

    public static func defaultFeatures() -> [AVOSystemFeatureState] {
        [
            .init(feature: .reviewDatasetQuality, isEnabled: true, isVisibleInUI: true, area: .review, note: "Dataset scoring and weak-frame detection."),
            .init(feature: .reviewBatchReview, isEnabled: true, isVisibleInUI: true, area: .review, note: "Fast IA dataset review."),
            .init(feature: .reviewModelBenchmark, isEnabled: true, isVisibleInUI: false, area: .review, note: "CoreML model comparison."),
            .init(feature: .reviewTemporalAutoPose, isEnabled: true, isVisibleInUI: true, area: .review, note: "Temporal correction for IA retraining."),
            .init(feature: .reviewExportColab, isEnabled: true, isVisibleInUI: true, area: .review, note: "Export dataset/model packages."),

            .init(feature: .biotechLiveBiomech, isEnabled: true, isVisibleInUI: true, area: .biotech, note: "Live biomechanical metrics."),
            .init(feature: .biotechReplay, isEnabled: true, isVisibleInUI: true, area: .biotech, note: "Biomech replay/scrub."),
            .init(feature: .biotechDepthFusion, isEnabled: true, isVisibleInUI: false, area: .biotech, note: "LiDAR/RGB depth fusion."),
            .init(feature: .biotechClinicalExport, isEnabled: true, isVisibleInUI: true, area: .biotech, note: "Clinical CSV/PDF reports."),
            .init(feature: .biotechAdvancedHUD, isEnabled: true, isVisibleInUI: false, area: .biotech, note: "Advanced collapsible HUD."),

            .init(feature: .hardwareTelemetry, isEnabled: true, isVisibleInUI: true, area: .hardware, note: "External vest/cincha telemetry."),
            .init(feature: .hardwareLiDAR, isEnabled: true, isVisibleInUI: true, area: .hardware, note: "iPad/ARKit depth path."),
            .init(feature: .hardwareNFC, isEnabled: true, isVisibleInUI: true, area: .hardware, note: "Horse/rider identification."),
            .init(feature: .hardwareExternalSensors, isEnabled: true, isVisibleInUI: false, area: .hardware, note: "LoRa/ESP32/IMU path."),

            .init(feature: .gpuMetalRenderer, isEnabled: false, isVisibleInUI: false, area: .settings, note: "Future real Metal renderer."),
            .init(feature: .coreMLAsyncInference, isEnabled: true, isVisibleInUI: false, area: .settings, note: "Async CoreML inference switch."),
            .init(feature: .annotatedVideoExport, isEnabled: true, isVisibleInUI: true, area: .export, note: "Export annotated MP4."),
            .init(feature: .systemAuditLog, isEnabled: true, isVisibleInUI: false, area: .settings, note: "Always keep audit file updated.")
        ]
    }
}
