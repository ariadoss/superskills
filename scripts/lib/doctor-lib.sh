#!/usr/bin/env bash
# doctor-lib.sh — read-only readiness checks behind /superskills-doctor.
#
# Every check is a pure function that takes its paths as parameters (no $HOME
# inside the library) and prints ONE tab-separated row:
#     <check name> <TAB> <status> <TAB> <evidence or next action>
# where status is one of: ready | warning | blocked | unverified.
#   ready       the check passed
#   warning     usable, but something optional is off (fix at leisure)
#   blocked     a required piece is missing or broken (the next action says what)
#   unverified  the probe itself could not run (e.g. no `claude` binary), so
#               nothing is known either way — never treated as ready
#
# Nothing here writes, installs, clones, or authenticates. scripts/doctor.sh is
# the thin wrapper that supplies real-world defaults. Unit-tested in
# tests/doctor-lib.bats.

_DOCTOR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/gstack-install-lib.sh
. "$_DOCTOR_LIB_DIR/gstack-install-lib.sh"
# shellcheck source=scripts/lib/skills-lib.sh
. "$_DOCTOR_LIB_DIR/skills-lib.sh"

# Manifests that scripts/sync-version.sh stamps. One list, shared with the
# doctor's manifest check (DRY: the sync script and the doctor agree by
# construction).
DOCTOR_MANIFESTS=(
  ".claude-plugin/plugin.json"
  ".claude-plugin/marketplace.json"
  ".codex-plugin/plugin.json"
  ".cursor-plugin/plugin.json"
  ".cursor-plugin/marketplace.json"
  "marketing-skills/.claude-plugin/plugin.json"
)

# Required rows: a "blocked" here blocks the overall verdict. Everything else
# only ever warns.
DOCTOR_REQUIRED_CHECKS="Repo Install Links gstack"

_doctor_row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

_doctor_realpath() {
  readlink -f "$1" 2>/dev/null || perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$1" 2>/dev/null
}

# doctor_check_repo <root>
doctor_check_repo() {
  local root="$1" v
  if [ -f "$root/VERSION" ] && [ -f "$root/setup" ] && [ -d "$root/skills" ]; then
    v="$(tr -d '[:space:]' < "$root/VERSION")"
    _doctor_row "Repo" "ready" "superskills v$v at $root"
  else
    _doctor_row "Repo" "blocked" "$root is not a superskills checkout (needs VERSION, setup, skills/). Re-install: git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills && cd there && ./setup"
  fi
}

# doctor_install_kind <root> <claude_skills_dir> → canonical | dev-repo | unlinked
# canonical: the repo IS the managed clone at <skills>/superskills
# dev-repo : skills are symlinked into <skills> from a checkout elsewhere
doctor_install_kind() {
  local root="$1" skills="$2" real_root link target
  real_root="$(_doctor_realpath "$root")"
  if [ -e "$skills/superskills" ] && [ "$(_doctor_realpath "$skills/superskills")" = "$real_root" ]; then
    echo canonical; return 0
  fi
  for link in "$skills"/*/SKILL.md; do
    [ -L "$link" ] || continue
    target="$(_doctor_realpath "$link")"
    case "$target" in "$real_root"/*) echo dev-repo; return 0 ;; esac
  done
  echo unlinked
}

# doctor_check_install <root> <claude_skills_dir>
doctor_check_install() {
  local kind
  kind="$(doctor_install_kind "$1" "$2")"
  case "$kind" in
    canonical) _doctor_row "Install" "ready" "canonical install (managed clone at $2/superskills)" ;;
    dev-repo)  _doctor_row "Install" "ready" "dev-repo install (skills symlinked from $1)" ;;
    *)         _doctor_row "Install" "blocked" "no skill in $2 points at $1 — run ./setup from the repo" ;;
  esac
}

# doctor_check_links <root> <claude_skills_dir>
# Every skills/*/SKILL.md must be reachable as <skills>/<name>/SKILL.md, where
# <name> is the frontmatter name (falling back to the directory name).
doctor_check_links() {
  local root="$1" skills="$2" skill_md name link total=0 ok=0 missing="" broken=""
  for skill_md in "$root"/skills/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    total=$((total + 1))
    name="$(skill_name_from "$skill_md" "$(basename "$(dirname "$skill_md")")")"
    link="$skills/$name/SKILL.md"
    if [ ! -L "$link" ] && [ ! -f "$link" ]; then
      missing="$missing $name"
    elif [ ! -e "$link" ]; then
      broken="$broken $name"
    else
      ok=$((ok + 1))
    fi
  done
  if [ -z "$missing" ] && [ -z "$broken" ]; then
    _doctor_row "Links" "ready" "$ok/$total skills linked into $skills"
  else
    local msg="$ok/$total linked."
    [ -n "$missing" ] && msg="$msg Not linked:${missing} (new skills stay invisible until ./setup runs)."
    [ -n "$broken" ] && msg="$msg Dangling:${broken} (re-run ./setup)."
    _doctor_row "Links" "blocked" "$msg Run ./setup"
  fi
}

# doctor_check_manifests <root>
doctor_check_manifests() {
  local root="$1" v f stale="" found
  v="$(tr -d '[:space:]' < "$root/VERSION" 2>/dev/null)"
  for f in "${DOCTOR_MANIFESTS[@]}"; do
    [ -f "$root/$f" ] || continue
    found="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/$f" | grep -v "\"$v\"" || true)"
    [ -n "$found" ] && stale="$stale $f"
  done
  if [ -z "$stale" ]; then
    _doctor_row "Manifests" "ready" "all plugin manifests at v$v"
  else
    _doctor_row "Manifests" "warning" "stale version in:$stale — run ./scripts/sync-version.sh (VERSION is the source of truth)"
  fi
}

