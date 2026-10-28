---
name: humanize
description: |
  Prose-quality cleanup for text real users read: READMEs and docs, blog
  posts, marketing pages, templates, locale strings, UI text, and copy that
  code generates, in any language or file type (md, html, Blade/ERB/Liquid,
  json/yaml/po, jsx/vue/svelte, Go/Rust/PHP/Python/Node generators), keeping
  the author's voice. Markdown gets deterministic punctuation fixes; every
  type gets a slop scan, surgical edits, and a re-scan. Use when asked to
  "humanize" or "remove AI slop" from user-facing text. Do not invoke for
  code logic, code comments, log text, prompts, or agent instructions.
  Preserve facts.
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

## Scope

Use this skill on language people read: READMEs and documentation, blog
posts, marketing pages and copy, help text, email or notification text,
locale strings, visible UI labels and messages, and the pages or files that
code generates for people to read. It is by content, not extension: a
landing page is in scope as `.html`, `.mdx`, `.vue`, a `.liquid` or `.blade.php`
template, a string in `locales/en.json`, or the HTML a Go, Rust, PHP, Python
or Node generator writes out.

Out of scope, whatever the extension: code logic, code comments, log and
error text, prompts, agent instructions (`SKILL.md`, `AGENTS.md`, `CLAUDE.md`,
`prompts/`), tests and fixtures, and vendored or generated trees
(`node_modules`, `vendor`, `target`, `dist`, `build`). A README is always in
scope, even inside a `tests/` folder. Past changelog entries are history:
scan them, but edit only text the change adds.
Internal prompts, agent instructions, plans, and code comments are out of scope.
Technical wording in those files serves an operational purpose; style cleanup
can change instructions or obscure meaning.

The toolkit decides this in one place. Ask it, never guess from the extension:

```bash
python3 "$TOOLKIT/userfacing.py" classify <path>   # markdown | text | html | template | locale | source | none
python3 "$TOOLKIT/userfacing.py" extract  <path>   # the copy only, same line numbers as the file
```

`none` means leave the file alone. What each type yields:

| type | files | what is scanned |
|---|---|---|
| `markdown`, `text` | `.md .mdx .markdown .txt .rst .adoc` | prose; code fences, inline code, link targets, comments and front matter are dropped except copy keys (`title`, `description`, `summary`, ...) |
| `html`, `template` | `.html .htm`, Blade, ERB, Twig, Liquid, Jinja, Handlebars, Nunjucks, EJS, Go templates | text nodes and `alt`/`title`/`placeholder`/meta description; tags, `<script>`/`<style>`/`<code>`, template logic and comments are dropped; sentence-like strings inside translation calls such as `{{ __('...') }}` are kept |
| `locale` | `.json .yaml .yml` under `locales/`, `i18n/`, `lang/`, `translations/` and the like or named `en.json`; `.po .pot .properties .strings .arb` | message values only, never keys |
| `source` (components) | `.jsx .tsx .vue .svelte .astro` | JSX and template text, sentence-like string literals |
| `source` (generators) | `.go .rs .php .py .rb .js .ts .java .kt .swift .cs` and the like, **only** when the file visibly renders pages or writes files (HTML in strings, `WriteFile`, `render_template`, `res.send`, `echo`, ...) | string literals of four or more words in sentence shape; comments, docstrings, log/print/panic/raise text, SQL and imports are excluded; PHP also scans the HTML outside `<?php ?>` |

Extraction is conservative by design: short labels and one-word strings are
not scanned from code. A code file with no output signal is `none`. Symlinks
and files over 512KB are never read and are not reported; strings assigned to
a prompt or instruction name are never copy.

**Markdown and plain text** (`markdown`, `text`) run the whole workflow below.
**Every other type** must never go through `normalize.py`: it would corrupt
markup, JSON or source. For these, use Step 2 on the extraction
(`extract <path> > <scratch>.txt`, then `slop_report.py <scratch>.txt`; line
numbers match the source), then apply Step 3 as surgical Edit calls on the
**source file's** string or text span only, preserving interpolation, markup
and syntax. Re-scan the extraction as the Step 4 gate and run the project's
tests or build. Skip Step 1.

For Markdown runs, `TOOLKIT` below means the `toolkit/` directory inside this skill's own directory.
The host prints that directory when the skill loads (Claude Code: "Base directory
for this skill: …") — use it. Do **not** derive it from `$0`: in your shell that
names the shell, not this file. Confirm the path before running a toolkit command, so a
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

`<file> [exempt.txt]`

- `file` — the user-facing copy to clean. Markdown and text: write to
  `<dir>/<name>_humanized.md`. **Never overwrite the source** with the normalizer's
  output. Other types are edited in place at the flagged spans (see Scope). Output
  derived from private text must not be committed.
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

The **rhetorical scaffolding** group flags stock scene invitations, announced
questions or takeaways, and conversational filler. These are review candidates,
not proof of AI authorship or automatic deletions. They do not affect the
lexical `slop_index`, which can remain zero while constructions need editing.

The **editorial patterns** group checks selected stock openers and closers,
contrast formulas, and chatbot wrappers. A match records a shape, not a verdict:
preserve both claims in a real comparison, purposeful fictional rhythm or
reader address, and actual greetings, offers, or closings in correspondence.
When a contrast adds only emphasis, state its useful claim directly. Retain
the negative half only if it corrects a real misconception or carries useful
information; do not turn discarded framing into a new assertion.
Python detects the wording; you decide whether it serves the passage. Resolve
each finding by editing it or explaining the hold. Do not impose Wikipedia's
markup or neutral-register conventions on marketing, documentation, or fiction.

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

Also read for these construction roles when the scanner misses a variant:
an invitation to picture something before stating it, a label announcing the
next question or lesson, or a stock claim of candor before a plain assertion.
Flag unnecessary scaffolding during that read, then edit just that span. A
setup that adds nothing can usually be deleted while keeping its useful point.
Preserve concrete thought experiments, direct questions, literal uses,
quotations, code, and distinctive narrator or character voice. In fiction,
check whether a reader address or rhetorical question creates perspective,
suspense, or rhythm before changing it; retain it when that function matters.
Explain a hold rather than flattening the passage to clear a flag.

**Preserve meaning absolutely.** Never change a fact, number, name, date, or the
logical relation between statements. Edit prose, not content.

**4. Re-scan — this is the gate.**

Run `slop_report.py` again on the edited file. **PASS** when every genuine flag
from step 2 is either removed by a disciplined edit, a deliberately held vivid
line (name which, and why), or an exempt domain term — **and** the edits
introduced no new flags — **and** meaning is intact.

The scan and editorial read must cover the version being handed off. An earlier
draft's report does not validate a later adaptation or replacement paragraph.

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
- Selected editorial patterns — [blader/humanizer](https://github.com/blader/humanizer),
  MIT; source revision and license are recorded in `toolkit/NOTICE.md`.
