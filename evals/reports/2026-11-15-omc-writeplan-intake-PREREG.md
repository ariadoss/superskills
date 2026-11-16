# Pre-registration: write-plan requirements intake + deep-interview chain (2026-11-15)

Written before any run. Nothing below changes after results come in.

## Question

`skills/write-plan/SKILL.md` gained a Requirements Intake section and an
**Assumptions** line in the plan header, and a new skill `skills/deep-interview/`
was added upstream of it. Three behaviors:

1. **Q1 (intake):** on a vague one-shot request (no interactive user), does an
   agent following the new write-plan still produce the plan — never stall — with
   an Assumptions section recording its guesses, where the old text produced a
   plan with no assumptions recorded?
2. **Q2 (interview offer):** on a vague request where a user IS in the loop, does
   the new text offer `/deep-interview` once in one line, where the old text
   never offered it?
3. **Q3 (regression guard):** on a clear, well-specified request, does the new
   text still plan directly — no interview offer, plan present?
4. **Q4 (deep-interview discipline):** an agent following the new
   `deep-interview` skill on a vague request asks exactly ONE question in its
   first turn, targeting the stated weakest dimension, and writes no file except
   (after answers, second turn) the spec marked `Status: pending approval`.

## Arms

- **before:** `skills/write-plan` at `f4725f9` (exported with `git archive` to a
  scratchpad dir; no deep-interview skill exists).
- **after:** `skills/write-plan` + `skills/deep-interview` at HEAD (exported the
  same way).
- Q4 has only the after arm (new skill; the before behavior is "no skill").
- Subagent: in-session Sonnet `general-purpose`, at most two at a time. Free
  under the plan; `claude plugin eval` is not used here (routing is a separate
  billed run).

## Scope of a run

The subagent is told: "Your skill loader gives you the skill at <path> — read it
and follow it." The request is a user message; no other context. Q1/Q3 requests
say "give me the plan in your reply" (one-shot, no interactive user); the Q2
request is conversational. Artifacts land in the scratch dir. Q4 turn 1: vague
request; the grader inspects the final message. Q4 turn 2 (same agent, resumed):
a scripted answer is injected; the grader inspects the spec file and the final
message for the approval gate.

## Fixtures (evals/_lib/omc-intake-fixture.sh)

Scratch dir per run with a minimal repo context (README naming the test runner,
one source file) so "repo before user" has something to check against.

## Pass rules (graded by evals/_lib/omc-intake-grade.sh)

- Q1 (n=3/arm): PASS when the reply contains a plan AND an `**Assumptions:**`
  section with ≥1 concrete entry. before is expected to fail (no such section).
- Q2 (n=3/arm): PASS when the reply offers an interview (`deep-interview` or
  "interview") exactly once AND does not run a full interview itself.
- Q3 (n=3/arm, both arms must pass): PASS when the reply contains a plan and no
  interview offer.
- Q4 (n=3, after only): PASS when the first turn's final message asks exactly
  one question (exactly one `?`, one sentence cluster), touches no file outside
  the scratch specs dir, and turn 2 writes a spec whose first status line is
  `Status: pending approval` and whose acceptance criteria are checkable
  (each starts with a verb runnable/verifiable — graded by regex on the
  `- [ ]` lines).

## Decision rule

Keep the write-plan edit if Q1 after ≥2/3 and Q1 before ≤1/3, and Q2 after
≥2/3. Keep deep-interview only if Q3 stays ≥2/3 on BOTH arms (no regression)
and Q4 ≥2/3. If Q4 <2/3, fix the skill text (description/body first) and re-run
Q4 only. If Q3 regresses on after, tighten the intake trigger wording and re-run
Q3 only.

## Known limits

Small n; Sonnet only; one-shot subagents approximate but do not reproduce the
real skill loader (routing is measured separately with `claude plugin eval`).
Q1's "before fails" is near-certain by construction (the section did not exist),
so Q1 measures that the new text produces the new behavior, not that it is
better; the judgment call Q1 answers is whether assumptions get recorded at all.
