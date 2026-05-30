import Foundation

// When our cached access token expires, we don't refresh it ourselves (that would
// require writing to Claude Code's keychain item, which prompts the user separately).
// Instead, we spawn a tiny `claude` subprocess. Claude Code sees its expired token,
// refreshes it via its own OAuth flow (the keychain item is owned by Claude Code,
// so it has unprompted write access), and writes the new token to the keychain.
// We then re-read the keychain — silently, since we already have read ACL.

enum ClaudeRefreshError: Error {
    case claudeNotInstalled
    case subprocessFailed(Int32)
    case timeout
}

struct ClaudeRefreshTrigger {
    private static let timeoutSeconds: Double = 30

    static func triggerRefresh() async throws {
        // Run claude via a login shell so PATH includes nvm/brew/etc — same as
        // when the user runs `claude` in their terminal. `claude -p .` makes a
        // minimal API call, which forces a token refresh if the token is expired.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "claude -p '.' > /dev/null 2>&1"]

        // Redirect output away from app — we don't care about claude's stdout/stderr
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw ClaudeRefreshError.claudeNotInstalled
        }

        // Wait for completion with a timeout
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                throw ClaudeRefreshError.timeout
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms poll
        }

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            throw ClaudeRefreshError.subprocessFailed(exitCode)
        }
    }
}
