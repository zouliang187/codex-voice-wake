#!/usr/bin/env python3
"""Experimental Windows local Vosk listener for ChatGPT Voice."""

import argparse
import json
import logging
import os
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

import psutil
import pythoncom
import sounddevice as sd
import win32api
import win32com.client
import win32con
import win32gui
import win32process
from vosk import KaldiRecognizer, Model, SetLogLevel

from state_machine import WakeStateMachine, normalize


VK_F20 = 0x83


def load_config(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


class WakeService:
    def __init__(self, config_path):
        self.config_path = config_path.resolve()
        self.project_dir = self.config_path.parent
        self.config = load_config(self.config_path)
        self.audio_queue = queue.Queue()
        self.audio_clock = 0.0
        self.speaking = threading.Lock()
        self.log_transcripts = bool(self.config.get("logTranscripts", False))
        self.wake_grammar = list(dict.fromkeys(self.config["wakePhrases"]))
        self.exit_grammar = list(dict.fromkeys(self.config.get("exitPhrases", ["退出"])))
        self.machine = WakeStateMachine(
            self.wake_grammar,
            self.exit_grammar,
            self.config.get("exitArmDelaySeconds", 3.0),
            self.config.get("postExitSuppressSeconds", 3.0),
        )
        model_path = self.project_dir / Path(self.config["modelDirectory"])
        SetLogLevel(-1)
        self.model = Model(str(model_path))
        self.recognizer = None
        self.set_recognition_mode("wake")

    def set_recognition_mode(self, mode):
        phrases = self.wake_grammar if mode == "wake" else [*self.exit_grammar, *self.wake_grammar]
        grammar = list(dict.fromkeys([*phrases, "[unk]"]))
        self.recognizer = KaldiRecognizer(
            self.model,
            16000,
            json.dumps(grammar, ensure_ascii=False),
        )
        self.recognizer.SetWords(False)

    def inspect(self, raw, kind):
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            return
        text = payload.get("partial", "") or payload.get("text", "")
        if self.log_transcripts and normalize(text):
            logging.info("TRANSCRIPT kind=%s text=%r", kind, text)
        event = self.machine.accept(text, kind, self.audio_clock)
        if not event:
            return
        if event["event"] == "wake":
            logging.info("WAKE state=waiting_exit recovered=%s", event["recovered"])
            self.set_recognition_mode("waiting")
            self.speak_acknowledgement()
            self.open_voice()
        else:
            logging.info("EXIT state=idle")
            self.set_recognition_mode("wake")
            self.close_voice()

    def audio_callback(self, indata, frames, time_info, status):
        if status:
            logging.warning("AUDIO status=%s", status)
        self.audio_queue.put(bytes(indata))

    def run(self):
        device = self.config.get("audioDevice")
        logging.info("START state_machine=idle transcripts=%s audio_saved=false", self.log_transcripts)
        with sd.RawInputStream(
            samplerate=16000,
            blocksize=4000,
            device=device,
            dtype="int16",
            channels=1,
            callback=self.audio_callback,
        ):
            logging.info("AUDIO listening=true device=%r sample_rate=16000", device)
            while True:
                chunk = self.audio_queue.get()
                self.audio_clock += len(chunk) / 2.0 / 16000.0
                if self.recognizer.AcceptWaveform(chunk):
                    self.inspect(self.recognizer.Result(), "final")
                else:
                    self.inspect(self.recognizer.PartialResult(), "partial")

    def speak_acknowledgement(self):
        if not self.config.get("acknowledgementEnabled", True):
            return
        text = str(self.config.get("acknowledgementText", "在呢")).strip()
        if not text or not self.speaking.acquire(blocking=False):
            return

        def speak():
            pythoncom.CoInitialize()
            try:
                voice = win32com.client.Dispatch("SAPI.SpVoice")
                voice.Rate = int(self.config.get("acknowledgementRate", 1))
                voice.Speak(text)
                logging.info("ACTION acknowledgement_finished=true characters=%d", len(text))
            except Exception:
                logging.exception("ERROR acknowledgement")
            finally:
                pythoncom.CoUninitialize()
                self.speaking.release()

        logging.info("ACTION acknowledgement_started=true characters=%d", len(text))
        threading.Thread(target=speak, daemon=True).start()

    def chatgpt_window(self):
        wanted_titles = str(self.config.get("chatgptWindowTitleContains", "ChatGPT")).casefold()
        wanted_processes = {name.casefold() for name in self.config.get("chatgptProcessNames", ["ChatGPT.exe"])}
        candidates = []

        def visit(hwnd, _):
            if not win32gui.IsWindowVisible(hwnd):
                return
            title = win32gui.GetWindowText(hwnd)
            if wanted_titles and wanted_titles not in title.casefold():
                return
            try:
                _, pid = win32process.GetWindowThreadProcessId(hwnd)
                if psutil.Process(pid).name().casefold() in wanted_processes:
                    candidates.append(hwnd)
            except (psutil.Error, OSError):
                return

        win32gui.EnumWindows(visit, None)
        return candidates[0] if candidates else None

    def activate_chatgpt(self):
        hwnd = self.chatgpt_window()
        if hwnd is None:
            command = self.config.get("chatgptLaunchCommand", [])
            if not command:
                logging.error("ERROR chatgpt_not_running=true cold_launch_unconfigured=true")
                return False
            subprocess.Popen(command, shell=False)
            time.sleep(float(self.config.get("activationDelayMilliseconds", 900)) / 1000.0)
            hwnd = self.chatgpt_window()
        if hwnd is None:
            logging.error("ERROR chatgpt_window_not_found=true")
            return False
        win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
        try:
            win32gui.SetForegroundWindow(hwnd)
        except Exception:
            logging.exception("ERROR chatgpt_focus")
            return False
        return True

    @staticmethod
    def send_key(virtual_key):
        win32api.keybd_event(virtual_key, 0, 0, 0)
        win32api.keybd_event(virtual_key, 0, win32con.KEYEVENTF_KEYUP, 0)

    def open_voice(self):
        if not self.activate_chatgpt():
            return
        time.sleep(float(self.config.get("activationDelayMilliseconds", 900)) / 1000.0)
        if self.config.get("sendVoiceHotkey", True):
            self.send_key(VK_F20)
            logging.info("ACTION voice_hotkey_sent=true key=F20")

    def close_voice(self):
        if self.activate_chatgpt():
            time.sleep(0.2)
            self.send_key(win32con.VK_ESCAPE)
            logging.info("ACTION voice_exit_escape_sent=true")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()
    local = Path(os.environ.get("LOCALAPPDATA", args.config.resolve().parent)) / "CodexVoiceWake"
    log_dir = local / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=str(log_dir / "wake.log"),
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    pid_path = local / "runtime" / "wake.pid"
    pid_path.parent.mkdir(parents=True, exist_ok=True)
    pid_path.write_text(str(os.getpid()), encoding="ascii")
    try:
        WakeService(args.config).run()
    except Exception:
        logging.exception("FATAL service")
        return 1
    finally:
        try:
            pid_path.unlink()
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
