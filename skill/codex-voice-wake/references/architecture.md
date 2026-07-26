# Architecture and state machine

## Shared behavior

Both platform templates use a constrained Vosk grammar while idle, unrestricted
recognition during Voice, and the same dependency-free state machine.
`wakePhrases` and `exitPhrases` are arrays of user-selected Unicode strings.
Matching applies NFKC normalization, case folding, and removes
punctuation/spacing, then requires final whole-utterance equality.

```text
idle --custom wake--> waiting_exit --standalone exit--> idle
                              \--ordinary speech, including wake--> waiting_exit
```

Both commands are final-only whole-utterance matches. The wake phrase is ignored
in `waiting_exit`. State changes to `idle` before Escape is emitted; there is no
conversation timeout.

Audio is processed as 16 kHz mono PCM in memory. Transcript logging is off by
default. Phrase text is stored in the user's local `config.json`; audio is not.

## macOS host

An `LSUIElement` Swift app captures and converts audio with `AVAudioEngine`,
pipes it to the Python/Vosk worker, speaks with `say`, and posts F20/Escape using
Accessibility events. A LaunchAgent keeps it alive after login.

## Windows host

One Python process captures audio with `sounddevice`, runs Vosk and the state
machine, speaks through local SAPI, focuses a ChatGPT window with pywin32, and
sends F20/Escape. A command in the user's Startup folder launches it at login.

The Windows implementation has unit/static/CI coverage but no real-device Voice
acceptance yet. Foreground-window restrictions, app process naming, microphone
privacy, audio drivers, and the ChatGPT distribution can change runtime results.

## Product boundary

Configure **Settings > Voice > Voice chat hotkey** to F20 and restart ChatGPT.
Voice may use a separate overlay from the ordinary task window. Voice feature
availability depends on the user's plan, rollout, and workspace.

Both templates include an optional cold-launch branch, but neither platform may
be reported as cold-launch verified without a fully quit-app natural speech test.
