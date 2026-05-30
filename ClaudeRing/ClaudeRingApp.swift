import SwiftUI
import AppKit

@main
struct ClaudeRingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement=true hides dock icon; Settings scene prevents SwiftUI from creating a main window
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let service = UsageService()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var iconUpdateTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        observeServiceChanges()
        renderIcon()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 165)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(onClose: { [weak self] in self?.closePopover() })
                .environment(service)
        )
    }

    private func observeServiceChanges() {
        iconUpdateTask = Task { [weak self] in
            var lastSession = -1.0
            var lastState = RefreshState.idle
            while !Task.isCancelled {
                guard let self else { return }
                let s = self.service.snapshot.sessionUtilization
                let st = self.service.refreshState
                if abs(s - lastSession) > 0.001 || st != lastState {
                    lastSession = s
                    lastState = st
                    self.renderIcon()
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms — icon doesn't need sub-second updates
            }
        }
    }

    func renderIcon() {
        let hasFailed: Bool
        if case .failed(.authFailed) = service.refreshState { hasFailed = true } else { hasFailed = false }
        let isRefreshing = service.refreshState == .refreshing
        let util = service.snapshot.sessionUtilization

        let view = MenuBarIconView(utilization: util, isRefreshing: isRefreshing)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        if let nsImage = renderer.nsImage {
            // Template mode: macOS handles light/dark adaptation automatically.
            // The icon is white on dark menu bars, black on light — exactly like all other icons.
            nsImage.isTemplate = true
            statusItem.button?.image = nsImage
            statusItem.button?.imageScaling = .scaleProportionallyDown

            // contentTintColor tints the entire template: nil = system default (white/black),
            // orange/red = usage alert. This is the correct macOS API for colored menu bar icons.
            if hasFailed || util >= 0.85 {
                statusItem.button?.contentTintColor = .systemRed
            } else if util >= 0.60 {
                statusItem.button?.contentTintColor = .systemOrange
            } else {
                statusItem.button?.contentTintColor = nil
            }
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Re-create content so popover state is always fresh
            let controller = NSHostingController(
                rootView: PopoverView(onClose: { [weak self] in self?.closePopover() })
                    .environment(service)
            )
            // Make the hosting view transparent so NSPopover's frosted-glass
            // visual effect material shows through (matches system popovers).
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = .clear
            popover.contentViewController = controller
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
