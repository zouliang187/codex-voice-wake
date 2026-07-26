---
name: codex-voice-wake
description: Install, configure, diagnose, or validate an experimental local wake-word launcher for ChatGPT/Codex desktop Voice on macOS or Windows. Use when a user wants to choose any custom wake phrase, keep a private offline Vosk listener running at login, hear a local acknowledgement, open Voice with F20, leave with a standalone exit phrase, reject command words embedded in longer speech, or verify microphone, keyboard-control, signing, startup, and real spoken acceptance boundaries.
---

# Codex Voice Wake

Create a platform-specific launcher from the bundled templates. Keep audio local,
preserve permission identity, and separate automated evidence from human speech.

## Guardrails

- Do not change DNS, proxies, TUN, sleep, display, lock-screen, or unrelated
  security settings.
- Do not record, retain, upload, or log microphone transcripts by default.
- Never use synthetic playback as proof of natural spoken success.
- Treat the macOS path as previously validated on one Apple silicon Mac setup;
  re-accept every new phrase and machine.
- Treat Windows as experimental until a real Windows device completes the full
  spoken loop. CI and unit tests are not runtime acceptance.
- Do not claim a cold launch works until a fully quit ChatGPT app is launched
  and enters Voice from a natural spoken wake on that platform.

## Workflow

1. **Before running anything, ask the user to choose the exact wake phrase.**
   Also ask for any likely ASR spelling/spacing variants. Offer standalone exit
   phrase `退出` and acknowledgement `在呢` as editable defaults.
2. Detect whether the target is macOS or Windows. Read only the matching guide:
   `references/macos.md` or `references/windows.md`.
3. Explain that configuration accepts any non-empty Unicode phrase, but the
   selected Vosk model must cover its language and vocabulary. Never promise
   that an arbitrary phrase will recognize reliably before natural speech tests.
4. Scaffold a new project without overwriting existing files:

   ```text
   python scripts/scaffold_project.py --platform <macos|windows> \
     --target <new-project-directory> --wake-phrase "<chosen phrase>"
   ```

   Repeat `--wake-phrase` for recognition variants; optionally pass
   `--exit-phrase` and `--acknowledgement`.
5. Follow the matching platform reference to build, install, configure F20,
   inspect permissions, and start the login-persistent listener.
6. Read `references/architecture.md` before changing the state machine.
7. Run dependency-free state-machine tests and platform static checks. On macOS,
   run the optional local synthetic-ASR diagnostic after building.
8. Perform one natural spoken acceptance from a normal non-Voice screen:
   chosen wake → local acknowledgement → Voice overlay → wait at least three
   seconds → standalone exit → Voice closes → chosen wake starts Voice again.

## State-machine invariants

- In `idle`, accept only a final whole-utterance configured wake phrase.
- In `waiting_exit`, ignore every wake phrase and accept only a final
  whole-utterance EXIT.
- Return to `idle` before the host sends Escape.
- Decode unrestricted speech in `waiting_exit`; an exit-only constrained grammar
  can coerce similar speech into the exit command.
- Do not impose a short conversation timeout.

## Completion evidence

Require running listener/audio evidence, offline state-machine tests, a working
F20 action, and the natural spoken loop. On macOS also verify the installed
bundle identity and Accessibility state. On Windows record microphone privacy,
foreground-window, Startup entry, process, and log evidence.

Report every unverified boundary. A generated project, CI pass, synthetic test,
or sent hotkey alone is not a complete result.
