#!/usr/bin/env python3
"""Compatibility entry point; implementation lives inside novel/."""
from pathlib import Path
import runpy
import sys

if __name__ == "__main__":
    directory = Path(__file__).resolve().parents[2] / "novel/tools"
    sys.path.insert(0, str(directory))
    runpy.run_path(str(directory / "story_continuity.py"), run_name="__main__")
