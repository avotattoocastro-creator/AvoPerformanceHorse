import Foundation
import SwiftUI
import UIKit

// MARK: - AVO PHASE 122
// REVIEW TRAINING INTAKE FROM BIOTECH
//
// REVIEW can now import the data stream captured from BIOTECH.

@MainActor
public final class ReviewBiotechTrainingIntake: ObservableObject {

    @Published public private(set) var importedCount: Int = 0
    @Published public private(set) var status: String = "BIOTECH INTAKE READY"

    private let receiver = ReviewTrainingFrameReceiver()
    private let storage = AVOStorageEngine.shared

    public init() {}

    public func importFromBiotechBuffer(horseName: String) {
        let frames = receiver.importAvailableFrames()
        importedCount = frames.count
        status = "IMPORTED \(frames.count) BIOTECH FRAMES"
    }

    public func exportCurrentBufferForTraining(horseName: String) {
        do {
            let csv = receiver.exportAvailableManifestCSV()
            _ = try storage.writeText(
                csv,
                area: .recData,
                horseName: horseName,
                fileName: "review_import_from_biotech.csv"
            )
            importedCount = receiver.availableFrames().count
            status = "TRAINING MANIFEST EXPORTED \(importedCount)"
        } catch {
            status = "INTAKE EXPORT ERROR: \(error.localizedDescription)"
        }
    }
}

public struct ReviewBiotechTrainingIntakePanel: View {

    @StateObject private var intake = ReviewBiotechTrainingIntake()
    public var horseName: String

    public init(horseName: String = "SIN_CABALLO") {
        self.horseName = horseName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BIOTECH → REVIEW TRAINING")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.cyan)

            Text(intake.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))

            HStack {
                Button("IMPORTAR DATA") {
                    intake.importFromBiotechBuffer(horseName: horseName)
                }
                .buttonStyle(.borderedProminent)

                Button("EXPORT TRAINING") {
                    intake.exportCurrentBufferForTraining(horseName: horseName)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
