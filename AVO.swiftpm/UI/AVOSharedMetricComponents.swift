import SwiftUI

struct StableMetricBar: View {
    var title: String
    var value: Double
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundColor(.gray)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                Spacer()
                Text("\(Int(max(0.0, min(1.0, value)) * 100.0))%")
                    .foregroundColor(color)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(max(0.0, min(1.0, value))))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AVOMetricTile: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 9, weight: .black, design: .monospaced))
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
