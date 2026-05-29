# ClaudeRing

A tiny Mac menu bar app that shows your real Claude subscription usage — the exact same numbers as Claude Code's `/usage` command, without opening a terminal.

**Session ring** (5-hour window) · **Weekly bar** · **Reset timers** · Zero config

---

## What it looks like

The Claude sparkle icon sits in your menu bar wrapped in a progress ring. The ring fills as your 5-hour session quota is consumed:

- **Gray** — 0–59% used
- **Orange** — 60–84%
- **Red** — 85–100%

Click the icon to see both session and weekly usage with exact reset times.

---

## Install

> **Requires:** macOS 14 (Sonoma) or later · Claude Code installed and signed in

1. Download `ClaudeRing.app.zip` from the [latest release](../../releases/latest)
2. Unzip and move `ClaudeRing.app` to `/Applications`
3. Remove the quarantine flag (required for ad-hoc-signed apps):
   ```
   xattr -dr com.apple.quarantine /Applications/ClaudeRing.app
   ```
4. Open `ClaudeRing.app` — a keychain prompt will appear once. Click **Always Allow**
5. The ring appears in your menu bar

---

## How it works

ClaudeRing reads your Claude Code OAuth token from the macOS Keychain (where Claude Code stores it) and makes a tiny API call to Anthropic to read the `anthropic-ratelimit-unified-*` response headers. Those headers are the same source Claude Code's own `/usage` command uses.

**The numbers are always real — never estimated from local files.**

### When does it refresh?

| Trigger | When |
|---|---|
| Stop hook | Instantly after every Claude Code response (optional, see below) |
| Claude desktop app running | Every N minutes while the app is open (configurable, default 5 min) |
| Open the popover | Always refreshes when you click the icon |
| Mac wakes from sleep | On every wake |

### How much does it cost?

Each refresh = 1 tiny API call = ~2 tokens against your quota.

| Interval | Tokens/day* |
|---|---|
| 1 min | ~960 |
| 5 min (default) | ~192 |
| 10 min | ~96 |
| Off | 0 |

*Assumes 8 hours of Claude desktop app open per day. Stop hook + popover refreshes are always on; each one costs ~2 tokens.

At 5-minute intervals with 8h open daily, ClaudeRing uses ~192 tokens/day — less than 0.01% of a Max 5x weekly budget.

---

## Optional: Stop hook for instant updates

Install this once and ClaudeRing will update the ring immediately after every Claude Code response, not just when you click it.

See [docs/stop-hook-install.md](docs/stop-hook-install.md) for the one-time setup (paste a JSON snippet into `~/.claude/settings.json`).

---

## How much does it cost?

See [How much does it cost?](#how-much-does-it-cost) above.

---

## Preferences

Click the gear icon in the popover:
- **Refresh interval** — how often to poll when the Claude desktop app is open
- **Launch at login** — start ClaudeRing automatically when you log in

---

## Legal

ClaudeRing is an unofficial, fan-made tool. The Claude sparkle mark belongs to Anthropic and is used here solely to identify what the app tracks. This project has no affiliation with Anthropic.

MIT License — see [LICENSE](LICENSE)
