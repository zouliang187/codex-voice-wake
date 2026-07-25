#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
SOURCE_APP="$PROJECT_DIR/build/CodexVoiceWake.app"
TARGET_APP="$HOME/Applications/CodexVoiceWake.app"
CONFIG_DIR="$HOME/Library/Application Support/CodexVoiceWake"
CONFIG="$CONFIG_DIR/config.json"
LABEL="io.github.codex-voice-wake"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$UID"

[[ -d "$SOURCE_APP" ]] || { echo "Run scripts/build.sh first." >&2; exit 2; }
mkdir -p "$HOME/Applications" "$CONFIG_DIR" "$HOME/Library/LaunchAgents" \
  "$HOME/Library/Logs/CodexVoiceWake" "$PROJECT_DIR/work"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
if [[ -d "$TARGET_APP" ]]; then
  mv "$TARGET_APP" "$PROJECT_DIR/work/CodexVoiceWake.installed.previous.$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$SOURCE_APP" "$TARGET_APP"
if [[ ! -f "$CONFIG" ]]; then
  cp "$PROJECT_DIR/config.example.json" "$CONFIG"
fi

plutil -create xml1 "$PLIST"
plutil -insert Label -string "$LABEL" "$PLIST"
plutil -insert ProgramArguments -json \
  "[\"$TARGET_APP/Contents/MacOS/CodexVoiceWake\"]" "$PLIST"
plutil -insert RunAtLoad -bool true "$PLIST"
plutil -insert KeepAlive -bool true "$PLIST"
plutil -insert ProcessType -string Interactive "$PLIST"
plutil -insert StandardOutPath -string "$HOME/Library/Logs/CodexVoiceWake/launchd.out.log" "$PLIST"
plutil -insert StandardErrorPath -string "$HOME/Library/Logs/CodexVoiceWake/launchd.err.log" "$PLIST"
plutil -lint "$PLIST"
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "Installed: $TARGET_APP"
echo "Config:    $CONFIG"
echo "Log:       $HOME/Library/Logs/CodexVoiceWake/wake.log"
echo "Grant permissions to the installed app, never the build copy."

