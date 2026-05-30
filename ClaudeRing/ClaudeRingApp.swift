import SwiftUI

@main
struct ClaudeRingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene = proper macOS settings window.
        // Correct dark/light appearance, standard close button, Cmd+, shortcut.
        // NSApp.sendAction(Selector(("showSettingsWindow:")), ...) opens it programmatically.
        Settings {
            PreferencesWindowView()
                .environment(appDelegate.service)
        }
    }
}
