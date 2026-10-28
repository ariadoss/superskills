# Humanizer patterns in Python: evaluation plan

Baseline is the local humanize state after the earlier construction eval, before
this extension; exact hashes are saved with results. Compare the same complete
skill before and after adding protected, read-only editorial checks. Sources:
blader/humanizer 8c307f367c91bd974002f10f2be2965d642c13df and Wikipedia's Signs
of AI writing, retrieved 2026-10-27. These are editorial signals, not an
AI-authorship classifier. Wikipedia's guidance is descriptive and context-bound.

## Gates declared before implementation

- Detect the declared stock opener/closer, contrast-frame and chat-wrapper
  shapes. Positive class: shape requiring contextual editorial review. A real
  contrast may match and must then be retained when meaning requires it.
- Zero new findings on declared literal/code/quotation and near-miss controls.
- Every existing report section and score remains byte-identical on the previous
  63-case set and the new set after stripping only the new report group.
- Existing toolkit tests, focused pipeline tests and standalone export have no
  new failures. New paths have regression tests; target >=90% statement coverage
  of added/refactored helper functions.
- Six complete editing tasks, two independent agents per arm, split equally
  between fiction and nonfiction. Required cleanup passes; all preservation
  checks pass in each genre. No regression can be offset by another genre.
- A separate blind grader sees shuffled outputs and the rubric, never arm names
  or primary keys. Calibrate with deliberate bad edits as well as actual outputs.
- At most three repair rounds. Any cases added after results are exploratory.

The dataset includes purposeful literary repetition/contrast, actual support
correspondence, technical limitations, uncertainty, quoted stock phrasing, and
prose with empty setup. Keep future source-validation, spelling/style preferences,
and Wikipedia-specific markup conventions out of this patch. No phrase rewrites
or automatic content deletions are introduced.

Labels are agent-reviewed, not human study data. Two repetitions per task and
one model family limit generalization; report raw counts per genre. The previous
study used the in-session harness after Claude plugin eval hit a session limit;
reuse that harness rather than claim testing of automatic skill selection.

## Post-review boundary cases

The initial set had 55 cases: 29 shapes and 26 controls. Independent review
found false contrasts spanning removed protected text or different Markdown
blocks, and missed closers wrapped in emphasis. Add six boundary controls and
six positive variants as exploratory regressions. Retain the initial results.
Two unit tests fail before repair; rerun both editing repetitions against a
fresh final snapshot after repair. Interrupted earlier candidate tasks are
intermediate runs and excluded from final outcome counts.

## Final wording repair after behavioral review

One of the two candidate product edits replaced an ornamental negative contrast
with a positive assertion retaining its empty framing. The required cleanup gate
failed on that run. Keep its complete output as intermediate evidence and as a
blind-grading check. Clarify the general distinction between useful information
and ornamental framing without adding the fixture or its answer to the skill.
Rerun both candidate repetitions on all six unchanged tasks. This is the third
repair round (paragraph boundary, reviewed parsing boundaries, editorial meaning).
No further tuning is part of this run.
