import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let service = UsageService()
    private var statusItem: NSStatusItem!
    private var iconUpdateTask: Task<Void, Never>?

    // We use NSMenu (not NSPopover or NSPanel) for the status item's popup.
    // NSMenu has the system's built-in frosted glass with proper desktop tint —
    // matches Shottr, Apple's own menu bar UIs. Custom usage display goes in a
    // NSMenuItem.view at the top; Preferences and Quit are native menu items.
    private static let menuContentSize = NSSize(width: 260, height: 130)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        startIconUpdater()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        if let image = NSImage(named: "ClaudeIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            button.image = image
            button.imagePosition = .imageLeft
        }
        button.attributedTitle = Self.buttonAttributedTitle(" —%", color: .labelColor)

        // Setting statusItem.menu makes the click handler automatic — left-click
        // or right-click both open the menu, native positioning below the icon,
        // built-in click-outside dismissal.
        statusItem.menu = buildMenu()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        // Usage display — SwiftUI hosted inside a custom NSMenuItem.view
        let usageItem = NSMenuItem()
        usageItem.isEnabled = false   // not selectable, no hover highlight on the slot
        let hosting = NSHostingView(
            rootView: PopoverView().environment(service)
        )
        hosting.frame = NSRect(origin: .zero, size: Self.menuContentSize)
        // Transparent so the menu's vibrancy shows through
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        usageItem.view = hosting
        menu.addItem(usageItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…",
                                   action: #selector(openPrefs),
                                   keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ClaudeMeter",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    // NSMenuDelegate — refresh data when the menu is about to appear so the
    // numbers shown are current.
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in await self.service.refresh() }
    }

    // MARK: - Preferences window
    // Uses NSHostingView (not NSHostingController) as the contentView. The Controller
    // variant fights with the window over auto-sizing, causing infinite layout
    // recursion crashes. The View variant just renders SwiftUI inside the fixed
    // rect we give it. No bidirectional sizing, no loop.

    private var prefsWindow: NSWindow?

    @objc func openPrefs() {
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

    // contentTintColor on NSStatusBarButton is unreliable on Sequoia — the button
    // spends its first tick in VibrantLight before settling in VibrantDark, leaving
    // the tint stuck. attributedTitle resolves dynamic colors at draw time in the
    // button's actual drawing context, so labelColor / systemOrange / systemRed all
    // render correctly without any manual appearance inspection.
    private func startIconUpdater() {
        iconUpdateTask = Task { [weak self] in
            var lastPct = -1
            var lastFailed = false
            while !Task.isCancelled {
                guard let self else { return }
                let u = self.service.snapshot.sessionUtilization
                let pct = Int(u * 100)
                let failed: Bool
                if case .failed(.authFailed) = self.service.refreshState { failed = true } else { failed = false }

                if pct != lastPct || failed != lastFailed {
                    lastPct = pct
                    lastFailed = failed
                    let color: NSColor = failed || u >= 0.85 ? .systemRed
                        : u >= 0.60 ? .systemOrange
                        : .labelColor
                    self.statusItem.button?.attributedTitle =
                        Self.buttonAttributedTitle(" \(pct)%", color: color)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private static func buttonAttributedTitle(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ])
    }
}
