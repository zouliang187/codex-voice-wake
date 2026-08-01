# macOS installation, permissions, and validation

## Create and build

Run the cross-platform scaffolder from the Skill directory after collecting the
chosen phrase:

```sh
python3 scripts/scaffold_project.py --platform macos \
  --target ./codex-voice-wake-macos --wake-phrase "<chosen phrase>"
cd ./codex-voice-wake-macos
./scripts/build.sh
./scripts/install-login.sh
```

The bundled downloader is pinned to a small Mandarin Vosk model. Configuration
accepts any phrase text, but reliable recognition requires a model whose
language and vocabulary contain it. Add likely ASR variants during scaffolding
and reject the phrase only after natural voice evidence, not guesswork.

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
6. **External-close acceptance**: after a wake, close Voice through its UI or
   Escape, confirm `STATE sync_reset=true reason=voice_stopped state=idle`, and
   naturally wake again.

Levels 1–4 never substitute for levels 5–6.

The state synchronizer reads only ChatGPT's local realtime start/stop event
types under `~/Library/Logs/com.openai.codex`; it does not read conversation
text. If F20 never produces a real start event, the listener returns to `idle`
after the configured activation check instead of remaining stuck. There is no
timeout after a real Voice session becomes active.

The reference implementation was revalidated on one Apple silicon Mac mini
after the standalone-command fix. A natural wake opened Voice; a sentence that
contained both command phrases caused no listener event; a standalone exit
closed Voice and returned the listener to `idle`; and a later standalone wake
opened Voice again. Other Macs and every new custom phrase still require level
5 acceptance.

## Privacy checks

- Keep `logTranscripts=false`.
- Do not commit `runtime/`, `build/`, `work/`, audio fixtures generated during
  tests, user configs, LaunchAgent plists, logs, or TCC databases.
- Do not upload audio. Synthetic audio should be generated locally and deleted
  or ignored by version control.
