import Foundation

enum RefreshState: Equatable {
    case idle
    case refreshing
    case failed(RefreshError)
}

enum RefreshError: Equatable {
    case authFailed          // refresh token dead — user must sign in to Claude Code again
    case offline
    case headersUnreadable
}

struct UsageSnapshot: Equatable {
    let sessionUtilization: Double   // 0.0–1.0 from anthropic-ratelimit-unified-5h-utilization
    let weeklyUtilization: Double    // 0.0–1.0 from anthropic-ratelimit-unified-7d-utilization
    let sessionReset: Date
    let weeklyReset: Date
    let updatedAt: Date

    static let empty = UsageSnapshot(
        sessionUtilization: 0,
        weeklyUtilization: 0,
        sessionReset: .distantFuture,
        weeklyReset: .distantFuture,
        updatedAt: .distantPast
    )
}
