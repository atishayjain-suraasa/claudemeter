import SwiftUI
import ServiceManagement

struct PreferencesSheet: View {
    @Environment(UsageService.self) var service
    @Environment(\.dismiss) var dismiss

    @State private var selectedInterval: Int = UserDefaults.standard.integer(forKey: "claudering.refreshInterval").nonZeroOr(5)
    @State private var launchAtLogin: Bool = false

    private let intervals: [(label: String, minutes: Int, tokensPerDay: Int)] = [
        ("1 min",  1,  960),
        ("5 min",  5,  192),
        ("10 min", 10,  96),
        ("15 min", 15,  64),
        ("Off",     0,   0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Refresh while Claude app is open")
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 12)

            ForEach(intervals, id: \.minutes) { option in
                HStack(spacing: 10) {
                    Image(systemName: selectedInterval == option.minutes ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(selectedInterval == option.minutes ? Color.accentColor : Color.secondary)
                        .font(.system(size: 14))

                    Text(option.label)
                        .frame(width: 48, alignment: .leading)

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
                .onTapGesture {
                    selectedInterval = option.minutes
                }
                .padding(.vertical, 4)
            }

            Text("*Assumes 8 hours of Claude desktop open per day.\nEach refresh ≈ 2 tokens. Stop hook + opening\nthis popover also refresh; those are always on.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 12)

            Toggle(isOn: $launchAtLogin) {
                Text("Launch ClaudeRing at login")
                    .font(.system(size: 13))
            }
            .toggleStyle(.checkbox)
            .onChange(of: launchAtLogin) { _, newValue in
                setLaunchAtLogin(newValue)
            }

            Spacer(minLength: 16)

            HStack {
                Spacer()
                Button("Done") {
                    UserDefaults.standard.set(selectedInterval, forKey: "claudering.refreshInterval")
                    service.refreshIntervalDidChange()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { launchAtLogin = currentLaunchAtLoginState() }
    }

    private func currentLaunchAtLoginState() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // If registration fails, reflect actual state
                launchAtLogin = currentLaunchAtLoginState()
            }
        }
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
