"""Deterministic em-dash replacement by clause role.

The em-dash is the single most-cited AI-writing tell. This replaces each one by the
*grammatical role* of what it joins, rather than deleting it blindly:

  - PAIRED dashes bracketing an aside  ( X — aside — Y )      -> commas: X, aside, Y
                                          (parentheses when the aside is a full clause)
  - LONE dash before an INDEPENDENT clause (has subject+verb) -> period (new sentence)
  - LONE dash before an EXPANSION / list / restatement        -> colon
  - LONE dash before a DEPENDENT fragment                      -> comma
  - TRAILING dash with nothing after it (break-off)           -> period

Independent-vs-dependent is decided with a dependency parse (spaCy en_core_web_sm), so
"— she left" (independent) becomes ". She left" while "— cold and tired" (fragment) becomes
", cold and tired". Usage:  python3 emdash_fix.py FILE  [--tighten] [--in-place]
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
from mla_format import _CLOSE, code_lines, mask_literals, unmask_literals
from textio import read_prose, write_prose

EM = re.compile(r"\s*[—–]\s*|\s*(?<!-)--(?!-)\s*")  # em, en, or double-hyphen, with surrounding space
_nlp = None

# Numeric ranges and closed en-dash compounds are NOT dashes-as-punctuation and must survive
# untouched (MLA: "3–64 characters", "1999–2004", "pp. 12–15", "1×–3×", "A–Z", "New York–London").
# A closed en dash (no space on either side) is always a range/compound; an em dash or double
# hyphen closed between two numbers is a range typed with the wrong glyph and becomes an en dash.
_RANGE_PH = "\ue000"
_CLOSED_EN = re.compile(r"(?<=\S)–(?=\S)")
_NUMERIC_EM = re.compile(r"(?<=[\d×%])\s*(?:—|--)\s*(?=[\d×%$])")


def _protect_ranges(text: str) -> str:
    text = _NUMERIC_EM.sub("–", text)          # 3—64 / 3 -- 64  ->  3–64
    return _CLOSED_EN.sub(_RANGE_PH, text)     # shield every closed en dash from EM


def _restore_ranges(text: str) -> str:
    return text.replace(_RANGE_PH, "–")


# spaCy + en_core_web_sm is an OPTIONAL dependency, needed only to tell an
# independent clause (-> period) from an appositive (-> comma). Without it this
# script used to raise ModuleNotFoundError mid-file; now the undecidable dashes
# are left alone and reported, because guessing either way corrupts the prose:
# a comma after an independent clause is a splice, and a period after an
# appositive severs the sentence.
_nlp_unavailable = False
skipped_undecidable = 0


def nlp():
    """The loaded pipeline, or None when spaCy or its model is unavailable."""
    global _nlp, _nlp_unavailable
    if _nlp_unavailable:
        return None
    if _nlp is None:
        try:
            import spacy
            _nlp = spacy.load("en_core_web_sm")
        except Exception:
            _nlp_unavailable = True
            return None
    return _nlp


def _is_independent(clause: str):
    """True / False if the clause can stand alone (finite verb + explicit
    subject); None when that cannot be determined because spaCy is absent."""
    pipeline = nlp()
    if pipeline is None:
        return None
    doc = pipeline(clause.strip())
    has_subj = any(t.dep_ in ("nsubj", "nsubjpass", "expl") for t in doc)
    has_finite_verb = any(t.pos_ in ("VERB", "AUX") and t.morph.get("VerbForm") == ["Fin"] for t in doc)
    return has_subj and has_finite_verb


def _is_expansion(clause: str) -> bool:
    """A list or restatement reads as an expansion -> colon (e.g. 'everything: food, water, shelter')."""
    c = clause.strip().rstrip(".!?")
    return c.count(",") >= 2 or (" and " in c and "," in c)


def fix_sentence(sentence: str) -> str:
    """Replace em-dashes in one sentence by clause role."""
    global skipped_undecidable
    parts = EM.split(sentence)
    if len(parts) == 1:
        return sentence
    # Paired dash bracketing an aside (A — mid — B). A nonrestrictive appositive reads best set
    # off by COMMAS. Commas are only
    # safe around a phrase, though: around a full clause ("left—it was late—and") they make a comma
    # splice. Parentheses are grammatical around any aside, so they are used whenever the aside is,
    # or without spaCy might be, an independent clause, and when it holds its own commas.
    if len(parts) == 3 and parts[0].strip() and parts[2].strip():
        a, mid, b = (p.strip() for p in parts)
        tail = b if b[:1] in ",.;:!?" else " " + b
        if "," in mid or _is_independent(mid) is not False:
            return f"{a} ({mid}){tail}".strip()
        return f"{a}, {mid},{tail}".strip()
    # Otherwise resolve each dash left-to-right by the role of the text that follows it.
    out = parts[0].rstrip()
    for follow in parts[1:]:
        f = follow.strip()
        if not f:                                   # trailing break-off dash
            out = out.rstrip(" ,;:") + "."
            continue
        independent = _is_independent(f)
        if independent is None:
            # Undecidable without spaCy. An expansion is still safe to convert:
            # a colon is grammatical after an independent clause AND before a
            # list/restatement, so it cannot be wrong either way. Anything else
            # keeps its dash rather than risk a splice or a severed sentence.
            if _is_expansion(f):
                out = out.rstrip(" ,;:") + ": " + f
            else:
                skipped_undecidable += 1
                out = out.rstrip() + "\u2014" + f
            continue
        if independent:
            out = out.rstrip(" ,;:") + ". " + f[0].upper() + f[1:]
        elif _is_expansion(f):
            out = out.rstrip(" ,;:") + ": " + f
        else:
            out = out.rstrip(" ,;:") + ", " + f
    return out


# "- label — gloss": a dash after a list item's short label introduces a gloss,
# which is exactly what a colon is for. Only when the dash is the line's only one.
_LIST_ITEM = re.compile(r"^(\s*(?:[-+]|\d+[.)])\s+)(.*)$")


def _list_gloss(line: str):
    m = _LIST_ITEM.match(line)
    if not m:
        return None
    parts = EM.split(m.group(2))
    if len(parts) != 2 or not parts[0].strip() or not parts[1].strip():
        return None
    label = parts[0].strip()
    if len(label.split()) > 4 or label[-1] in ".,;:!?":
        return None
    return f"{m.group(1)}{label}: {parts[1].strip()}"


# A dash ending a line whose sentence wraps onto the next prose line is not a
# break-off: join the two so the clause after it decides the punctuation. Never
# across code (a CLI flag or SQL comment ends in `--`), and never out of a
# heading, table row or quote, which do not wrap onto a plain line.
_LINE_END_DASH = re.compile(r"(\S)[ \t]*(—|–|(?<!-)--(?!-))[ \t]*$")
# \ue010 opens a masked literal: a line that starts with a comment, URL or link
# definition is not a sentence continuation.
_CONTINUATION = re.compile(r"[ \t]*(?![-*+][ \t]|\d+[.)][ \t])[^\s#>|`\ue010]")


def _join_wrapped_dashes(text: str) -> str:
    lines = text.split("\n")
    code = code_lines(lines)
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        while (i + 1 < len(lines) and not code[i] and not code[i + 1]
               and not line.lstrip().startswith(("#", "|", ">"))
               and not line.endswith("  ")                       # a hard break ends the line
               and not _SETEXT.match(lines[i + 1])
               and _LINE_END_DASH.search(line) and _CONTINUATION.match(lines[i + 1])):
            line = _LINE_END_DASH.sub(r"\1 \2 ", line) + lines[i + 1].lstrip()
            i += 1
        out.append(line)
        i += 1
    return "\n".join(out)


# A setext heading underline (`Heading` / `--`) is structure, not a dash.
_SETEXT = re.compile(r"^ {0,3}(?:=+|-+)[ \t]*$")


def _prose_lines(text: str):
    """(line, is_editable) for each line: code, headings, quotes, tables, `*` lists and
    setext underlines are structure and pass through untouched."""
    src = text.split("\n")
    for line, is_code in zip(src, code_lines(src)):
        yield line, not (is_code or _SETEXT.match(line)
                         or line.lstrip().startswith(("#", "*", ">", "|")))


def _split_edges(line: str) -> tuple[str, str, str]:
    """(indent, body, hard_break): the sentence rules only ever see the body, so a
    line's indentation and a trailing two-space hard break survive them."""
    lead = line[: len(line) - len(line.lstrip())]
    body = line.strip()
    trail = line[len(line.rstrip()):]
    return lead, body, ("  " if len(trail) >= 2 and body else "")


