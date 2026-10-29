# humanize

Strip AI slop out of prose **without flattening the author's voice**.

Use it for reader-facing documentation, help content, and visible UI copy.
Internal prompts, agent instructions, plans, and code comments are out of scope.
For UI strings in source files, edit the visible strings directly; the Markdown
normalizer and scanner must not run on source code.

Deterministic em-dash and spacing fixes, a ~45-check slop scan with line numbers,
then surgical subtractive edits that an agent following [`SKILL.md`](SKILL.md)
applies itself, gated by a re-scan.

```
slop_index = 33.3  [word 1, bigram 0, trigram 0]   |   legacy_slop_index = 206.9
complexity_index = 89.7  (FK grade 11.1; vocab-maxxing if high)

— EQ-BENCH SLOP WORDS: 1  (tapestry×1)
    L1: [tapestry]  Our platform is a tapestry of tools that helps teams delve into their data and navigate an ever-e...
— AI-OVERUSED VOCAB (delve, intricate, underscore…; curated + research): 4  (delve×1, navigate×1, evolving×1, seamless×1)
      high-confidence core among them: delve, seamless
```

## What this is not

**It will not help anything pass AI detectors.** A frontier model editing
prose re-stamps the AI fingerprint, and deterministic tweaks do not move real
detectors. This is a *prose-quality* tool: it finds genuine AI tells so a human can
cut them. If your goal is detector evasion, this is the wrong repo.

It also never calls an LLM paraphraser and never calls a paid detector API.

## Install

As a Python package (the distribution is `humanize-toolkit`, the import name is
`humanize_toolkit`; plain `humanize` on PyPI is an unrelated library). Pin a release
tag so upgrades are deliberate:

```bash
pip install https://github.com/ariadoss/humanize/archive/refs/tags/v0.1.0.tar.gz
```

That installs the library, every word list, and a `humanize-scan` command. As a
checkout, for the agent skill or for hacking on it:

```bash
git clone https://github.com/ariadoss/humanize
cd humanize
```

Python 3 standard library is enough. Two optional packages improve results and
degrade cleanly when absent:

```bash
pip install spacy && python3 -m spacy download en_core_web_sm   # recommended
pip install nltk                                                # optional
```

| Optional | Used for | Without it |
|---|---|---|
| `spacy` + `en_core_web_sm` | telling an independent clause from an appositive, so a dash becomes a period rather than a comma splice | undecidable dashes are **kept** and reported on stderr; expansions still become colons |
| `nltk` | better tokenizing and CMU-dict syllable counts | regex tokenizer and a syllable heuristic |

With `nltk` installed, the scorer downloads the `punkt` tokenizer once, quietly, on
first use.

## Use it as a library

```python
import humanize_toolkit as ht

ht.slop_index(text)        # {"slop_index": 33.3, "word_hits": ..., ...}
ht.scan(text)              # the full line-numbered report, as a string
ht.normalize(text)         # em-dash and spacing fixes in one call
ht.fix_dashes(text)        # dashes only
ht.format_spacing(text)    # spacing only
ht.complexity_index(text)  # Flesch-Kincaid grade and a 0-100 complexity score
ht.classify("docs/a.html") # markdown | text | html | template | locale | source | none
```

Importing the package loads nothing heavy, writes no files and never touches
`sys.path`. Each function imports its module on first use. `scan` runs the report
in a child interpreter, so it is safe from threads and from apps that own stdout.
Command line, installed:

```bash
humanize-scan draft.md [--exempt terms.txt]
python -m humanize_toolkit.slop_report draft.md
python -m humanize_toolkit.normalize draft.md draft_humanized.md
```

## Use it

```bash
# 1. deterministic fixes (never overwrites the source)
python3 toolkit/normalize.py draft.md draft_humanized.md

# 2. scan
python3 toolkit/slop_report.py draft_humanized.md [--exempt terms.txt]

# 3. edit the flagged spans, subtractively, then re-scan as a gate
```

Not only Markdown. `userfacing.py` decides what counts as user-facing copy and
pulls out just that text, with the source file's line numbers, so the same scan
works on a landing page, a locale file, or a component:

