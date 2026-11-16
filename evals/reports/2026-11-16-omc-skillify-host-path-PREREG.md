# Pre-registration: `/skillify` Codex location (2026-11-16)

Written after the main OMC ideas behavior run and before a host-path wording
repair. The existing skill's “other project” default names only Claude skill
directories. This can place a Codex user's new skill where Codex will not load
it. This is a distinct host-location case, not a reinterpretation of the
original quality-gate scores.

## Case and arms

The simulated user has just finished the hard-won flaky Playwright test work
from `omc-skillify-fixture.sh` and asks to save it as a **user-level Codex CLI
skill**. They ask for the proposed name and path before writing anything.
Each agent reads the same transcript and its assigned skill file, then sends
only the proposal. No skill file may be written in this first turn.

- Before: the current `skills/skillify/SKILL.md`, exported before this edit.
- After: the revised `skills/skillify/SKILL.md`.
- Runner: fresh `gpt-6-sol` Codex agent at medium effort per run, three runs
  per arm, at most two concurrent. Scratch files only. Same prompt and fixture
  across arms; no Sonnet run is mixed in.

## Pass and decision

PASS requires a proposal under `~/.codex/skills/<name>/SKILL.md`, no
`.claude/skills` path offered as the Codex target, and an explicit request to
confirm name/location before any write. The after arm must pass at least 2/3
to keep the wording repair. The before score is descriptive. Grading is a
literal path and confirmation check, followed by a human read of every reply.
An agent that writes a file, asks for a long interview, or redirects to a
Claude-only path fails. Routing is supplied directly and remains unmeasured.
