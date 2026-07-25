#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
MODEL_NAME="vosk-model-small-cn-0.22"
MODEL_ZIP="$PROJECT_DIR/work/$MODEL_NAME.zip"
MODEL_DIR="$PROJECT_DIR/runtime/models/$MODEL_NAME"
MODEL_SHA256="3af8b0e7e0f835ae9d414ce5df580237a3cfb08d586c9fbbb0f7ff29ad5b14ba"
SYSTEM_PYTHON="/usr/bin/python3"
VENV_PYTHON="$PROJECT_DIR/runtime/venv/bin/python"
APP="$PROJECT_DIR/build/CodexVoiceWake.app"
SIGNING_REQUIREMENT='=designated => identifier "io.github.codex-voice-wake"'

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS is required." >&2; exit 2; }
[[ -x "$SYSTEM_PYTHON" ]] || { echo "Install Apple Command Line Tools first." >&2; exit 2; }
mkdir -p "$PROJECT_DIR/work" "$PROJECT_DIR/runtime/models" "$PROJECT_DIR/build"

if [[ ! -x "$VENV_PYTHON" ]]; then
  "$SYSTEM_PYTHON" -m venv "$PROJECT_DIR/runtime/venv"
fi
if ! "$VENV_PYTHON" -c 'import vosk' 2>/dev/null; then
  "$VENV_PYTHON" -m pip install --upgrade pip
  "$VENV_PYTHON" -m pip install 'vosk==0.3.44'
fi

if [[ ! -d "$MODEL_DIR" ]]; then
  if [[ ! -f "$MODEL_ZIP" ]]; then
    curl --fail --location --output "$MODEL_ZIP" \
      "https://alphacephei.com/vosk/models/$MODEL_NAME.zip"
  fi
  actual_sha256="$(shasum -a 256 "$MODEL_ZIP" | awk '{print $1}')"
  if [[ "$actual_sha256" != "$MODEL_SHA256" ]]; then
    echo "Model checksum mismatch: $actual_sha256" >&2
    exit 3
  fi
  unzip -tq "$MODEL_ZIP"
  unzip -q "$MODEL_ZIP" -d "$PROJECT_DIR/runtime/models"
fi

if [[ -d "$APP" ]]; then
  mv "$APP" "$PROJECT_DIR/work/CodexVoiceWake.previous.$(date +%Y%m%d-%H%M%S).app"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/python"
cp "$PROJECT_DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_DIR/config.example.json" "$APP/Contents/Resources/config.json"
cp "$PROJECT_DIR/wake_listener.py" "$APP/Contents/Resources/wake_listener.py"
ditto "$MODEL_DIR" "$APP/Contents/Resources/model"
site_packages="$("$VENV_PYTHON" -c 'import site; print(site.getsitepackages()[0])')"
ditto "$site_packages" "$APP/Contents/Resources/python"

mkdir -p "$PROJECT_DIR/work/swift-module-cache"
swift_target="$(uname -m)-apple-macosx13.0"
xcrun swiftc -O \
  -target "$swift_target" \
  -module-cache-path "$PROJECT_DIR/work/swift-module-cache" \
  -framework AppKit \
  -framework AVFoundation \
  -framework ApplicationServices \
  "$PROJECT_DIR/Sources/WakeHost/main.swift" \
  -o "$APP/Contents/MacOS/CodexVoiceWake"

codesign --force --deep --sign - --requirements "$SIGNING_REQUIREMENT" "$APP"
codesign --verify --deep --strict "$APP"
if ! codesign -d -r- "$APP" 2>&1 | /usr/bin/grep -Fq 'designated => identifier "io.github.codex-voice-wake"'; then
  echo "Stable designated requirement was not embedded." >&2
  exit 4
fi
echo "Built: $APP"
