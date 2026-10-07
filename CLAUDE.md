# Superskills

## Engineering standards (applies to all code in this repo)

All code here (`setup`, `scripts/`, skill helpers, anything executable) follows
[`ENGINEERING_STANDARDS.md`](ENGINEERING_STANDARDS.md): TDD, DRY, SOLID, YAGNI,
to a Google/Meta-quality bar. Concretely:

- **Shell/library code is tested with `bats`.** Run `./tests/run.sh` before
  committing any change to `setup`, `scripts/`, or `tests/`. New behavior gets a
  failing test first (TDD); logic shared across call sites lives in one place
  (`scripts/lib/skills-lib.sh`), not copy-pasted (DRY).
- **Skills that generate or review code must enforce the same bar** by
  referencing `ENGINEERING_STANDARDS.md`, not by restating it. When you add or
  edit a code-producing or quality-gate skill, point it at that file.

## Versioning

VERSION gets one reviewed bump per merged change, never one per intermediate
commit: bump it when a change is about to land on `main` (on the feature
branch, at `/ship` time), re-reading latest `main` first so parallel branches
never claim the same number. The full decision model (SemVer vs CalVer vs
build IDs, release tags, changelog fragments for parallel agents) lives in
[`DEVELOPER_WORKFLOW.md`](DEVELOPER_WORKFLOW.md):
- Patch (2.x.X): bug fixes, typo corrections, small clarifications to existing skills
- Minor (2.X.0): new skills, significant updates to existing skills, new tool support
- Major (X.0.0): breaking changes, major new capability bundles

Update the version badge in README.md to match (e.g. `v2.1.0` → `v2.2.0`).

After bumping VERSION, **run `./scripts/sync-version.sh`** to propagate it into the
plugin manifests (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
`.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.cursor-plugin/marketplace.json`).
These `version` fields are what trigger the native "plugins updated" alert in
Claude Code and Codex. A bump that doesn't reach them means existing plugin
installs never see the update. VERSION is the single source of truth; the
manifests are generated from it, never hand-edited.

`sync-version.sh` also regenerates the `superskills-marketing` plugin:
`marketing-skills/plugin-skills/` (one relative symlink per skill, named by its
frontmatter `name`) and `marketing-skills/.claude-plugin/plugin.json`. The shim
tree exists because Claude Code's plugin loader does not recurse into nested
skill directories and names a plugin skill by its **directory** basename, not
its frontmatter name (verified by `evals/` on Claude Code 2.1.273; 100 of the
174 marketing skills would otherwise get the wrong slash name and two would
collide on `article`). After adding, moving or renaming a marketing skill, run
`./scripts/sync-marketing-manifest.sh`; `tests/manifest-lib.bats` and
`tests/plugin-manifests.bats` fail on drift. `./setup` ignores the shim tree.
The shim tree is the repo's only committed symlinks: a Windows checkout without
`core.symlinks` gets text files there and the marketing plugin will not load.

Skill *behaviour* is evaluated with `claude plugin eval`: suite in `evals/`,
the suite rubric in `evals/RUBRIC.md`, the general method (synthetic
datasets, judge calibration, TPR/TNR/accuracy/precision) in
`evals/METHODOLOGY.md`. Run it whenever a change alters behaviour (a skill
`description` or body rewording, prompt logic), not only at release. Runs cost
model calls, so they are a release step, not part of `./tests/run.sh`.
`AGENTS.md` is the Codex-facing pointer to this
file and to `ENGINEERING_STANDARDS.md`, which carries the skill-authoring
conventions every SKILL.md follows; `/superskills-doctor` is their reference
implementation.

## Always re-run `./setup` after a pull or after adding a skill

Skills are exposed to the tools as symlinks created by `./setup`. Edits to an
**existing** skill propagate instantly (the symlink points at the live file),
but a **new** skill is invisible until `./setup` runs again to create its link.

So:
- **After every `git pull`** in this repo, run `./setup` (a `post-merge` git
  hook does this automatically once you've run setup once; if you cloned fresh,
  run it manually the first time).
- **After adding a new skill locally, before you push**, run `./setup` so the
  new skill is linked and testable in your own environment.

End users get the same guarantee via `/superskills-upgrade`, which fetches,
force-syncs to `origin/main` even across a rewritten history, and re-runs setup.
Because of that force-sync, **never rewrite published `main`** (no force-push /
history squash of released commits) unless unavoidable. Keep releases
forward-only so existing installs always fast-forward cleanly.

## Always keep a local copy of imported skills

Whenever you add a skill that originates from an external GitHub repo (or any other remote source), commit a local copy of its full contents into this repository. The remote could be deleted, renamed, or made private at any time, and the skill must keep working without it.

Two patterns are valid. Pick the one that matches the skill's runtime needs:

