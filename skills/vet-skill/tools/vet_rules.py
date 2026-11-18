"""Rule table for vet_scan. Each rule is a function: {relative path: text} -> list of findings.
A finding is {"rule", "severity", "path", "line", "snippet", "note"}.
Rules only inspect text; they never execute or import it."""
import re

MAX_LINE = 4_096


def line_rule(rule_id, severity, pattern, note, globs=None):
    """Build a rule that flags each line matching `pattern` (case-insensitive) in files matching `globs`."""
    rx = re.compile(pattern, re.I)

    def run(texts):
        out = []
        for path, text in texts.items():
            if globs and not any(path.endswith(g) for g in globs):
                continue
            for n, line in enumerate(text.splitlines(), 1):
                if len(line) > MAX_LINE:
                    continue  # reported once per line by long_line_rule (VS010), never silently
                if rx.search(line):
                    out.append({"rule": rule_id, "severity": severity, "path": path, "line": n,
                                "snippet": line.strip(), "note": note})
        return out
    return run


def long_line_rule(texts):
    """VS010: a line over 4 KB is not examined by the line rules, so a payload can hide there. Say so."""
    return [{"rule": "VS010", "severity": "medium", "path": p, "line": n, "snippet": l[:160],
             "note": "line over 4096 characters: not examined by the other rules, read it by hand"}
            for p, t in texts.items() for n, l in enumerate(t.splitlines(), 1) if len(l) > MAX_LINE]


steering_rule = line_rule(
    "VS001", "high",
    r"(ignore|disregard|forget).{0,30}(previous|prior|above).{0,20}(instruction|rule)"
    r"|\b(ai|llm|claude|model|agent|assistant)\s+(reviewer|scanner|auditor)\b"
    r"|(do not|don't|never)\s+(tell|mention|report|reveal|disclose).{0,30}(user|reviewer|this)"
    r"|report that (this|it) (is|has)\b.{0,30}(safe|no (issues|vulnerabilit))"
    r"|<IMPORTANT>|<system>|\[SYSTEM\]",
    "text that addresses the reviewer or hides instructions from the user")

_invisible = line_rule(
    "VS002", "high",
    r"[​-‏‪-‮⁦-⁩﻿]|[\U000e0000-\U000e007f]",
    "invisible or bidirectional-control character: the text a reviewer sees is not the text that runs")


def invisible_rule(texts):
    """VS002, ignoring a single byte-order mark at the very start of a file."""
    return _invisible({p: (t[1:] if t.startswith("﻿") else t) for p, t in texts.items()})


obfuscation_rule = line_rule(
    "VS003", "medium",
    r"[A-Za-z0-9+/=]{200,}"
    r"|\b(eval|exec)\s*\(.{0,40}(b64decode|decode|fromhex|atob|decompress)"
    r"|String\.fromCharCode\(([^)]*,){8,}"
    r"|\\x[0-9a-f]{2}(\\x[0-9a-f]{2}){20,}",
    "encoded or obfuscated payload")

RULES = [steering_rule, invisible_rule, obfuscation_rule, long_line_rule]
FLOORS = {"VS001": "block", "VS002": "block", "VS003": "caution", "VS010": "caution"}
