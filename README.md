# Codex Voice Wake

An experimental, local-first Codex Skill that turns ChatGPT/Codex desktop Voice
into a customizable smart-speaker-like workflow:

```text
<your wake phrase> → local acknowledgement → ChatGPT Voice
                  → <standalone exit phrase> → ready again
```

Choose the phrase during setup; it is configuration, not hard-coded behavior.
The listener uses Vosk locally. Microphone audio stays in memory and is not
uploaded, recorded, or written into transcript logs by default.

> Unofficial community project. Not affiliated with or supported by OpenAI.

## Platform status

| Platform | Implementation | Evidence | Honest status |
| --- | --- | --- | --- |
| macOS | Swift host, Vosk worker, local `say`, F20/Escape, LaunchAgent, local realtime event sync | Built, signed, state-machine tested, and revalidated on one Apple silicon Mac mini | Validated starting point; every machine and custom phrase needs natural speech acceptance |
| Windows | Python/Vosk/sounddevice, local SAPI, pywin32 F20/Escape, user Startup entry | Dependency-free unit tests, Python compilation, PowerShell parser CI | Experimental; no real Windows device or ChatGPT Voice loop has been verified |

The fully quit-app cold-launch path is not accepted end to end on either
platform. Keep ChatGPT running for the proven first setup.

## What is included

- A reusable Skill at [`skill/codex-voice-wake`](skill/codex-voice-wake).
- Separate macOS and Windows project templates.
- A safe scaffolder that requires the chosen wake phrase and refuses to
  overwrite a non-empty target.
- Editable wake, exit, acknowledgement, input-device, and privacy settings.
- State-isolated commands: only a final standalone wake phrase works while
  idle, and only a final standalone exit phrase works during Voice.
- On macOS, sync from ChatGPT's local realtime start/stop event types so closing
  Voice through the UI or another non-spoken path returns the listener to idle.
- Windows CI plus platform-independent state-machine regressions.

## Install the Skill

```sh
git clone https://github.com/zouliang187/codex-voice-wake.git
skill_root="${CODEX_HOME:-$HOME/.codex}/skills"
mkdir -p "$skill_root"
cp -R codex-voice-wake/skill/codex-voice-wake "$skill_root/"
```

On Windows PowerShell:

```powershell
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$SkillRoot = Join-Path $CodexHome "skills"
New-Item -ItemType Directory -Force -Path $SkillRoot | Out-Null
Copy-Item .\codex-voice-wake\skill\codex-voice-wake -Destination $SkillRoot -Recurse -Force
```

Restart Codex if it does not appear, then invoke:

```text
Use $codex-voice-wake to build my local Voice wake launcher.
```

The Skill's first action is to ask which wake phrase you want. It then selects
the macOS or Windows path, scaffolds a project, and guides installation and
evidence-based acceptance.

## Manual scaffold

The phrase can be any non-empty Unicode string. Repeat `--wake-phrase` for
spacing or ASR spelling variants:

```sh
python3 skill/codex-voice-wake/scripts/scaffold_project.py \
  --platform macos \
  --target ./local-macos-project \
  --wake-phrase "<your phrase>" \
  --wake-phrase "<recognition variant>"
```

```powershell
py -3 skill\codex-voice-wake\scripts\scaffold_project.py `
  --platform windows `
  --target .\local-windows-project `
  --wake-phrase "<your phrase>"
```

Configuration accepts arbitrary phrase text; Vosk can only recognize words
covered by the selected language model. The bundled installers use a pinned
small Mandarin model. Other languages require a matching local Vosk model.

## Platform guides

- [macOS installation, signing, permissions, and validation](skill/codex-voice-wake/references/macos.md)
- [Windows experimental installation and validation](skill/codex-voice-wake/references/windows.md)
- [Shared state-machine architecture](skill/codex-voice-wake/references/architecture.md)

ChatGPT Voice must be available for the account/workspace. Set **Settings >
Voice > Voice chat hotkey** to F20 and restart ChatGPT. Official Voice guidance:
[ChatGPT Voice](https://learn.chatgpt.com/docs/features/voice).

## Required acceptance

Synthetic audio, unit tests, CI, or an injected F20 key are diagnostics—not a
complete result. On the target computer, from a normal non-Voice screen:

1. Naturally say the chosen wake phrase and hear the local acknowledgement.
2. Confirm the separate Voice UI appears.
3. Say sentences containing the wake and exit phrases; confirm neither causes
   a state change.
4. Wait at least three seconds and say the standalone exit phrase.
5. Confirm Voice closes.
6. Say the wake phrase again and confirm a second Voice session starts.
7. End that Voice session with its UI or Escape instead of the spoken exit;
   confirm the listener reports a `voice_stopped` sync reset and wakes again.

The reference macOS setup passed this full loop after the standalone-command
fix. Its acceptance also covered a natural sentence containing both configured
commands: the listener emitted neither a wake nor an exit event. A standalone
exit then returned the listener to `idle`, and a later standalone wake opened a
new Voice session. This is reference evidence, not a substitute for repeating
the same acceptance on each target machine and custom phrase.

## Privacy and risks

- Audio remains local and in memory; `logTranscripts` defaults to `false`.
- macOS state sync reads only structured realtime start/stop event types from
  ChatGPT's local diagnostic logs. It does not read or copy conversation text.
  This is an internal integration surface and may need maintenance after app
  updates; activation failure safely returns the listener to idle.
- Models, virtual environments, builds, generated audio, user configs, logs,
  LaunchAgent/Startup artifacts, TCC databases, and account data are excluded.
- Custom phrase text is stored only in the generated local `config.json`.
- macOS uses a fixed ad-hoc designated requirement to reduce repeated permission
  identity changes. Verify the installed identity before authorization.
- Windows foreground focus and key injection can vary by ChatGPT distribution,
  session state, elevation, and OS policy; no real-device claim is made yet.
- Wake/exit filtering does not stop television or other people from entering
  ChatGPT's microphone after Voice begins.

## License

MIT. See [LICENSE](LICENSE).
