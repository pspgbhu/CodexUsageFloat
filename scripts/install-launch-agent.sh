#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/AgentUsageFloat.app}"
LABEL="com.local.agent-usage-float"
OLD_LABEL="com.local.codex-usage-float"
DRY_RUN="${DRY_RUN:-0}"
PLIST_PATH="${PLIST_PATH:-$HOME/Library/LaunchAgents/$LABEL.plist}"
OLD_PLIST_PATH="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
LOG_DIR="$HOME/Library/Logs/AgentUsageFloat"

if [[ ! -d "$APP_PATH" ]]; then
  "$ROOT_DIR/scripts/package-app.sh" >/dev/null
fi

EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/AgentUsageFloat"
if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Executable not found: $EXECUTABLE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$PLIST_PATH")" "$LOG_DIR"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$EXECUTABLE_PATH</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>Crashed</key>
    <true/>
  </dict>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/stderr.log</string>
</dict>
</plist>
PLIST

plutil -lint "$PLIST_PATH"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run OK: $PLIST_PATH"
  exit 0
fi

# Remove the pre-rename LaunchAgent so only AgentUsageFloat runs at login.
launchctl bootout "gui/$UID" "$OLD_PLIST_PATH" 2>/dev/null || true
rm -f "$OLD_PLIST_PATH"
launchctl bootout "gui/$UID" "$PLIST_PATH" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST_PATH"
launchctl enable "gui/$UID/$LABEL" 2>/dev/null || true
launchctl kickstart -k "gui/$UID/$LABEL" 2>/dev/null || true

echo "Installed $LABEL"
