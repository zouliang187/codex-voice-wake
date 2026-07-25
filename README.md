# Codex Voice Wake

An experimental macOS Skill and local launcher that turns ChatGPT/Codex Voice
into a smart-speaker-like workflow:

```text
“小亮小亮” → local “在呢” → ChatGPT Voice → “退出” → ready again
```

The wake detector runs locally with Vosk. Microphone audio stays in memory and
is not uploaded, saved, or written into transcripts by default.

> Unofficial community project. Not affiliated with or supported by OpenAI.

## What is included

- A reusable Codex Skill in [`skill/codex-voice-wake`](skill/codex-voice-wake).
- A complete Swift + Python project template bundled with the Skill.
- Login-persistent LaunchAgent installation.
- Local macOS TTS acknowledgement (“在呢”).
- F20 integration with **Settings > Voice > Voice chat hotkey**.
- Standalone “退出” handling and missed-exit recovery: if Voice closes outside
  the listener, the next wake phrase is accepted instead of being ignored
  forever.
- Offline state-machine regressions and a strict real-speech acceptance plan.

## Requirements

- macOS 13 or newer. Initial end-to-end validation was on Apple silicon Mac
  mini; other Macs are not yet verified.
- The current ChatGPT desktop app with Voice available for the account and
  workspace.
- Apple Command Line Tools, `/usr/bin/python3`, `curl`, and `unzip`.
- `ffmpeg` only for synthetic diagnostic tests.
- Microphone permission for ChatGPT and the installed wake host; Accessibility
  permission for the wake host.

Official ChatGPT Voice guidance says a task must begin in Voice mode and the
shortcut is configured under **Settings > Voice > Voice chat hotkey**. Voice
availability also depends on plan, rollout, and workspace settings. See
[ChatGPT Voice](https://learn.chatgpt.com/docs/features/voice).

## Install the Skill

```sh
git clone https://github.com/zouliang187/codex-voice-wake.git
mkdir -p "$HOME/.agents/skills"
cp -R codex-voice-wake/skill/codex-voice-wake "$HOME/.agents/skills/"
```

Restart Codex if the Skill does not appear, then invoke:

```text
Use $codex-voice-wake to install and verify the local Voice wake launcher.
```

Codex will run the environment check, scaffold a fresh local project, build and
install the app, configure F20 without deleting unrelated keybindings, guide the
two macOS permissions, and run validation.

## Manual project setup

```sh
skill/codex-voice-wake/scripts/check-environment.sh
skill/codex-voice-wake/scripts/scaffold-project.sh ./local-project
cd ./local-project
./scripts/build.sh
./scripts/install-login.sh
../skill/codex-voice-wake/scripts/configure-f20.py
```

Fully quit and reopen ChatGPT after changing the hotkey. Add the exact installed
`~/Applications/CodexVoiceWake.app` to Microphone and Accessibility. Do not add
the copy inside `build/`; macOS permissions are identity- and path-sensitive.

## Validation

Automated diagnostics:

```sh
./scripts/status.sh
./scripts/test-synthetic.sh
```

Final acceptance must use the person’s natural voice from a normal non-Voice
screen:

1. Say “小亮小亮” and hear “在呢”.
2. Confirm the separate Voice overlay appears.
3. Wait at least three seconds and say standalone “退出”.
4. Confirm Voice closes.
5. Say “小亮小亮” again and confirm a second Voice session starts.

Speaker playback and synthetic WAV tests are useful diagnostics, but they do not
prove real spoken wake-word reliability.

## Privacy and security

- Audio remains local and in memory.
- `logTranscripts` defaults to `false`.
- The repository excludes models, virtual environments, builds, generated
  audio, user configs, LaunchAgent plists, application logs, TCC databases, and
  account data.
- The app uses ad-hoc signing with a fixed designated requirement so updates can
  retain the same macOS permission identity. Verify the requirement before
  granting permissions.
- Review the source and scripts before installing a login-persistent process.

## Honest boundaries

- This is an experiment, not a hardened consumer voice assistant.
- A fully quit ChatGPT cold launch branch exists, but natural spoken cold launch
  through Voice has **not** been accepted end to end. Keep ChatGPT running for
  the proven path.
- Voice appears in a separate Electron `avatarOverlay`; the ordinary task window
  can remain visible even when Voice started.
- Local wake/exit filtering does not prevent television or other people from
  entering ChatGPT’s microphone after Voice starts.
- TCC behavior can change across macOS releases. Never reset permissions as a
  first diagnostic step.

## License

MIT. See [LICENSE](LICENSE).
