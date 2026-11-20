---
name: superskills-doctor
version: 1.1.0
description: |
  Diagnose a superskills install WITHOUT changing anything: install kind, which
  skills are linked, VERSION vs the plugin manifests, gstack (real clone or
  vendor stopgap), bun and optional tools. Use when a skill is missing or won't
  trigger, a pull or upgrade looks stale, setup failed, or the user asks whether
  superskills is healthy, ready, or installed correctly. Read-only: it never
  installs, pulls, or re-runs setup — to fix things use /superskills-upgrade.
triggers:
  - is superskills healthy
  - check my superskills install
  - superskills doctor
  - skill missing after pull
allowed-tools:
  - Bash
  - Read
---

# /superskills-doctor

Read-only health check. Report what is, never repair it.

## Rules

1. **Never mutate.** Do not run `./setup`, `git pull`, `git reset`, `curl … | bash`,
   `bun install`, or any login. If the user wants the fix, name the command from
   the table's "next action" column or point at `/superskills-upgrade`.
2. **Never claim readiness the script did not.** The verdict is the script's
   verdict. "blocked" or "unverified" means not ready, even if most rows are fine.
3. **Report evidence, not impressions.** Reproduce the table; do not summarise
   rows away or add checks you did not run.

## Steps

### Step 1: Locate and run the doctor (one command)

The script lives in the superskills repo at `scripts/doctor.sh`. Find the repo, in
order: the directory this skill was loaded from (if your host told you this skill's
base directory, put it in `SKILL_DIR` on the first line), the Claude Code plugin
root, then this skill's `./setup` symlink for Claude Code, Codex or OpenCode —
never the working directory. Locate and run it **in a single Bash call**: separate
calls do not share shell variables, so a path found in one call is gone in the next.

```bash
NAME=superskills-doctor
WANT=scripts/doctor.sh
SKILL_DIR="${SKILL_DIR:-}"   # set to this skill's base directory when the host provides it
case "$SKILL_DIR" in /*) : ;; *) SKILL_DIR="" ;; esac   # only an absolute path is trusted, never resolved against the cwd
ROOT=""
for cand in "${SKILL_DIR:+$SKILL_DIR/../..}" "${CLAUDE_PLUGIN_ROOT}"; do
  [ -n "$cand" ] && [ -f "$cand/$WANT" ] && { ROOT="$(cd "$cand" && pwd -P)"; break; }
done
if [ -z "$ROOT" ]; then
  # What ./setup creates: Claude Code and ZCode link SKILL.md, OpenCode links it under a
  # superskills- prefix, Codex links the whole skill folder (so SKILL.md itself is no symlink).
  for probe in "$HOME/.claude/skills/$NAME/SKILL.md" \
               "$HOME/.codex/skills/$NAME/SKILL.md" \
               "$HOME/.config/opencode/skills/superskills-$NAME/SKILL.md" \
               "$HOME/.config/opencode/skills/$NAME/SKILL.md" \
               "$HOME/.zcode/skills/$NAME/SKILL.md"; do
    # Only a file that resolves to a real path counts; never fall back to the cwd.
    [ -f "$probe" ] || continue
    real="$(readlink -f "$probe" 2>/dev/null || perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$probe")"
    if [ -n "$real" ] && [ -f "$real" ]; then
      ROOT="$(cd "$(dirname "$real")/../.." 2>/dev/null && pwd -P)"
      [ -f "$ROOT/$WANT" ] && break
      ROOT=""
    fi
  done
fi
if [ -n "$ROOT" ] && [ -f "$ROOT/scripts/doctor.sh" ]; then
  echo "DOCTOR=$ROOT/scripts/doctor.sh"
  bash "$ROOT/scripts/doctor.sh" "$@"
else
  echo "DOCTOR=missing"
fi
```

The locate block above is intentionally duplicated in `/superskills-doctor`, `/debrief` and `/prune-skills` (a skill needs the repo path before it can source anything); `tests/locate-block.bats` keeps the three identical.

If it prints `DOCTOR=missing`, that is itself the finding: report **Repo: blocked**
with the reinstall command below and stop. Do not improvise checks.

```
git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills && cd ~/.claude/skills/superskills && ./setup
```

To inspect an install that is not the current user's (a container, a test tree,
a colleague's copy), run the same block with the flags appended to the
`bash "$ROOT/scripts/doctor.sh"` line: `--root <superskills-checkout> --home <home-dir>`.
To call the script directly later, use the path from the `DOCTOR=` line.

### Step 2: Read the output

The script prints a markdown table (`Check | Status | Evidence / next action`)
and a final `Verdict:` line. Statuses:

| Status | Meaning |
| --- | --- |
| ready | passed |
| warning | usable; something optional is off |
| blocked | a required piece is missing or broken — the row says what to run |
| unverified | the probe could not run (e.g. no `claude` CLI) — unknown, not fine |

### Step 3: Report

Return the table verbatim, then the verdict, then one line per non-ready row
naming the next action from that row. Say plainly:

- **Verdict: ready** → "superskills is ready."
- **ready with warnings** → ready, and list the warnings.
- **blocked** → "Not ready" and the blocked rows first. The usual fix is
  `./setup` from the repo, or `/superskills-upgrade`; offer it, do not run it.
- **unverified** → say readiness is unknown and which probe could not run.