# doctor_check_gstack <gstack_dir>
doctor_check_gstack() {
  local dir="$1" state v
  state="$(gstack_install_state "$dir")"
  v="$(cat "$dir/VERSION" 2>/dev/null | tr -d '[:space:]')"
  case "$state" in
    real)    _doctor_row "gstack" "ready" "real clone v$v at $dir" ;;
    vendor)  _doctor_row "gstack" "warning" "running on the vendor stopgap copy (v$v) — browser skills (/qa, /browse) need the real clone; ./setup retries it when online" ;;
    partial) _doctor_row "gstack" "blocked" "$dir exists but has no VERSION (broken install) — ./setup moves it aside and re-clones" ;;
    *)       _doctor_row "gstack" "blocked" "not installed at $dir — run ./setup" ;;
  esac
}

# doctor_check_command <name> <why> [required]
# Optional tools warn when missing; pass a third arg "required" to block instead.
doctor_check_command() {
  local name="$1" why="$2" level="${3:-optional}" path
  if path="$(command -v "$name" 2>/dev/null)"; then
    _doctor_row "$name" "ready" "$path"
  elif [ "$level" = "required" ]; then
    _doctor_row "$name" "blocked" "not on PATH — $why"
  else
    _doctor_row "$name" "warning" "not on PATH — $why"
  fi
}

