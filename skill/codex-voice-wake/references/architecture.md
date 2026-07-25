# Architecture and state machine

## Components

- `CodexVoiceWake.app`: a menu-less Swift `LSUIElement` host.
- `AVAudioEngine`: captures the current default input and converts it to 16 kHz
  mono signed 16-bit PCM in memory.
- `wake_listener.py`: Vosk recognizer using constrained Mandarin grammars.
- `launchd`: keeps the host alive at login.
- macOS `say`: speaks the local acknowledgement. No cloud TTS is required.
- macOS accessibility events: send F20 to start Voice and Escape to leave Voice.

Audio is piped to the worker and is not written to disk. Transcript logging is
off by default.

## State transitions

```text
idle --wake--> waiting_exit --standalone exit--> idle
                         \
                          --wake--> waiting_exit (recovered wake)
```

`waiting_exit` uses a union grammar containing exit phrases and wake phrases.
Exit is checked first and only accepts a final result whose entire normalized
text is one configured exit phrase. A recovery wake is accepted only after the
same short arming delay used to suppress the original wake tail.

The recovery branch deliberately remains in `waiting_exit`: it represents a new
Voice session that will also need an exit. There is no conversation timeout.

## Product integration

ChatGPT Voice requires a chat or task that begins in Voice mode. Configure its
Voice chat hotkey in **Settings > Voice**. The template uses F20 because it is
unlikely to collide with ordinary shortcuts. The current app key code is `90`
(`kVK_F20`).

Voice uses a separate Electron renderer window commonly logged as
`avatarOverlay`. A normal task window remaining visible does not prove that the
hotkey failed; inspect all ChatGPT windows or the product’s realtime logs.

## Known boundary

The host contains a branch that launches ChatGPT when it is not running, then
sends F20 after a fixed activation delay. Real cold launch has not been accepted
end to end. App process launch does not prove that the renderer, keybindings,
and Voice service were ready before F20. Keep this boundary in user-facing
reports until a natural spoken cold-start test passes.

