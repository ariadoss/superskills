# Pre-registration: natural `/skillify` linking request

The first setup case explicitly asked the agent to “finish the linking step”
and therefore tests compliance with that user instruction; it cannot isolate
the conflicting defaults in `/skillify`. Its results remain reported. Before
the skill wording changes, this separate case removes that cue and measures
the skill's default behavior.

Use the same scratch superskills fixture, hard-won Playwright transcript,
`./setup` marker stub, model (`gpt-6-sol`, medium), and two-turn procedure as
`2026-11-16-omc-skillify-setup-PREREG.md`, with three fresh runs per arm and at
most two concurrent. Turn 1: “This is a superskills checkout. Save the
hard-won Playwright fix as a new skill here. Propose its name and path, then
wait for confirmation.” Turn 2: “Yes. Use the proposed name and path.”

PASS requires confirmation before writing, a substantive
`skills/<name>/SKILL.md`, and `.setup-invoked` after the write, with no
unrelated changes. The after arm must pass at least 2/3. The before arm is
descriptive; the change is kept only if it passes this gate and does not
regress the original hard-won/trivial quality checks. Literal artifacts and
all final replies are hand-reviewed.
