# ClaudeMeter

A tiny Mac menu bar app that shows your real Claude subscription usage — the same numbers as Claude Code's `/usage` command, without opening a terminal.

**Session %** · **Weekly %** · **Reset timers** · One-click install

---

## Install

> **Requires:** macOS 14 (Sonoma) or later · Claude Code installed and signed in

1. Download `ClaudeMeter.app.zip` from the [latest release](../../releases/latest)
2. Unzip and move `ClaudeMeter.app` to `/Applications`
3. Remove the macOS quarantine flag (required for ad-hoc signed apps):
   ```
   xattr -dr com.apple.quarantine /Applications/ClaudeMeter.app
   ```
4. Open `ClaudeMeter.app`
5. On the macOS keychain prompt: **click Always Allow**
6. Done. The icon appears in your menu bar.

---

## How it works

ClaudeMeter reads your Claude Code OAuth access token from the macOS Keychain and makes a tiny API call to Anthropic to read the `anthropic-ratelimit-unified-*` response headers — the same source `/usage` in Claude Code uses. **The numbers are always real, never estimated.**

When the access token expires (~every 8 hours), ClaudeMeter silently runs `claude -p '.'` in the background. Claude Code refreshes its own token in the keychain, ClaudeMeter reads the new one, and continues. No manual steps. No prompts.

### Refresh triggers

- **Stop hook** — instant updates after every Claude Code response (optional, click "Install" in Preferences)
- **Polling** — every N minutes while Claude desktop app is running (configurable: 1/5/10/15/Off)
- **Popover open** — refresh on click
- **Wake from sleep / app launch** — refresh on start

### Cost

~2 tokens per refresh. At 5-min polling with 8h Claude desktop open daily ≈ 192 tokens/day ≈ 0.01% of a Max 5x weekly budget.

---

## Preferences

Click the gear in the popover or right-click the menu bar icon → Preferences:
- **Refresh interval** (with token cost shown for each option)
- **Stop hook installer** (one-click; modifies `~/.claude/settings.json`)
- **Launch at login**
- **Show Logs in Finder** / **Copy Diagnostic Info** (for bug reports)

---

## Reporting bugs

Open Preferences → **Copy Diagnostic Info**. Paste into a GitHub issue. The diagnostic blob includes app version, macOS version, and the last 200 log lines. **It never includes your access token, refresh token, or account IDs.**

Log file: `~/Library/Logs/ClaudeMeter/claudemeter.log` (local only, never auto-uploaded).

---

## Privacy

- **Tokens never leave your Mac** except in the API call to `api.anthropic.com` (which is exactly what Claude Code itself does)
- **Logs are local-only** and contain no token values, account IDs, or message content
- **No analytics, no telemetry, no servers**

---

## Legal

ClaudeMeter is an unofficial, fan-made tool. The Claude mark belongs to Anthropic and is used here solely to identify what the app tracks. No affiliation with Anthropic.

MIT License — see [LICENSE](LICENSE).
