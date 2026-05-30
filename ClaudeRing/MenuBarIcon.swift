import SwiftUI

// Claude brand orange — visible on both light and dark menu bars
private let claudeOrange = Color(red: 0.851, green: 0.467, blue: 0.325)

// Rendered via ImageRenderer to NSImage on each refresh
struct MenuBarIconView: View {
    let utilization: Double
    let isRefreshing: Bool
    let hasFailed: Bool

    private var progressColor: Color {
        if hasFailed { return .red }
        if utilization >= 0.85 { return .red }
        if utilization >= 0.60 { return .orange }
        return claudeOrange
    }

    var body: some View {
        ZStack {
            // Faint ring track in brand orange
            Circle()
                .stroke(claudeOrange.opacity(0.25), lineWidth: 2)
                .frame(width: 20, height: 20)

            // Progress arc
            Circle()
                .trim(from: 0, to: max(0.02, isRefreshing ? 0.25 : utilization))
                .stroke(progressColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(-90))

            // Claude logo in brand orange
            Image("ClaudeIcon")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(claudeOrange)
                .frame(width: 11, height: 11)

            // Red dot overlay for auth failure
            if hasFailed {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                    .offset(x: 7, y: -7)
            }
        }
        .frame(width: 22, height: 22)
        .background(Color.clear)
    }
}
