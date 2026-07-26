#!/usr/bin/env python3
"""Create a platform project and write the user's chosen phrases to config.json."""

import argparse
import json
import shutil
import sys
import unicodedata
from pathlib import Path


def normalize(text):
    return "".join(
        ch.casefold()
        for ch in unicodedata.normalize("NFKC", text)
        if ch.isalnum()
    )


def unique_phrases(values, label):
    result = []
    seen = set()
    for value in values:
        value = value.strip()
        if not normalize(value):
            raise ValueError("%s contains an empty or punctuation-only phrase" % label)
        # Preserve different spacing/spelling forms for Vosk's raw grammar even
        # when the state machine later normalizes them to the same match value.
        key = unicodedata.normalize("NFKC", value).casefold()
        if key not in seen:
            seen.add(key)
            result.append(value)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("macos", "windows"), required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument(
        "--wake-phrase",
        action="append",
        required=True,
        help="Exact wake phrase; repeat for ASR spelling/spacing variants",
    )
    parser.add_argument(
        "--exit-phrase",
        action="append",
        help="Standalone exit phrase; repeat for variants (default: 退出)",
    )
    parser.add_argument("--acknowledgement", default="在呢")
    args = parser.parse_args()

    try:
        wake_phrases = unique_phrases(args.wake_phrase, "wakePhrases")
        exit_phrases = unique_phrases(args.exit_phrase or ["退出"], "exitPhrases")
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 2

    skill_dir = Path(__file__).resolve().parents[1]
    template = skill_dir / "assets" / (args.platform + "-template")
    target = args.target.expanduser().resolve()
    if not template.is_dir():
        print("Missing template: %s" % template, file=sys.stderr)
        return 3
    if target.exists() and any(target.iterdir()):
        print("Refusing to overwrite non-empty target: %s" % target, file=sys.stderr)
        return 4

    target.mkdir(parents=True, exist_ok=True)
    shutil.copytree(str(template), str(target), dirs_exist_ok=True)
    config_path = target / "config.json"
    config = json.loads((target / "config.example.json").read_text(encoding="utf-8"))
    config["wakePhrases"] = wake_phrases
    config["exitPhrases"] = exit_phrases
    config["acknowledgementText"] = args.acknowledgement
    config_path.write_text(
        json.dumps(config, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    # Keep stdout ASCII-only so Windows hosts using a legacy console encoding do
    # not fail after successfully writing a Unicode config. Avoid echoing the
    # user's private wake phrase as a side benefit.
    print("Created %s project." % args.platform)
    print("Configured wake phrase variants: %d" % len(wake_phrases))
    print("Review config.json, then follow the platform README reference in the Skill.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
