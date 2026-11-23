#!/usr/bin/env python3
"""Pull a subagent's final report out of its transcript.

Usage: extract_finals.py <transcript.jsonl> <out.txt>
Writes the `message` of the last SubagentHandback tool call to <out.txt> (empty if none),
and prints "<out.txt> <tool-call count> <found>".
"""
import json
import sys


def final(path):
    msg, ids = None, set()
    with open(path, encoding="utf-8", errors="replace") as fh:
        for ln in fh:
            try:
                obj = json.loads(ln)
            except ValueError:
                continue
            message = obj.get("message") if isinstance(obj, dict) else None
            content = message.get("content") if isinstance(message, dict) else None
            if not isinstance(content, list):
                continue
            for b in content:
                if not isinstance(b, dict) or b.get("type") != "tool_use" or "id" not in b:
                    continue
                ids.add(str(b["id"]))
                args = b.get("input")
                if b.get("name") == "SubagentHandback" and isinstance(args, dict):
                    msg = args.get("message")
    return msg, len(ids)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    m, n = final(sys.argv[1])
    with open(sys.argv[2], "w", encoding="utf-8") as out:
        out.write(m or "")
    print(sys.argv[2], n, bool(m))
