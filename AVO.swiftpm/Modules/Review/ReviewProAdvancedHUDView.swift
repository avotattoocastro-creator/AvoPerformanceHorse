import SwiftUI

// PHASE 105
// Advanced HUD overlay

public struct ReviewProAdvancedHUDView: View {

    public var symmetry: Double
    public var risk: Double
    public var temporalStability: Double
    public var frame: Int

    public init(symmetry: Double,
                risk: Double,
                temporalStability: Double,
                frame: Int) {
        self.symmetry = symmetry
        self.risk = risk
        self.temporalStability = temporalStability
        self.frame = frame
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("FRAME \(frame)")
            Text("SYM \(String(format: "%.2f", symmetry))")
            Text("RISK \(String(format: "%.2f", risk))")
            Text("TEMP \(String(format: "%.2f", temporalStability))")

        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(10)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
