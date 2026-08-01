import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from voice_state import CodexRealtimeLogMonitor, VoiceStateSynchronizer


class FakeMonitor:
    def __init__(self, event=None, running=True):
        self.event = event
        self.running = running

    def latest_event(self):
        return self.event

    def app_running(self):
        return self.running


def event(kind, timestamp):
    return {"kind": kind, "marker": (timestamp, "app.log", 1)}


class VoiceStateSynchronizerTests(unittest.TestCase):
    def test_start_then_external_stop_resets(self):
        monitor = FakeMonitor(event("stop", "2026-08-01T10:00:00Z"))
        sync = VoiceStateSynchronizer(monitor, 10, 1)
        sync.begin(0)
        monitor.event = event("start", "2026-08-01T10:00:01Z")
        self.assertEqual(sync.poll(1), {"action": "active"})
        monitor.event = event("stop", "2026-08-01T10:00:02Z")
        self.assertEqual(sync.poll(2), {"action": "reset", "reason": "voice_stopped"})

    def test_start_and_stop_between_polls_still_resets(self):
        monitor = FakeMonitor(event("stop", "2026-08-01T10:00:00Z"))
        sync = VoiceStateSynchronizer(monitor, 10, 1)
        sync.begin(0)
        monitor.event = event("stop", "2026-08-01T10:00:03Z")
        self.assertEqual(sync.poll(3), {"action": "reset", "reason": "voice_stopped"})

    def test_active_session_has_no_conversation_timeout(self):
        monitor = FakeMonitor(event("stop", "2026-08-01T10:00:00Z"))
        sync = VoiceStateSynchronizer(monitor, 10, 1)
        sync.begin(0)
        monitor.event = event("start", "2026-08-01T10:00:01Z")
        self.assertEqual(sync.poll(1), {"action": "active"})
        self.assertIsNone(sync.poll(60 * 60 * 8))

    def test_failed_voice_start_resets(self):
        monitor = FakeMonitor(event("stop", "2026-08-01T10:00:00Z"))
        sync = VoiceStateSynchronizer(monitor, 10, 1)
        sync.begin(0)
        self.assertEqual(sync.poll(10), {"action": "reset", "reason": "voice_start_timeout"})

    def test_codex_termination_resets_active_session(self):
        monitor = FakeMonitor(event("stop", "2026-08-01T10:00:00Z"))
        sync = VoiceStateSynchronizer(monitor, 10, 1)
        sync.begin(0)
        monitor.event = event("start", "2026-08-01T10:00:01Z")
        sync.poll(1)
        monitor.running = False
        self.assertEqual(sync.poll(2), {"action": "reset", "reason": "codex_terminated"})


class CodexRealtimeLogMonitorTests(unittest.TestCase):
    def test_reads_only_strict_start_and_stop_event_lines(self):
        with tempfile.TemporaryDirectory() as temporary:
            date_dir = Path(temporary) / "2026" / "08" / "01"
            date_dir.mkdir(parents=True)
            log = date_dir / "app.log"
            log.write_text(
                "2026-08-01T10:00:00Z info quoted method=thread/realtime/stop\n"
                "2026-08-01T10:00:01Z info [AppServerConnection] realtime_session_started hostId=local\n"
                "2026-08-01T10:00:02Z info [AppServerConnection] response_routed errorCode=null method=thread/realtime/stop\n",
                encoding="utf-8",
            )
            self.assertEqual(CodexRealtimeLogMonitor(Path(temporary)).latest_event()["kind"], "stop")


if __name__ == "__main__":
    unittest.main()
