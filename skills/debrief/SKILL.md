---
name: debrief
description: |
  Take the current session apart: what went right, what went wrong, and where
  each lesson should live (a skill edit, a new skill, a project rule, a
  memory note, a script, or a hook). Checks whether an existing skill already
  covers the lesson before proposing anything new. Use at the end of a
  session, or when asked to "debrief", "what did we learn", or "codify this".
  Proposes only. Not for saving a finished procedure as a skill (/skillify),
  not for resuming work in a new session (/handoff), and not for pruning
  the skill list (/prune-skills).
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Debrief

A session produces lessons. Most are trivia, a few deserve a permanent home.
This skill separates them and says where each one goes. It proposes; you decide.

**Announce at start:** "I'm using the debrief skill to review this session."

## Step 1: Classify the repo

Run `git remote -v` and check visibility if a remote exists. For a **public repo**,
session specifics (client names, plans, research, private paths) must
never go into a tracked file. They go to private memory only. Say which case
applies before proposing anything.

## Step 2: List what went right and wrong

Work from this session's own history. List at most five of each, one line
each: a decision that paid off, a mistake that cost time, a correction the
user gave, a step that was repeated by hand. Skip anything that only mattered
to this one task. Never quote session or transcript text into a proposal: it
can hold secrets, tokens or client names. Describe the lesson in your own words.

## Step 3: Keep only lessons worth keeping

A lesson stays if it will recur **and** is not obvious from the code or docs.
One-offs and facts the repo already records are dropped, and you say that you
dropped them.

## Step 4: Check existing coverage

For each lesson that stays, ask whether a skill already covers it. The overlap
tool (`skill_overlap.py query`) lives in the superskills repo, not the working directory. Find the repo
the way `/superskills-doctor` does and run the lookup in a **single Bash
call**, since separate calls do not share shell variables.

```bash
SKILL_DIR="${SKILL_DIR:-}"   # set to this skill's base directory when the host provides it
case "$SKILL_DIR" in /*) : ;; *) SKILL_DIR="" ;; esac   # only an absolute path is trusted
ROOT=""
for cand in "${SKILL_DIR:+$SKILL_DIR/../..}" "${CLAUDE_PLUGIN_ROOT}"; do
  [ -n "$cand" ] && [ -f "$cand/scripts/skill-census/skill_overlap.py" ] && { ROOT="$(cd "$cand" && pwd -P)"; break; }
done
if [ -z "$ROOT" ]; then
  for probe in "$HOME/.claude/skills/debrief/SKILL.md" \
               "$HOME/.codex/skills/debrief/SKILL.md" \
               "$HOME/.config/opencode/skills/debrief/SKILL.md" \
               "$HOME/.zcode/skills/debrief/SKILL.md"; do
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
  python3 -I "$CENSUS/skill_overlap.py" query "$ROOT" "<the lesson in one sentence>" --top 3
fi
```

If it prints `CENSUS=missing`, say the lookup tool could not be found and
continue with step 4's manual read only. Do not invent scores.

**Overlap has low recall.** It is a coarse word-match score, and real
neighbours such as `qa-full` and `basic-review` score only about 0.09. An
empty or weak result does NOT mean no skill covers the lesson. Before you
propose a new skill, also read the `name` and `description` lines of candidate
skills under `skills/` and `design-skills/` yourself, and judge. Prefer
extending an existing skill over adding one. If a skill scores high, read it
before deciding; the score is a hint, not proof.

## Step 5: Route each lesson to one home

- **Existing skill gap:** edit that skill. Name the file and the sentence.
- **Repeatable procedure with no home:** hand off to `/skillify`.
- **Project rule:** a line in `CLAUDE.md` or `AGENTS.md`.
- **About the user or how they like to work:** a memory note.
- **Same input always gives the same output:** a script, called by a skill.
- **Must happen every time, with no judgment:** a hook. Describe it and hand
  off to `/update-config`. Do not edit `settings.json` here.

Each proposal says what changes, where, and why, in two short lines.

## Step 6: Stop and ask

This skill proposes only. Never write a file before the user says yes to that
item, and never create, edit or delete a skill without an explicit yes for it.
After a yes, make the edit, then tell the user what gates apply: a change to a
skill's description or body is a behaviour change, so run `/eval` before
pushing; `./scripts/lint-skills.sh` and `./tests/run.sh` must pass.

## Gotchas

- Do not invent lessons to fill the list. Zero is a valid result.
- Do not paste private details into a skill that other people install.
- A missing overlap hit is not evidence of a gap. Read the descriptions.
- The cross-session sweep is out of scope: this reads only the current session.
