#!/bin/zsh
set -euo pipefail

fail=0
check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS $label"
  else
    echo "FAIL $label" >&2
    fail=1
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || { echo "FAIL macOS_required" >&2; exit 2; }
echo "PASS macOS $(sw_vers -productVersion) arch=$(uname -m)"

check chatgpt_app test -d /Applications/ChatGPT.app
check chatgpt_bundle_id test "$(plutil -extract CFBundleIdentifier raw /Applications/ChatGPT.app/Contents/Info.plist 2>/dev/null)" = com.openai.codex
check swift_compiler xcrun --find swiftc
check python3 test -x /usr/bin/python3
check curl command -v curl
check unzip command -v unzip
check local_tts test -x /usr/bin/say

if command -v ffmpeg >/dev/null 2>&1; then
  echo "PASS ffmpeg"
else
  echo "WARN ffmpeg_missing synthetic audio tests will be unavailable" >&2
fi

exit "$fail"
