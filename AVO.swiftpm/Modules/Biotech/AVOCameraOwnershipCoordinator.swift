import Foundation
import SwiftUI
import AVFoundation

// MARK: - BIOTECH PHASE 120
// CAMERA OWNERSHIP COORDINATOR
//
// Problem:
// Dashboard and BIOTECH can both try to own AVCaptureSession.
// iOS/iPad can freeze, show black preview or keep a static frame.
//
// Solution:
// Single ownership coordinator.
// Before BIOTECH starts camera, it claims the camera.
// Other camera owners should stop/release when they are not active.

public enum AVOCameraOwner: String, Codable, Hashable {
    case none
    case dashboard
    case biotech
    case review
    case unknown
}

@MainActor
public final class AVOCameraOwnershipCoordinator: ObservableObject {

    public static let shared = AVOCameraOwnershipCoordinator()

    @Published public private(set) var owner: AVOCameraOwner = .none
    @Published public private(set) var status: String = "CAMERA FREE"
    @Published public private(set) var lastClaimAt: Date = Date()

    private init() {}

    public func claim(_ newOwner: AVOCameraOwner) {
        owner = newOwner
        lastClaimAt = Date()
        status = "CAMERA OWNER: \(newOwner.rawValue.uppercased())"
    }

    public func release(_ releasingOwner: AVOCameraOwner) {
        if owner == releasingOwner {
            owner = .none
            status = "CAMERA FREE"
            lastClaimAt = Date()
        }
    }

    public func shouldRun(_ requestedOwner: AVOCameraOwner) -> Bool {
        owner == .none || owner == requestedOwner
    }

    public func forceReleaseAll() {
        owner = .none
        status = "CAMERA FORCE RELEASED"
        lastClaimAt = Date()
    }
}

@MainActor
public struct AVOCameraOwnershipBadge: View {

    @ObservedObject private var coordinator = AVOCameraOwnershipCoordinator.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(coordinator.owner == .none ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(coordinator.status)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
