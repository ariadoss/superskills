# Pre-registration: skillify quality gate and output shape (2026-11-15)

Written before any run. Nothing below changes after results come in.

## Question

New skill `skills/skillify/` turns finished work into a reusable SKILL.md,
behind a three-question quality gate. Two behaviors:

1. **Q1 (gate passes on hard-won work):** given a session transcript excerpt
   where a non-obvious procedure was established through real debugging, does
   an agent following the skill produce a draft SKILL.md with frontmatter
   (name + trigger-bearing description), a pitfalls section with the actual
   failure modes hit, and success criteria — and confirm before writing?
2. **Q2 (gate blocks trivia):** given a transcript where the "discovery" is a
   one-liner findable in the README, does the agent REFUSE to create a skill
   and name where the content belongs instead — where an agent without the
   skill writes a low-value skill file?

## Arms

- **before:** no skillify skill (the request goes to the model's default).
- **after:** `skills/skillify` at HEAD, exported via `git archive`.
- Subagent: in-session Sonnet `general-purpose`, at most two at a time. Free
  under the plan.

## Scope of a run

The subagent gets a scratch dir styled as a project, the request ("save this
as a skill" / "make a reusable skill out of this"), and the transcript excerpt
as a file. It may write into the scratch dir only. One turn.

## Fixtures (evals/_lib/omc-skillify-fixture.sh)

Two transcript excerpts (hard-won vs trivial), both mentioning the same
nominal topic (a flaky test fix) so the delta is the gate, not the subject
matter.

## Pass rules (graded by evals/_lib/omc-skillify-grade.sh)

- Q1 (n=3/arm): PASS when a SKILL.md draft exists with `name:`, a
  `description:` that names a trigger situation, a pitfalls section, and the
  agent asked/stated confirmation of location before or while writing.
- Q2 (n=3/arm): PASS when NO skill file was created AND the reply names an
  alternative home (README/docs/comment). before expected fail (default
  behavior writes the file).

## Decision rule

Keep skillify if Q1 after ≥2/3 and Q2 after ≥2/3 (before Q2 expected ≤1/3).
On a Q1 miss, fix the capture/format text; on a Q2 miss, sharpen the gate's
refusal language; re-run only the missed question.

## Known limits

Small n; Sonnet only; one-shot turn (the confirm-then-write flow is graded
from the single reply, so "confirm" is accepted as stated intent, not a real
second turn). Routing of the skill (does it fire from natural language) is a
separate billed `claude plugin eval` run.
