import Foundation

enum TokenRefreshError: Error {
    case invalidGrant        // refresh token is dead — user must sign in to Claude Code again
    case network(Error)
    case badResponse
    case serverError(Int)
}

struct TokenRefresher {
    private static let endpoint = URL(string: "https://claude.ai/v1/oauth/token")!
    private static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    // Refreshes the access token using the refresh token. On success, writes the
    // entire updated payload back to the keychain (preserving any non-Claude keys
    // like mcpOAuth) and returns the new credentials.
    //
    // Refresh tokens ROTATE — the response includes a new refresh_token that
    // invalidates the one we just used. We MUST persist immediately or lose access.
    static func refresh(using credentials: ClaudeCredentials) async throws -> ClaudeCredentials {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": credentials.refreshToken,
            "client_id": clientID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TokenRefreshError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw TokenRefreshError.badResponse
        }

        if http.statusCode == 400 || http.statusCode == 401 {
            // invalid_grant — refresh token dead; user needs to re-auth via Claude Code
            throw TokenRefreshError.invalidGrant
        }

        if http.statusCode >= 500 {
            throw TokenRefreshError.serverError(http.statusCode)
        }

        guard
            http.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let newAccess = json["access_token"] as? String,
            let newRefresh = json["refresh_token"] as? String,
            let expiresIn = json["expires_in"] as? Double
        else {
            throw TokenRefreshError.badResponse
        }

        // Merge into the existing payload — preserves mcpOAuth, subscriptionType, scopes, etc.
        var updatedPayload = credentials.fullPayload
        var oauth = (updatedPayload["claudeAiOauth"] as? [String: Any]) ?? [:]
        oauth["accessToken"] = newAccess
        oauth["refreshToken"] = newRefresh
        // expiresAt is stored as unix ms in the keychain JSON (matches Claude Code's format)
        oauth["expiresAt"] = (Date().timeIntervalSince1970 + expiresIn) * 1000
        updatedPayload["claudeAiOauth"] = oauth

        try KeychainReader.writeCredentials(payload: updatedPayload)

        return ClaudeCredentials(
            accessToken: newAccess,
            refreshToken: newRefresh,
            expiresAt: Date().addingTimeInterval(expiresIn),
            fullPayload: updatedPayload
        )
    }
}
