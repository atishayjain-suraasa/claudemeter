# Phase 0 Validation Results

**Date:** 2026-05-30

## Gate A — Keychain readability

`security find-generic-password -s "Claude Code-credentials" -w` returns the full JSON payload including OAuth token from the terminal (and therefore from any app that has been granted keychain access). A one-time macOS keychain dialog will appear on first run of ClaudeMeter. After the user clicks "Always Allow," subsequent runs do not re-prompt for the same binary.

**Result: PASS**

## Gate A.1 — Claude desktop app bundle ID

`/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" /Applications/Claude.app/Contents/Info.plist`

**Result: `com.anthropic.claudefordesktop`** ✓

## Gate B — OAuth token scope against /v1/messages

Ran `curl` with the Keychain-extracted `claudeAiOauth.accessToken` against `https://api.anthropic.com/v1/messages` with `model: claude-haiku-4-5-20251001`, `max_tokens: 1`.

**Result: 200 OK** ✓

### Actual header schema (differs from plan draft — use these exact names)

```
anthropic-ratelimit-unified-status: allowed
anthropic-ratelimit-unified-5h-status: allowed
anthropic-ratelimit-unified-5h-reset: <unix timestamp>
anthropic-ratelimit-unified-5h-utilization: 0.42        ← float 0.0–1.0 = session %
anthropic-ratelimit-unified-7d-status: allowed
anthropic-ratelimit-unified-7d-reset: <unix timestamp>
anthropic-ratelimit-unified-7d-utilization: 0.05        ← float 0.0–1.0 = weekly %
anthropic-ratelimit-unified-representative-claim: five_hour
```

Key differences from plan:
- Headers use `utilization` (0.0–1.0 float) directly — no remaining/limit math needed
- Window is `7d` not `weekly`
- Reset values are Unix timestamps (not RFC3339)

Token used: `claudeAiOauth.accessToken` from the Keychain JSON payload.
Subscription confirmed: `max` / `default_claude_max_5x`
