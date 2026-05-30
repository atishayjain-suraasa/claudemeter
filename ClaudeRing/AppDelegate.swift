import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let service = UsageService()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var iconUpdateTask: Task<Void, Never>?
    private var prefsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        startIconUpdater()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.action = #selector(handleClick)

        if let image = NSImage(named: "ClaudeIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 14, height: 14)
            button.image = image
            button.imagePosition = .imageLeft
        }
        button.title = " —%"
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPrefsWindow), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ClaudeRing", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // restore left-click popover behavior
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 175)
        popover.behavior = .transient
        popover.animates = true
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let controller = NSHostingController(
                rootView: PopoverView(openPrefs: { [weak self] in self?.openPrefsWindow() })
                    .environment(service)
            )
            // Fix first-render appearance — set before the view draws
            controller.view.appearance = NSApp.effectiveAppearance
            popover.contentViewController = controller
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Preferences window (from right-click)

    @objc func openPrefsWindow() {
        popover.performClose(nil)

        if prefsWindow == nil {
            let vc = NSHostingController(rootView: PreferencesWindowView().environment(service))
            vc.view.appearance = NSApp.effectiveAppearance
            // sizingOptions = [] stops NSHostingController from trying to resize the window
            // to fit SwiftUI content size after every layout pass — that causes the
            // infinite "Update Constraints in Window" loop that crashes the app.
            vc.sizingOptions = []

            let win = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 330),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "ClaudeRing"
            win.contentViewController = vc
            win.isReleasedWhenClosed = false
            win.center()
            prefsWindow = win
        }

        prefsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Icon updater

    private func startIconUpdater() {
        iconUpdateTask = Task { [weak self] in
            var lastPct = -1
            var lastFailed = false
            while !Task.isCancelled {
                guard let self else { return }
                let pct = Int(self.service.snapshot.sessionUtilization * 100)
                let failed: Bool
                if case .failed(.authFailed) = self.service.refreshState { failed = true } else { failed = false }

                if pct != lastPct || failed != lastFailed {
                    lastPct = pct
                    lastFailed = failed
                    self.statusItem.button?.title = " \(pct)%"
                    let u = self.service.snapshot.sessionUtilization
                    if failed || u >= 0.85 {
                        self.statusItem.button?.contentTintColor = .systemRed
                    } else if u >= 0.60 {
                        self.statusItem.button?.contentTintColor = .systemOrange
                    } else {
                        self.statusItem.button?.contentTintColor = nil
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}
