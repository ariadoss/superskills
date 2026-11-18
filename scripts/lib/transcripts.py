"""Shared reader for Claude Code session transcripts (JSONL).

Seam: session_files(projects_dir, days=None) and iter_entries(path).
Used by evals/_lib/mine-agent-mistakes.py and scripts/skill-census/skill_usage.py
so the log format is parsed in exactly one place.
"""
import glob
import json
import os
import time
from pathlib import Path


def session_files(projects_dir, days=None):
    """Sorted *.jsonl paths under projects_dir; with days, only files modified inside the window.

    Sorted as plain strings with glob semantics (hidden directories skipped), the
    order the mistake miner always used, so its event numbering stays stable.
    """
    cutoff = time.time() - days * 86400 if days is not None else None
    pattern = os.path.join(str(projects_dir), "**", "*.jsonl")
    out = []
    for name in sorted(glob.glob(pattern, recursive=True)):
        p = Path(name)
        if cutoff is None or p.stat().st_mtime >= cutoff:
            out.append(p)
    return out


def iter_entries(path):
    """Yield each line of a transcript that decodes to a JSON object; skip the rest."""
    with Path(path).open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if isinstance(entry, dict):
                yield entry
