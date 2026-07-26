# Windows experimental installation and validation

No real Windows device has completed the spoken Voice loop for this repository.
Treat every instruction below as an implementation candidate until accepted on
the target PC.

## Create and install

Use Python 3.11 or newer from a PowerShell prompt:

```powershell
py -3 scripts\scaffold_project.py --platform windows `
  --target .\codex-voice-wake-windows --wake-phrase "<chosen phrase>"
Set-Location .\codex-voice-wake-windows
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

The installer uses `%LOCALAPPDATA%\CodexVoiceWake`, creates a virtual environment,
installs pinned Python packages, verifies the pinned Mandarin Vosk model SHA-256,
and writes a user-level Startup command. It does not require an administrator.

Configuration accepts any non-empty Unicode phrase. The bundled model is
Mandarin; a phrase in another language requires a matching Vosk model and an
updated `modelDirectory`. A configured phrase is not proof of recognition.

## ChatGPT and permissions

1. In ChatGPT **Settings > Voice**, set the Voice chat hotkey to F20 and fully
   quit/reopen the app.
2. In **Settings > Privacy & security > Microphone**, allow microphone access
   and desktop apps. ChatGPT needs its own microphone access.
3. Keep ChatGPT running for the first acceptance. The default
   `chatgptLaunchCommand` is empty because Microsoft Store/classic installs do
   not have one verified universal launch command.
4. If window focus fails, inspect the real process name and window title before
   editing `chatgptProcessNames` or `chatgptWindowTitleContains`.

Windows has no macOS TCC/Accessibility entry. Keyboard injection and foreground
activation can still be restricted by session state, elevation mismatch, or
Windows focus rules. Never run the listener elevated merely to bypass evidence.

## Local diagnostics

```powershell
.\scripts\test.ps1
.\scripts\status.ps1
```

Expected runtime log evidence includes `START state_machine=idle`,
`AUDIO listening=true`, `WAKE`, `voice_hotkey_sent=true`, `EXIT`, and
`voice_exit_escape_sent=true`. Transcript text must remain absent unless the
user deliberately sets `logTranscripts=true` for a short diagnostic.

## Acceptance and stop

From a normal non-Voice screen, naturally speak the configured wake phrase,
hear the local acknowledgement, observe Voice, speak the standalone exit phrase,
observe Voice close, then wake again. CI, PowerShell parsing, unit tests, and an
F20 key event do not substitute for this loop.

```powershell
.\scripts\stop.ps1
.\scripts\uninstall.ps1
```

The uninstall script removes only the exact user Startup entry and
`%LOCALAPPDATA%\CodexVoiceWake` installation.
