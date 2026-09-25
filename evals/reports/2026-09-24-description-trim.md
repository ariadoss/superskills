# Description-trim audit and in-session eval (2026-09-24)

Prompted by an external "harness token efficiency" prompt. Most of it targets
harness internals superskills does not own; the parts that apply are skill
descriptions (sent on every turn) and SKILL.md bodies (loaded on invocation).

## Method

In-session Sonnet `general-purpose` subagents (covered by plan; `claude plugin
eval` is off the table per the no-Claude-credits rule). Same prompts before and
after the edit. Graded from each subagent's JSONL transcript: which skill fired,
whether the skill's content was used (Read of its SKILL.md, or `doctor.sh`),
whether the final reply named the skill, and read-only safety. Doctor cases ran
against `evals/_lib/doctor-fixture.sh` fixtures. Marketing cases could not run
in-session (marketing plugin not installed) and were out of edit scope.
Routing cases ran in this repo with a dry-run prefix; the repo has no target
code (no Dockerfile, form, parser, landing page), so they measure recognition,
not invocation.

## Cost baseline

- Installed pack descriptions: 7,586 chars, about 1,900 tokens per turn, cached.
- A subagent turn is about 43k prompt tokens, so descriptions are about 4%.
- Heaviest per-invocation load: `qa-full` (5,502 words) plus the gstack bodies it
  loads inline: review 10,369, qa 8,702, design-review 18,805 words.

## Edits kept (later reverted)

Update, same day: all five trims were reverted. The saving is about 0.6% of a
turn, cached, and the routing test could not exercise the dropped trigger
phrases; commit 3760c28 shows an earlier trim round already caused misrouting.


Trimmed descriptions: qa-full 625->442, clean-code 631->383,
test-coverage 616->357, iac-scan 542->393, a11y 487->348 chars.
Total 2,901 -> 1,923 chars, about 245 cached tokens per turn (about 0.6% of a turn).

## Edit reverted

superskills-doctor description (lowercased "WITHOUT", one dash to a period).

## Pass criterion (written before editing)

Method: in-session Sonnet general-purpose subagents, same prompts, before vs after.
Keep the edits only if ALL hold, pooled per group:
1. Doctor (12 runs): count(invoked) + count(content-used) after >= before (before = 6: 4 invoked + 2 content-used).
   Invoked-only after >= before - 1 (noise allowance of one run at n=12).
2. Doctor content (12 runs): no-false-ready, domain-correct, names-the-fact graders pass 12/12 (before: 12/12).
   Read-only: no mutating Bash command (./setup, git pull/reset/clone, installs) in any run (before: 0).
3. Upgrade (3 runs): upgrade invoked-or-content-used after >= before (3/3); doctor never fires.
4. Off-topic (3 runs): no skill fires (before 3/3 quiet).
5. Routing recognition (18 runs): intended skill named or used, pooled, after >= before - 1.
Any group failing -> revert the description edit for that skill and re-report.

## Results (pooled, 3 runs per case)

| Group | Before | After |
|---|---|---|
| Doctor skill invoked | 4/12 | 1/12 |
| Doctor skill invoked or content used | 6/12 | 7/12 |
| Doctor answer correct (no false ready, domain-correct, names the fact) | 12/12 | 12/12 |
| Mutating command run in doctor cases | 0 | 0 (four regex hits were `cat fixture-repo/setup`, read-only) |
| Upgrade: skill invoked or content used | 3/3 | 3/3 |
| Off-topic: no skill fired | 3/3 | 3/3 |
| Routing, edited skills: reply names the skill | 13/15 | 13/15 |

web-perf was not edited and is excluded (two of its after-runs were still
running at report time).

Rule 1 tripped (invoked 4 -> 1), so the doctor edit was reverted. The more
likely cause is a confound: after-run agents saw the six modified SKILL.md
files in `git status` and several read `skills/superskills-doctor/SKILL.md`
directly instead of calling the Skill tool. That same confound raised routing
"content used" counts, so only the "names the skill" metric is reported for
routing, and it is flat. A clean-tree rerun of the 12 doctor cases would settle it.

## Findings

1. Selection in-session is weak. superskills-doctor fired in 4 of 12 baseline
   runs (0/3 symptom, 0/3 release-check) versus 12/12 in the 2026-09-16 plugin
   eval. Answers were still correct because agents found `doctor.sh` or reasoned
   from the fixture. Either a subagent artifact or a real triggering weakness.
2. superskills-upgrade invocation was denied by the auto-mode classifier
   ("Irreversible Local Destruction") in two runs, because the skill contains a
   `git reset --hard` branch. The skill is hard to use in auto mode.
3. Description trims are worth little: about 0.6% of a turn, cached.

## Proposals (not done, no eval coverage)

- qa-full: run heavy gstack sub-skills (/review, /qa, /design-review) in
  subagents that return short handoffs, instead of loading 38k+ words of bodies
  into the main context. Needs a qa-full eval fixture (repo with a planted bug)
  first.
- qa-full body: the Anti-patterns and Related commands sections restate Hard
  rules and the Steps (roughly 15% of the file).
- daily-qa, subagent-driven-development: same body audit; no eval coverage yet.

## Method lessons

- Keep the tree clean during after-runs (commit to a branch or stash), or agents
  read the diff.
- Routing cases need fixture repos containing the target (Dockerfile, form...).
