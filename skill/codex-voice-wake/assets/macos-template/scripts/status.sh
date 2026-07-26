#!/bin/zsh
set -u
LABEL="io.github.codex-voice-wake"
DOMAIN="gui/$UID"
LOG="$HOME/Library/Logs/CodexVoiceWake/wake.log"

if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
  echo "launch_agent=loaded"
  launchctl print "$DOMAIN/$LABEL" | grep -E 'state =|pid =|last exit code ='
else
  echo "launch_agent=not_loaded"
fi
pgrep -alf 'CodexVoiceWake|wake_listener.py' || true
if [[ -f "$LOG" ]]; then
  echo "recent_log:"
  tail -20 "$LOG"
fi
