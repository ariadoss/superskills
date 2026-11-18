#!/usr/bin/env python3
"""Count skill invocations in Claude Code transcripts.

Usage: skill_usage.py <projects_dir> [--days 90]
Prints "# sessions=N subagent_files=M" (sessions exclude subagent
transcripts; skill calls inside them still count) then "<skill> TAB <count>" per skill. Reads each line as
JSON and looks at two shapes only: a Skill tool call and a typed
<command-name>/x</command-name>. It never prints message text, so a secret in
a transcript cannot leak through this tool. Non-JSON lines are skipped.
A session counts when its file was modified inside the window.
"""
import argparse
import importlib.util
import re
import sys
from collections import Counter
from pathlib import Path

# python3 -I adds no script directory to sys.path, so load the shared reader by path.
_spec = importlib.util.spec_from_file_location(
    "transcripts", Path(__file__).resolve().parents[1] / "lib" / "transcripts.py")
_transcripts = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_transcripts)

COMMAND = re.compile(r"<command-name>/([A-Za-z0-9:_-]+)</command-name>")


def _bare(name):
    """Drop a `plugin:` prefix so plugin and local names match."""
    return name.rpartition(":")[2] or name


def _blocks(entry):
    msg = entry.get("message") or {}
    content = msg.get("content")
    if isinstance(content, list):
        return content
    return [{"type": "text", "text": content}] if isinstance(content, str) else []


def count_usage(projects_dir, days):
    counts, sessions, subagent_files = Counter(), 0, 0
    for path in _transcripts.session_files(projects_dir, days):
        if _transcripts.is_subagent_path(path, projects_dir):
            subagent_files += 1
        else:
            sessions += 1
        for entry in _transcripts.iter_entries(path):
            for b in _blocks(entry):
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "tool_use" and b.get("name") == "Skill":
                    name = (b.get("input") or {}).get("skill")
                    if isinstance(name, str) and name:
                        counts[_bare(name)] += 1
                elif b.get("type") == "text" and isinstance(b.get("text"), str):
                    for m in COMMAND.finditer(b["text"]):
                        counts[_bare(m.group(1))] += 1
    return sessions, subagent_files, counts


def main(argv):
    p = argparse.ArgumentParser()
    p.add_argument("projects_dir")
    p.add_argument("--days", type=int, default=90)
    a = p.parse_args(argv[1:])
    sessions, subagent_files, counts = count_usage(a.projects_dir, a.days)
    print(f"# sessions={sessions} subagent_files={subagent_files}")
    for name, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"{name}\t{n}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
