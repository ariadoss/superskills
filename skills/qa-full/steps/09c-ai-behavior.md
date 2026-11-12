## Step 9c: AI-behavior pipeline — `/eval` (ask-first if triggered)

**Trigger:** the diff changes AI behavior. Judge it the way human eyes would:
does the change alter what a model sees, how it is instructed, or how its
output is judged or used? A prompt template edited inside source code counts,
not just prompt files. The obvious file signals are prompts, agent or skill
instructions (`**/SKILL.md`, `.claude/commands/**`, `AGENTS.md` /
`CLAUDE.md` instruction files), and LLM/RAG pipeline code or configuration
(retrieval parameters, judge rubrics, agent-loop logic). Pure formatting
changes to the same files do not count. NOT-TRIGGERED means "no plausible
behavior change," never "no matching filename."

How the eval runs decides whether to ask. Running the cases and judge as
in-session subagents of this session (the `/eval` skill's own method) draws on
the user's plan allowance and has no separate charge, so run it without asking
and say so in the ledger. Anything metered or billed on top of the plan
(`claude plugin eval`, a paid API key, an external model endpoint) follows the
money rule: ask the user first, name what it will cost, and run only on an
explicit yes. A decline is SKIPPED(reason: not authorized), a legal skip with
reason, not a blocker.

1. **Audit:** invoke `/eval`; it builds or reuses the project's synthetic eval
   set for the changed behavior and reports the behavior's before/after
   system metrics (pass rate per dimension), with the judge's calibration
   (TPR, TNR, accuracy, precision, plus the bias reading) attached so the
   numbers are trusted before they are read.
2. **Fix:** wording first, structure second — the method's fix ladder.
3. **Verify:** re-run the eval. The changed behavior must be no worse than the
   baseline on every reported metric, and better on the dimension the change
   targeted. "No degradation" is the floor, not the goal.

A metric regression is a warning unless the project marks evals MANDATORY in
`CLAUDE.md`; a MANDATORY eval that was declined or never ran is MANDATORY-FAIL.