- **In-tree (preferred for self-contained skills)**: copy the upstream repo's contents directly into the appropriate skills folder (`marketing-skills/<category>/<skill>/`, `design-skills/<skill>/`, or `skills/<skill>/`). The skill ships with the repo, the setup script symlinks it into the target tools, and no separate clone is needed at install time. This is how all marketing-skills, design-skills, and `marketing-skills/content/video-editing/` work.
- **Vendor + runtime clone (only when the upstream is updated frequently and managed by its own setup)**. Clone the upstream into `~/.claude/skills/<name>` at install time, AND keep a snapshot at `vendor/<name>/` as a fallback if the remote disappears. This is how `vendor/gstack/` works.

Never reference an external repo as a live dependency without one of these two backups in place. Record the upstream URL in the skill's frontmatter (e.g. `metadata.upstream: https://...`) so the source is traceable.

### dbmap/repomap are canonical here; their public repo is an export

The `dbmap`, `repomap`, `dbmap-auto-on`, `dbmap-auto-off`, `repomap-auto-on`, and `repomap-auto-off` skills are the single source of truth for the public [ariadoss/repomap](https://github.com/ariadoss/repomap) repo (the old pull direction is retired). After changing any of the six skills, regenerate and publish the standalone tree:

```bash
./scripts/export-repomap.sh            # -> dist/repomap (git-ignored)
```

The export is a pure copy: each `skills/<name>/SKILL.md` lands as `<name>.md`, byte-identical, frontmatter and all, and owns only those six paths. The public repo's README, LICENSE, `setup`, `requirements.txt`, and Python sources live in that checkout and are edited there via PR. `tests/export-repomap.bats` asserts byte-identity. Never edit the six `<name>.md` files in the public repo directly; the next export would silently overwrite them.

### Keeping the `vendor/gstack` snapshot current

`vendor/gstack/` is a markdown-only snapshot of the gstack install
(`~/.claude/skills/gstack`). When the live install is ahead of
`vendor/gstack/VERSION`, run:

```bash
./scripts/sync-gstack.sh
```

`./setup` treats that snapshot as a stopgap only: `scripts/lib/gstack-install-lib.sh`
retries the real clone on every run and promotes a vendor-copy install when it
succeeds (tested by `tests/gstack-install-lib.bats`).

It copies every skill's SKILL.md plus the sections/specialists/checklist
markdown those bodies load, `docs/*.md`, VERSION, CLAUDE.md and gstack's own
`setup` (so `./setup`'s clone-failed fallback can still link the skills), never
other code or build output, and removes anything no longer upstream. Tested by
`tests/sync-gstack.bats`. It also regenerates `skills/basic-review/checklist.md`, the
copy of gstack's review checklist that `/basic-review` ships so it works without
gstack; `tests/basic-review.bats` fails if that copy drifts.

### `/humanize` is canonical here; its public repo is an export

`skills/humanize/` is the single source of truth for the public
[`ariadoss/humanize`](https://github.com/ariadoss/humanize) repo. After changing
the skill or its toolkit, regenerate and publish the standalone tree:

```bash
./scripts/export-humanize.sh            # -> dist/humanize (git-ignored)
```

The export is a pure copy of git-tracked files only (`git add` a new toolkit
file to publish it) and refuses to finish unless the exported tree passes its
own tests under `bats`; `tests/export-humanize.bats` asserts byte-identity. Never edit the
public repo directly. The next export would silently overwrite the change.
Whole-text LLM rewriting humanizers are private and must never be added here;
`/humanize` only makes surgical, span-level edits.

### `/eval` is canonical here; its public repo is an export

`skills/eval/` is the single source of truth for the public
[`ariadoss/eval`](https://github.com/ariadoss/eval) repo. After changing the
skill or its toolkit, regenerate and publish the standalone tree:

```bash
./scripts/export-eval.sh              # -> dist/eval (git-ignored)
```

Same doctrine as `/humanize`: pure copy of git-tracked files only, refuses to
finish unless the exported tree passes its own tests under `bats`;
`tests/export-eval.bats` asserts byte-identity. Never edit the public repo
directly. The in-repo prose method the skill operationalizes lives in
`evals/METHODOLOGY.md`; keep the two telling the same story when either
changes.

<!-- superskills-workflow-rule -->
## Superskills Developer Workflow

Read DEVELOPER_WORKFLOW.md to understand how to use superskills commands together: parallel agents, vertical slices, quality pipeline, performance optimization, and shipping workflow.

## Prose quality before push

Two push surfaces are gated by the PreToolUse hook
(`scripts/humanize-prepush-hook.sh`): the repo-root `README.md` when
MODIFIED, and any NEWLY-CREATED `.md` outside the skill packs (new docs
are human-facing by default). Modified internal records are not gated;
renames count by destination; deletions never gate. A push carrying
flagged text is blocked until `/humanize` cleans it
(`HUMANIZE_PREPUSH=0` is the bypass for deliberately-held wording).
Everything else is deliberately OUT of the gate: skill bodies are how
agents speak to agents (register is the product; wording is often the
exact bytes an eval adopted — humanize only deliberately and surgically),
and internal docs, reports, and plans are working records. As a habit,
run `/humanize` over human-facing prose you author (READMEs, public docs)
before it ships; never batch-rewrite the excluded categories.
