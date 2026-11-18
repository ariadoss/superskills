"""Rule table for vet_scan. Each rule is a function: {relative path: text} -> list of findings.
A finding is {"rule", "severity", "path", "line", "snippet", "note"}.
Rules only inspect text; they never execute or import it."""
import re

MAX_LINE = 4_096
_EOL = re.compile(r"\r\n|\r|\n")

# Invisible characters, as a regex character-class body (zero-width joiner U+200D handled apart).
# vet_scan.py reuses this to escape the same characters in quoted snippets.
INVISIBLE = (
    "\u00ad\u034f\u061c\u180e\u200b\u200c\u200e\u200f\u202a-\u202e\u2060-\u2064\u2066-\u206f"
    "\u2800\u3164\ufe00-\ufe0f\ufeff\U000e0000-\U000e007f\U000e0100-\U000e01ef"
)


# Characters str.splitlines treats as breaks but an editor and a reader treat as plain whitespace.
_SEPARATORS = re.compile("[\x0b\x0c\x1c-\x1e\x85\u2028\u2029]")


def variants(line):
    """The line as written, with separators read as spaces, and with them deleted (a word split by one)."""
    if not _SEPARATORS.search(line):
        return (line,)
    return (line, _SEPARATORS.sub(" ", line), _SEPARATORS.sub("", line))


def split_lines(text):
    """Split on LF, CRLF or CR only, as an editor numbers lines. str.splitlines also splits on
    \\x0b, \\x0c, \\x1c-\\x1e, \\x85, U+2028 and U+2029, which a reader treats as plain spaces."""
    return _EOL.split(text)


def line_rule(rule_id, severity, pattern, note, globs=None):
    """Build a rule that flags each line matching `pattern` (case-insensitive) in files matching `globs`."""
    rx = re.compile(pattern, re.I)

    def run(texts):
        out = []
        for path, text in texts.items():
            if globs and not any(path.endswith(g) for g in globs):
                continue
            for n, line in enumerate(split_lines(text), 1):
                if len(line) > MAX_LINE:
                    continue  # reported once per line by long_line_rule (VS010), never silently
                if any(rx.search(v) for v in variants(line)):
                    out.append({"rule": rule_id, "severity": severity, "path": path, "line": n,
                                "snippet": line.strip(), "note": note})
        return out
    return run


def long_line_rule(texts):
    """VS010: a line over 4 KB is not examined by the line rules, so a payload can hide there. Say so."""
    return [{"rule": "VS010", "severity": "medium", "path": p, "line": n, "snippet": l[:160],
             "note": "line over 4096 characters: not examined by the other rules, read it by hand"}
            for p, t in texts.items() for n, l in enumerate(split_lines(t), 1) if len(l) > MAX_LINE]


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
    "[" + INVISIBLE + "]|(?<![^\\x00-\\x7f])\u200d|\u200d(?![^\\x00-\\x7f])",
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
