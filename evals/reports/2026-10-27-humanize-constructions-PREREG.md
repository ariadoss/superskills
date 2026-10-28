# Humanize construction checks: preregistration

Baseline: superskills commit 208ecbc, copied before any skill or toolkit edit.
Question: can review-only construction flags catch stock setup phrases without
changing existing findings, scores, literal content, or the surgical-edit contract?

## Gates fixed before implementation

- Detector: all declared positive cases flagged; zero flags on declared negative
  controls. The positive class is needs editorial review, not AI authorship.
- Regression: all existing report sections byte-identical between arms for every
  detector case after removing the new section. Existing toolkit, pipeline,
  extraction, pre-push, and export tests pass with no new failures.
- Behavioral eval: three editing tasks (marketing copy, technical documentation,
  clean prose), two runs per arm with the original and updated complete skills.
  Remove unnecessary setup in the two affected tasks, preserve facts, quotes,
  code and legitimate hypothetical examples, and keep edits local. Candidate
  must pass every preservation check and remove all targeted setups. No failed
  baseline preservation check may be introduced by the candidate.
- Three implementation/review rounds maximum on the declared set. Any cases
  added after inspection are marked exploratory, not an untouched holdout.

## Sampling and labels

The deterministic set spans scene-setting, question/takeaway announcements,
conversational filler, casing, punctuation, Markdown, multi-line layout,
literal language, quoted language, and existing detector signals. Expected
labels are editorial judgments prepared by the agent, not human study labels.
Known problem phrases are development examples. This set is a regression eval,
not a claim of generalization to all AI-written prose.

Behavioral tasks use separate complete passages; no expected final answer is
shown to the editing model. Assess output and preservation, not exact phrasing.
The source remains unchanged; Markdown output is a separate humanized file.
Grading uses the complete returned copy, the saved file, and manual transcript
review. Any LLM judge is checked against independently reviewed labels, including
deliberately incomplete, over-edited and meaning-changing answers.

Report counts, recall, specificity, accuracy and precision together. A zero
lexical slop score is not a pass for constructions. These are writing-review
signals, not an AI-authorship detector. No public release or cache edit is part
of this evaluation.

## Harness substitution before implementation

The requested Claude plugin behavioral run produced six session-limit errors
and no graded runs (zero evidence about behavior). Use two independent in-session
agents per arm, each completing the same three tasks with an isolated copy of
the applicable skill. This evaluates editing outcomes, not skill selection.
All original gates and cases remain fixed. Batching three tasks per agent and
using one model family limits independence; report that limitation. Preserve
the failed CLI result separately rather than counting it as skill failure.

## User-requested genre coverage, before implementation

Add two fiction tasks per repetition in both arms: an editing case with empty
question/filler labels embedded in a scene, and a clean second-person story
with an imaginative premise, narrator voice, dialogue and a suspense question.
That makes five tasks per repetition and twenty outputs across two arms.
Preservation gates must pass separately for fiction and nonfiction; improvement
in one cannot compensate for damage in the other. Add detector controls for
fictional dialogue, literal uses, concrete imagined scenes, and direct narrative
questions. Exact-trigger imaginative exercises or narrator invitations can be
review flags with a justified hold; genre alone is not proof of bad writing.

Run classifiers from each actual task directory using relative draft.md. An
initial baseline repetition classified absolute paths under evals as excluded;
that is a harness-scope error, not an editing outcome. Preserve the diagnostic
and rerun with the same task-local cwd in both arms.

## Exploratory quote stress cases after independent review

The reviewer found false positives inside wrapped quotations, single-quoted
dialogue containing contractions, and lazy Markdown blockquote continuations.
Add five detector controls and two unit tests for this failure class. These
are post-review regression cases, not an untouched holdout. Add a sixth editing
task, a fiction letter containing these quotation forms, to both baseline
repetitions. Rerun both candidate repetitions with the final quote repair and
all six tasks. Keep the original twenty-output study as an intermediate result;
the final comparison has twenty-four outputs. All preservation gates still
apply separately to fiction and nonfiction.
