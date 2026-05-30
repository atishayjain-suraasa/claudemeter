import SwiftUI

@main
struct ClaudeRingApp: App {
    @State private var service = UsageService()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(service)
        } label: {
            HStack(spacing: 3) {
                Image("ClaudeIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(sessionLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
            .foregroundStyle(labelColor)
        }
        .menuBarExtraStyle(.window)
    }

    private var sessionLabel: String {
        if case .refreshing = service.refreshState, service.snapshot.updatedAt == .distantPast {
            return "—%"
        }
        return "\(Int(service.snapshot.sessionUtilization * 100))%"
    }

    private var labelColor: Color {
        if case .failed(.authFailed) = service.refreshState { return .red }
        let u = service.snapshot.sessionUtilization
        if u >= 0.85 { return .red }
        if u >= 0.60 { return .orange }
        return .primary   // white in dark mode, black in light mode — matches all other icons
    }
}
