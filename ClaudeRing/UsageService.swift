import Foundation
import AppKit
import Network
import ServiceManagement

@MainActor
@Observable
final class UsageService {
    var snapshot: UsageSnapshot = .empty
    var refreshState: RefreshState = .idle

    private var pollTimer: Timer?
    private var listener: NWListener?
    private let socketPath: String = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("ClaudeRing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("refresh.sock").path
    }()

    private let claudeBundleID = "com.anthropic.claudefordesktop"

    private var refreshIntervalMinutes: Int {
        UserDefaults.standard.integer(forKey: "claudering.refreshInterval").nonZeroOr(5)
    }

    init() {
        startUnixSocketListener()
        observeClaudeDesktopLifecycle()
        observeWake()
        Task { await refresh() }
    }

    func refresh() async {
        guard refreshState != .refreshing else { return }
        refreshState = .refreshing

        do {
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
            snapshot = .empty
            refreshState = .failed(.authFailed)
        } catch KeychainError.accessDenied {
            snapshot = .empty
            refreshState = .failed(.authFailed)
        } catch AnthropicClient.ClientError.unauthorized {
            snapshot = .empty
            refreshState = .failed(.authFailed)
        } catch AnthropicClient.ClientError.networkError {
            refreshState = .failed(.offline)
        } catch {
            refreshState = .failed(.headersUnreadable)
        }
    }

    // MARK: - Desktop app lifecycle polling

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

        if isClaudeDesktopRunning() {
            startPollTimer()
        }
    }

    private func isClaudeDesktopRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == claudeBundleID }
    }

    private func startPollTimer() {
        stopPollTimer()
        let interval = TimeInterval(refreshIntervalMinutes * 60)
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
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

    // MARK: - Unix socket listener (Stop hook trigger)

    private func startUnixSocketListener() {
        try? FileManager.default.removeItem(atPath: socketPath)

        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        params.acceptLocalOnly = true

        guard let listener = try? NWListener(using: params) else { return }
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global())
            connection.cancel()
            Task { @MainActor [weak self] in await self?.refresh() }
        }

        let endpoint = NWEndpoint.unix(path: socketPath)
        listener.parameters.requiredLocalEndpoint = endpoint
        listener.start(queue: .global())
    }

    // MARK: - Interval update (called from PreferencesSheet when changed)

    func refreshIntervalDidChange() {
        if isClaudeDesktopRunning() {
            startPollTimer()
        }
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
