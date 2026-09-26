# humanize

Strip AI slop out of prose **without flattening the author's voice**.

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

## Use it

```bash
# 1. deterministic fixes (never overwrites the source)
python3 toolkit/normalize.py draft.md draft_humanized.md

# 2. scan
python3 toolkit/slop_report.py draft_humanized.md [--exempt terms.txt]

# 3. edit the flagged spans, subtractively, then re-scan as a gate
```

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

## Tests

```bash
bats tests/humanize-toolkit.bats
```

They are packaging tests as much as unit tests: the scripts are only useful if
every data file they load travelled with them, and two failure modes are silent. A missing phrase-probability table makes the legacy index read `0.0` rather than
"unavailable", and spaCy's absence used to raise `ModuleNotFoundError` mid-file.

## Attribution

Scripts are MIT (see [LICENSE](LICENSE)). The research data is third-party and
redistributed under its own terms; see [NOTICE.md](NOTICE.md). In short: EQ-Bench
slop lists and slop-index formulas and `slop-forensics` (MIT) and
`antislop-sampler` (Apache-2.0), all by [Sam Paech](https://github.com/sam-paech);
academic AI-overused vocabulary from Reinhart et al. (PNAS 2025,
[arXiv:2410.16107](https://arxiv.org/abs/2410.16107)) and Juzek (COLING 2025); and a
common-word frequency list via [`wordfreq`](https://github.com/rspeer/wordfreq)
(Apache-2.0).

If you redistribute this, keep `NOTICE.md`. Apache-2.0 requires it.
