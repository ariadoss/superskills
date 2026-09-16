#!/bin/bash
# Shared scaffold for the evals/doctor-* cases. Each case's fixture.sh sources
# this and calls doctor_fixture with its deltas; the eval harness runs the
# fixture with --scaffold in an empty workspace (cwd) and the real $HOME is
# unreadable, so the doctor is pointed at ./fixture-repo and ./fixture-home.
#
#   doctor_fixture <linked-skills> <codex-manifest-version>
#     linked-skills            space-separated subset of "tdd debug clean-code"
#                              to symlink into fixture-home (the rest stay
#                              unlinked — the "new skill after a pull" case)
#     codex-manifest-version   version stamped into .codex-plugin/plugin.json
#                              (2.24.0 = in step; 2.23.0 = stale manifest)
# gstack is always the vendor stopgap copy (marker file, no .git).
set -e
doctor_fixture() {
  local linked="$1" codex_version="$2" s
  local R="$PWD/fixture-repo" H="$PWD/fixture-home"
  mkdir -p "$R/skills/tdd" "$R/skills/debug" "$R/skills/clean-code" "$R/.claude-plugin" "$R/.codex-plugin" \
           "$R/.cursor-plugin" "$R/marketing-skills/.claude-plugin" "$H/.claude/skills/gstack"
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
  printf '{ "name": "superskills", "version": "%s" }\n' "$codex_version" > "$R/.codex-plugin/plugin.json"
  printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$R/.cursor-plugin/plugin.json"
  printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$R/.cursor-plugin/marketplace.json"
  printf '{ "name": "superskills-marketing", "version": "2.24.0" }\n' > "$R/marketing-skills/.claude-plugin/plugin.json"
  for s in $linked; do mkdir -p "$H/.claude/skills/$s"; ln -s "$R/skills/$s/SKILL.md" "$H/.claude/skills/$s/SKILL.md"; done
  printf '1.80.0.0\n' > "$H/.claude/skills/gstack/VERSION"; touch "$H/.claude/skills/gstack/.superskills-vendor-copy"
}
