# Humanizer patterns: deterministic checks and editorial judgment

The local `/humanize` already detects "Imagine this:" and "The practical test:"
from the preceding change. Blader's humanizer 3.1.0 does not name "Imagine this"
explicitly; its staged-run-up category covers the same editorial problem.

This extension adds read-only Python checks for selected stock openers and
closers, negative contrast frames, and chatbot wrappers. The skill asks the
editor to resolve every finding through a surgical edit or an explained hold.
The scanner does not automatically rewrite prose or classify its author.

## What belongs in Python

| Pattern or task | Deterministic work | Agent judgment | Status here |
| --- | --- | --- | --- |
| Stock scene invitations and announced questions | Find bounded phrase shapes and report source lines | Decide whether the setup adds perspective or useful context | Existing construction checks |
| Stock openers and closers | Find selected phrases such as “Let's break this down” and “Read that again” | Remove empty staging; retain actual instructions and voice | Added |
| Negative contrast formulas | Recognize bounded “not X but Y” and paired “This isn't X. It's Y” forms | Distinguish useful corrections from ornamental framing; preserve facts | Expanded with new checks |
| Chat wrappers | Find selected praise, closings, offers to continue, and AI-model self-references | Distinguish accidental wrappers from real correspondence, quoted speech, or a fictional narrator | Added |
| Vocabulary, repeated openings, triplets, hedges and participial chains | Count occurrences and report density/locations | Decide whether repetition, uncertainty, or rhythm is intentional | Existing partial coverage |
| Punctuation and spacing | Apply configured style rules outside protected syntax when unambiguous | Resolve clause relationships and deliberate punctuation | Existing normalizer; no new rewrite rules |
| Bold, headings, emojis and tables | Count/layout checks against an explicit format profile | Decide whether formatting helps readers | Wikipedia conventions are not imported as global bans |
| Inflated importance, vague attribution, empty analysis, redundancy and wrong audience | Locate some lexical cues and exact repetitions | Read the argument and context; retain nuance and meaning | Existing cues plus editorial review |
| Citations and source claims | Validate identifier syntax/checksums; optionally resolve a URL or identifier | Verify that the source actually supports the claim; handle unavailable sources | Not implemented in this patch |

Mechanical detection does not make deletion mechanical. A contrast containing
two real facts should survive. A letter can reasonably end with “I hope this
helps.” A suspense scene can use short repeated sentences. A real uncertainty
must not become certainty to clear a flag.

For a future automated completion gate, require every finding to have an edit
or a reasoned hold tied to the final text. Do not fail solely because a watched
word remains or a lexical score is nonzero. `slop_report.py` remains a read-only
reporting CLI; this patch does not introduce a new nonzero exit-code policy.

## Source boundaries

Wikipedia describes its list as observations, not prescriptive rules, and
notes that some signals are specific to Wikipedia. Markdown is normal in our
README files; promotional language can be appropriate in an advertisement;
fiction does not need an encyclopedia's neutral register. A working citation
also does not prove that the cited page supports a claim.

The project page's focus on factual reliability is useful: prose cleanup must
not conceal unsupported claims by merely removing conspicuous wording. The
agent must check meaning and evidence when the task supplies or requires sources.
No network source validation was added to the scanner.

Sources inspected on 2026-10-27:

