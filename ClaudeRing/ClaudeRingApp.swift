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
        // Re-render icon whenever service state changes
        // We poll the @Observable values via a Task loop
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
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms poll for icon freshness
            }
        }
    }

    func renderIcon() {
        let hasFailed: Bool = {
            if case .failed(.authFailed) = service.refreshState { return true }
            return false
        }()
        let isRefreshing = service.refreshState == .refreshing
        let util = service.snapshot.sessionUtilization

        let view = MenuBarIconView(
            utilization: util,
            isRefreshing: isRefreshing,
            hasFailed: hasFailed
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        if let nsImage = renderer.nsImage {
            nsImage.isTemplate = false
            statusItem.button?.image = nsImage
            statusItem.button?.imageScaling = .scaleProportionallyDown
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Re-create content so popover state is always fresh
            popover.contentViewController = NSHostingController(
                rootView: PopoverView(onClose: { [weak self] in self?.closePopover() })
                    .environment(service)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
