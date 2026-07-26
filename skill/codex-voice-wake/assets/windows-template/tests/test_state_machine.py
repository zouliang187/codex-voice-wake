import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from state_machine import WakeStateMachine


class WakeStateMachineTests(unittest.TestCase):
    def make_machine(self):
        return WakeStateMachine(["电脑，请听", "Hey Codex"], ["结束对话"], 3, 2)

    def test_custom_unicode_and_latin_phrases(self):
        machine = self.make_machine()
        self.assertEqual(machine.accept("电脑 请听", "final", 1)["event"], "wake")

    def test_exit_is_exact_final_and_atomic(self):
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
        machine.accept("Hey Codex", "final", 8)
        self.assertEqual(machine.events, ["wake", "exit", "wake"])

    def test_missed_exit_recovery(self):
        machine = self.make_machine()
        machine.accept("Hey Codex", "final", 1)
        event = machine.accept("Hey Codex", "final", 5)
        self.assertTrue(event["recovered"])
        self.assertEqual(machine.events, ["wake", "wake"])


if __name__ == "__main__":
    unittest.main()
