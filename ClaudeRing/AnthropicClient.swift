import Foundation

struct AnthropicClient {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    struct RateLimitData {
        let sessionUtilization: Double
        let weeklyUtilization: Double
        let sessionReset: Date
        let weeklyReset: Date
    }

    enum ClientError: Error {
        case unauthorized
        case missingHeaders
        case networkError(Error)
    }

    static func fetchUsage(token: String) async throws -> RateLimitData {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "."]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClientError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClientError.missingHeaders
        }

        if http.statusCode == 401 {
            throw ClientError.unauthorized
        }

        guard
            let sessionStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-5h-utilization"),
            let weeklyStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-7d-utilization"),
            let sessionResetStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-5h-reset"),
            let weeklyResetStr = http.value(forHTTPHeaderField: "anthropic-ratelimit-unified-7d-reset"),
            let sessionUtil = Double(sessionStr),
            let weeklyUtil = Double(weeklyStr),
            let sessionResetTs = TimeInterval(sessionResetStr),
            let weeklyResetTs = TimeInterval(weeklyResetStr)
        else {
            throw ClientError.missingHeaders
        }

        return RateLimitData(
            sessionUtilization: sessionUtil,
            weeklyUtilization: weeklyUtil,
            sessionReset: Date(timeIntervalSince1970: sessionResetTs),
            weeklyReset: Date(timeIntervalSince1970: weeklyResetTs)
        )
    }
}
