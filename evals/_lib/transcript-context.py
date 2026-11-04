#!/usr/bin/env python3
"""transcript-context.py <transcript.jsonl...>: bytes of tool results loaded into context, by source.

Prints one JSON object: total, by_tool, by_skill (Skill tool results by skill name),
references_read (bytes of Read results whose path contains /references/).
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


def breakdown(paths):
    uses = {}
    by_tool, by_skill = defaultdict(int), defaultdict(int)
    refs = 0
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                blocks = (rec.get("message") or {}).get("content")
                if not isinstance(blocks, list):
                    continue
                for b in blocks:
                    if not isinstance(b, dict):
                        continue
                    if b.get("type") == "tool_use":
                        uses[b.get("id")] = (b.get("name", "?"), b.get("input") or {})
                    elif b.get("type") == "tool_result":
                        name, inp = uses.get(b.get("tool_use_id"), ("?", {}))
                        n = len(_text(b.get("content")).encode("utf-8"))
                        by_tool[name] += n
                        if name == "Skill":
                            by_skill[str(inp.get("skill", "?")).split(":")[-1]] += n
                        if name == "Read" and "/references/" in str(inp.get("file_path", "")):
                            refs += n
    return {"total": sum(by_tool.values()), "by_tool": dict(by_tool),
            "by_skill": dict(by_skill), "references_read": refs}


if __name__ == "__main__":
    print(json.dumps(breakdown(sys.argv[1:]), sort_keys=True))
