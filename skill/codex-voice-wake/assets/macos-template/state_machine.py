"""Dependency-free wake/exit state machine shared by runtime and tests."""

import unicodedata


def normalize(text):
    return "".join(
        ch.casefold()
        for ch in unicodedata.normalize("NFKC", str(text))
        if ch.isalnum()
    )


def _phrases(values, label):
    result = []
    for value in values:
        candidate = normalize(value)
        if candidate and candidate not in result:
            result.append(candidate)
    if not result:
        raise ValueError("%s must contain at least one non-empty phrase" % label)
    return result


class WakeStateMachine:
    def __init__(self, wake_phrases, exit_phrases, exit_arm_delay=3.0, post_exit_suppress=3.0):
        self.wake_phrases = _phrases(wake_phrases, "wakePhrases")
        self.exit_phrases = _phrases(exit_phrases, "exitPhrases")
        self.exit_arm_delay = float(exit_arm_delay)
        self.post_exit_suppress = float(post_exit_suppress)
        self.state = "idle"
        self.exit_armed_at = float("inf")
        self.wake_armed_at = 0.0
        self.events = []

    def reset_to_idle(self):
        self.state = "idle"
        self.exit_armed_at = float("inf")
        self.wake_armed_at = 0.0

    def accept(self, text, kind, audio_clock):
        candidate = normalize(text)
        if not candidate:
            return None

        if self.state == "idle":
            if (
                kind != "final"
                or audio_clock < self.wake_armed_at
                or candidate not in self.wake_phrases
            ):
                return None
            self.state = "waiting_exit"
            self.exit_armed_at = audio_clock + self.exit_arm_delay
            self.events.append("wake")
            return {
                "event": "wake",
                "matched": candidate,
                "state": self.state,
                "recovered": False,
            }

        if audio_clock < self.exit_armed_at:
            return None

        # EXIT is final-only. Return to idle before the caller sends Escape so
        # a UI action cannot strand the state.
        if kind == "final" and candidate in self.exit_phrases:
            self.state = "idle"
            self.wake_armed_at = audio_clock + self.post_exit_suppress
            self.events.append("exit")
            return {"event": "exit", "matched": candidate, "state": self.state}

        # Wake phrases inside an active conversation are ordinary text.
        return None
