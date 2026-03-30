import SwiftUI

struct RingGaugeView: View {
    let value: Double
    let label: String
    var colors: [Color] = [.pink]
    var size: CGFloat = 78
    var lineWidth: CGFloat = 10
    var valueFontSize: CGFloat = 16

    var body: some View {
        let gradientColors = colors.count >= 2 ? colors : [colors.first ?? .pink, colors.first ?? .pink]
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.45
                    )
                )
            Circle()
                .trim(from: 0, to: CGFloat(min(value / 100, 1)))
                .stroke(
                    AngularGradient(colors: gradientColors, center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: (colors.first ?? .pink).opacity(0.35), radius: 8)
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(lineWidth + 2)
        }
        .frame(width: size, height: size)
    }
}
