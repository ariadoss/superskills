"""Deterministic MLA typographic normalization for prose — the mechanically-safe subset.

Applies the MLA conventions that can be done without judgment:
  - em-dashes CLOSED / unspaced:  word — word  ->  word—word   (and  --  ->  —)
  - a single space after sentence-ending punctuation (never two); collapse other space runs

It deliberately does NOT touch:
  - numbers (MLA: spell out one-or-two-word numbers, numerals otherwise) — context-dependent
  - quotation marks / italics / titles — judgment
those MLA rules belong to the human/LLM edit step. Markdown structure is left alone: structural
lines (headings, list items, blockquotes, tables), fenced and indented code, leading indentation,
and a trailing two-space hard break. Usage:  python3 mla_format.py FILE [--in-place]
"""
import re
import sys
from pathlib import Path

# Sibling imports resolve against this file's real directory, so they work when it
# runs as a script, via runpy, as part of a package, or through a symlink; and they
# never write __pycache__ into the installed skill directory.
sys.dont_write_bytecode = True
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
from textio import read_prose

_CLOSE = re.compile(r"\s*—\s*|\s*(?<!-)--(?!-)\s*")   # em-dash / double-hyphen, with surrounding space
_MULTISPACE = re.compile(r"[ \t]{2,}")


_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
_EDGES = re.compile(r"^([ \t]*)(.*?)([ \t]*)$", re.S)


# HTML comments, inline code (`--flag`), link targets ](#a--b) and autolinks are
# literal: neither stage may touch them. Each is swapped for a placeholder of
# private-use characters, which no dash, spacing or sentence rule matches, and
# put back afterwards.
_LITERAL = re.compile(r"<!--.*?-->|(`+)(?:(?!\1).)+?\1|\]\([^)\s]*(?:\s+\"[^\"]*\")?\)|<https?://[^>\s]+>",
                      re.S)


def mask_literals(text: str) -> tuple[str, list[str]]:
    spans: list[str] = []

    def hold(m: re.Match) -> str:
        spans.append(m.group(0))
        return f"\ue010{len(spans) - 1}\ue011"

    return _LITERAL.sub(hold, text), spans


def unmask_literals(text: str, spans: list[str]) -> str:
    return re.sub("\ue010(\\d+)\ue011", lambda m: spans[int(m.group(1))], text)


def code_lines(lines: list[str]) -> list[bool]:
    """Per line, True when it is Markdown code: a fence, inside a fence, or indented
    four-plus spaces / a tab. Shared with emdash_fix so neither stage edits code."""
    mask, fence = [], None
    for line in lines:
        m = _FENCE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence):
                fence = None
            mask.append(True)
        elif m:
            fence = m.group(1)
            mask.append(True)
        else:
            lead = line[: len(line) - len(line.lstrip(" \t"))]
            mask.append(bool(line.strip()) and ("\t" in lead or len(lead) >= 4))
    return mask


def mla_format(text: str) -> str:
    text, spans = mask_literals(text)
    src = text.split("\n")
    lines = []
    for line, is_code in zip(src, code_lines(src)):
        lead, body, trail = _EDGES.match(line).groups()
        if is_code or body.startswith(("#", "*", ">", "|", "-")):   # code / markdown structure
            lines.append(line)
            continue
        body = _CLOSE.sub("—", body)          # close em-dashes (leaves hyphenated words / en-dashes)
        body = _MULTISPACE.sub(" ", body)     # single space after periods; no double spaces
        # Two or more trailing spaces are a Markdown hard break; anything less is noise.
        lines.append(lead + body + ("  " if len(trail) >= 2 and body else ""))
    return unmask_literals("\n".join(lines), spans)


def main():
    if len(sys.argv) < 2:
        print("usage: python3 mla_format.py FILE [--in-place]"); sys.exit(1)
    p = Path(sys.argv[1])
    out = mla_format(read_prose(p))
    if "--in-place" in sys.argv:
        p.write_text(out)
        print(f"MLA-formatted {p}")
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
