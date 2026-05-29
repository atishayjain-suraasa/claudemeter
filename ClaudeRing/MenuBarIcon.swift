import SwiftUI

struct MenuBarIcon: View {
    let utilization: Double  // 0.0–1.0
    let isRefreshing: Bool
    let hasFailed: Bool

    private var ringColor: Color {
        if hasFailed { return .red }
        if utilization >= 0.85 { return .red }
        if utilization >= 0.60 { return Color.orange }
        return Color.primary.opacity(0.5)
    }

    var body: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                .frame(width: 18, height: 18)

            Circle()
                .trim(from: 0, to: isRefreshing ? 0.25 : utilization)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(-90))
                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .easeInOut(duration: 0.4), value: isRefreshing ? 1.0 : utilization)

            // Claude mesh logo — drawn as a simplified asterisk/sparkle using SF Symbol
            // "sparkle" is the closest built-in symbol to the Claude mark
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.primary)

            // Red dot overlay for auth failure
            if hasFailed {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                    .offset(x: 6, y: -6)
            }
        }
        .frame(width: 22, height: 22)
    }
}
