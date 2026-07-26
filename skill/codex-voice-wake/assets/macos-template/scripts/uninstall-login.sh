#!/bin/zsh
set -euo pipefail
LABEL="io.github.codex-voice-wake"
DOMAIN="gui/$UID"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
APP="$HOME/Applications/CodexVoiceWake.app"
TRASH="$HOME/.Trash"
STAMP="$(date +%Y%m%d-%H%M%S)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
mkdir -p "$TRASH"
if [[ -f "$PLIST" ]]; then
  mv "$PLIST" "$TRASH/$LABEL.$STAMP.plist"
fi
if [[ -d "$APP" ]]; then
  mv "$APP" "$TRASH/CodexVoiceWake.$STAMP.app"
fi
echo "Removed the login agent and moved the app to Trash."
echo "Configuration and logs were preserved for recovery."

