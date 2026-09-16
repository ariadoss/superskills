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
# shellcheck source=scripts/lib/version-lib.sh
. "$_DOCTOR_LIB_DIR/version-lib.sh"

# The manifests the doctor checks: the stamped list from version-lib.sh (the
# same array scripts/sync-version.sh iterates) plus the generated marketing one.
DOCTOR_MANIFESTS=("${SUPERSKILLS_MANIFESTS[@]}" "marketing-skills/.claude-plugin/plugin.json")

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
    _doctor_row "Repo" "blocked" "$root is not a superskills checkout (needs VERSION, setup, skills/). Re-install: git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills && cd ~/.claude/skills/superskills && ./setup"
  fi
}

# doctor_install_kind <root> <claude_skills_dir> [plugin_version]
#   → canonical | dev-repo | plugin | unlinked
# canonical: the repo IS the managed clone at <skills>/superskills
# dev-repo : skills are symlinked into <skills> from a checkout elsewhere
# plugin   : nothing is linked, but superskills is installed as a Claude Code
#            plugin (`claude plugin install superskills@superskills`) — either
#            the CLI reports it (<plugin_version>) or <root> is the plugin
#            cache copy itself. ./setup was never run; that is a valid install
#            of the core + design skills (gstack skills are not part of it).
doctor_install_kind() {
  local root="$1" skills="$2" plugin_version="${3:-}" real_root link target
  real_root="$(_doctor_realpath "$root")"
  if [ -e "$skills/superskills" ] && [ "$(_doctor_realpath "$skills/superskills")" = "$real_root" ]; then
    echo canonical; return 0
  fi
  for link in "$skills"/*/SKILL.md; do
    [ -L "$link" ] || continue
    target="$(_doctor_realpath "$link")"
    case "$target" in "$real_root"/*) echo dev-repo; return 0 ;; esac
  done
  if [ -n "$plugin_version" ]; then echo plugin; return 0; fi
  case "$real_root" in */plugins/cache/*) echo plugin; return 0 ;; esac
  echo unlinked
}

# doctor_check_install <root> <claude_skills_dir> [plugin_version]
doctor_check_install() {
  local kind
  kind="$(doctor_install_kind "$1" "$2" "${3:-}")"
  case "$kind" in
    canonical) _doctor_row "Install" "ready" "canonical install (managed clone at $2/superskills)" ;;
    dev-repo)  _doctor_row "Install" "ready" "dev-repo install (skills symlinked from $1)" ;;
    plugin)    _doctor_row "Install" "ready" "plugin install (superskills@superskills${3:+ v$3}); skills load from the plugin cache, ./setup was not run — gstack, marketing and knowledge-base features need ./setup from a clone" ;;
    *)         _doctor_row "Install" "blocked" "no skill in $2 points at $1 — run ./setup from the repo" ;;
  esac
}

# doctor_check_links <root> <claude_skills_dir> [kind]
# Every skills/*/SKILL.md must be reachable as <skills>/<name>/SKILL.md, where
# <name> is the frontmatter name (falling back to the directory name). A
# plugin install has no links by design: the plugin loader reads skills/ itself.
doctor_check_links() {
  local root="$1" skills="$2" kind="${3:-}" skill_md name link total=0 ok=0 missing="" broken=""
  if [ "$kind" = "plugin" ]; then
    total=$(ls -d "$root"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    _doctor_row "Links" "ready" "$total skills served by the plugin loader from $root/skills (no ./setup symlinks in a plugin install)"
    return 0
  fi
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
# A manifest that is absent is reported, not skipped: silence here would let a
# broken or partial checkout read as "ready".
doctor_check_manifests() {
  local root="$1" v f stale="" missing="" found msg=""
  v="$(tr -d '[:space:]' < "$root/VERSION" 2>/dev/null)"
  for f in "${DOCTOR_MANIFESTS[@]}"; do
    if [ ! -f "$root/$f" ]; then missing="$missing $f"; continue; fi
    found="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/$f" | grep -v "\"$v\"" || true)"
    [ -n "$found" ] && stale="$stale $f"
  done
  if [ -z "$stale" ] && [ -z "$missing" ]; then
    _doctor_row "Manifests" "ready" "all plugin manifests at v$v"
    return 0
  fi
  [ -n "$stale" ] && msg="stale version in:$stale."
  [ -n "$missing" ] && msg="$msg missing:$missing."
  _doctor_row "Manifests" "warning" "$msg Run ./scripts/sync-version.sh (VERSION is the source of truth); a missing manifest means the checkout is older than this doctor or was trimmed"
}

# doctor_check_gstack <gstack_dir> [kind]
# gstack is installed by ./setup, so its absence blocks a setup-based install
# but is only a warning for a plugin install (which never promised it).
doctor_check_gstack() {
  local dir="$1" kind="${2:-}" state v
  state="$(gstack_install_state "$dir")"
  v="$(cat "$dir/VERSION" 2>/dev/null | tr -d '[:space:]')"
  case "$state" in
    real)    _doctor_row "gstack" "ready" "real clone v$v at $dir" ;;
    vendor)  _doctor_row "gstack" "warning" "running on the vendor stopgap copy (v$v) — browser skills (/qa, /browse) need the real clone; ./setup retries it when online" ;;
    partial) _doctor_row "gstack" "blocked" "$dir exists but has no VERSION (broken install) — ./setup moves it aside and re-clones" ;;
    *)
      if [ "$kind" = "plugin" ]; then
        _doctor_row "gstack" "warning" "not installed — the gstack skills (/qa, /browse, /review, /ship …) are not part of a plugin install; run ./setup from a clone to add them"
      else
        _doctor_row "gstack" "blocked" "not installed at $dir — run ./setup"
      fi ;;
  esac
}

