import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case accessDenied
    case unexpectedData
    case missingToken
    case writeFailed(OSStatus)
}

struct ClaudeCredentials {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date           // when accessToken expires
    let fullPayload: [String: Any] // the entire keychain JSON, preserved for write-back
}

struct KeychainReader {
    static let service = "Claude Code-credentials"

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
            let refresh = oauth["refreshToken"] as? String, !refresh.isEmpty,
            let expiresMs = oauth["expiresAt"] as? Double
        else {
            throw KeychainError.missingToken
        }

        return ClaudeCredentials(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000),
            fullPayload: payload
        )
    }

    // Write back the full payload with updated claudeAiOauth values.
    // The caller has already merged new tokens into a copy of fullPayload.
    static func writeCredentials(payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError.writeFailed(addStatus)
            }
            return
        }

        throw KeychainError.writeFailed(updateStatus)
    }
}
