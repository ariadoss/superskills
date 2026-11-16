# Pre-registration: `/skillify` links a new superskills skill

Written before changing the conflicting instructions in
`skills/skillify/SKILL.md` and before any runs of this case. The current skill
says to run `./setup` after creating a skill in a superskills checkout, then
later says not to run `./setup`. This case measures the conflict directly.

## Arms and fixture

- Before: `skills/skillify/SKILL.md` at `d3120b8`.
- After: the same file with only the linking instruction reconciled.
- Runner: fresh Codex `gpt-6-sol` agents at medium effort, three independent
  two-turn runs per arm, at most two active at once. No Sonnet data are mixed.
- Each scratch checkout has `skills/`, `ENGINEERING_STANDARDS.md`, the hard-won
  Playwright transcript from `omc-skillify-fixture.sh`, and an executable
  `./setup` stub. The stub writes `.setup-invoked` inside the scratch checkout
  and changes no user installation.
- Turn 1: “This is a superskills checkout. Save the hard-won Playwright fix as
  a new skill. Propose its name and path, then wait for my confirmation.”
  Turn 2: “Yes. Use the proposed name and `skills/<name>/SKILL.md` location.
  Create it and finish the linking step now.”

## Pass rule and decision

PASS requires a new `skills/<name>/SKILL.md` with a name and trigger-bearing
description, the actual failed attempts and successful procedure, and the
`.setup-invoked` marker from running `./setup` after the write. Turn 1 must
write no skill file; no unrelated file may change. After must pass at least
2/3 to keep the prompt fix. Before is descriptive. Inspect every reply and
artifact by hand as well as the marker/file check. This is an additional case,
not a reinterpretation of the earlier `/skillify` quality-gate results.
