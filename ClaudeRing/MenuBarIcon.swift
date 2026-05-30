import SwiftUI

// Rendered via ImageRenderer to NSImage — not placed directly in a MenuBarExtra label
struct MenuBarIconView: View {
    let utilization: Double
    let isRefreshing: Bool
    let hasFailed: Bool

    private var ringColor: Color {
        if hasFailed { return .red }
        if utilization >= 0.85 { return .red }
        if utilization >= 0.60 { return .orange }
        return Color(white: 0.2)
    }

    var body: some View {
        ZStack {
            // Background ring track
            Circle()
                .stroke(Color(white: 0.5).opacity(0.3), lineWidth: 2)
                .frame(width: 20, height: 20)

            // Progress arc
            Circle()
                .trim(from: 0, to: max(0.02, isRefreshing ? 0.25 : utilization))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(-90))

            // Claude tray icon (template PNG from Claude.app bundle)
            Image("ClaudeIcon")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color(white: 0.15))
                .frame(width: 12, height: 12)

            // Red dot for auth failure
            if hasFailed {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                    .offset(x: 7, y: -7)
            }
        }
        .frame(width: 22, height: 22)
    }
}