```bash
python3 toolkit/userfacing.py classify site/pricing.html   # markdown | text | html | template | locale | source | none
python3 toolkit/userfacing.py extract  site/pricing.html > copy.txt
python3 toolkit/slop_report.py copy.txt
```

It covers READMEs and docs, blog posts, HTML, template engines (Blade, ERB,
Twig, Liquid, Jinja, Handlebars, Go templates), locale files (`json`, `yaml`,
`po`, `properties`), components (`jsx`, `tsx`, `vue`, `svelte`, `astro`), and the
copy that Go, Rust, PHP, Python, Node, TypeScript, Ruby and Java generators write
into pages and files. Code logic, comments, log text, prompts, agent
instructions, tests and vendored trees classify as `none` and are never scanned. Only Markdown and text go
through `normalize.py`; other types are edited in place at the flagged spans.

`--exempt` takes an allowlist, one token per line, for product names and terms of art
so the scan leaves legitimate vocabulary alone. See
[`toolkit/exempt_example.txt`](toolkit/exempt_example.txt).

## The editing discipline

The scan measures; the edits are surgical, one flagged span at a time, never a
whole-text rewrite. In order:

1. **Delete** filler adverbs, rhetorical scaffolding, redundant restatement. Biggest win.
2. **Compress** only where meaning and temperature survive.
3. **Hold**: a flagged line that is vivid, specific and reads aloud well stays. A flag is a reason to look, not a mandate to change.
4. **Substitute only as a last resort**, and only for something strictly plainer with the same meaning. **Never swap one charged word for another to clear a flag** (`delve`→`dig into`). That flattens voice, and it is exactly what the scanner would reward.
5. **Normalize punctuation last.**

Never change a fact, number, name, date, or the logical relation between statements.

**`slop_index == 0` is not the goal.** Chasing the index to zero rewards
synonym-swapping. A held vivid word leaving a nonzero index is the correct outcome.

## Use it with an agent

[`SKILL.md`](SKILL.md) is an [agent skill](https://code.claude.com/docs/en/skills):
drop this directory into `~/.claude/skills/humanize/` (or install
[superskills](https://github.com/ariadoss/superskills), which ships it) and ask your
agent to humanize a file. The agent runs the fixes and the scan, applies the
surgical edits itself without asking, and re-scans. The three-round gate and the
hold-vivid rule are built in.

## Releasing (maintainers)

This repo is generated. The source of truth is the `skills/humanize/` folder in
[superskills](https://github.com/ariadoss/superskills); never edit it here.

1. In superskills, bump `__version__` in `skills/humanize/toolkit/__init__.py`. It is the only place the version lives; `pyproject.toml` reads it.
2. Run `scripts/export-humanize.sh`. It refuses to finish unless the exported tree passes its tests.
3. Commit the exported tree in this repo, then tag it: `git tag vX.Y.Z && git push origin main vX.Y.Z`.
4. Consumers pin the tag tarball, `https://github.com/ariadoss/humanize/archive/refs/tags/vX.Y.Z.tar.gz`, and bump the pin when they choose to.

Build check: `python -m build` produces a wheel and an sdist. Both carry every
JSON word list, `LICENSE` and `NOTICE.md`.

## Tests

```bash
bats tests/humanize-toolkit.bats
```

They are packaging tests as much as unit tests: the scripts are only useful if
every data file they load travelled with them, and two failure modes are silent. A missing phrase-probability table makes the legacy index read `0.0` rather than
"unavailable", and spaCy's absence used to raise `ModuleNotFoundError` mid-file.

## Attribution

Scripts are MIT (see [LICENSE](LICENSE)); wheels and sdists carry both files. The research data is third-party and
redistributed under its own terms; see [NOTICE.md](NOTICE.md). In short: EQ-Bench
slop lists and slop-index formulas and `slop-forensics` (MIT) and
`antislop-sampler` (Apache-2.0), all by [Sam Paech](https://github.com/sam-paech);
academic AI-overused vocabulary from Reinhart et al. (PNAS 2025,
[arXiv:2410.16107](https://arxiv.org/abs/2410.16107)) and Juzek (COLING 2025); and a
common-word frequency list via [`wordfreq`](https://github.com/rspeer/wordfreq)
(Apache-2.0).

If you redistribute this, keep `NOTICE.md`. Apache-2.0 requires it.
