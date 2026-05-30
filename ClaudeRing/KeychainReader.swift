import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case accessDenied
    case unexpectedData
    case missingToken
}

struct ClaudeCredentials {
    let accessToken: String
    let expiresAt: Date
}

struct KeychainReader {
    static let service = "Claude Code-credentials"

    // Read-only: never modifies the keychain item. One ACL grant (Always Allow) covers all future reads.
    static func loadCredentials() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess: break
        case errSecItemNotFound: throw KeychainError.itemNotFound
        case errSecUserCanceled, errSecAuthFailed: throw KeychainError.accessDenied
        default: throw KeychainError.accessDenied
        }

        guard
            let data = result as? Data,
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = payload["claudeAiOauth"] as? [String: Any],
            let access = oauth["accessToken"] as? String, !access.isEmpty,
            let expiresMs = oauth["expiresAt"] as? Double
        else {
            throw KeychainError.missingToken
        }

        return ClaudeCredentials(
            accessToken: access,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000)
        )
    }
}
