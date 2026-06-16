#!/usr/bin/env bash
set -euo pipefail

LABEL="com.local.agent-usage-float"
OLD_LABEL="com.local.codex-usage-float"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
OLD_PLIST_PATH="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"

launchctl bootout "gui/$UID" "$PLIST_PATH" 2>/dev/null || true
launchctl bootout "gui/$UID" "$OLD_PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"
rm -f "$OLD_PLIST_PATH"

echo "Uninstalled $LABEL"
