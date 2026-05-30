import SwiftUI

// Rendered via ImageRenderer → NSImage with isTemplate=true
// Template images let macOS handle the color (white in dark mode, black in light mode).
// contentTintColor on the button tints the whole icon orange/red at high usage.
struct MenuBarIconView: View {
    let utilization: Double
    let isRefreshing: Bool

    var body: some View {
        ZStack {
            // Faint track ring
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.8)
                .frame(width: 20, height: 20)

            // Progress arc — white, alpha channel is what matters for template
            Circle()
                .trim(from: 0, to: max(0.04, isRefreshing ? 0.25 : utilization))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(-90))

            // Claude logo
            Image("ClaudeIcon")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.white)
                .frame(width: 12, height: 12)
        }
        .frame(width: 22, height: 22)
        .background(Color.clear)
    }
}
