#!/usr/bin/env python3
"""transcript-context.py <transcript.jsonl...>: bytes of tool results loaded into context, by source.

Prints one JSON object: total, by_tool, by_skill (Skill tool results by skill name),
references_read (bytes of Read results whose path contains /references/),
references and skill_calls (ordered, sharing one seq counter over tool_use order).
A Skill call's body arrives as a separate isMeta user text block; it is counted into
total, by_tool.Skill and by_skill.
Malformed lines are skipped. Stdlib only.
"""
import json
import sys
from collections import defaultdict


def _text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(b.get("text", "") for b in content if isinstance(b, dict))
    return ""


def _skill_name(inp):
    return str(inp.get("skill", "?")).split(":")[-1]


def breakdown(paths):
    uses = {}
    by_tool, by_skill = defaultdict(int), defaultdict(int)
    refs, references, skill_calls = 0, [], []
    seq = 0
    for path in paths:
        pending = None  # skill name whose body message has not arrived yet
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(rec, dict):
                    continue
                blocks = (rec.get("message") or {}).get("content")
                if not isinstance(blocks, list):
                    continue
                for b in blocks:
                    if not isinstance(b, dict):
                        continue
                    kind = b.get("type")
                    if kind == "tool_use":
                        seq += 1
                        name, inp = b.get("name", "?"), b.get("input") or {}
                        uses[(path, b.get("id"))] = (name, inp, seq)
                        if name == "Skill":
                            skill_calls.append({"seq": seq, "skill": _skill_name(inp)})
                    elif kind == "tool_result":
                        name, inp, s = uses.get((path, b.get("tool_use_id")), ("?", {}, 0))
                        n = len(_text(b.get("content")).encode("utf-8"))
                        by_tool[name] += n
                        if name == "Skill":
                            by_skill[_skill_name(inp)] += n
                            pending = _skill_name(inp)
                        fp = str(inp.get("file_path", ""))
                        if name == "Read" and "/references/" in fp:
                            refs += n
                            references.append({"seq": s, "path": fp, "bytes": n})
                    elif (kind == "text" and rec.get("isMeta") and pending
                          and "Base directory for this skill" in str(b.get("text", ""))):
                        n = len(str(b.get("text", "")).encode("utf-8"))
                        by_tool["Skill"] += n
                        by_skill[pending] += n
                        pending = None
    return {"total": sum(by_tool.values()), "by_tool": dict(by_tool),
            "by_skill": dict(by_skill), "references_read": refs,
            "references": references, "skill_calls": skill_calls}


if __name__ == "__main__":
    print(json.dumps(breakdown(sys.argv[1:]), sort_keys=True))
