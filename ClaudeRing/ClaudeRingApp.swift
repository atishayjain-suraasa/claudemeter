import SwiftUI
import AppKit

@main
struct ClaudeRingApp: App {
    @State private var service = UsageService()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(service)
        } label: {
            MenuBarIcon(
                utilization: service.snapshot.sessionUtilization,
                isRefreshing: service.refreshState == .refreshing,
                hasFailed: {
                    if case .failed(.authFailed) = service.refreshState { return true }
                    return false
                }()
            )
        }
        .menuBarExtraStyle(.window)
    }
}
