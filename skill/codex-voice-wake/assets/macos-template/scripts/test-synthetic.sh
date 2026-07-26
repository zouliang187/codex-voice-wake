#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
MODEL="$PROJECT_DIR/runtime/models/vosk-model-small-cn-0.22"
PYTHON="$PROJECT_DIR/runtime/venv/bin/python"
CONFIG="$PROJECT_DIR/config.json"
WORK="$PROJECT_DIR/work/tests"
WAKE_AIFF="$WORK/wake.aiff"
EXIT_AIFF="$WORK/exit.aiff"
SENTENCE_AIFF="$WORK/exit-sentence.aiff"
WAKE_SENTENCE_AIFF="$WORK/wake-sentence.aiff"
WAKE_WAV="$WORK/wake.wav"
EXIT_WAV="$WORK/exit.wav"
SENTENCE_WAV="$WORK/exit-sentence.wav"
WAKE_SENTENCE_WAV="$WORK/wake-sentence.wav"
SEQUENCE_WAV="$WORK/wake-exit.wav"
NEGATIVE_WAV="$WORK/embedded-exit.wav"
ACTIVE_WAKE_NEGATIVE_WAV="$WORK/active-wake-sentence.wav"
REWAKE_WAV="$WORK/wake-exit-wake.wav"

[[ -d "$MODEL" ]] || { echo "Run scripts/build.sh first." >&2; exit 2; }
[[ -f "$CONFIG" ]] || { echo "Missing config.json; scaffold with a chosen wake phrase first." >&2; exit 2; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required." >&2; exit 3; }
mkdir -p "$WORK"

WAKE_TEXT="$($PYTHON -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["wakePhrases"][0])' "$CONFIG")"
EXIT_TEXT="$($PYTHON -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["exitPhrases"][0])' "$CONFIG")"
SYNTHETIC_VOICE="$($PYTHON -c 'import json,sys; data=json.load(open(sys.argv[1], encoding="utf-8")); print(data.get("syntheticVoice") or data.get("acknowledgementVoice", ""))' "$CONFIG")"
SENTENCE_TEXT="请不要把${EXIT_TEXT}当成单独口令"
WAKE_SENTENCE_TEXT="我刚才说${WAKE_TEXT}只是举个例子"

[[ -n "$SYNTHETIC_VOICE" ]] || { echo "Set syntheticVoice or acknowledgementVoice in config.json." >&2; exit 4; }
say -v "$SYNTHETIC_VOICE" -r 155 -o "$WAKE_AIFF" "$WAKE_TEXT"
say -v "$SYNTHETIC_VOICE" -r 155 -o "$EXIT_AIFF" "$EXIT_TEXT"
say -v "$SYNTHETIC_VOICE" -r 155 -o "$SENTENCE_AIFF" "$SENTENCE_TEXT"
say -v "$SYNTHETIC_VOICE" -r 155 -o "$WAKE_SENTENCE_AIFF" "$WAKE_SENTENCE_TEXT"
ffmpeg -hide_banner -loglevel error -y -i "$WAKE_AIFF" -ar 16000 -ac 1 -c:a pcm_s16le "$WAKE_WAV"
ffmpeg -hide_banner -loglevel error -y -i "$EXIT_AIFF" -ar 16000 -ac 1 -c:a pcm_s16le "$EXIT_WAV"
ffmpeg -hide_banner -loglevel error -y -i "$SENTENCE_AIFF" -ar 16000 -ac 1 -c:a pcm_s16le "$SENTENCE_WAV"
ffmpeg -hide_banner -loglevel error -y -i "$WAKE_SENTENCE_AIFF" -ar 16000 -ac 1 -c:a pcm_s16le "$WAKE_SENTENCE_WAV"
ffmpeg -hide_banner -loglevel error -y \
  -i "$WAKE_WAV" -f lavfi -t 4 -i anullsrc=r=16000:cl=mono -i "$EXIT_WAV" \
  -filter_complex '[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]' -map '[out]' -c:a pcm_s16le "$SEQUENCE_WAV"
ffmpeg -hide_banner -loglevel error -y \
  -i "$WAKE_WAV" -f lavfi -t 4 -i anullsrc=r=16000:cl=mono -i "$SENTENCE_WAV" \
  -filter_complex '[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]' -map '[out]' -c:a pcm_s16le "$NEGATIVE_WAV"
ffmpeg -hide_banner -loglevel error -y \
  -i "$WAKE_WAV" -f lavfi -t 4 -i anullsrc=r=16000:cl=mono \
  -i "$EXIT_WAV" -f lavfi -t 4 -i anullsrc=r=16000:cl=mono -i "$WAKE_WAV" \
  -filter_complex '[0:a][1:a][2:a][3:a][4:a]concat=n=5:v=0:a=1[out]' -map '[out]' -c:a pcm_s16le "$REWAKE_WAV"
ffmpeg -hide_banner -loglevel error -y \
  -i "$WAKE_WAV" -f lavfi -t 4 -i anullsrc=r=16000:cl=mono -i "$WAKE_SENTENCE_WAV" \
  -filter_complex '[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]' -map '[out]' -c:a pcm_s16le "$ACTIVE_WAKE_NEGATIVE_WAV"

run_test() {
  local name="$1" wav="$2" expected="$3"
  echo "$name:"
  PYTHONPATH="$($PYTHON -c 'import site; print(site.getsitepackages()[0])')" \
    "$PYTHON" "$PROJECT_DIR/wake_listener.py" \
    --model "$MODEL" --config "$CONFIG" \
    --wav "$wav" --expect-sequence "$expected"
}

run_test positive_state_machine "$SEQUENCE_WAV" wake,exit
run_test embedded_exit_negative "$NEGATIVE_WAV" wake
run_test wake_exit_wake_regression "$REWAKE_WAV" wake,exit,wake
run_test embedded_wake_idle_negative "$WAKE_SENTENCE_WAV" ""
run_test wake_ignored_during_active_conversation "$ACTIVE_WAKE_NEGATIVE_WAV" wake
