---
name: humanize
description: |
  Prose-quality cleanup that strips AI slop while keeping the author's voice:
  deterministic em-dash and spacing fixes, a ~45-check slop scan, then surgical
  subtractive edits the agent applies itself, gated by a re-scan. Use when asked
  to "humanize" prose, "remove AI slop", "de-slop", "cut the AI tells", "fix the
  em-dashes", or when a draft "reads like AI". Not for code, and not for copy
  editing that changes facts.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
---

# Humanize — cut AI slop, keep the voice

Deterministic fixes and a scan do the measuring. **You, the agent, then make the
edits**: surgical, subtractive, one flagged span at a time with the Edit tool,
applied directly to the working copy without asking first. A re-scan is the gate.
Never regenerate or paraphrase the whole text; a whole-document rewrite loses the
author's voice and adds new tells.

`TOOLKIT` below means the `toolkit/` directory inside this skill's own directory.
The host prints that directory when the skill loads (Claude Code: "Base directory
for this skill: …") — use it. Do **not** derive it from `$0`: in your shell that
names the shell, not this file. Confirm the path before running anything, so a
wrong one fails loudly instead of step 1 running nothing:

```bash
TOOLKIT="<base directory for this skill>/toolkit"
# Fallback, only if the host printed no base directory. Never the shell's cwd:
# that would run whatever toolkit/ happens to sit there.
for d in "$TOOLKIT" "$HOME/.claude/skills/humanize/toolkit"; do
  [ -f "$d/slop_report.py" ] && { TOOLKIT="$d"; break; }
done
[ -f "$TOOLKIT/slop_report.py" ] || { echo "humanize toolkit not found" >&2; exit 1; }
```

## Prerequisites

The toolkit runs on the Python standard library alone. Two optional packages
improve it, and their absence degrades cleanly rather than failing:

| Optional | Used for | Without it |
|---|---|---|
| `spacy` + `en_core_web_sm` | telling an independent clause from an appositive, so a dash becomes a period rather than a comma splice | undecidable dashes are **kept** and reported on stderr; expansions still become colons |
| `nltk` | better tokenizing and CMU-dict syllable counts for the complexity index | falls back to a regex tokenizer and a syllable heuristic |

```bash
pip install spacy && python3 -m spacy download en_core_web_sm   # recommended
pip install nltk                                                # optional
```

Note: when `nltk` is installed, the scorer downloads the `punkt` tokenizer once,
quietly, on first use.

## Arguments

`<file.md> [exempt.txt]`

- `file.md` — the prose to clean. Write to `<dir>/<name>_humanized.md`. **Never
  overwrite the source.** Output derived from private text must not be committed.
- `exempt.txt` — optional allowlist of product names and terms of art, one token
  per line, so the scan and your edits leave legitimate vocabulary alone. See
  `toolkit/exempt_example.txt`.

## Steps

**1. Em-dashes — the default is to replace them.**

```bash
python3 "$TOOLKIT/normalize.py" "<file>" "<dir>/<name>_humanized.md"
```

`normalize.py` runs `emdash_fix.py` then `mla_format.py` and writes the output
only if both succeed, so a failure leaves no half-written `_humanized.md` to
mistake for a result. It refuses to overwrite the source. Code blocks, hard
breaks and indentation pass through untouched.

Replace by clause role: clean appositive → commas, independent clause → period,
expansion → colon, break-off → period. Keep an em-dash only where replacing it
genuinely hurts the line, not as a default. A kept dash is sparse (~2 per 1,000
words), **lone** rather than paired, and closed/unspaced (`word—word`), which
`mla_format.py` enforces along with single sentence spacing. Straighten stray
curly quotes. Nothing else is auto-safe: never let a tool do synonym
substitution, which corrupts meaning.

**2. Scan the working copy.**

```bash
python3 "$TOOLKIT/slop_report.py" "<dir>/<name>_humanized.md" [--exempt <exempt.txt>]
```

You get `slop_index`, `complexity_index`, EQ-Bench slop words/bigrams/trigrams
with line numbers, and construction densities (way-x, aphorism, as-if, magic
adverb, pushbutton, distancing verb, filler).

**3. Apply the edits to `<dir>/<name>_humanized.md` with the Edit tool.**

Work through the flags from step 2 and fix each one in place, without stopping
to ask for approval. Each edit touches only the flagged span and what it needs
to stay grammatical. In this order:

1. **Delete** — filler adverbs, rhetorical scaffolding, redundant restatement (a
   sentence that merely repeats the one before it). This is the biggest win.
2. **Compress** — only where meaning and temperature survive intact.
3. **Hold** — if a flagged line is vivid, specific, and reads aloud well, **leave
   it** and note it for the report. A flag is a reason to look, not a mandate to
   change.
4. **Substitute only as a last resort**, and only for something strictly plainer
   with the same meaning. **Never swap one charged word for another to clear a
   flag** (`delve`→`dig into`, `crucial`→`key`). That flattens voice, and it is
   exactly what the scanner would reward.
5. **Normalize punctuation last.**

**Preserve meaning absolutely.** Never change a fact, number, name, date, or the
logical relation between statements. Edit prose, not content.

**4. Re-scan — this is the gate.**

Run `slop_report.py` again on the edited file. **PASS** when every genuine flag
from step 2 is either removed by a disciplined edit, a deliberately held vivid
line (name which, and why), or an exempt domain term — **and** the edits
introduced no new flags — **and** meaning is intact.

`slop_index == 0` is **not** a pass condition. Do not chase the index to zero:
that rewards synonym-swapping and flattening. A held vivid word leaving a nonzero
index is the correct outcome. At most **three rounds**; if something cannot be
fixed without harming the prose, hold it and say so.

**5. Meaning check, then hand off.** Diff the output against the source and
confirm no fact, number or name drifted. Report: the output path, what you cut,
what you deliberately held and why, and the before/after slop headline.

## MLA style for all output

- Em-dashes closed and unspaced; prefer replacing (step 1).
- One space after sentence-ending punctuation.
- Spell out numbers writable in one or two words (`twenty-seven`, `two thousand`);
  numerals for the rest and with units. Restore digit forms a paraphrase
  introduced (`450` → `four hundred fifty`) — but never change the numeric value.
- Double quotes for quotations, single for nested, straight and consistent.

## Never

- Never regenerate, paraphrase or rewrite the whole text. Edit flagged spans only.
- Never swap a charged word for another charged word; never alter facts, numbers,
  names or values.
- Never commit output derived from private text.

## Attribution

The scan reuses public research data, redistributed under the licenses below. See
`toolkit/NOTICE.md` for the full list.

- EQ-Bench slop lists and slop-index formula — Sam Paech, MIT.
- Over-represented words and phrases — `slop-forensics` (MIT) / `antislop-sampler`
  (Apache-2.0), Sam Paech.
- Academic AI-overused vocabulary — Reinhart et al., PNAS 2025
  ([arXiv:2410.16107](https://arxiv.org/abs/2410.16107)); Juzek, COLING 2025.
- `top2000_en.json` — common-word frequency list via `wordfreq` (Apache-2.0).
