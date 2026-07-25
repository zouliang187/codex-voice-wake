#!/bin/zsh
set -euo pipefail

pid="$(pgrep -x CodexVoiceWake | head -1)"
[[ -n "$pid" ]] || { echo "CodexVoiceWake is not running." >&2; exit 2; }
kill -USR1 "$pid"
sleep 2
tail -8 "$HOME/Library/Logs/CodexVoiceWake/wake.log"
echo "This tests activation and F20 only; it is not wake-word acceptance."

