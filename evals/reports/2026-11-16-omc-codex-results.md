# OMC ideas: Codex behavior results (2026-11-16)

Four ideas from Oh My Claude Code were adapted in our own words: requirements
interview, reusable-skill extraction, a feedback baseline and handoff contract
for subagent development, and requirements intake before planning. No OMC
runtime or source was vendored.

The original Sonnet run stopped at a subscription limit. This report applies
the registered gates to a separate Codex replication using `gpt-6-sol` at
medium effort. The attempted `gpt-6.1-sol` launches returned deployment 404
before producing output and were excluded. No score mixes models. The exact
prompts, fixtures, thresholds, and protocol are in the three
`2026-11-15-omc-*-PREREG.md` files and
`2026-11-16-omc-codex-PREREG.md`. Runs used fresh scratch repositories, at
most two agents concurrently. The final replies and artifacts remain under
`/tmp/omc-eval/codex-runs/` in this workspace.

## Gate decisions

| Idea and case | Before | After | Registered gate | Decision |
|---|---:|---:|---|---|
| `/skillify`: reject README-level trivia | 1/3 | 3/3 | After ≥2/3; before ≤1/3 expected | Keep |
| `/skillify`: hard-won procedure, two turns | 0/3 | 3/3 human; 2/3 script | After ≥2/3 | Keep |
| SDD: record pre-existing red feedback | 0/3 | 3/3 | After ≥2/3; before ≤1/3 | Keep |
| SDD: Task-2 handoff and assumptions contract | 0/3 | 3/3 | After ≥2/3 | Keep |
| SDD: green repo, no invented baseline | — | 3/3 | After ≥2/3 | Keep |
| `/write-plan`: vague one-shot, assumptions in reply | 0/3 | 0/3 first wording; **3/3** revised | After ≥2/3; before ≤1/3 | Keep revised wording |
| `/write-plan`: interactive interview offer | 0/3 | 2/3 | After ≥2/3 | Keep |
| `/write-plan`: clear spec, direct plan | 3/3 | 3/3 | Both ≥2/3 | No regression |
| `/deep-interview`: one weakest-point question and pending spec | — | 0/3 first wording; 1/3 second; **3/3** third, human | After ≥2/3 and clear-spec guard | Keep third wording |

The hard-won `/skillify` case used the two-turn correction registered before
Codex runs: the agent proposed a name and location, then received “Yes. Use
the proposed name and project location.” All three after-arm runs waited for
that confirmation and produced a substantive skill. All three before-arm runs
wrote a skill before confirmation. On the trivial case, two before-arm runs
created a low-value skill; all after-arm runs declined and named a better home.

SDD runs exercised setup and Task-2 dispatch composition, not actual task
implementation. The red fixture had one known failing test. Every after-arm
red run recorded its ID and referred to it as pre-existing. The Task-2
dispatches named `task-1-handoff.md`, omitted the full Task-1 report, and
required assumptions. All green runs omitted the baseline. This also exposed
a real script defect: `feedback-baseline.sh check` previously returned success
when no baseline file existed even if current failures were present. It now
treats every such failure as new, with Bats coverage.

The first `/write-plan` one-shot wording recorded assumptions in the saved
plan but omitted them from the requested reply. The registered second round
added a final-reply instruction; all three revised replies state concrete
assumptions, their basis, and reversibility. The interactive after-arm missed
once by asking three questions alongside its interview offer. The other two
offered once and did not conduct a full interview. All six clear-spec runs
planned directly, preserving the no-interview guard.

The first `/deep-interview` round asked one question and wrote a pending spec,
but its acceptance checkboxes did not begin with verifiable actions. The
second round fixed that syntax; two runs then asked about component location
or topology instead of the weakest dimension, success criteria. The third
round made missing code an open implementation question and let an already
named topology stand provisionally. All three first questions then asked how
to define signup success. Each run wrote one pending-approval spec with
checkable acceptance criteria and no unrelated file changes.

## Judge calibration and corrections

All figures below declare **FAIL as the positive class**. TPR measures
detected failures; TNR measures accepted good work. We hand-read the boundary
cases and negative controls, then compared them with the script labels.

| Grader | TP | TN | FP | FN | TPR | TNR | Accuracy | Precision | Bias |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `/skillify`, 12 labels | 5 | 6 | 1 | 0 | 1.000 | 0.857 | 0.917 | 0.833 | Harsh |
| SDD, 15 case labels | 6 | 9 | 0 | 0 | 1.000 | 1.000 | 1.000 | 1.000 | None |
| `/write-plan`, 21 labels after grader repair | 10 | 11 | 0 | 0 | 1.000 | 1.000 | 1.000 | 1.000 | None |
| `/deep-interview`, 9 labels across three rounds | 3 | 4 | 0 | 2 | 0.600 | 1.000 | 0.778 | 1.000 | Lenient |

The `/skillify` false positive is a good skill with a “Failure signatures”
section and an inline success criterion; the script expected headings named
“Pitfalls” and “Success criteria.” Human review supplies the adoption label.
The `/deep-interview` script checks the one-question and spec format contract
but cannot determine whether a question targets the weakest dimension. Its
two false negatives were second-round topology questions. The final 3/3
decision uses human labels, corroborated by the script's format checks.

Two grader faults were repaired under Bats tests before the affected final
counts were taken. The SDD grader selected a Task-2 brief ahead of the
dispatch file; it now selects the dispatch. The intake grader treated the
word “none” anywhere in an assumption as an empty marker, and missed inline
assumptions at end of file; it now recognizes only a standalone “none” and
accepts inline or next-line entries. The initial Q1 v2 script count was 2/3;
inspection found the third reply valid, and the repaired script reports 3/3.

## Limits

These are small synthetic samples with a directly supplied skill file, so
they measure behavior when the skill is loaded, not natural-language routing.
The unavailable Sonnet runs cannot establish transfer to that model. SDD's
live implementer handoff and the effect of the resulting plans on shipped
software remain untested. The original, unmodified first-round scores and
the wording-repair preregistrations are retained to make that iteration
visible.

After the registered runs, the final SDD text gained a pointer to
`ENGINEERING_STANDARDS.md`, required for code-producing skills in this repo.
One supplemental Codex red-fixture run on that exact file passed both the
baseline and dispatch checks. It is a smoke check, excluded from the table and
calibration counts above.
