import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @Environment(UsageService.self) var service
    let onDone: () -> Void

    @State private var selectedInterval: Int = {
        let v = UserDefaults.standard.integer(forKey: "claudering.refreshInterval")
        return v == 0 ? 5 : v
    }()
    @State private var launchAtLogin: Bool = false

    private let options: [(label: String, minutes: Int, tokensPerDay: Int)] = [
        ("1 min",  1,  960),
        ("5 min",  5,  192),
        ("10 min", 10,  96),
        ("15 min", 15,  64),
        ("Off",     0,   0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: save) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Text("Preferences")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                // Invisible balance for centering
                Text("Back")
                    .font(.system(size: 12))
                    .opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text("Refresh while Claude app is open")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                ForEach(options, id: \.minutes) { option in
                    Button(action: { selectedInterval = option.minutes }) {
                        HStack(spacing: 10) {
                            Image(systemName: selectedInterval == option.minutes
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedInterval == option.minutes
                                                 ? Color.accentColor : Color.secondary)
                                .font(.system(size: 14))

                            Text(option.label)
                                .frame(width: 50, alignment: .leading)

                            if option.minutes > 0 {
                                Text("~\(option.tokensPerDay) tokens/day*")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("0 tokens/day")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .font(.system(size: 13))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }

                Text("*Assumes 8h of Claude desktop open/day.\nEach refresh ≈ 2 tokens. Stop hook + popover open also refresh.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                Divider().padding(.vertical, 12)

                Toggle(isOn: $launchAtLogin) {
                    Text("Launch at login")
                        .font(.system(size: 13))
                }
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .onAppear { launchAtLogin = currentLaunchAtLoginState() }
    }

    private func save() {
        UserDefaults.standard.set(selectedInterval, forKey: "claudering.refreshInterval")
        service.refreshIntervalDidChange()
        onDone()
    }

    private func currentLaunchAtLoginState() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}
