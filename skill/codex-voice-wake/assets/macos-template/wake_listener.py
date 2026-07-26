#!/usr/bin/env python3
"""Offline constrained-grammar wake and exit detector using Vosk.

Input is raw 16 kHz mono signed 16-bit little-endian PCM on stdin, or a
compatible WAV passed with --wav. Audio is never written by this process.
"""

import argparse
import json
import sys
import warnings
import wave
from pathlib import Path

warnings.filterwarnings("ignore", message="urllib3 v2 only supports OpenSSL")

from vosk import KaldiRecognizer, Model, SetLogLevel
from state_machine import WakeStateMachine, normalize


def load_config(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def emit(payload):
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


class Detector:
    def __init__(self, model_path, config):
        SetLogLevel(-1)
        self.model = Model(str(model_path))
        self.wake_grammar = list(dict.fromkeys(config["wakePhrases"]))
        self.exit_grammar = list(dict.fromkeys(config.get("exitPhrases", ["退出"])))
        self.recognizer = None
        self.exit_arm_delay = float(config.get("exitArmDelaySeconds", 3.0))
        self.post_exit_suppress = float(config.get("postExitSuppressSeconds", 3.0))
        self.log_transcripts = bool(config.get("logTranscripts", False))
        self.last_candidate = ""
        self.audio_clock = 0.0
        self.machine = WakeStateMachine(
            self.wake_grammar,
            self.exit_grammar,
            self.exit_arm_delay,
            self.post_exit_suppress,
        )
        self.events = self.machine.events
        self.set_recognition_mode("wake")

    def set_recognition_mode(self, mode):
        if mode == "wake":
            phrases = self.wake_grammar
        elif mode == "waiting":
            phrases = [*self.exit_grammar, *self.wake_grammar]
        else:
            raise ValueError(f"unknown recognition mode: {mode}")
        grammar = list(dict.fromkeys([*phrases, "[unk]"]))
        self.recognizer = KaldiRecognizer(
            self.model,
            16000,
            json.dumps(grammar, ensure_ascii=False),
        )
        self.recognizer.SetWords(False)
        self.last_candidate = ""

    def inspect(self, result, kind):
        try:
            payload = json.loads(result)
        except json.JSONDecodeError:
            return False
        text = payload.get("partial", "") or payload.get("text", "")
        candidate = normalize(text)
        if self.log_transcripts and candidate and candidate != self.last_candidate:
            emit({"event": "transcript", "kind": kind, "text": text})
        self.last_candidate = candidate
        if not candidate:
            return False

        event = self.machine.accept(text, kind, self.audio_clock)
        if not event:
            return False
        emit(event)
        self.set_recognition_mode("wake" if event["event"] == "exit" else "waiting")
        return True

    def feed(self, chunk):
        self.audio_clock += len(chunk) / 2.0 / 16000.0
        if self.recognizer.AcceptWaveform(chunk):
            return self.inspect(self.recognizer.Result(), "final")
        return self.inspect(self.recognizer.PartialResult(), "partial")

    def finish(self):
        return self.inspect(self.recognizer.FinalResult(), "final")


def wav_chunks(path):
    with wave.open(str(path), "rb") as source:
        if (source.getframerate(), source.getnchannels(), source.getsampwidth()) != (16000, 1, 2):
            raise ValueError("WAV must be 16 kHz, mono, signed 16-bit PCM")
        while True:
            chunk = source.readframes(4000)
            if not chunk:
                break
            yield chunk


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--wav")
    parser.add_argument("--expect-wake", action="store_true")
    parser.add_argument("--expect-sequence")
    args = parser.parse_args()

    detector = Detector(Path(args.model), load_config(args.config))
    found = False
    source = wav_chunks(Path(args.wav)) if args.wav else iter(lambda: sys.stdin.buffer.read(8000), b"")
    for chunk in source:
        found = detector.feed(chunk) or found
    found = detector.finish() or found
    if args.expect_wake and not found:
        emit({"event": "test_failed", "reason": "wake phrase was not detected"})
        return 2
    if args.expect_sequence:
        expected = [item.strip() for item in args.expect_sequence.split(",") if item.strip()]
        if detector.events != expected:
            emit(
                {
                    "event": "test_failed",
                    "reason": "event sequence mismatch",
                    "expected": expected,
                    "actual": detector.events,
                }
            )
            return 3
    if args.wav:
        emit({"event": "test_complete", "wakeDetected": "wake" in detector.events, "events": detector.events})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
