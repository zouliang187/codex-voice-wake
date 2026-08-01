# AGENTS.md

## Project objective

Maintain an experimental, local-first Codex Skill that creates configurable
wake-phrase launchers for ChatGPT desktop Voice on macOS and Windows.

## Sources of truth

- `README.md` owns public support and acceptance claims.
- `skill/codex-voice-wake/SKILL.md` owns the Codex workflow.
- `skill/codex-voice-wake/assets/*-template/` owns generated runtime behavior.
- Platform references own installation, permission, and validation details.

## Change rules

- Ask for a custom wake phrase before scaffolding; never hard-code one user's phrase.
- Preserve final standalone wake, final standalone exit, and second-wake behavior.
- Ignore both command phrases when embedded in longer speech, and ignore wake
  phrases while Voice is active.
- On macOS, preserve local realtime start/stop synchronization so UI, Escape,
  app termination, or failed Voice activation cannot strand `waiting_exit`.
- Never inspect or publish conversation content from ChatGPT diagnostic logs;
  parse only strict realtime lifecycle event lines.
- Keep audio local and in memory; transcript logging must default to off.
- Preserve the macOS bundle identifier and fixed designated requirement unless a
  migration and permission impact are explicitly documented.
- Keep Windows and cold-launch paths labeled unverified until their full natural
  spoken loops pass on real target machines.
- Never substitute unit, synthetic-audio, CI, or injected-key checks for the
  natural spoken acceptance loop described in `README.md`.

## Verification

Run before publishing:

```sh
python3 -m unittest discover -s skill/codex-voice-wake/assets/macos-template/tests -v
python3 -m unittest discover -s skill/codex-voice-wake/assets/windows-template/tests -v
python3 -m unittest discover -s skill/codex-voice-wake/scripts/tests -v
zsh -n skill/codex-voice-wake/scripts/*.sh skill/codex-voice-wake/assets/macos-template/scripts/*.sh
```

On macOS, also typecheck the Swift host as CI does. CI must pass on macOS,
Windows, and Ubuntu before describing the repository as release-ready.

## Repository hygiene

Do not commit generated projects, configs, models, virtual environments, builds,
audio, logs, credentials, TCC data, or machine-specific paths. Do not rewrite
public Git history merely to make it look cleaner.
