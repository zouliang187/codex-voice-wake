---
name: codex-voice-wake
description: Install, configure, diagnose, or validate an experimental local wake-word launcher that turns the macOS ChatGPT/Codex desktop Voice feature into a smart-speaker-like workflow. Use for requests involving a Chinese wake phrase such as “小亮小亮”, a login-persistent offline Vosk listener, a local “在呢” acknowledgement, the F20 Voice hotkey, an “退出” command, missed-exit state recovery, macOS microphone or Accessibility permissions, stable code-signing identity, or real spoken end-to-end acceptance.
---

# Codex Voice Wake

Build the launcher from the bundled project template. Keep audio local, preserve
macOS permission identity, and distinguish automated diagnostics from real human
acceptance.

## Guardrails

- Work only on macOS. Treat Apple silicon as tested and other architectures as
  unverified until built and tested there.
- Do not change DNS, proxies, TUN, sleep, display, lock-screen, or unrelated
  security settings.
- Do not record, retain, transcribe in logs, or upload microphone audio by
  default.
- Never reset TCC or ask the user to re-authorize before verifying the exact
  installed bundle path, bundle ID, designated requirement, running process,
  and current TCC state.
- Never use synthetic playback as proof of natural spoken wake-word success.
- Do not claim cold launch works until ChatGPT is fully quit and a real wake
  launches the app and starts Voice. That path is not yet proven by this Skill.

## Workflow

1. Run `scripts/check-environment.sh`.
2. Read `references/architecture.md` before changing the state machine.
3. Read `references/permissions-and-validation.md` before building, signing,
   installing, or asking for permissions.
4. Run `scripts/scaffold-project.sh <new-project-directory>`. Refuse to overwrite
   a non-empty target.
5. In the generated project, run `scripts/build.sh`, then
   `scripts/install-login.sh`.
6. Run `scripts/configure-f20.py`. It must preserve unrelated keybindings and
   create a timestamped backup before changing `~/.codex/keybindings.json`.
7. Ask the user to grant Microphone and Accessibility only if runtime logs and
   read-only checks show they are missing. Add the exact installed app at
   `~/Applications/CodexVoiceWake.app`; do not authorize a build copy.
8. Restart ChatGPT once after changing the Voice hotkey, then verify F20 from a
   normal, empty task. Voice appears in a separate `avatarOverlay` window and
   may not be visible in the ordinary task window.
9. Run the generated project’s `scripts/test-synthetic.sh` as an offline ASR and
   state-machine regression. Treat it as diagnostic evidence only.
10. Perform one natural spoken acceptance from a normal non-Voice screen:
    “小亮小亮” → hear “在呢” → Voice overlay appears → wait at least three
    seconds → say standalone “退出” → overlay closes → say “小亮小亮” again.

## State-machine invariants

- In `idle`, match only a complete configured wake phrase.
- In `waiting_exit`, match standalone final `退出` before considering wake
  recovery.
- Change state to `idle` before emitting EXIT; the host sends Escape only after
  receiving that event.
- Keep wake grammar active in `waiting_exit`. If Voice ended externally or EXIT
  was missed, the next deliberate wake emits `recovered=true` and runs the wake
  action again.
- Do not add a short conversation timeout. Long Voice conversations are valid.

## Completion evidence

Require all of the following:

- LaunchAgent, host, and worker are running; logs show `state_machine=idle`,
  `AUDIO listening=true`, and the expected sample rate.
- The installed app satisfies the fixed designated requirement and runtime
  reports `accessibility=true`.
- Offline regressions pass for `wake,exit,wake`, embedded-exit rejection, and
  missed-exit recovery `wake,wake` with `recovered=true`.
- A real spoken test produces two WAKE events, one EXIT, two successful Codex
  realtime starts, and a realtime stop between them.

Report any unverified boundary explicitly. Do not call a generated app, a
synthetic test, or a sent hotkey alone a complete result.

