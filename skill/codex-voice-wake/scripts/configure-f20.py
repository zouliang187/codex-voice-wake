#!/usr/bin/env python3
"""Safely set Codex/ChatGPT Voice to F20 while preserving other keybindings."""

import json
import shutil
import sys
import argparse
from datetime import datetime
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--path",
        type=Path,
        default=Path.home() / ".codex" / "keybindings.json",
        help="Keybindings JSON path; defaults to ~/.codex/keybindings.json",
    )
    path = parser.parse_args().path.expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            print(f"Cannot read {path}: {error}", file=sys.stderr)
            return 2
        if not isinstance(data, list):
            print(f"Expected a JSON array in {path}", file=sys.stderr)
            return 3
    else:
        data = []

    replacement = {"command": "realtimeVoice", "key": "F20"}
    result = []
    replaced = False
    for item in data:
        if isinstance(item, dict) and item.get("command") == "realtimeVoice":
            if not replaced:
                result.append(replacement)
                replaced = True
            continue
        result.append(item)
    if not replaced:
        result.append(replacement)

    if result == data:
        print(f"Already configured: {path}")
        return 0
    if path.exists():
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = path.with_name(f"keybindings.before-f20.{stamp}.json")
        shutil.copy2(path, backup)
        print(f"Backup: {backup}")
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Configured realtimeVoice=F20: {path}")
    print("Fully quit and reopen ChatGPT before testing F20.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
