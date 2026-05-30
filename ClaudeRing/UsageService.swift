import Foundation
import AppKit
import ServiceManagement

@MainActor
@Observable
final class UsageService {
    var snapshot: UsageSnapshot = .empty
    var refreshState: RefreshState = .idle

    private var pollTimer: Timer?
    private var fileWatchTimer: Timer?
    private var lastTriggerMtime: Date = .distantPast  // seeded from actual file at init to avoid spurious trigger

    private let claudeBundleID = "com.anthropic.claudefordesktop"

    private let triggerPath: String = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("ClaudeRing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("trigger").path
    }()

    private var refreshIntervalMinutes: Int {
        let stored = UserDefaults.standard.integer(forKey: "claudering.refreshInterval")
        return stored == 0 ? 5 : stored
    }

    init() {
        startFileWatcher()
        observeClaudeDesktopLifecycle()
        observeWake()
        Task { await refresh() }
    }

    // MARK: - Refresh

    func refresh() async {
        guard refreshState != .refreshing else { return }
        refreshState = .refreshing

        do {
            // Read keychain fresh on every refresh — no in-memory cache. macOS keychain
            // ACL ("Always Allow") makes repeated reads silent, and reading fresh means
            // Claude Code's token refreshes propagate instantly without any special handling.
            let token = try KeychainReader.claudeAccessToken()
            let data = try await AnthropicClient.fetchUsage(token: token)
            snapshot = UsageSnapshot(
                sessionUtilization: data.sessionUtilization,
                weeklyUtilization: data.weeklyUtilization,
                sessionReset: data.sessionReset,
                weeklyReset: data.weeklyReset,
                updatedAt: Date()
            )
            refreshState = .idle
        } catch KeychainError.itemNotFound, KeychainError.missingToken {
            refreshState = .failed(.authFailed)
        } catch KeychainError.accessDenied {
            refreshState = .failed(.authFailed)
        } catch AnthropicClient.ClientError.unauthorized {
            refreshState = .failed(.authFailed)
        } catch AnthropicClient.ClientError.networkError {
            refreshState = .failed(.offline)
        } catch {
            refreshState = .failed(.headersUnreadable)
        }
    }

    // MARK: - File watcher (Stop hook trigger)
    // Stop hook writes a timestamp to the trigger file; we detect the mtime change.

    private func startFileWatcher() {
        // Create trigger file if absent so the watcher has something to stat
        if !FileManager.default.fileExists(atPath: triggerPath) {
            FileManager.default.createFile(atPath: triggerPath, contents: nil)
        }
        // Seed mtime from the existing file so the first timer tick doesn't
        // immediately fire a spurious refresh (causing a second keychain prompt).
        if let existingMtime = (try? FileManager.default.attributesOfItem(atPath: triggerPath))?[.modificationDate] as? Date {
            lastTriggerMtime = existingMtime
        }

        fileWatchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let attrs = try? FileManager.default.attributesOfItem(atPath: self.triggerPath)
                guard let mtime = attrs?[.modificationDate] as? Date, mtime > self.lastTriggerMtime else { return }
                self.lastTriggerMtime = mtime
                await self.refresh()
            }
        }
    }

    // MARK: - Claude desktop app lifecycle polling

    private func observeClaudeDesktopLifecycle() {
        let ws = NSWorkspace.shared.notificationCenter

        ws.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo,
                  let app = info[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == self?.claudeBundleID else { return }
            Task { @MainActor [weak self] in
                await self?.refresh()
                self?.startPollTimer()
            }
        }

        ws.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo,
                  let app = info[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == self?.claudeBundleID else { return }
            Task { @MainActor [weak self] in self?.stopPollTimer() }
        }

        if isClaudeDesktopRunning() { startPollTimer() }
    }

    private func isClaudeDesktopRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == claudeBundleID }
    }

    private func startPollTimer() {
        stopPollTimer()
        let interval = TimeInterval(refreshIntervalMinutes * 60)
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Wake from sleep

    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    // MARK: - Interval update (called from PreferencesSheet when changed)

    func refreshIntervalDidChange() {
        if isClaudeDesktopRunning() { startPollTimer() }
    }
}