# doctor_check_plugin <root> [claude_bin]
# Whether the plugin-install path (claude plugin install superskills@superskills)
# is in step with the repo. Not being installed as a plugin is fine: the
# ./setup symlink install is the primary path.
doctor_check_plugin() {
  local root="$1" bin="${2:-claude}" v out installed
  v="$(tr -d '[:space:]' < "$root/VERSION" 2>/dev/null)"
  if ! command -v "$bin" >/dev/null 2>&1; then
    _doctor_row "Plugin" "unverified" "claude CLI not on PATH — could not query 'claude plugin list'"
    return 0
  fi
  out="$("$bin" plugin list --json 2>/dev/null)" || {
    _doctor_row "Plugin" "unverified" "'$bin plugin list --json' failed"
    return 0
  }
  installed="$(printf '%s' "$out" | tr -d '\n' | grep -o '"id":"superskills@[^"]*"[^}]*"version":"[^"]*"' | head -1 | sed -E 's/.*"version":"([^"]*)".*/\1/')"
  if [ -z "$installed" ]; then
    _doctor_row "Plugin" "ready" "not installed as a Claude Code plugin (skills are linked by ./setup); optional: /plugin marketplace add ariadoss/superskills"
  elif [ "$installed" = "$v" ]; then
    _doctor_row "Plugin" "ready" "plugin superskills@superskills v$installed matches VERSION"
  else
    _doctor_row "Plugin" "warning" "plugin superskills@superskills is v$installed but the repo is v$v — update the marketplace, then /reload-plugins"
  fi
}

# doctor_check_hook <root>
doctor_check_hook() {
  local root="$1" hooks hook
  hooks="$(git -C "$root" rev-parse --git-path hooks 2>/dev/null || true)"
  case "$hooks" in "") _doctor_row "Post-merge hook" "warning" "$root is not a git checkout — git pull cannot auto-link new skills"; return 0 ;; /*) : ;; *) hooks="$root/$hooks" ;; esac
  hook="$hooks/post-merge"
  if [ -f "$hook" ] && grep -qF "superskills post-merge hook" "$hook" 2>/dev/null; then
    _doctor_row "Post-merge hook" "ready" "installed — git pull re-runs setup"
  else
    _doctor_row "Post-merge hook" "warning" "not installed — after git pull you must run ./setup by hand (./setup installs the hook)"
  fi
}

# doctor_check_knowledge <knowledge_conf>
doctor_check_knowledge() {
  local conf="$1" n=0 missing="" name path desc url resolved
  [ -s "$conf" ] || { _doctor_row "Knowledge bases" "ready" "none configured (optional; edit $conf)"; return 0; }
  while IFS='|' read -r name path desc url; do
    [ -z "$name" ] && continue; [[ "$name" = \#* ]] && continue
    n=$((n + 1))
    resolved="${path/#\~/$HOME}"
    [ -d "$resolved/.git" ] || missing="$missing $name"
  done < "$conf"
  if [ -z "$missing" ]; then
    _doctor_row "Knowledge bases" "ready" "$n configured, all cloned"
  else
    _doctor_row "Knowledge bases" "warning" "$n configured; not cloned:$missing — ./setup clones them"
  fi
}

# doctor_verdict <rows>
# rows: the tab-separated lines from the checks above.
# Never "ready" while any REQUIRED row is blocked or any row is unverified —
# "unknown" is not "fine".
doctor_verdict() {
  local rows="$1" name status blocked=0 unverified=0 warning=0 req
  while IFS=$'\t' read -r name status _; do
    [ -z "$name" ] && continue
    case "$status" in
      blocked)
        for req in $DOCTOR_REQUIRED_CHECKS; do [ "$name" = "$req" ] && blocked=1; done
        [ "$blocked" -eq 1 ] || warning=1 ;;
      unverified) unverified=1 ;;
      warning)    warning=1 ;;
    esac
  done <<< "$rows"
  if [ "$blocked" -eq 1 ]; then echo "blocked"
  elif [ "$unverified" -eq 1 ]; then echo "unverified"
  elif [ "$warning" -eq 1 ]; then echo "ready with warnings"
  else echo "ready"; fi
}

# doctor_report <root> <home> [claude_bin]
# Runs every check against an install rooted at <home> (so a fixture tree or a
# container can be inspected) and prints a markdown table plus the verdict.
doctor_report() {
  local root="$1" home="$2" bin="${3:-claude}"
  local skills="$home/.claude/skills" rows verdict line name status evidence
  rows="$(
    doctor_check_repo "$root"
    doctor_check_install "$root" "$skills"
    doctor_check_links "$root" "$skills"
    doctor_check_manifests "$root"
    doctor_check_gstack "$skills/gstack"
    doctor_check_plugin "$root" "$bin"
    doctor_check_hook "$root"
    doctor_check_knowledge "$home/.superskills/knowledge.conf"
    doctor_check_command bun "gstack's browser tool (/qa, /browse) needs it — curl -fsSL https://bun.sh/install | bash"
    doctor_check_command bats "runs ./tests/run.sh — brew install bats-core"
    doctor_check_command clearwing "needed for /pentest — uv tool install clearwing && clearwing setup"
    doctor_check_command ffuf "needed for /fuzz — brew install ffuf"
  )"
  verdict="$(doctor_verdict "$rows")"
  printf '| Check | Status | Evidence / next action |\n|---|---|---|\n'
  while IFS=$'\t' read -r name status evidence; do
    [ -z "$name" ] && continue
    printf '| %s | %s | %s |\n' "$name" "$status" "$evidence"
  done <<< "$rows"
  printf '\nVerdict: %s\n' "$verdict"
  case "$verdict" in
    blocked)    printf 'A required check is blocked; superskills is NOT ready until its next action is done.\n' ;;
    unverified) printf 'A probe could not run, so readiness is unknown — not "ready".\n' ;;
  esac
}
