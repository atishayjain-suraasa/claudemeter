import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let service = UsageService()
    private var statusItem: NSStatusItem!
    private var iconUpdateTask: Task<Void, Never>?

    // Custom popover panel (not NSPopover — NSPopover has a non-removable arrow tail
    // and Apple's own menu bar UIs like Bluetooth/Control Center don't use it).
    private var popoverPanel: NSPanel!
    private var popoverEffectView: NSVisualEffectView!
    private var globalClickMonitor: Any?
    private static let popoverSize = NSSize(width: 260, height: 180)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopoverPanel()
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

    // MARK: - Popover (custom borderless NSPanel)
    //
    // Matches the Bluetooth / Control Center / Wi-Fi pattern: a borderless panel
    // anchored under the status item button, with a visual effect background
    // (frosted glass) and rounded corners. No NSPopover arrow tail.

    private func setupPopoverPanel() {
        popoverPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.popoverSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        popoverPanel.isOpaque = false
        popoverPanel.backgroundColor = .clear
        popoverPanel.hasShadow = true
        popoverPanel.level = .popUpMenu
        popoverPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        popoverPanel.hidesOnDeactivate = false
        popoverPanel.isMovableByWindowBackground = false

        // Visual effect view as the visible chrome.
        // Material .hudWindow is the most translucent macOS material — gives the
        // same desktop-tint look as Shottr / Wispr Flow / Bluetooth popovers.
        // (.popover is more opaque; .menu sits between the two.)
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.popoverSize))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        // Rounded corners via maskImage (Apple's documented pattern). Using
        // layer.cornerRadius + masksToBounds interferes with NSVisualEffectView's
        // hardware blur, which is why our popover looked more solid than others.
        effect.maskImage = Self.makeRoundedMask(radius: 10)
        popoverPanel.contentView = effect
        popoverEffectView = effect
    }

    private static func makeRoundedMask(radius: CGFloat) -> NSImage {
        let edge = 2 * radius + 1   // 9-slice: 1px middle stretches; corners stay rounded
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    func togglePopover() {
        if popoverPanel.isVisible {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        // Mount fresh SwiftUI content each open so state (refresh, ticker) is clean
        popoverEffectView.subviews.forEach { $0.removeFromSuperview() }
        let hosting = NSHostingView(
            rootView: PopoverView(openPrefs: { [weak self] in self?.openPrefs() })
                .environment(service)
        )
        hosting.frame = popoverEffectView.bounds
        hosting.autoresizingMask = [.width, .height]
        popoverEffectView.addSubview(hosting)

        // Position: left edge aligned with the status item, just below the menu bar
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let gap: CGFloat = 4
        var origin = NSPoint(
            x: buttonFrame.minX,
            y: buttonFrame.minY - Self.popoverSize.height - gap
        )
        if let screenFrame = NSScreen.main?.visibleFrame {
            origin.x = min(origin.x, screenFrame.maxX - Self.popoverSize.width - 8)
            origin.x = max(origin.x, screenFrame.minX + 8)
        }
        popoverPanel.setFrameOrigin(origin)
        popoverPanel.makeKeyAndOrderFront(nil)

        // Auto-dismiss on outside clicks. Global monitor fires only for clicks
        // outside our app, so clicking the status item (which routes through
        // handleClick → togglePopover → closePopover) and clicking inside the
        // popover content are both handled correctly without flicker.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.closePopover() }
        }
    }

    private func closePopover() {
        popoverPanel?.orderOut(nil)
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
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
