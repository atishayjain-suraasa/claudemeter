import SwiftUI
import ServiceManagement

// Shared preferences content — used both inline (popover gear) and as a window (right-click)
private struct PreferencesContent: View {
    @Environment(UsageService.self) var service

    @State private var selectedInterval: Int = {
        let v = UserDefaults.standard.integer(forKey: "claudering.refreshInterval")
        return v == 0 ? 5 : v
    }()
    @State private var launchAtLogin = false
    @State private var hookStatus = StopHookInstaller.status()
    @State private var hookInstalling = false

    private let options: [(label: String, minutes: Int, tokensPerDay: Int)] = [
        ("1 min",  1,  960),
        ("5 min",  5,  192),
        ("10 min", 10,  96),
        ("15 min", 15,  64),
        ("Off",     0,   0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Refresh interval
            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh while Claude app is open")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                ForEach(options, id: \.minutes) { option in
                    Button { selectedInterval = option.minutes } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedInterval == option.minutes
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedInterval == option.minutes
                                                 ? Color.accentColor : .secondary)
                                .font(.system(size: 14))
                            Text(option.label).frame(width: 50, alignment: .leading)
                            Text(option.minutes > 0 ? "~\(option.tokensPerDay) tokens/day*" : "0 tokens/day")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .font(.system(size: 13))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }

                Text("*Assumes 8h of Claude desktop open/day. Each refresh ≈ 2 tokens.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Stop hook
            VStack(alignment: .leading, spacing: 6) {
                Text("Instant updates (Stop hook)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack {
                    Text(hookStatus == .installed
                         ? "Refreshes after every Claude Code response."
                         : "Install to refresh after every Claude Code response.")
                        .font(.system(size: 12))
                        .foregroundStyle(hookStatus == .installed ? .secondary : .primary)

                    Spacer()

                    if hookStatus == .installed {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    } else {
                        Button(hookInstalling ? "Installing…" : "Install") {
                            hookInstalling = true
                            do {
                                try StopHookInstaller.install()
                                hookStatus = .installed
                            } catch {
                                // silently fail — user can install manually
                            }
                            hookInstalling = false
                        }
                        .disabled(hookInstalling)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            Divider()

            // Launch at login
            Toggle(isOn: $launchAtLogin) {
                Text("Launch at login")
                    .font(.system(size: 13))
            }
            .toggleStyle(.checkbox)
            .onChange(of: launchAtLogin) { _, new in setLaunchAtLogin(new) }
        }
        .onAppear { launchAtLogin = currentLoginState() }
        .onChange(of: selectedInterval) { _, new in
            UserDefaults.standard.set(new, forKey: "claudering.refreshInterval")
            service.refreshIntervalDidChange()
        }
    }

    private func currentLoginState() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}

// MARK: - Inline (gear in popover)

struct PreferencesView: View {
    @Environment(UsageService.self) var service
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text("Back").font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text("Preferences").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Back").font(.system(size: 12)).opacity(0) // balance
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                PreferencesContent()
                    .environment(service)
                    .padding(16)
            }
        }
    }
}

// MARK: - Standalone window (right-click Preferences)

