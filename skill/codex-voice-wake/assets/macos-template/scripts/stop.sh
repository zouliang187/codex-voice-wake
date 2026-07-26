#!/bin/zsh
set -euo pipefail
LABEL="io.github.codex-voice-wake"
DOMAIN="gui/$UID"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
pkill -x CodexVoiceWake 2>/dev/null || true
echo "Stopped. Login plist and configuration were preserved."

