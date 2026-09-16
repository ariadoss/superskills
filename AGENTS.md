# Superskills — agent instructions

Context for any coding agent (Codex, Claude Code, Cursor, …) working **in this
repository**. It is contributor context, not plugin context: a plugin's own
CLAUDE.md/AGENTS.md is not loaded for end users, so nothing here reaches them.

The rules live in two files; this page only points at them so they are defined once:

- [`CLAUDE.md`](CLAUDE.md) — release process (VERSION bump → `scripts/sync-version.sh`),
  `./setup` after pulls and new skills, vendoring rules for imported skills, mirror syncs.
- [`ENGINEERING_STANDARDS.md`](ENGINEERING_STANDARDS.md) — the quality bar for all
  code here and for the code the skills produce (TDD, DRY, SOLID, YAGNI), plus the
  skill-authoring conventions every SKILL.md follows.

## Repository structure

- `skills/` — the core skills (one `<name>/SKILL.md` each; sibling files are linked too).
- `design-skills/`, `marketing-skills/` — the design and marketing packs. Marketing skills
  nest up to three levels deep; `marketing-skills/plugin-skills/` (symlinks named by
  frontmatter name) and `marketing-skills/.claude-plugin/plugin.json` are **generated**
  by `scripts/sync-marketing-manifest.sh` — never edit them by hand.
- `vendor/gstack/` — markdown-only snapshot of gstack, a stopgap for offline installs.
- `.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/` — host manifests. `VERSION` is
  the single source of truth; the manifests are stamped, never hand-edited.
- `scripts/` + `scripts/lib/` — installer helpers, all unit-tested in `tests/*.bats`.
- `evals/` — `claude plugin eval` suite (skill-trigger and outcome evals; see `evals/README.md`).

## Invariants

- **Never rewrite published `main`.** `/superskills-upgrade` force-syncs canonical
  installs to `origin/main`; releases must stay forward-only.
- **VERSION drives every manifest.** Bump VERSION, run `./scripts/sync-version.sh`,
  update the README badge. A bump that misses a manifest means installs never see it.
- **A new skill is invisible until `./setup` runs.** Run it before you push.
- **Imported skills are vendored.** No live dependency on an external repo without an
  in-tree copy (or `vendor/` snapshot) and `metadata.upstream` in the frontmatter.
- **Mirrors sync explicitly.** `scripts/sync-mirrors.sh` and `scripts/sync-gstack.sh`
  are maintainer steps before a release; `./setup` never modifies the source tree.
- **Read-only skills stay read-only.** `/superskills-doctor` diagnoses; only
  `/superskills-upgrade` and `./setup` change an install.
- **No release automation or paid CI** without an explicit decision: GitHub Actions on
  a private repo is a recurring charge.

## Validation

```bash
./tests/run.sh                                  # bats suite (includes manifest validation)
claude plugin validate --strict .               # marketplace + root plugin
claude plugin validate --strict marketing-skills
claude plugin eval . --trust-plugin --no-publish --judge-model sonnet \
  --scaffold --allow-tools Bash                  # behavioural evals — costs model calls
```
