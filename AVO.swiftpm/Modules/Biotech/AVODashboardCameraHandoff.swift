import Foundation
import SwiftUI

// MARK: - BIOTECH PHASE 120
// DASHBOARD CAMERA HANDOFF HELPER
//
// Use this from DashboardView when leaving live camera pages:
// AVODashboardCameraHandoff.claimDashboard()
// AVODashboardCameraHandoff.releaseDashboardForBiotech()

@MainActor
public enum AVODashboardCameraHandoff {

    public static func claimDashboard() {
        AVOCameraOwnershipCoordinator.shared.claim(.dashboard)
    }

    public static func releaseDashboardForBiotech() {
        if AVOCameraOwnershipCoordinator.shared.owner == .dashboard {
            AVOCameraOwnershipCoordinator.shared.release(.dashboard)
        }
    }

    public static func prepareBiotechCamera() {
        AVOCameraOwnershipCoordinator.shared.forceReleaseAll()
        AVOCameraOwnershipCoordinator.shared.claim(.biotech)
    }
}
