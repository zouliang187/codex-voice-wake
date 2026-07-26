import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from state_machine import WakeStateMachine, normalize


class WakeStateMachineTests(unittest.TestCase):
    def make_machine(self):
        return WakeStateMachine(["电脑，请听", "Hey Codex"], ["结束对话"], 3, 2)

    def test_arbitrary_unicode_phrase_is_normalized(self):
        machine = self.make_machine()
        event = machine.accept("电脑 请听！", "final", 1)
        self.assertEqual(event["event"], "wake")
        self.assertFalse(event["recovered"])

    def test_exit_is_standalone_final_and_returns_idle_first(self):
        machine = self.make_machine()
        machine.accept("Hey Codex", "final", 1)
        self.assertIsNone(machine.accept("请结束对话吧", "final", 5))
        self.assertIsNone(machine.accept("结束对话", "partial", 5))
        event = machine.accept("结束对话", "final", 5)
        self.assertEqual((event["event"], event["state"]), ("exit", "idle"))

    def test_wake_exit_wake(self):
        machine = self.make_machine()
        machine.accept("Hey Codex", "final", 1)
        machine.accept("结束对话", "final", 5)
        self.assertIsNone(machine.accept("Hey Codex", "final", 6))
        event = machine.accept("Hey Codex", "final", 8)
        self.assertFalse(event["recovered"])
        self.assertEqual(machine.events, ["wake", "exit", "wake"])

    def test_missed_exit_next_wake_recovers(self):
        machine = self.make_machine()
        machine.accept("电脑请听", "final", 1)
        event = machine.accept("电脑请听", "final", 5)
        self.assertTrue(event["recovered"])
        self.assertEqual(machine.events, ["wake", "wake"])

    def test_empty_phrases_are_rejected(self):
        with self.assertRaises(ValueError):
            WakeStateMachine(["---"], ["stop"])

    def test_normalize_accepts_unicode_and_case(self):
        self.assertEqual(normalize(" HéY，电脑！ "), "héy电脑")


if __name__ == "__main__":
    unittest.main()
