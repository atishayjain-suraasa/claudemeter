import SwiftUI

struct PopoverView: View {
    @Environment(UsageService.self) var service
    let onClose: () -> Void

    @State private var showPrefs = false
    @State private var now = Date()
    @State private var ticker: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                UsageRow(
                    label: "Session",
                    utilization: service.snapshot.sessionUtilization,
                    resetDate: service.snapshot.sessionReset,
                    state: service.refreshState
                )

                UsageRow(
                    label: "Weekly",
                    utilization: service.snapshot.weeklyUtilization,
                    resetDate: service.snapshot.weeklyReset,
                    state: service.refreshState
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            HStack(spacing: 8) {
                Group {
                    switch service.refreshState {
                    case .idle:
                        Text(updatedText)
                            .foregroundStyle(.secondary)
                    case .refreshing:
                        Text("Refreshing…")
                            .foregroundStyle(.secondary)
                    case .failed(.authFailed):
                        Text("Auth failed · open Claude Code")
                            .foregroundStyle(.red)
                    case .failed(.offline):
                        Text("Offline · \(updatedText)")
                            .foregroundStyle(.secondary)
                    case .failed(.headersUnreadable):
                        Text("ClaudeRing may need an update")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 11))
                .lineLimit(1)

                Spacer()

                Button(action: { showPrefs = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Preferences")

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 260)
        .task {
            await service.refresh()
            startTicker()
        }
        .onDisappear {
            stopTicker()
            showPrefs = false   // reset so next open starts fresh
        }
        .sheet(isPresented: $showPrefs, onDismiss: { showPrefs = false }) {
            PreferencesSheet()
                .environment(service)
        }
    }

    private var updatedText: String {
        if service.snapshot.updatedAt == .distantPast { return "Never updated" }
        let elapsed = now.timeIntervalSince(service.snapshot.updatedAt)
        if elapsed < 10 { return "Just now" }
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: service.snapshot.updatedAt)
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in now = Date() }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}

private struct UsageRow: View {
    let label: String
    let utilization: Double
    let resetDate: Date
    let state: RefreshState

    private var barColor: Color {
        if utilization >= 0.85 { return .red }
        if utilization >= 0.60 { return .orange }
        return .accentColor
    }

    private var resetText: String {
        if resetDate == .distantFuture { return "—" }
        let interval = resetDate.timeIntervalSinceNow
        if interval <= 0 { return "Resetting…" }
        let hours = Int(interval / 3600)
        let mins = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 24 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d MMM, HH:mm"
            return "Resets \(formatter.string(from: resetDate))"
        }
        if hours > 0 { return "Resets in \(hours)h \(mins)m" }
        return "Resets in \(mins)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(state == .refreshing ? "—" : "\(Int(utilization * 100))%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(utilization >= 0.85 ? .red : .primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geo.size.width * utilization, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: utilization)
                }
            }
            .frame(height: 4)

            Text(resetText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
