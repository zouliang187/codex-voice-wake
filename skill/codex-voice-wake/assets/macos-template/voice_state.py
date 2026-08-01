"""Track ChatGPT Voice lifecycle from local diagnostic event logs.

Only realtime start/stop event types are inspected. Conversation text is never
read, retained, emitted, or logged by this module.
"""

import subprocess
from pathlib import Path


START_TOKEN = "[AppServerConnection] realtime_session_started"
STOP_TOKEN = "[AppServerConnection] response_routed"
STOP_METHOD = "method=thread/realtime/stop"


class CodexRealtimeLogMonitor:
    def __init__(self, log_root=None, process_name="ChatGPT", max_tail_bytes=2 * 1024 * 1024):
        self.log_root = Path(log_root or Path.home() / "Library/Logs/com.openai.codex")
        self.process_name = process_name
        self.max_tail_bytes = int(max_tail_bytes)

    def _recent_logs(self):
        if not self.log_root.is_dir():
            return []
        files = []
        for path in self.log_root.rglob("*.log"):
            try:
                files.append((path.stat().st_mtime_ns, path))
            except OSError:
                continue
        files.sort(reverse=True)
        return [path for _, path in files[:8]]

    def _tail_lines(self, path):
        try:
            with path.open("rb") as handle:
                handle.seek(0, 2)
                size = handle.tell()
                handle.seek(max(0, size - self.max_tail_bytes))
                data = handle.read()
        except OSError:
            return []
        return data.decode("utf-8", errors="ignore").splitlines()

    def latest_event(self):
        latest = None
        for path in self._recent_logs():
            for line_number, line in enumerate(self._tail_lines(path)):
                kind = None
                if START_TOKEN in line:
                    kind = "start"
                elif STOP_TOKEN in line and STOP_METHOD in line and "errorCode=null" in line:
                    kind = "stop"
                if kind is None:
                    continue
                timestamp = line.split(" ", 1)[0]
                marker = (timestamp, path.name, line_number)
                if latest is None or marker > latest["marker"]:
                    latest = {"kind": kind, "marker": marker}
        return latest

    def app_running(self):
        try:
            result = subprocess.run(
                ["/usr/bin/pgrep", "-x", self.process_name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        except OSError:
            return False
        return result.returncode == 0


class VoiceStateSynchronizer:
    def __init__(self, monitor, activation_timeout=15.0, poll_interval=1.0):
        self.monitor = monitor
        self.activation_timeout = float(activation_timeout)
        self.poll_interval = float(poll_interval)
        self.baseline = None
        self.active_marker = None
        self.deadline = float("inf")
        self.next_poll_at = float("inf")
        self.active_reported = False

    @staticmethod
    def _is_newer(event, baseline):
        if event is None:
            return False
        if baseline is None:
            return True
        return event["marker"] > baseline["marker"]

    def begin(self, audio_clock):
        self.baseline = self.monitor.latest_event()
        self.active_marker = None
        self.deadline = float(audio_clock) + self.activation_timeout
        self.next_poll_at = float(audio_clock)
        self.active_reported = False

    def end(self):
        self.baseline = None
        self.active_marker = None
        self.deadline = float("inf")
        self.next_poll_at = float("inf")
        self.active_reported = False

    def poll(self, audio_clock):
        audio_clock = float(audio_clock)
        if audio_clock < self.next_poll_at:
            return None
        self.next_poll_at = audio_clock + self.poll_interval
        event = self.monitor.latest_event()
        if self._is_newer(event, self.baseline):
            if event["kind"] == "stop":
                self.end()
                return {"action": "reset", "reason": "voice_stopped"}
            if event["kind"] == "start":
                self.active_marker = event["marker"]
                if not self.active_reported:
                    self.active_reported = True
                    return {"action": "active"}
        if self.active_marker is not None:
            if not self.monitor.app_running():
                self.end()
                return {"action": "reset", "reason": "codex_terminated"}
            return None
        if audio_clock >= self.deadline:
            self.end()
            return {"action": "reset", "reason": "voice_start_timeout"}
        return None
