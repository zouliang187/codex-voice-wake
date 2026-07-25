# Permissions, signing, and validation

## Stable identity before authorization

Build and install the final bundle path before asking for permissions. The
template signs ad hoc with a fixed designated requirement:

```text
designated => identifier "io.github.codex-voice-wake"
```

Keep the bundle ID, installed path, executable name, and designated requirement
stable across updates. Verify with:

```sh
codesign --verify --deep --strict --verbose=2 \
  "$HOME/Applications/CodexVoiceWake.app"
codesign -d -r- --verbose=4 \
  "$HOME/Applications/CodexVoiceWake.app"
```

Do not treat a matching display name as proof that the TCC entry points to the
running app.

## Required macOS permissions

- **Microphone**: required for the installed host to receive audio.
- **Accessibility**: required for the installed host to post F20 and Escape.
- **ChatGPT microphone**: separately required by ChatGPT Voice.

If authorization is missing, direct the user to **System Settings > Privacy &
Security**, add the exact installed app, and let the user enter any password or
approve any protected prompt. Never automate password entry.

## Voice hotkey

Run the bundled `configure-f20.py`, restart ChatGPT, and verify that
`~/.codex/keybindings.json` contains a `realtimeVoice` entry using `F20`. The
script preserves unrelated entries and writes a backup when it changes the
file.

Official ChatGPT Voice guidance says a task must begin in Voice mode and that
the shortcut is configured in **Settings > Voice > Voice chat hotkey**:
<https://learn.chatgpt.com/docs/features/voice>.

## Evidence ladder

1. **Static**: bundle identity, signature, configuration, and LaunchAgent path.
2. **Runtime**: host and worker PIDs, accessibility result, audio listening log,
   and current input device/sample rate.
3. **Offline diagnostic**: Vosk synthetic WAV tests for all state transitions.
4. **Action diagnostic**: F20 causes `thread/realtime/start`; Escape causes
   `thread/realtime/stop`.
5. **Acceptance**: a person naturally speaks the full wake/exit/wake sequence
   from a normal non-Voice screen.

Levels 1–4 never substitute for level 5.

## Privacy checks

- Keep `logTranscripts=false`.
- Do not commit `runtime/`, `build/`, `work/`, audio fixtures generated during
  tests, user configs, LaunchAgent plists, logs, or TCC databases.
- Do not upload audio. Synthetic audio should be generated locally and deleted
  or ignored by version control.

