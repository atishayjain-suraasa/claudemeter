# Install the Stop Hook (Optional but Recommended)

The Stop hook triggers ClaudeRing to refresh its numbers instantly after every Claude Code response, so you never have to open the popover to see fresh data.

Without it, ClaudeRing still refreshes when:
- You open the popover
- The Claude desktop app is running (every 5 min by default)
- Your Mac wakes from sleep

## How to install

Open `~/.claude/settings.json` and add the `hooks` block. If the file already has other settings, merge the `hooks` key in — don't replace the whole file.

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "curl -fsS --max-time 1 --unix-socket \"$HOME/Library/Application Support/ClaudeRing/refresh.sock\" http://localhost/refresh > /dev/null 2>&1 || true"
          }
        ]
      }
    ]
  }
}
```

The `|| true` at the end means: if ClaudeRing isn't running, the hook does nothing. Removing the app won't break Claude Code.

## How to uninstall

Remove the `hooks` block (or just the ClaudeRing entry) from `~/.claude/settings.json`.
