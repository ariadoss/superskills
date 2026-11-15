#!/usr/bin/env python3
"""mine-agent-mistakes.py — read-only incident miner over Claude Code session
logs (external-ideas round 2, T4 groundwork).

Incident definitions (PREREG 2026-11-15, fixed in advance):
  edit-thrash        same file edited >=3 times in one session WITH a failed
                     test/build command between its first and last edit
  repeat-fail        same normalized command failing >=2 times in one session
  skill-load-failure a Skill tool_use whose result is an error

Dedup: one incident per (session, file) / (session, command) — a retry loop
counts once. A TDD red-green flow is NOT thrash: the failure must fall
between edits of that file; a red test that precedes all edits of the file
does not count.

Usage:
  python3 -I mine-agent-mistakes.py [--sample N] [--max-files N] [--json]
"""
import argparse
import collections
import glob
import json
import os
import re
import sys

HOME = os.path.expanduser("~")
TEST_BUILD = re.compile(
    r"\b(pytest|unittest|npm\s+test|yarn\s+test|pnpm\s+test|go\s+test|"
    r"cargo\s+test|bats|rspec|make\s+test|mvn\s+-q|gradle\s+test|"
    r"tests?/run\.sh|claude\s+plugin\s+(validate|eval))\b", re.I)


def result_is_error(block):
    if block.get("is_error"):
        return True
    content = block.get("content")
    text = ""
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        text = " ".join(c.get("text", "") for c in content
                        if isinstance(c, dict))
    return bool(re.match(r"^\s*(Exit code|Error|error:|Traceback)", text))


def normalize_command(cmd):
    return re.sub(r"\s+", " ", cmd.strip())


def mine(args):
    sessions = 0
    thrash, repeat_fail, skill_fail = [], [], []
    files = sorted(glob.glob(HOME + "/.claude/projects/**/*.jsonl",
                             recursive=True))
    if args.max_files:
        files = files[:args.max_files]
    for path in files:
        sessions += 1
        sid = os.path.basename(path)
        bash_calls = {}          # tool_use_id -> normalized command
        edit_events = collections.defaultdict(list)  # file -> [event_no]
        skill_calls = {}         # tool_use_id -> skill name
        failed_test_nos = []     # [event_no]
        failed_bash = collections.Counter()
        failed_skills = []
        events = 0
        try:
            with open(path, errors="ignore") as fh:
                for line in fh:
                    try:
                        row = json.loads(line)
                    except ValueError:
                        continue
                    msg = row.get("message")
                    if not isinstance(msg, dict):
                        continue
                    content = msg.get("content")
                    if not isinstance(content, list):
                        continue
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        events += 1
                        btype = block.get("type")
                        if btype == "tool_use":
                            name = block.get("name", "")
                            inp = block.get("input") or {}
                            bid = block.get("id")
                            if name in ("Edit", "Write", "NotebookEdit"):
                                fp = (inp.get("file_path")
                                      or inp.get("notebook_path") or "?")
                                edit_events[os.path.basename(fp)].append(events)
                            elif name == "Bash":
                                bash_calls[bid] = normalize_command(
                                    inp.get("command", ""))
                            elif name == "Skill":
                                skill_calls[bid] = inp.get("skill", "?")
                        elif btype == "tool_result" and result_is_error(block):
                            tu = block.get("tool_use_id")
                            text = ""
                            c = block.get("content")
                            if isinstance(c, str):
                                text = c
                            elif isinstance(c, list):
                                text = " ".join(x.get("text", "")
                                                for x in c if isinstance(x, dict))
                            if tu in edit_events or tu in skill_calls:
                                if tu in skill_calls:
                                    failed_skills.append(
                                        {"session": sid,
                                         "skill": skill_calls[tu]})
                                continue
                            if tu in bash_calls:
                                cmd = bash_calls[tu]
                                failed_bash[cmd] += 1
                                if TEST_BUILD.search(cmd) or TEST_BUILD.search(text):
                                    failed_test_nos.append(events)
        except OSError:
            continue
        for fname, nos in edit_events.items():
            if len(nos) >= 3:
                lo, hi = nos[0], nos[-1]
                if any(lo < f < hi for f in failed_test_nos):
                    thrash.append({"session": sid, "file": fname,
                                   "edits": len(nos)})
        for cmd, k in failed_bash.items():
            if k >= 2:
                repeat_fail.append({"session": sid, "fails": k,
                                    "command": cmd[:160]})
        skill_fail.extend(failed_skills)
    return sessions, thrash, repeat_fail, skill_fail


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", type=int, default=20)
    ap.add_argument("--max-files", type=int, default=0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    sessions, thrash, repeat, skillf = mine(args)
    sample = (thrash + repeat + skillf)[:args.sample]
    if args.json:
        json.dump({"sessions_scanned": sessions,
                   "edit_thrash": len(thrash),
                   "repeat_fail": len(repeat),
                   "skill_load_failures": len(skillf),
                   "sample": sample}, sys.stdout, indent=1)
    else:
        print(f"sessions_scanned: {sessions}")
        print(f"edit_thrash: {len(thrash)}")
        print(f"repeat_fail: {len(repeat)}")
        print(f"skill_load_failures: {len(skillf)}")
        print(f"sample ({len(sample)}) for hand labeling:")
        for s in sample:
            print(json.dumps(s))


if __name__ == "__main__":
    main()
