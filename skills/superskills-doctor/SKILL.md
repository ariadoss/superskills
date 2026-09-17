---
name: superskills-doctor
version: 1.0.0
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

### Step 1: Locate the doctor script

The script lives in the superskills repo at `scripts/doctor.sh`. Find the repo the
same way `/superskills-upgrade` does — plugin root first, then the symlink of this
skill back to its checkout:

```bash
ROOT="${CLAUDE_PLUGIN_ROOT}"
if [ -z "$ROOT" ] || [ ! -f "$ROOT/scripts/doctor.sh" ]; then
  ROOT=""
  probe="$HOME/.claude/skills/superskills-doctor/SKILL.md"
  # Only a link that resolves to a real file counts; never fall back to the cwd.
  if [ -L "$probe" ]; then
    real="$(readlink -f "$probe" 2>/dev/null || perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$probe")"
    [ -n "$real" ] && [ -f "$real" ] && ROOT="$(cd "$(dirname "$real")/../.." 2>/dev/null && pwd -P)"
  fi
fi
[ -n "$ROOT" ] && [ -f "$ROOT/scripts/doctor.sh" ] && echo "DOCTOR=$ROOT/scripts/doctor.sh" || echo "DOCTOR=missing"
```

If the script is missing, that is itself the finding: report **Repo: blocked** with
the reinstall command below and stop. Do not improvise checks.

```
git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills && cd ~/.claude/skills/superskills && ./setup
```

### Step 2: Run it

```bash
bash "$ROOT/scripts/doctor.sh"
```

To inspect an install that is not the current user's (a container, a test tree,
a colleague's copy), pass the checkout and home directory explicitly:

```bash
bash "$ROOT/scripts/doctor.sh" --root <superskills-checkout> --home <home-dir>
```

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
