import SwiftUI

struct PopoverView: View {
    @Environment(UsageService.self) var service
    @State private var showPrefs = false
    @State private var now = Date()
    @State private var ticker: Timer?

    var body: some View {
        Group {
            if showPrefs {
                PreferencesView(onDone: { showPrefs = false })
                    .environment(service)
            } else {
                mainView
            }
        }
        .frame(width: 260)
        .onDisappear {
            stopTicker()
            showPrefs = false
        }
    }

    // MARK: - Main view

    private var mainView: some View {
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
                statusText
                    .font(.system(size: 11))
                    .lineLimit(1)
                Spacer()
                Button(action: { showPrefs = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Preferences")

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .task {
            await service.refresh()
            startTicker()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch service.refreshState {
        case .idle:
            Text(updatedText).foregroundStyle(.secondary)
        case .refreshing:
            Text("Refreshing…").foregroundStyle(.secondary)
        case .failed(.authFailed):
            Text("Auth failed · open Claude Code").foregroundStyle(.red)
        case .failed(.offline):
            Text("Offline · \(updatedText)").foregroundStyle(.secondary)
        case .failed(.headersUnreadable):
            Text("ClaudeRing may need an update").foregroundStyle(.secondary)
        }
    }

    private var updatedText: String {
        if service.snapshot.updatedAt == .distantPast { return "Never updated" }
        let elapsed = now.timeIntervalSince(service.snapshot.updatedAt)
        if elapsed < 10 { return "Just now" }
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: service.snapshot.updatedAt)
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in now = Date() }
    }
    private func stopTicker() { ticker?.invalidate(); ticker = nil }
}

// MARK: - Usage row

private struct UsageRow: View {
    let label: String
    let utilization: Double
    let resetDate: Date
    let state: RefreshState

    private var barColor: Color {
        utilization >= 0.85 ? .red : utilization >= 0.60 ? .orange : .accentColor
    }

    private var resetText: String {
        guard resetDate != .distantFuture else { return "—" }
        let interval = resetDate.timeIntervalSinceNow
        if interval <= 0 { return "Resetting…" }
        let h = Int(interval / 3600)
        let m = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if h > 24 {
            let f = DateFormatter(); f.dateFormat = "EEE d MMM, HH:mm"
            return "Resets \(f.string(from: resetDate))"
        }
        return h > 0 ? "Resets in \(h)h \(m)m" : "Resets in \(m)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(state == .refreshing ? "—" : "\(Int(utilization * 100))%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(utilization >= 0.85 ? .red : .primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.1)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(barColor)
                        .frame(width: geo.size.width * utilization, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: utilization)
                }
            }
            .frame(height: 4)
            Text(resetText).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}
