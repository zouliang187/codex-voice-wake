import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scaffold_project.py"


class ScaffoldProjectTests(unittest.TestCase):
    def scaffold(self, platform):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        target = Path(temporary.name) / "project"
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--platform",
                platform,
                "--target",
                str(target),
                "--wake-phrase",
                "电脑，请听",
                "--wake-phrase",
                "Hey Codex",
                "--exit-phrase",
                "结束对话",
                "--acknowledgement",
                "我在",
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        return target, result

    def test_macos_template_and_unicode_config(self):
        target, result = self.scaffold("macos")
        config = json.loads((target / "config.json").read_text(encoding="utf-8"))
        self.assertEqual(config["wakePhrases"], ["电脑，请听", "Hey Codex"])
        self.assertEqual(config["exitPhrases"], ["结束对话"])
        self.assertEqual(config["acknowledgementText"], "我在")
        self.assertTrue((target / "Sources" / "WakeHost" / "main.swift").is_file())
        self.assertIn("Created macos project", result.stdout)

    def test_preserves_raw_spacing_variants_for_vosk_grammar(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "project"
            subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--platform",
                    "macos",
                    "--target",
                    str(target),
                    "--wake-phrase",
                    "你好电脑",
                    "--wake-phrase",
                    "你好 电脑",
                ],
                check=True,
                text=True,
                capture_output=True,
            )
            config = json.loads((target / "config.json").read_text(encoding="utf-8"))
            self.assertEqual(config["wakePhrases"], ["你好电脑", "你好 电脑"])

    def test_windows_template(self):
        target, _ = self.scaffold("windows")
        self.assertTrue((target / "wake_service.py").is_file())
        self.assertTrue((target / "scripts" / "install.ps1").is_file())

    def test_refuses_nonempty_target(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary)
            (target / "keep.txt").write_text("keep", encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--platform",
                    "macos",
                    "--target",
                    str(target),
                    "--wake-phrase",
                    "Hey Codex",
                ],
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 4)
            self.assertEqual((target / "keep.txt").read_text(encoding="utf-8"), "keep")

    def test_rejects_punctuation_only_phrase(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--platform",
                    "windows",
                    "--target",
                    str(Path(temporary) / "project"),
                    "--wake-phrase",
                    "---",
                ],
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
