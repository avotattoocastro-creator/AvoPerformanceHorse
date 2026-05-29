import SwiftUI

struct AVOLiveBiomechLiDAROverlay: View {
    var activeHorseName: String
    @ObservedObject var camera: CameraManager
    @ObservedObject var sensors: SensorHub

    private var riskLabel: String {
        if camera.risk > 0.70 { return "LIVE RISK HIGH" }
        if camera.risk > 0.45 { return "LIVE RISK WATCH" }
        return "LIVE RISK OK"
    }

    private var riskColor: Color {
        camera.risk > 0.70 ? .red : (camera.risk > 0.45 ? .orange : .green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("ACTIVE HORSE")
                    .foregroundColor(.gray)
                Text(activeHorseName.uppercased())
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text(camera.lidarSupported ? "LiDAR ON" : "LiDAR OFF")
                    .foregroundColor(camera.lidarSupported ? .cyan : .orange)
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))

            HStack(spacing: 8) {
                lidarChip("DEPTH", camera.lidarDistanceText, .cyan)
                lidarChip("QUALITY", camera.lidarQualityText.replacingOccurrences(of: "DEPTH ", with: ""), camera.lidarQuality > 0.70 ? .green : .orange)
                lidarChip("RISK", riskLabel.replacingOccurrences(of: "LIVE RISK ", with: ""), riskColor)
                lidarChip("IMPACT", sensors.impactStatus, .orange)
            }

            HStack(spacing: 8) {
                lidarChip("GAIT", camera.gait, .cyan)
                lidarChip("SYM", camera.asymmetry, .green)
                lidarChip("HR", sensors.pulseStatus, .green)
                lidarChip("SPEED", sensors.speedStatus, .white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.72))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cyan.opacity(0.55), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func lidarChip(_ name: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name)
                .foregroundColor(.gray)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
            Text(value.isEmpty ? "--" : value)
                .foregroundColor(color)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