def fix_text(text: str) -> str:
    text, spans = mask_literals(text)
    text = _join_wrapped_dashes(text)
    lines = []
    for line, editable in _prose_lines(text):
        if not editable or not EM.search(line):
            lines.append(line)
            continue
        lead, body, hard = _split_edges(line)
        body = _protect_ranges(body)        # prose only: code keeps its `3--1`
        gloss = _list_gloss(lead + body)
        if gloss is None:
            # split into sentences, fix each, rejoin (sentence-final punct + space)
            sents = re.split(r"(?<=[.!?])\s+", body)
            gloss = lead + " ".join(fix_sentence(s) for s in sents)
        lines.append(_restore_ranges(gloss) + hard)
    return unmask_literals("\n".join(lines), spans)


# --tighten: KEEP the em-dash but close the spaces around it (word — word -> word—word), and
# normalize a double-hyphen to a real em-dash. Leaves hyphenated words and en-dash ranges alone.


def tighten_text(text: str) -> str:
    text, spans = mask_literals(text)
    lines = []
    for line, editable in _prose_lines(text):
        if not editable or ("—" not in line and "--" not in line):
            lines.append(line)
            continue
        lead, body, hard = _split_edges(line)
        lines.append(lead + _restore_ranges(_CLOSE.sub("—", _protect_ranges(body))) + hard)
    return unmask_literals("\n".join(lines), spans)


def report_undecidable() -> None:
    """Tell the user, on stderr, how many dashes were kept for want of spaCy."""
    if skipped_undecidable:
        print(
            f"note: kept {skipped_undecidable} em-dash(es) whose clause role could not be "
            "determined without spaCy, rather than guessing. For automatic clause-role "
            "replacement: pip install spacy && python3 -m spacy download en_core_web_sm",
            file=sys.stderr,
        )


def main():
    if len(sys.argv) < 2:
        print("usage: python3 emdash_fix.py FILE [--tighten] [--in-place]"); sys.exit(1)
    p = Path(sys.argv[1])
    # --tighten keeps dashes and only closes the spaces; default replaces them by clause role.
    text = read_prose(p)
    out = tighten_text(text) if "--tighten" in sys.argv else fix_text(text)
    if "--in-place" in sys.argv:
        write_prose(p, out)
        print(f"{'tightened' if '--tighten' in sys.argv else 'fixed'} em-dashes in {p}")
    else:
        sys.stdout.write(out)
    report_undecidable()


if __name__ == "__main__":
    main()
