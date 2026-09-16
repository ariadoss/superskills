#!/bin/bash
# Builds a fake superskills checkout + home in the run workspace so the doctor
# can be pointed at it with --root/--home (the real $HOME is unreadable here).
set -e
R="$PWD/fixture-repo"; H="$PWD/fixture-home"
mkdir -p "$R/skills/tdd" "$R/skills/debug" "$R/skills/clean-code" "$R/.claude-plugin" "$R/.codex-plugin" "$H/.claude/skills"
printf '2.24.0\n' > "$R/VERSION"
# A realistic (abridged) installer, so the baseline cannot diagnose "setup is a stub".
cat > "$R/setup" <<'S'
#!/usr/bin/env bash
# superskills setup — links every skills/*/SKILL.md into ~/.claude/skills/<name>/,
# installs gstack (real clone, else the vendor stopgap), and installs the git
# post-merge hook so `git pull` re-runs this script. Safe to re-run.
set -e
SRC="$(cd "$(dirname "$0")" && pwd -P)"; DST="$HOME/.claude/skills"; mkdir -p "$DST"
for md in "$SRC"/skills/*/SKILL.md; do
  name="$(grep -m1 '^name:' "$md" | sed 's/^name:[[:space:]]*//')"
  mkdir -p "$DST/$name"; ln -snf "$md" "$DST/$name/SKILL.md"
done
if [ ! -d "$DST/gstack/.git" ]; then
  git clone --depth 1 https://github.com/garrytan/gstack.git "$DST/gstack" 2>/dev/null \
    || { cp -R "$SRC/vendor/gstack" "$DST/gstack"; touch "$DST/gstack/.superskills-vendor-copy"; }
fi
echo "superskills ready"
S
chmod +x "$R/setup"
for s in tdd debug clean-code; do printf -- '---\nname: %s\ndescription: %s skill\n---\n' "$s" "$s" > "$R/skills/$s/SKILL.md"; done
printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$R/.claude-plugin/plugin.json"
printf '{ "name": "superskills", "plugins": [{ "version": "2.24.0" }] }\n' > "$R/.claude-plugin/marketplace.json"
mkdir -p "$R/.cursor-plugin" "$R/marketing-skills/.claude-plugin"
printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$R/.cursor-plugin/plugin.json"
printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$R/.cursor-plugin/marketplace.json"
printf '{ "name": "superskills-marketing", "version": "2.24.0" }\n' > "$R/marketing-skills/.claude-plugin/plugin.json"
printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$R/.codex-plugin/plugin.json"
# tdd and debug are linked; clean-code was added upstream and never linked.
for s in tdd debug; do mkdir -p "$H/.claude/skills/$s"; ln -s "$R/skills/$s/SKILL.md" "$H/.claude/skills/$s/SKILL.md"; done
# gstack: the vendor stopgap copy (no .git, marker present)
mkdir -p "$H/.claude/skills/gstack"; printf '1.80.0.0\n' > "$H/.claude/skills/gstack/VERSION"; touch "$H/.claude/skills/gstack/.superskills-vendor-copy"
