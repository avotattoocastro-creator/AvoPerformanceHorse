import SwiftUI

// MARK: - BIOTECH PHASE 116
// CAMERA INTEGRATION WRAPPER
//
// Use this wrapper around the existing BIOTECH overlay page if the current
// AVOBiomechFullPage uses a black background instead of a real camera preview.

public struct BiotechCameraIntegratedHost<OverlayContent: View>: View {

    private let overlayContent: OverlayContent

    public init(@ViewBuilder overlayContent: () -> OverlayContent) {
        self.overlayContent = overlayContent()
    }

    public var body: some View {
        ZStack {
            BiotechCameraPreviewView()
            overlayContent
        }
    }
}
