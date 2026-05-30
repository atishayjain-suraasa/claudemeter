import SwiftUI

@main
struct ClaudeRingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings { EmptyView() } suppresses the automatic main window
        // while still keeping LSUIElement=true for no dock icon.
        Settings { EmptyView() }
    }
}
