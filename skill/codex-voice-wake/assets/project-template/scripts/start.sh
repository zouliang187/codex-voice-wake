#!/bin/zsh
set -euo pipefail
LABEL="io.github.codex-voice-wake"
DOMAIN="gui/$UID"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [[ -f "$PLIST" ]]; then
  launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null || true
  launchctl kickstart -k "$DOMAIN/$LABEL"
else
  open "$HOME/Applications/CodexVoiceWake.app"
fi
echo "CodexVoiceWake started"

