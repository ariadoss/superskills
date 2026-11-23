---
name: superskills
version: 1.0.0
description: |
  Load a skill pack or one skill into context on demand, so the design and
  marketing skills cost nothing until asked for. `/superskills design` or
  `/superskills marketing` loads that pack's index (names and short
  descriptions); `/superskills <skill-name>` loads that skill's full text and
  follows it. Use when the user types /superskills, or asks to "load the design
  skills", "pull in the marketing skills", or "use the <name> skill" for a skill
  that is not installed as a command. Read-only: it never installs or links
  anything; to change which packs are installed use ./setup --packs.
triggers:
  - /superskills
  - load the design skills
  - load the marketing skills
allowed-tools:
  - Bash
  - Read
---

# /superskills

Pull skills into context only when needed. Read-only.

## Steps

### Step 1: Locate the repo and run the loader (one command)

Pass the user's argument (`design`, `marketing`, a skill name, or `--list`) after
`--`. Run it in a **single Bash call**; separate calls do not share variables.

```bash
SKILL_DIR="${SKILL_DIR:-}"   # set to this skill's base directory when the host provides it
case "$SKILL_DIR" in /*) : ;; *) SKILL_DIR="" ;; esac   # only an absolute path is trusted
ROOT=""
for cand in "${SKILL_DIR:+$SKILL_DIR/../..}" "${CLAUDE_PLUGIN_ROOT}"; do
  [ -n "$cand" ] && [ -f "$cand/scripts/superskills-load.sh" ] && { ROOT="$(cd "$cand" && pwd -P)"; break; }
done
if [ -z "$ROOT" ]; then
  for probe in "$HOME/.claude/skills/superskills/SKILL.md" \
               "$HOME/.codex/skills/superskills/SKILL.md" \
               "$HOME/.config/opencode/skills/superskills/SKILL.md" \
               "$HOME/.zcode/skills/superskills/SKILL.md"; do
    [ -L "$probe" ] || continue
    real="$(readlink -f "$probe" 2>/dev/null || perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$probe")"
    if [ -n "$real" ] && [ -f "$real" ]; then
      ROOT="$(cd "$(dirname "$real")/../.." 2>/dev/null && pwd -P)"
      [ -f "$ROOT/scripts/superskills-load.sh" ] && break
      ROOT=""
    fi
  done
fi
if [ -n "$ROOT" ] && [ -f "$ROOT/scripts/superskills-load.sh" ]; then
  bash "$ROOT/scripts/superskills-load.sh" "$@"
else
  echo "LOADER=missing"
fi
```

`LOADER=missing` means superskills is not installed here. Say so and point at
`/superskills-doctor`. Do not guess paths.

### Step 2: Act on the output

- **A pack** (`design`, `marketing`): the first line is the pack's skill count,
  then one line per skill (name, short description). Quote that count, never
  count the lines yourself. Tell the user the pack is loaded. Do not read any
  skill body yet. When a task matches a line, load it with `/superskills <name>`.
- **A skill name**: the output is the skill's full text, with its path first. Follow
  it for the user's task. Resolve any relative paths it mentions against the
  directory of the printed path. If an `also in:` line appears, mention that
  another copy exists and which one you loaded.
- **No argument or `--list`**: show the packs and ask which to load.
- **Unknown name**: report the error line as printed and offer `--list`.
