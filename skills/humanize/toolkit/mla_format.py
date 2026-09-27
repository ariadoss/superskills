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
from bisect import bisect_left, bisect_right
from pathlib import Path

# Sibling imports resolve against this file's real directory, so they work when it
# runs as a script, via runpy, as part of a package, or through a symlink; and they
# never write __pycache__ into the installed skill directory.
sys.dont_write_bytecode = True
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
from textio import read_prose, write_prose

_CLOSE = re.compile(r"\s*—\s*|\s*(?<!-)--(?!-)\s*")   # em-dash / double-hyphen, with surrounding space
_MULTISPACE = re.compile(r"[ \t]{2,}")


_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
_CLOSE_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})[ \t]*$")
_EDGES = re.compile(r"^([ \t]*)(.*?)([ \t]*)$", re.S)


def code_lines(lines: list[str]) -> list[bool]:
    """Per line, True when it is Markdown code: a fence, inside a fence, or an
    indented (four-plus spaces / a tab) line that does not continue a paragraph.
    Shared with emdash_fix so neither stage edits code."""
    mask, fence, prev_blank = [], None, True
    for line in lines:
        if fence:
            m = _CLOSE_FENCE.match(line)      # a closing fence carries nothing after it
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence):
                fence = None
            mask.append(True)
        elif _FENCE.match(line):
            fence = _FENCE.match(line).group(1)
            mask.append(True)
        else:
            lead = line[: len(line) - len(line.lstrip(" \t"))]
            indented = bool(line.strip()) and ("\t" in lead or len(lead) >= 4)
            # Indented code cannot interrupt a paragraph: it follows a blank line or more code.
            mask.append(indented and (prev_blank or (mask and mask[-1])))
        prev_blank = not line.strip()
    return mask


# Literal text neither stage may touch: HTML comments (one left open runs to the
# end of its prose run), reference-link definitions (destination on the same or
# the next line), inline link destinations (up to three levels of nested parens,
# any title style), autolinks, bare URLs (never their trailing punctuation or a
# dash glued to them) and email addresses. Each is swapped for a placeholder of
# private-use characters, which no dash, spacing or sentence rule matches, and put
# back afterwards. Inline code is found by _CodeSpans; _mask_prose takes whichever
# starts first.
_PARENS = r"(?:[^()\s]|\((?:[^()\s]|\((?:[^()\s]|\([^()\s]*\))*\))*\))*"
# A bare URL's body: parens only when balanced, so an enclosing `(...)` ends it,
# never a dash glued to it (— or –), and never its trailing punctuation.
_URL_BODY = r"(?:[^\s<>`()—–]|\([^\s<>`()]*\))*(?:[^\s<>`()—–.,;:!?'\"\]}]|\([^\s<>`()]*\))"
_LITERAL = re.compile(r"""
      <!--.*?(?:-->|\Z)
    | ^[ ]{0,3}\[[^\]\n]+\]:[ \t]*(?:\n[ \t]*)?[^\n]*
    | \]\(""" + _PARENS + r"""(?:[ \t]+(?:"[^"\n]*"|'[^'\n]*'|\([^()\n]*\)))?[ \t]*\)
    | <[A-Za-z][A-Za-z0-9+.-]*:[^<>\s]*>
    | \b(?:https?|ftp)://""" + _URL_BODY + r"""
    | \bwww\.""" + _URL_BODY + r"""
    | (?<![\w.+-])[\w.+-]+@[\w-]+(?:\.[\w-]+)+
""", re.S | re.M | re.X)
_SENTINEL = re.compile("[]")   # the placeholder alphabet itself
_TICKS = re.compile(r"`+")


class _CodeSpans:
    """Inline code spans, found on demand from a position. A backtick run closes at
    the next run of the same length, as CommonMark pairs them; an opener preceded
    by an unescaped backslash loses its first backtick. Each lookup is a bisect,
    so the whole scan stays linear-ish: a regex with a backreference here once
    backtracked exponentially on a long run of backticks."""

    def __init__(self, text: str):
        self.text = text
        self.runs = [(m.start(), m.end()) for m in _TICKS.finditer(text)]
        self.starts = [a for a, _ in self.runs]
        self.by_len: dict[int, list[int]] = {}
        for i, (a, b) in enumerate(self.runs):
            self.by_len.setdefault(b - a, []).append(i)

    def _escaped(self, a: int) -> bool:
        k = 0
        while a - k - 1 >= 0 and self.text[a - k - 1] == "\\":
            k += 1
        return k % 2 == 1

    def next_from(self, pos: int):
        for i in range(bisect_left(self.starts, pos), len(self.runs)):
            a, b = self.runs[i]
            if self._escaped(a):
                a += 1
            same = self.by_len.get(b - a, [])
            j = bisect_right(same, i)
            if b > a and j < len(same):
                return a, self.runs[same[j]][1]
        return None


def _mask_prose(text: str, hold) -> str:
    """Hold every literal in a run of prose lines, left to right: whichever of a
    code span or another literal starts first wins, so backticks inside a comment
    or link title never split it, and a link inside code stays code."""
    spans, out, pos = _CodeSpans(text), [], 0
    lit = span = None
    while True:
        if lit is None or lit.start() < pos:
            lit = _LITERAL.search(text, pos)
        if span is None or span[0] < pos:
            span = spans.next_from(pos)
        if span and (not lit or span[0] <= lit.start()):
            a, b = span
        elif lit:
            a, b = lit.span()
        else:
            break
        out.append(text[pos:a])
        out.append(hold(text[a:b]))
        pos = b
    out.append(text[pos:])
    return "".join(out)


def mask_literals(text: str) -> tuple[str, list[str]]:
    held: list[str] = []

    def stash(literal: str) -> str:
        held.append(literal)
        return f"{len(held) - 1}"

    def hold(literal: str) -> str:
        # A literal may contain stashed placeholder characters; store it as written
        # so restoring stays a single pass.
        return stash(unmask_literals(literal, held))

    # Placeholder characters already in the input are stashed first, so a stray
    # one can never be mistaken for a placeholder on the way back.
    text = _SENTINEL.sub(lambda m: stash(m.group(0)), text)

    # Code blocks are found on the raw text and never masked, so a fence can
    # never be misread as inline code (```sh ... printf "```" ...).
    lines = text.split("\n")
    out, prose = [], []
    for line, is_code in zip(lines, code_lines(lines)):
        if is_code:
            if prose:
                out.append(_mask_prose("\n".join(prose), hold))
                prose = []
            out.append(line)
        else:
            prose.append(line)
    if prose:
        out.append(_mask_prose("\n".join(prose), hold))
    return "\n".join(out), held


def unmask_literals(text: str, spans: list[str]) -> str:
    return re.sub("\ue010(\\d+)\ue011", lambda m: spans[int(m.group(1))], text)


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
        write_prose(p, out)
        print(f"MLA-formatted {p}")
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
