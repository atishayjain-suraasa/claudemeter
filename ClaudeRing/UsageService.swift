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

    // In-memory token cache. Populated on first need (one keychain ACL prompt → Always Allow),
    // refreshed only on 401 from Anthropic.
    private var cachedToken: String?

    func refresh() async {
        guard refreshState != .refreshing else { return }
        refreshState = .refreshing

        do {
            let token = try resolveToken()
            do {
                let data = try await AnthropicClient.fetchUsage(token: token)
                applyData(data)
                refreshState = .idle
            } catch AnthropicClient.ClientError.unauthorized {
                // Cached token expired. Trigger Claude Code to refresh its own keychain,
                // then re-read silently and retry once.
                cachedToken = nil
                try await ClaudeRefreshTrigger.triggerRefresh()
                let newToken = try resolveToken()
                let data = try await AnthropicClient.fetchUsage(token: newToken)
                applyData(data)
                refreshState = .idle
            }
        } catch KeychainError.itemNotFound, KeychainError.missingToken, KeychainError.accessDenied {
            refreshState = .failed(.authFailed)
        } catch AnthropicClient.ClientError.networkError {
            refreshState = .failed(.offline)
        } catch ClaudeRefreshError.claudeNotInstalled {
            refreshState = .failed(.authFailed)
        } catch ClaudeRefreshError.timeout, ClaudeRefreshError.subprocessFailed {
            refreshState = .failed(.authFailed)
        } catch {
            refreshState = .failed(.headersUnreadable)
        }
    }

    private func applyData(_ data: AnthropicClient.RateLimitData) {
        snapshot = UsageSnapshot(
            sessionUtilization: data.sessionUtilization,
            weeklyUtilization: data.weeklyUtilization,
            sessionReset: data.sessionReset,
            weeklyReset: data.weeklyReset,
            updatedAt: Date()
        )
    }

    // Returns cached token or reads from keychain on cache miss.
    // Keychain reads after the first Always Allow grant are silent.
    private func resolveToken() throws -> String {
        if let cached = cachedToken { return cached }
        let creds = try KeychainReader.loadCredentials()
        cachedToken = creds.accessToken
        return creds.accessToken
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
