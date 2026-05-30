import SwiftUI

struct PopoverView: View {
    @Environment(UsageService.self) var service
    let openPrefs: () -> Void

    @State private var displayedSession: Double = 0
    @State private var displayedWeekly: Double = 0
    @State private var now = Date()

    var body: some View {
        mainView
        .frame(width: 260)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .task {
            // Seed displayed values before first refresh so there's no flash from 0
            displayedSession = service.snapshot.sessionUtilization
            displayedWeekly = service.snapshot.weeklyUtilization
            await service.refresh()
        }
        .onChange(of: service.snapshot.sessionUtilization) { old, new in
            if new > old {
                withAnimation(.easeOut(duration: 0.7)) { displayedSession = new }
            } else {
                displayedSession = new
            }
        }
        .onChange(of: service.snapshot.weeklyUtilization) { old, new in
            if new > old {
                withAnimation(.easeOut(duration: 0.7)) { displayedWeekly = new }
            } else {
                displayedWeekly = new
            }
        }
    }

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                UsageRow(label: "Session",
                         displayed: displayedSession,
                         live: service.snapshot.sessionUtilization,
                         resetDate: service.snapshot.sessionReset,
                         state: service.refreshState,
                         now: now)

                UsageRow(label: "Weekly",
                         displayed: displayedWeekly,
                         live: service.snapshot.weeklyUtilization,
                         resetDate: service.snapshot.weeklyReset,
                         state: service.refreshState,
                         now: now)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            HStack(spacing: 8) {
                statusText.font(.system(size: 11)).lineLimit(1)
                Spacer()
                Button { openPrefs() } label: {
                    Image(systemName: "gear").font(.system(size: 12))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var statusText: some View {
        switch service.refreshState {
        case .idle:
            Text(updatedText).foregroundStyle(.secondary)
        case .refreshing:
            Text(service.snapshot.updatedAt == .distantPast ? "Loading…" : "Refreshing…")
                .foregroundStyle(.secondary)
        case .failed(.authFailed):
            Text("Sign in to Claude Code to refresh").foregroundStyle(.red)
        case .failed(.offline):
            Text("Offline · \(updatedText)").foregroundStyle(.secondary)
        case .failed(.headersUnreadable):
            Text("ClaudeMeter may need an update").foregroundStyle(.secondary)
        }
    }

    private var updatedText: String {
        guard service.snapshot.updatedAt != .distantPast else { return "Never updated" }
        let e = now.timeIntervalSince(service.snapshot.updatedAt)
        if e < 10 { return "Just now" }
        if e < 60 { return "\(Int(e))s ago" }
        if e < 3600 { return "\(Int(e / 60))m ago" }
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: service.snapshot.updatedAt)
    }
}

// MARK: - Usage row

private struct UsageRow: View {
    let label: String
    let displayed: Double
    let live: Double
    let resetDate: Date
    let state: RefreshState
    let now: Date

    private var barColor: Color {
        live >= 0.85 ? .red : live >= 0.60 ? .orange : .accentColor
    }

    private var resetText: String {
        guard resetDate != .distantFuture else { return "—" }
        let interval = resetDate.timeIntervalSince(now)
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
                // .contentTransition(.numericText()) smoothly counts digits up/down — macOS 14+
                Text("\(Int((displayed * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(live >= 0.85 ? .red : .primary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.7), value: displayed)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geo.size.width * displayed, height: 4)
                        .animation(.easeOut(duration: 0.7), value: displayed)
                }
            }
            .frame(height: 4)
            Text(resetText).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}
