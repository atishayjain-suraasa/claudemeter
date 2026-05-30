import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let service = UsageService()
    private var statusItem: NSStatusItem!
    private var iconUpdateTask: Task<Void, Never>?

    // NSPopover gives us the system's proper frosted-glass blur — matches Bluetooth,
    // Control Center, Shottr, etc. We use the well-known `shouldHideAnchor` private
    // KVC key to suppress the arrow tail. Apple has kept this key working since
    // 10.13; if they ever remove it, the arrow comes back but the app still works.
    private var popover: NSPopover!
    private static let popoverSize = NSSize(width: 260, height: 180)

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

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ClaudeMeter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Popover (NSPopover with arrow hidden via KVC)

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = Self.popoverSize
        popover.behavior = .transient
        popover.animates = true
        // Private API: hides the arrow tail. Survives across macOS versions since 10.13.
        // KVC lookup so the binary doesn't statically reference a private symbol —
        // if Apple ever removes the key, this is a no-op (arrow reappears) rather
        // than a crash or build failure.
        popover.setValue(true, forKey: "shouldHideAnchor")
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.close() }

        let controller = NSHostingController(
            rootView: PopoverView(openPrefs: { [weak self] in self?.openPrefs() })
                .environment(service)
        )
        popover.contentViewController = controller

        // Anchor to a 1px source rect at the LEFT edge of the button so the popover
        // is left-aligned with the status item icon (default centering would place
        // it under the percentage text instead). Matches the Bluetooth/Wi-Fi style.
        let sourceRect = NSRect(x: 0, y: 0, width: 1, height: button.bounds.height)
        popover.show(relativeTo: sourceRect, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    // MARK: - Preferences window
    // Uses NSHostingView (not NSHostingController) as the contentView. The Controller
    // variant fights with the window over auto-sizing, causing infinite layout
    // recursion crashes. The View variant just renders SwiftUI inside the fixed
    // rect we give it. No bidirectional sizing, no loop.

    private var prefsWindow: NSWindow?

    @objc func openPrefs() {
        closePopover()

        if prefsWindow == nil {
            let size = NSSize(width: 440, height: 560)

            let hostingView = NSHostingView(
                rootView: PreferencesWindowView().environment(service)
            )
            hostingView.frame = NSRect(origin: .zero, size: size)

            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "ClaudeMeter Preferences"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.center()
            prefsWindow = window
        }

        // For LSUIElement apps, the window may not come to front without explicit
        // activation. orderFrontRegardless bypasses focus-rules quirks.
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
        prefsWindow?.orderFrontRegardless()
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
