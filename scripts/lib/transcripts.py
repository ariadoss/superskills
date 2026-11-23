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


def is_subagent_path(path, projects_dir):
    """True when a transcript sits under a `subagents` directory inside projects_dir."""
    try:
        parts = Path(path).relative_to(projects_dir).parts
    except ValueError:
        parts = Path(path).parts
    return "subagents" in parts[:-1]


def session_files(projects_dir, days=None, top_level_only=False):
    """Sorted *.jsonl paths under projects_dir; with days, only files modified inside the window.

    top_level_only skips subagent transcripts (any `subagents` path segment), so the
    result counts real sessions. The default keeps them, as the mistake miner expects.

    Sorted as plain strings with glob semantics (hidden directories skipped), the
    order the mistake miner always used, so its event numbering stays stable.
    """
    cutoff = time.time() - days * 86400 if days is not None else None
    pattern = os.path.join(str(projects_dir), "**", "*.jsonl")
    out = []
    for name in sorted(glob.glob(pattern, recursive=True)):
        p = Path(name)
        if top_level_only and is_subagent_path(p, projects_dir):
            continue
        if cutoff is not None:
            try:
                if p.stat().st_mtime < cutoff:
                    continue
            except OSError:
                continue  # broken symlink or vanished file
        out.append(p)
    return out


def iter_entries(path, errors="replace"):
    """Yield each line of a transcript that decodes to a JSON object; skip the rest.

    errors is the text decoding policy; the mistake miner passes "ignore".
    """
    try:
        fh = Path(path).open(encoding="utf-8", errors=errors)
    except OSError:
        return  # a directory named *.jsonl, a broken link, a vanished file
    with fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if isinstance(entry, dict):
                yield entry
