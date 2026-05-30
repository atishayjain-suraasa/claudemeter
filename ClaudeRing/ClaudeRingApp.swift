import SwiftUI

@main
struct ClaudeRingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement=true (Info.plist) hides dock icon.
        // Settings scene prevents SwiftUI from auto-creating a main window.
        Settings { EmptyView() }
    }
}
