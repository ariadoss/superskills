---
name: prune-skills
description: |
  Find skills that are redundant, superseded, or too heavy, with evidence, and
  propose merging or removing them. Counts how often each skill is actually
  used in recent transcripts, scores description overlap between skills, and
  lists the biggest context costs. Use when asked to "prune skills", "which
  skills overlap", "clean up my skills", or when the skill list feels crowded.
  Proposes only: it never deletes. Not for creating a skill from a session
  (/skillify) and not for turning session lessons into rules (/debrief).
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Prune skills

Fewer, sharper skills route better and cost less context. This skill gathers
evidence and proposes. You decide.

**Announce at start:** "I'm using the prune-skills skill to look for redundant skills."

## Step 1: Gather the three signals (scripts, not judgment)

The tools live in the superskills repo, not the working directory. Find the
repo the way `/superskills-doctor` does and run all three signals in a
**single Bash call**, since separate calls do not share shell variables.

```bash
SKILL_DIR="${SKILL_DIR:-}"   # set to this skill's base directory when the host provides it
case "$SKILL_DIR" in /*) : ;; *) SKILL_DIR="" ;; esac   # only an absolute path is trusted
ROOT=""
for cand in "${SKILL_DIR:+$SKILL_DIR/../..}" "${CLAUDE_PLUGIN_ROOT}"; do
  [ -n "$cand" ] && [ -f "$cand/scripts/skill-census/skill_overlap.py" ] && { ROOT="$(cd "$cand" && pwd -P)"; break; }
done
if [ -z "$ROOT" ]; then
  for probe in "$HOME/.claude/skills/prune-skills/SKILL.md" \
               "$HOME/.codex/skills/prune-skills/SKILL.md" \
               "$HOME/.config/opencode/skills/prune-skills/SKILL.md" \
               "$HOME/.zcode/skills/prune-skills/SKILL.md"; do
    [ -L "$probe" ] || continue
    real="$(readlink -f "$probe" 2>/dev/null || perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$probe")"
    if [ -n "$real" ] && [ -f "$real" ]; then
      ROOT="$(cd "$(dirname "$real")/../.." 2>/dev/null && pwd -P)"
      [ -f "$ROOT/scripts/skill-census/skill_overlap.py" ] && break
      ROOT=""
    fi
  done
fi
if [ -z "$ROOT" ]; then echo "CENSUS=missing"; else
  CENSUS="$ROOT/scripts/skill-census"
  echo "ROOT=$ROOT"
  python3 -I "$CENSUS/skill_overlap.py" pairs "$ROOT"
  python3 -I "$CENSUS/skill_usage.py" "$HOME/.claude/projects" --days 90
  bash "$ROOT/scripts/skill-context-budget.sh" "$ROOT"
fi
```

If it prints `CENSUS=missing`, say the superskills install could not be found
and stop. Do not improvise the numbers.

Read the output with these limits in mind:

- **Overlap has low recall.** It is a coarse word-match score (Jaccard on
  descriptions and triggers, default threshold 0.15). Real neighbours such as
  `qa-full` and `basic-review` score only about 0.09 and do not appear. An empty
  or short candidate list does NOT mean there are no overlaps. Also read the
  skill descriptions yourself (`name` and `description` lines under `skills/`
  and `design-skills/`) and use your own judgment to spot pairs the score missed.
  Conversely, a listed pair can be noise.
- **Usage is Claude Code only.** `skill_usage.py` prints `# sessions=N` and then
  `skill<TAB>count`: counts only, never message content. Use of a skill from
  Codex or Cursor is invisible, so say so in the report.
- Only the flat trees `skills/` and `design-skills/` are scanned. `vendor/`,
  `marketing-skills/` and generated shims are upstream-owned or generated and
  are never candidates.

## Step 2: Judge each candidate pair

For each pair from the script, and each pair you spotted yourself, read both
SKILL.md files and decide which of three things is true:

- **Duplicate:** same job, same trigger. Propose folding the weaker into the
  stronger and keeping both names as trigger phrases in the survivor.
- **Neighbours:** similar words, different jobs. Leave both, and check that
  each description names the other as a boundary.
- **Superseded:** one covers everything the other does and more.

## Step 3: Apply the deletion gate

Never delete a skill on one signal. A removal proposal needs **both**: overlap
with a named survivor, and a usage window of at least 30 sessions (the
`# sessions=N` line) showing the candidate is not carrying its own weight. A
skill with zero uses is not redundant if its job is unique: rare and unique
stays. With fewer than 30 sessions in the window, report "insufficient data"
instead of a verdict.

## Step 4: Propose, then stop

This skill proposes only. It never deletes or edits a skill on its own. Reply
with a short list, in plain words, per candidate: what overlaps with what, the
usage numbers, your recommendation and the cost of being wrong. Wait for a yes
per item. On a yes: do the change on a branch with `git rm` or an edit, run
`./scripts/lint-skills.sh` and `./tests/run.sh`, and run `./setup` so dangling
links are cleaned. A merge changes a skill's description or body, which is a
behaviour change: tell the user to run `/eval` before pushing.

## Gotchas

- Do not read overlap as proof. Two skills can share most words and do
  different jobs.
- Do not quote transcript text anywhere. Only names and counts leave the tools.
- If asked to prune something under `vendor/`, explain it is upstream-owned and
  stop.