- [blader/humanizer 3.1.0, pinned source](https://github.com/blader/humanizer/blob/8c307f367c91bd974002f10f2be2965d642c13df/SKILL.md).
  Selected patterns are adapted locally; its MIT notice is included in the toolkit.
- [Wikipedia:Signs of AI writing, inspected revision](https://en.wikipedia.org/w/index.php?title=Wikipedia:Signs_of_AI_writing&oldid=1382015304).
- [Wikipedia:WikiProject AI Cleanup, inspected revision](https://en.wikipedia.org/w/index.php?title=Wikipedia:WikiProject_AI_Cleanup&oldid=1382243356).

## Evaluation

The [preregistered gates](2026-10-27-humanizer-python-PREREG.md) separate
recognition of a phrase shape from judgment about its usefulness. The baseline
is the local skill after the earlier “Imagine this” update, not the released
2.49.0 plugin. Exact before/after source hashes are saved with the evidence.

### Deterministic recognition

The initial set had 55 examples. Twelve exploratory boundary cases were added
after review. The final set has 35 positive shape examples and 32 negative
controls. Positive means **a declared shape requiring context review**, including
some legitimate contrasts; it does not mean bad prose or AI authorship.

| Dedicated new group | TP | TN | FP | FN | Recall | Specificity | Accuracy | Precision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline, no dedicated group | 0 | 32 | 0 | 35 | 0.0000 | 1.0000 | 0.4776 | n/a |
| Final candidate | 35 | 32 | 0 | 0 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |

This measures coverage of the new group, not total recall of every older check.
All existing report sections and scores remain byte-identical across the 67 new
cases and the preceding 63-case regression set after removing only the new group.

### Editing and preservation

Each arm used two fresh agents, each working from an isolated skill copy on six
complete passages. Three tasks are nonfiction: product copy, a technical
reference, and a support email. Three are fiction: suspense narration, a
first-person literary voice, and a scene containing a quoted letter. Agents
received genre context but no expected answers or access to other arms.

| Genre | Baseline outcomes | Final outcomes | Baseline preservation | Final preservation |
| --- | ---: | ---: | ---: | ---: |
| Nonfiction | 6/6 | 6/6 | 6/6 | 6/6 |
| Fiction | 6/6 | 6/6 | 6/6 | 6/6 |
| All | 12/12 | 12/12 | 12/12 | 12/12 |

The baseline agents already edited these passages correctly. This extension adds
reproducible detection; these results do not demonstrate better final prose than
the baseline. They show no observed regression on this set after repair.

Technical distinctions, actual offers and polite email closings remained. The
literary narrator retained deliberate repetition, a contrast expressing desire,
and an “Honestly?” aside. Quoted stock phrases retained their exact words;
quotation-mark normalization was permitted. Product and suspense copy lost
unnecessary setup while retaining facts, scene order and spoken dialogue.

One intermediate candidate edit converted ornamental framing into an unnecessary
assertion. The cleanup gate failed on that response. The final wording clarifies
that an editor should retain useful information, not repackage discarded framing.
Two new agents then repeated all six tasks from fresh directories. The failing
response is retained in the evidence and blind-grading packet. Interrupted earlier
runs and superseded candidate runs are excluded from final outcome counts.

### Independent grading

A separate fresh agent graded a shuffled packet without arm names or keys:
24 final study outputs, nine seeded answers, and the retained intermediate
failure. Seeds included missed cleanup, changed pricing, deleted attachments,
a stripped email closing, flattened narration, altered plot timing, advice
instead of an edit, and correct controls. The primary agent had reviewed every
output and fixed the keys before sending the packet.

All labels are agent-reviewed; there was no human-labeling study. **FAIL** is
the positive class. The calibrator's field named `human` contains the primary
reference key.

| Set | TP | TN | FP | FN | Recall | Specificity | Accuracy | Precision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Final study, 32 dimension judgments | 0 | 32 | 0 | 0 | n/a | 1.0000 | 1.0000 | n/a |
| Seeded answers, 14 dimension judgments | 8 | 6 | 0 | 0 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| Intermediate response, 2 dimension judgments | 1 | 1 | 0 | 0 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |

There were no grading disagreements. The judge separately confirmed that the
intermediate product edit failed cleanup while preserving the required facts.
The final-study recall is undefined because no final-study response failed;
the seeded failures provide the adverse cases for calibration. The small
calibration set does not establish broad judge reliability.

Complete inputs, outputs, rubrics, keys, judgments, counts and source hashes are
in the [machine-readable report](2026-10-27-humanizer-python.json). Raw local
artifacts are retained in `evals/results/humanizer-python-2026-10-27/`.

### Validation

Eight new regression tests pass. They exposed and fixed paragraph crossing,
contrasts fabricated across protected spans or separate Markdown blocks, and
missed closers inside emphasis. Independent review verified 76 targeted checks.
The final focused run completed 150 tests: 148 passed and two optional spaCy tests
skipped. The standalone export passed its embedded 119-test toolkit suite.

Coverage of the added/refactored detector functions is 28/28 executable
statements, including the shared protection helper. This is statement coverage,
not coverage of every possible regex input. Skill validation, skill lint,
whitespace checks and targeted Python lint pass; the unrelated pre-existing
F541 warning remains excluded from Python lint.

The preceding broad suite run had an unrelated plugin-validation failure caused
by a Claude CLI README-fallback warning; it was also reproduced at original
commit 208ecbc. This step reran focused tests and export, not the broad suite.
No full-suite success or release is claimed.

### Reproduce the detector eval

```bash
python3 evals/_lib/humanize-constructions.py \
  --toolkit skills/humanize/toolkit \
  --cases evals/_lib/humanizer-editorial-cases.json \
  --section 'EDITORIAL PATTERNS' --output /tmp/humanizer-editorial.json
python3 skills/eval/toolkit/calibrate.py /tmp/humanizer-editorial.labels.jsonl
bats tests/humanize-toolkit.bats tests/humanize-pipeline.bats tests/humanize-prepush-hook.bats tests/bats-assertions.bats
./scripts/export-humanize.sh
```

The six editing tasks and preservation requirements are saved in
[`../_lib/humanizer-editorial-tasks.json`](../_lib/humanizer-editorial-tasks.json).
This is a small synthetic regression set using one model family and two
repetitions per task. Tasks batched within an agent are not fully independent.
The in-session harness measures editing outcomes, not automatic skill selection.
Post-review cases and repeated development attempts are not an untouched holdout.

The canonical source and local symlinks are updated; cached plugins and public
releases are unchanged.
