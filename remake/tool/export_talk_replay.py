#!/usr/bin/env python3
"""Export every literal LORETALK.at coordinate for runtime dispatch replay."""

import argparse
import json
from pathlib import Path

from audit_loretalk import source_coordinates


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "test/fixtures/source_talk_replay.json"


def build():
    return {
        "source": "LORETALK.PAS",
        "cases": [
            {"map": m, "x": x, "y": y, "line": line}
            for m, x, y, line in source_coordinates()
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = json.dumps(build(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != content:
            raise SystemExit("source_talk_replay.json drifted")
        return
    OUTPUT.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
