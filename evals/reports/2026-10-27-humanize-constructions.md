# Humanize: construction detection and preservation

The new checks surface stock introductions such as "imagine this," announced
questions such as "the practical test: can...", and filler such as "here's the
thing." They guide editorial review; they do not identify AI authorship or
automatically delete text.

Both fiction and nonfiction improved on the tested tasks, with no observed
content-preservation regressions. The skill now asks the editor to check the
function of a construction, preserve meaningful voice and examples, and review
the final draft even when the lexical score is zero.

## Detector eval

The final set contains 63 cases: 26 target setups and 37 controls. Fifty-eight
cases were fixed before implementation; five quotation controls were added
after independent review exposed a bug. Those five are exploratory regression
cases, not an untouched holdout.

Cases cover scene invitations, announced questions and lessons, conversational
filler, literal uses, quoted dialogue, Markdown code, emphasis, soft wraps,
direct questions, fictional imagery and older detector signals. The source
text and labels are in
[`../_lib/humanize-constructions.json`](../_lib/humanize-constructions.json).

The positive class is **needs construction review**, not **written by AI**.

| Arm | TP | TN | FP | FN | Recall | Specificity | Accuracy | Precision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Original, 208ecbc | 0 | 37 | 0 | 26 | 0.0000 | 1.0000 | 0.5873 | n/a |
| Updated | 26 | 37 | 0 | 0 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |

The runner measures the dedicated construction-review group; the original has
no such group. These numbers describe the new checks' coverage, not the overall
recall of every existing slop detector. Actual editing improvement is measured
separately below. Removing the new report section leaves all 63 original
reports, including lexical scores and other findings, byte-identical.

On the initial set, the updated detector flags both fictional narration setups
and none of the six fiction controls. It flags all 24 nonfiction setups and
none of the 26 other controls. All five added quotation controls remain unflagged
by the final detector.

## Editing outcomes

Two independent in-session agents used the original skill, and two used the
final updated skill. Each completed the same six tasks from an isolated
directory: billing copy, technical documentation, clean instructional prose,
fiction with empty labels, a second-person story, and a fictional letter with
wrapped quotations. Agents saw only their applicable skill and drafts, not the
expected answers or the other arm's output. Both candidate runs used the exact
final skill and scanner, verified by byte comparison and saved hashes.

An outcome passes when the required cleanup is complete and content is
preserved. Clean controls pass when useful language remains. Preservation
includes facts, uncertainty, quoted words, code, plot, viewpoint, imagery,
meaningful questions and scene order. A preservation failure in either genre
would fail the candidate; improvement in one cannot offset damage in the other.

| Genre | Original outcomes passing | Updated outcomes passing | Original preservation | Updated preservation |
| --- | ---: | ---: | ---: | ---: |
| Nonfiction | 2/6 | 6/6 | 6/6 | 6/6 |
| Fiction | 4/6 | 6/6 | 6/6 | 6/6 |
| All | 6/12 | 12/12 | 12/12 | 12/12 |

The original removed "here's the thing" in two affected passages but left the
scene invitation and announced questions. The updated skill removed all seven
unnecessary setups per repetition. Both versions left the clean instructional
prose and the second-person story unchanged in both repetitions. The fictional
letter retained every word and line break; only quotation-mark normalization
occurred in one original run and both updated runs, as allowed by the rubric.

In fiction, the updated version removed "The practical test:" but retained
"Could she reach the gate before the bell rang?" It also retained Mara's spoken
"Imagine this," her brass key, the seven-minute limit and the second key on the
guard's wrist. The other story kept its imagined city, second-person narration,
father's dialogue, rhetorical question and ending. The letter preserved stock
phrases inside dialogue and Markdown blockquotes, including wrapped lines and
contractions inside single-quoted speech.

In nonfiction, the update preserved the price, invoice schedule, export policy,
navigation, retry count, job number, code sample and quotations. The concrete
"Imagine two workers" example remained intact.

## Independent grading and calibration

