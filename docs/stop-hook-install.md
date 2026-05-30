# Install the Stop Hook (Optional but Recommended)

The Stop hook triggers ClaudeMeter to refresh its numbers instantly after every Claude Code response, so you never have to open the popover to see fresh data.

Without it, ClaudeMeter still refreshes when:
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
            "command": "date +%s > \"$HOME/Library/Application Support/ClaudeMeter/trigger\" 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

The `|| true` at the end means: if ClaudeMeter isn't running or the file doesn't exist, the hook does nothing. ClaudeMeter watches this file for changes and refreshes within 1 second of the hook firing.

## How to uninstall

Remove the `hooks` block (or just the ClaudeMeter entry) from `~/.claude/settings.json`.
