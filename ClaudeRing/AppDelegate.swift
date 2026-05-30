import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let service = UsageService()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var iconUpdateTask: Task<Void, Never>?

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
            image.size = NSSize(width: 16, height: 16)
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
        statusItem.menu = nil
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 175)
        popover.behavior = .transient
        popover.animates = true
    }

    func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let controller = NSHostingController(
                rootView: PopoverView(openPrefs: { [weak self] in self?.openPrefsWindow() })
                    .environment(service)
            )
            // Set appearance before first draw so the dark/light rendering is correct
            // from the very first frame — without this it renders in the wrong mode.
            controller.view.appearance = NSApp.effectiveAppearance
            popover.contentViewController = controller
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Preferences window

    private var prefsWindow: NSWindow?

    @objc func openPrefsWindow() {
        popover.performClose(nil)

        if prefsWindow == nil {
            let vc = NSHostingController(
                rootView: PreferencesWindowView().environment(service)
            )
            vc.view.appearance = NSApp.effectiveAppearance
            // sizingOptions = [] is the key: stops the hosting controller from calling
            // setContentSize on the window after every SwiftUI layout pass, which would
            // trigger another layout, causing infinite recursion and a crash.
            vc.sizingOptions = []

            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "ClaudeRing Preferences"
            win.contentViewController = vc
            win.isReleasedWhenClosed = false
            win.center()
            prefsWindow = win
        } else {
            prefsWindow?.contentViewController?.view.appearance = NSApp.effectiveAppearance
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