The primary agent reviewed every diff and prepared binary keys. A separate
agent then graded a shuffled packet without arm names or keys. It included the
24 observed outputs and ten seeded answers: correct edits, missed setups,
advice without an edit, changed pricing, altered code, lost uncertainty and
flattened fictional voice. No seeded answer was supplied to an editing agent.

The labels below are agent-reviewed, not labels collected from a human study.
For grading, **FAIL** is the positive class. The calibration tool's field named
`human` contains the agent-reviewed reference label.

| Set | TP | TN | FP | FN | Recall | Specificity | Accuracy | Precision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Observed outputs, 36 dimension judgments | 6 | 30 | 0 | 0 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| Seeded answers, 18 dimension judgments | 7 | 10 | 1 | 0 | 1.0000 | 0.9091 | 0.9444 | 0.8750 |

The one calibration disagreement concerns overlapping dimensions. A seeded
fiction answer changed uncertainty into certainty. The primary key failed it
for preservation; the blind judge also failed its cleanup dimension because
that rubric says to preserve the underlying information. Both rejected the
answer overall. The initial labels and disagreement are retained. There were
no disagreements on the 24 observed outputs.

## Validation and reproducibility

Nine regression tests were added. The first six failed before implementation
and passed after. A seventh, literal-only/no-final-newline test exposed an
indexing error during implementation; it was fixed before the initial candidate
editing runs. Independent review then found quotation handling gaps. Two more
failing tests covered wrapped quotations, quoted contractions and lazy Markdown
blockquote continuation. After repair, all nine tests and the reviewer's 14
targeted assertions passed. The final function has 22 covered executable
statements out of 22; this is statement coverage, not proof of all regex paths.

The original toolkit completed 102 tests with no failures and two optional
spaCy skips. The final toolkit has 111 tests with the same two skips and no
failures. The final focused run across toolkit, pipeline and pre-push tests
completed 140 tests: 138 passed and two optional spaCy tests skipped. The
standalone export also passed its embedded toolkit suite on the final source.
Skill validation, repository skill lint, shell syntax checks and diff whitespace
checks pass. Targeted Python lint adds no findings; the original and updated
files share one pre-existing F541 warning outside the changed code.

The broad repository suite ran 793 tests before the final quotation repair.
It initially reported two plugin-validation failures involving untracked Finder
metadata. After those two metadata files were moved outside the checkout,
rerunning plugin validation left one failure: the test rejects a Claude CLI
informational warning about the marketing plugin inheriting the root README.
That same failure was reproduced in a clean worktree at original commit 208ecbc.
The focused humanize suite and standalone export were rerun after the final
repair. Full repository-suite success is not claimed.

Inputs, complete outputs, rubrics, keys, blind judgments, validation summaries
and exact skill/scanner hashes:
[`2026-10-27-humanize-constructions.json`](2026-10-27-humanize-constructions.json).
Design and gates:
[`2026-10-27-humanize-constructions-PREREG.md`](2026-10-27-humanize-constructions-PREREG.md).
Raw local run artifacts are retained under the ignored directory
`evals/results/humanize-constructions-2026-10-27/`.

```bash
python3 evals/_lib/humanize-constructions.py \
  --toolkit skills/humanize/toolkit --output /tmp/humanize-detector.json
python3 skills/eval/toolkit/calibrate.py /tmp/humanize-detector.labels.jsonl
bats tests/humanize-toolkit.bats tests/humanize-pipeline.bats tests/humanize-prepush-hook.bats
./tests/run.sh
./scripts/export-humanize.sh
```

Six `humanize-rhetoric-*` cases are also saved for `claude plugin eval`. The
attempted Claude run hit its session limit before any grading and is excluded
from all outcome counts. The in-session runs replaced it. One initial local
repetition used absolute paths under evals and reached the classifier's scope
exclusion; that harness error was preserved and rerun from each task directory.
The initial five-task candidate runs are retained as intermediate evidence;
the reported comparison uses all six tasks and the final repaired candidate.

These are small synthetic regression sets, with two repetitions per task and
one session model family. Batched tasks are not fully independent. The results
support this update on these cases; they do not prove that every possible
construction will be caught or every writing style preserved.

The canonical source and locally linked skill are updated. The cached 2.49.0
plugin and public releases are unchanged.