# doctor_check_shims <root>
# marketing-skills/plugin-skills/ is a committed tree of relative symlinks (the
# superskills-marketing plugin reads it). A checkout that cannot create
# symlinks (Windows without core.symlinks) materialises them as text files
# holding the target path, and the plugin then silently loads no skills.
doctor_check_shims() {
  local root="$1" shim e ok=0 text=0 dangling=0
  shim="$root/marketing-skills/plugin-skills"   # own line: `local a=$1 b=$a/x` expands b first
  [ -d "$shim" ] || { _doctor_row "Marketing shims" "ready" "no marketing-skills/plugin-skills tree (older checkout; only the superskills-marketing plugin needs it)"; return 0; }
  for e in "$shim"/*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    if [ -L "$e" ]; then
      if [ -f "$e/SKILL.md" ]; then ok=$((ok + 1)); else dangling=$((dangling + 1)); fi
    else
      text=$((text + 1))
    fi
  done
  if [ "$text" -gt 0 ]; then
    _doctor_row "Marketing shims" "warning" "$text of $((ok + text + dangling)) entries are plain files, not symlinks — git checked them out without symlink support. Fix: git config core.symlinks true, then re-checkout marketing-skills/plugin-skills (the superskills-marketing plugin loads nothing until then)"
  elif [ "$dangling" -gt 0 ]; then
    _doctor_row "Marketing shims" "warning" "$dangling dangling links — run ./scripts/sync-marketing-manifest.sh"
  else
    _doctor_row "Marketing shims" "ready" "$ok marketing skills exposed via plugin-skills/"
  fi
}

# doctor_check_command <name> <why>
# Every tool checked this way is optional (bun, bats, clearwing, ffuf), so a
# missing one is a warning. Required pieces have their own checks above.
doctor_check_command() {
  local name="$1" why="$2" path
  if path="$(command -v "$name" 2>/dev/null)"; then
    _doctor_row "$name" "ready" "$path"
  else
    _doctor_row "$name" "warning" "not on PATH — $why"
  fi
}

# _doctor_plugin_version <plugin-list-json> <id-prefix>
# Version of the first plugin whose "id" starts with <id-prefix>, or empty.
# jq when available; otherwise a position-based scan of the flattened text:
# find the id, then the next "version" key after it — which survives nested
# objects and braces inside strings (the CLI prints id before version).
# Exact-prefix match: "superskills@" must not match "superskills-marketing@".
_doctor_plugin_version() {
  local json="$1" pfx="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r --arg p "$pfx" '[.[]? | select((.id // "") | startswith($p)) | .version // empty] | first // empty' 2>/dev/null
    return 0
  fi
  printf '%s\n' "$json" | tr -d '\n' | awk -v pfx="$pfx" '
    {
      rest = $0
      while (match(rest, /"id"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
        id = substr(rest, RSTART, RLENGTH); sub(/^"id"[[:space:]]*:[[:space:]]*"/, "", id); sub(/"$/, "", id)
        rest = substr(rest, RSTART + RLENGTH)
        if (index(id, pfx) == 1 && match(rest, /"version"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
          v = substr(rest, RSTART, RLENGTH); sub(/^"version"[[:space:]]*:[[:space:]]*"/, "", v); sub(/"$/, "", v)
          print v; exit
        }
      }
    }'
}

# _doctor_cli_json <claude_bin>
# `claude plugin list --json`, bounded by DOCTOR_CLI_TIMEOUT seconds (default
# 20) so a hung CLI cannot stall a read-only report. Prints the JSON, or the
# sentinel "__unavailable__" when the binary is missing, fails, or times out.
DOCTOR_CLI_UNAVAILABLE="__unavailable__"
_doctor_cli_json() {
  local bin="$1" secs="${DOCTOR_CLI_TIMEOUT:-20}" out rc
  command -v "$bin" >/dev/null 2>&1 || { printf '%s' "$DOCTOR_CLI_UNAVAILABLE"; return 0; }
  if command -v timeout >/dev/null 2>&1; then out="$(timeout "$secs" "$bin" plugin list --json 2>/dev/null)"; rc=$?
  elif command -v gtimeout >/dev/null 2>&1; then out="$(gtimeout "$secs" "$bin" plugin list --json 2>/dev/null)"; rc=$?
  else out="$(perl -e 'alarm shift; exec @ARGV' "$secs" "$bin" plugin list --json 2>/dev/null)"; rc=$?
  fi
  if [ "$rc" -ne 0 ]; then printf '%s' "$DOCTOR_CLI_UNAVAILABLE"; else printf '%s' "$out"; fi
}

# doctor_check_plugin <root> [claude_bin] [plugin_list_json]
# Whether the plugin-install path (claude plugin install superskills@superskills)
# is in step with the repo. Not being installed as a plugin is fine: the
# ./setup symlink install is the primary path. doctor_report passes the JSON
# it already fetched so the CLI runs once; direct callers may omit it.
doctor_check_plugin() {
  local root="$1" bin="${2:-claude}" out="${3-}" v installed
  v="$(tr -d '[:space:]' < "$root/VERSION" 2>/dev/null)"
  [ $# -ge 3 ] || out="$(_doctor_cli_json "$bin")"
  if [ "$out" = "$DOCTOR_CLI_UNAVAILABLE" ]; then
    _doctor_row "Plugin" "unverified" "could not run '$bin plugin list --json' (not on PATH, failed, or exceeded ${DOCTOR_CLI_TIMEOUT:-20}s)"
    return 0
  fi
  installed="$(_doctor_plugin_version "$out" "superskills@")"
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

# doctor_check_knowledge <knowledge_conf> <home>
# Paths in the conf are written as ~/…; they are expanded against <home>, the
# install being inspected, never the caller's own HOME.
doctor_check_knowledge() {
  local conf="$1" home="$2" n=0 missing="" name path desc url resolved
  [ -s "$conf" ] || { _doctor_row "Knowledge bases" "ready" "none configured (optional; edit $conf)"; return 0; }
  while IFS='|' read -r name path desc url; do
    [ -z "$name" ] && continue; [[ "$name" = \#* ]] && continue
    n=$((n + 1))
    resolved="${path/#\~/$home}"
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
  local rows="$1" name status blocked=0 unverified=0 warning=0 req is_req
  while IFS=$'\t' read -r name status _; do
    [ -z "$name" ] && continue
    case "$status" in
      blocked)
        is_req=0
        for req in $DOCTOR_REQUIRED_CHECKS; do [ "$name" = "$req" ] && is_req=1; done
        if [ "$is_req" -eq 1 ]; then blocked=1; else warning=1; fi ;;
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
  local skills="$home/.claude/skills" rows verdict line name status evidence plugin_version kind
  # The install kind decides how Links and gstack are judged, and a plugin
  # install is only recognisable through the CLI (or the cache path), so probe
  # the plugin once here and pass the answer down.
  local plugin_json
  plugin_json="$(_doctor_cli_json "$bin")"
  plugin_version=""
  [ "$plugin_json" = "$DOCTOR_CLI_UNAVAILABLE" ] || plugin_version="$(_doctor_plugin_version "$plugin_json" "superskills@")"
  kind="$(doctor_install_kind "$root" "$skills" "$plugin_version")"
  rows="$(
    doctor_check_repo "$root"
    doctor_check_install "$root" "$skills" "$plugin_version"
    doctor_check_links "$root" "$skills" "$kind"
    doctor_check_manifests "$root"
    doctor_check_shims "$root"
    doctor_check_gstack "$skills/gstack" "$kind"
    doctor_check_plugin "$root" "$bin" "$plugin_json"
    doctor_check_hook "$root"
    doctor_check_knowledge "$home/.superskills/knowledge.conf" "$home"
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
