import SwiftUI

struct ReplayChartBox: View {
    let title: String
    let valueText: String
    let color: Color
    let values: [Double]
    var currentIndex: Int = 0

    private var safeIndex: Int {
        guard !values.isEmpty else { return 0 }
        return min(max(currentIndex, 0), values.count - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .black, design: .monospaced))

                Spacer()

                Text(valueText)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    chartPath(in: geo.size, upTo: values.count - 1)
                        .stroke(color.opacity(0.22), lineWidth: 1)

                    chartPath(in: geo.size, upTo: safeIndex)
                        .stroke(color, lineWidth: 2)

                    if values.count > 1 {
                        let x = geo.size.width * CGFloat(safeIndex) / CGFloat(max(values.count - 1, 1))
                        Rectangle()
                            .fill(Color.white.opacity(0.75))
                            .frame(width: 2)
                            .position(x: x, y: geo.size.height / 2)

                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .position(pointPosition(in: geo.size, index: safeIndex))
                    }
                }
            }
            .frame(minHeight: 70)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(Color.black.opacity(0.30))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(color.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func chartPath(in size: CGSize, upTo endIndex: Int) -> Path {
        Path { path in
            guard values.count > 1 else { return }

            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 0.0001)
            let last = min(max(endIndex, 0), values.count - 1)

            for i in 0...last {
                let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
                let normalized = (values[i] - minValue) / range
                let y = size.height - size.height * CGFloat(normalized)

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func pointPosition(in size: CGSize, index: Int) -> CGPoint {
        guard values.count > 1 else { return CGPoint(x: 0, y: size.height / 2) }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.0001)
        let idx = min(max(index, 0), values.count - 1)
        let x = size.width * CGFloat(idx) / CGFloat(values.count - 1)
        let normalized = (values[idx] - minValue) / range
        let y = size.height - size.height * CGFloat(normalized)
        return CGPoint(x: x, y: y)
    }
}
