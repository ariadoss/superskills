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
# Nothing here installs, clones, authenticates, or writes to the inspected
# install; the only write is a temporary file for the bounded CLI probe.
# scripts/doctor.sh is the thin wrapper that supplies real-world defaults.
# Unit-tested in tests/doctor-lib.bats.

_DOCTOR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/gstack-install-lib.sh
. "$_DOCTOR_LIB_DIR/gstack-install-lib.sh"
# shellcheck source=scripts/lib/skills-lib.sh
. "$_DOCTOR_LIB_DIR/skills-lib.sh"
# shellcheck source=scripts/lib/version-lib.sh
. "$_DOCTOR_LIB_DIR/version-lib.sh"
# shellcheck source=scripts/lib/manifest-lib.sh
. "$_DOCTOR_LIB_DIR/manifest-lib.sh"

DOCTOR_CLI_TIMEOUT_DEFAULT=20
DOCTOR_CLI_UNAVAILABLE="__unavailable__"

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

# doctor_install_kind <root> <claude_skills_dir> [plugin_version] [cli_state]
#   → canonical | dev-repo | plugin | unlinked
# canonical: the repo IS the managed clone at <skills>/superskills
# dev-repo : skills are symlinked into <skills> from a checkout elsewhere
# plugin   : nothing is linked, but superskills is installed and enabled as a
#            Claude Code plugin — the CLI reports it (<plugin_version>), or,
#            only when the CLI could not be asked (<cli_state> is not "ok"),
#            <root> is itself a plugin cache copy. A successful "not installed"
#            answer always wins over the path.
doctor_install_kind() {
  local root="$1" skills="$2" plugin_version="${3:-}" cli_state="${4:-}" real_root link target
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
  if [ "$cli_state" != "ok" ]; then
    case "$real_root" in */plugins/cache/*) echo plugin; return 0 ;; esac
  fi
  echo unlinked
}

# doctor_check_install <root> <claude_skills_dir> [plugin_version] [kind]
# [kind] is doctor_install_kind's answer when the caller already has it (the
# scan walks every link under the skills dir, so doctor_report does it once).
doctor_check_install() {
  local kind="${4:-}"
  [ -n "$kind" ] || kind="$(doctor_install_kind "$1" "$2" "${3:-}")"
  case "$kind" in
    canonical|dev-repo)
      local what="canonical install (managed clone at $2/superskills)"
      [ "$kind" = "dev-repo" ] && what="dev-repo install (skills symlinked from $1)"
      if [ -n "${3:-}" ]; then
        _doctor_row "Install" "warning" "$what AND the superskills@superskills plugin (v$3) — every skill appears twice (/tdd and /superskills:tdd). Keep one: claude plugin uninstall superskills@superskills, or remove the ./setup links"
      else
        _doctor_row "Install" "ready" "$what"
      fi ;;
    plugin)    _doctor_row "Install" "ready" "plugin install (superskills@superskills${3:+ v$3}); skills load from the plugin cache, ./setup was not run — gstack, marketing and knowledge-base features need ./setup from a clone" ;;
    *)         _doctor_row "Install" "blocked" "no skill in $2 points at $1 — run ./setup from the repo" ;;
  esac
}

# _doctor_skill_files <root> [plugin]
# Every SKILL.md the install is expected to expose, in ./setup's order:
# marketing-skills (nested; the plugin-skills/ symlink tree is not followed by
# find), design-skills, skills. With "plugin", only what the root plugin's
# loader reads: skills/ and design-skills/.
_doctor_skill_files() {
  local root="$1" mode="${2:-}"
  if [ "$mode" != "plugin" ] && [ -d "$root/marketing-skills" ]; then
    marketing_skill_files "$root/marketing-skills"
  fi
  ls -d "$root"/design-skills/*/SKILL.md "$root"/skills/*/SKILL.md 2>/dev/null
}

# doctor_check_links <root> <claude_skills_dir> [kind] [install_path] [home]
# Every skill ./setup links (skills/, design-skills/, marketing-skills/) must be
# reachable as <skills>/<name>/SKILL.md and point at the exact file setup would
# have linked: when two sources share a name, the last one in setup's order
# (marketing, then design, then skills) wins. Reported beyond present/absent:
#   corrupt   the winning SKILL.md is not a readable file (blocked)
#   wrong     the link resolves inside this checkout but to another skill (blocked)
#   elsewhere the link resolves into a different checkout (warning)
#   stale     a dangling SKILL.md link no expected skill owns, e.g. left by a
#             moved checkout (warning; listed, never removed)
#   shadowed  a name shared by two sources (informational)
# Pack awareness: when <home>/.superskills/packs.conf exists, only the skills
# the recorded selection installs are expected — a coding-only install is not
# "missing" its unselected marketing/design skills. No packs.conf means a
# pre-packs install: every skill is expected, as before.
# A plugin install has no links by design: the loader reads skills/ and
# design-skills/ itself — from [plugin_install_path] when the CLI reported one
# (the plugin's actual cache copy, which may differ from <root>, e.g. when
# --root/--home inspect someone else's install), else from <root> itself,
# flagged unconfirmed since that is then only an assumption, not a fact the CLI
# gave us.
doctor_check_links() {
  local root="$1" skills="$2" kind="${3:-}" install_path="${4:-}" home="${5:-}" name winner count link resolved real_root entry
  local total=0 ok=0 missing="" broken="" corrupt="" wrong="" elsewhere="" shadowed="" stale="" seen=" " status msg
  if [ "$kind" = "plugin" ]; then
    local serve_root="$root" confirmed=1
    if [ -n "$install_path" ]; then serve_root="$install_path"; else confirmed=0; fi
    # No links to check, but the loader can only serve files that are readable.
    local f bad=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      total=$((total + 1))
      if [ -f "$f" ] && [ -r "$f" ]; then ok=$((ok + 1)); else bad="$bad $(basename "$(dirname "$f")")"; fi
    done < <(_doctor_skill_files "$serve_root" plugin)
    if [ "$total" -eq 0 ]; then
      _doctor_row "Links" "blocked" "no skills found under $serve_root/skills or $serve_root/design-skills — the plugin serves nothing; reinstall the plugin"
    elif [ -n "$bad" ]; then
      _doctor_row "Links" "blocked" "$ok/$total plugin skills readable. SKILL.md is not a readable file:$bad — reinstall the plugin"
    elif [ "$confirmed" -eq 1 ]; then
      _doctor_row "Links" "ready" "$total skills served by the plugin loader from $serve_root/skills and $serve_root/design-skills (no ./setup symlinks in a plugin install; confirmed via the CLI's installPath)"
    else
      _doctor_row "Links" "ready" "$total skills served by the plugin loader from $serve_root/skills and $serve_root/design-skills — unconfirmed: the CLI did not report an installPath, so this assumes --root is the plugin's serving copy"
    fi
    return 0
  fi
  real_root="$(_doctor_realpath "$root")"
  local expected
  if [ -n "$home" ] && [ -f "$home/.superskills/packs.conf" ]; then
    SS_PACKS_CONF="$home/.superskills/packs.conf" packs_load
    expected="$(selected_source_paths "$root" "$root/skills" "$root/design-skills" "$root/marketing-skills")"
  else
    expected="$(_doctor_skill_files "$root")"
  fi
  while IFS=$'\t' read -r name winner count; do
    [ -n "$name" ] || continue
    seen="$seen$name "
    total=$((total + 1))
    [ "$count" -gt 1 ] && shadowed="$shadowed $name"
    link="$skills/$name/SKILL.md"
    if [ ! -f "$winner" ] || [ ! -r "$winner" ]; then
      corrupt="$corrupt $name"
    elif [ ! -L "$link" ] && [ ! -f "$link" ]; then
      missing="$missing $name"
    elif [ ! -e "$link" ]; then
      broken="$broken $name"
    elif [ "$link" -ef "$winner" ]; then
      ok=$((ok + 1))   # the common case, decided by the test builtin without resolving paths
    else
      resolved="$(_doctor_realpath "$link")"
      case "$resolved" in
        "$real_root"/*) wrong="$wrong ${name} (points at ${resolved}, expected ${winner})" ;;
        *) elsewhere="$elsewhere ${name} (${resolved})" ;;
      esac
    fi
  done < <(printf '%s\n' "$expected" | skill_names_from_files | awk -F'\t' '
    { if (!($2 in first)) { first[$2] = NR; order[++n] = $2 }; win[$2] = $1; cnt[$2]++ }
    END { for (i = 1; i <= n; i++) print order[i] "\t" win[order[i]] "\t" cnt[order[i]] }')
  for entry in "$skills"/*/SKILL.md; do
    [ -L "$entry" ] && [ ! -e "$entry" ] || continue
    name="$(basename "$(dirname "$entry")")"
    case "$seen" in *" $name "*) ;; *) stale="$stale $name" ;; esac
  done
  if [ -n "$missing$broken$corrupt$wrong" ]; then status="blocked"
  elif [ -n "$elsewhere$stale" ]; then status="warning"
  else status="ready"; fi
  msg="$ok/$total skills linked into $skills."
  [ -n "$missing" ] && msg="$msg Not linked:${missing} (new skills stay invisible until ./setup runs)."
  [ -n "$broken" ] && msg="$msg Dangling:${broken} (re-run ./setup)."
  [ -n "$corrupt" ] && msg="$msg SKILL.md is not a readable file:${corrupt} (restore it from git)."
  [ -n "$wrong" ] && msg="$msg Linked to the wrong skill:${wrong} (re-run ./setup)."
  [ -n "$elsewhere" ] && msg="$msg Linked to another checkout:${elsewhere} (run ./setup from the checkout you want loaded)."
  [ -n "$stale" ] && msg="$msg Stale links no skill owns:${stale} (safe to delete those dirs)."
  [ -n "$shadowed" ] && msg="$msg Names shadowed by a same-named skill (setup's order: skills > design > marketing):${shadowed}."
  [ "$status" = "blocked" ] && msg="$msg Run ./setup"
  _doctor_row "Links" "$status" "$msg"
}

# doctor_check_manifests <root>
# Each manifest must exist, carry the VERSION at least once and no other
# version, and parse as JSON (checked when jq is present). Absent, empty or
# unparsable manifests are reported, never read as "ready".
doctor_check_manifests() {
  local root="$1" v f stale="" missing="" noversion="" invalid="" msg="" jq="${DOCTOR_JQ:-jq}" have_jq=0
  command -v "$jq" >/dev/null 2>&1 && have_jq=1
  v="$(tr -d '[:space:]' < "$root/VERSION" 2>/dev/null)"
  local manifest_version
  for f in "${DOCTOR_MANIFESTS[@]}"; do
    if [ ! -f "$root/$f" ]; then missing="$missing $f"; continue; fi
    if [ "$have_jq" -eq 1 ]; then
      if ! "$jq" -e . "$root/$f" >/dev/null 2>&1; then invalid="$invalid $f"; continue; fi
      # The top-level "version" field only — a match nested in another object
      # (e.g. a "source" block) is not this manifest's own version.
      manifest_version="$("$jq" -r '.version // empty' "$root/$f" 2>/dev/null)"
      if [ -z "$manifest_version" ]; then
        # A marketplace manifest nests version per plugin entry; check those too.
        manifest_version="$("$jq" -r '(.plugins // [])[0].version // empty' "$root/$f" 2>/dev/null)"
      fi
      if [ -z "$manifest_version" ]; then noversion="$noversion $f"; continue; fi
      [ "$manifest_version" = "$v" ] || stale="$stale $f"
    else
      if ! grep -q '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/$f"; then noversion="$noversion $f"; continue; fi
      if grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/$f" | grep -qv "\"$v\""; then stale="$stale $f"; fi
    fi
  done
  if [ -z "$stale$missing$noversion$invalid" ]; then
    _doctor_row "Manifests" "ready" "all plugin manifests at v$v"
    return 0
  fi
  [ -n "$stale" ] && msg="stale version in:$stale."
  [ -n "$noversion" ] && msg="$msg no version field (empty or truncated?) in:$noversion."
  [ -n "$invalid" ] && msg="$msg invalid JSON in:$invalid."
  [ -n "$missing" ] && msg="$msg missing:$missing."
  _doctor_row "Manifests" "warning" "${msg# } Run ./scripts/sync-version.sh (VERSION is the source of truth); restore a damaged manifest from git"
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
# marketing-skills/plugin-skills/ must hold exactly one relative symlink per
# marketing skill, named by its frontmatter name and resolving to that skill's
# directory (the superskills-marketing plugin reads it). Compared name by name
# against skill_entries, so a renamed skill, two links to one skill, a dangling
# or leftover entry, or an interrupted sync cannot hide behind a matching count.
# Entries that are plain files mean git checked the tree out without symlink
# support (Windows, core.symlinks=false).
doctor_check_shims() {
  local root="$1" mk shim name rel e ok=0 text=0 expected=0 missing="" wrong="" dangling="" extra="" want=" " msg
  mk="$root/marketing-skills"; shim="$mk/plugin-skills"   # own line: `local a=$1 b=$a/x` expands b first
  local entries=""
  [ -d "$mk" ] && entries="$(skill_entries "$mk")"
  expected="$(printf '%s\n' "$entries" | grep -c . || true)"
  if [ ! -d "$shim" ]; then
    if [ "$expected" -eq 0 ]; then
      _doctor_row "Marketing shims" "ready" "no marketing-skills/plugin-skills tree (older checkout; only the superskills-marketing plugin needs it)"
    else
      _doctor_row "Marketing shims" "warning" "marketing-skills/plugin-skills/ is missing but $expected marketing skills exist — run ./scripts/sync-marketing-manifest.sh (the superskills-marketing plugin loads nothing until then)"
    fi
    return 0
  fi
  while IFS=$'\t' read -r name rel; do
    [ -n "$name" ] || continue
    want="$want$name "
    e="$shim/$name"
    if [ -L "$e" ]; then
      if [ ! -e "$e" ]; then dangling="$dangling $name"
      elif [ "$e" -ef "$mk/$rel" ]; then ok=$((ok + 1))
      else wrong="$wrong $name"; fi
    elif [ -e "$e" ]; then text=$((text + 1))
    else missing="$missing $name"; fi
  done <<< "$entries"
  for e in "$shim"/* "$shim"/.[!.]*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    name="$(basename "$e")"
    case "$want" in *" $name "*) continue ;; esac
    if [ -L "$e" ] && [ ! -e "$e" ]; then dangling="$dangling $name"
    elif [ -L "$e" ]; then extra="$extra $name"
    else text=$((text + 1)); fi
  done
  if [ "$text" -gt 0 ]; then
    _doctor_row "Marketing shims" "warning" "$text entries in plugin-skills/ are plain files, not symlinks — git checked them out without symlink support. Fix: git config core.symlinks true, then re-checkout marketing-skills/plugin-skills (the superskills-marketing plugin loads nothing until then)"
  elif [ -n "$missing$wrong$dangling$extra" ]; then
    msg="$ok of $expected marketing skills exposed via plugin-skills/."
    [ -n "$missing" ] && msg="$msg No shim for:${missing}."
    [ -n "$wrong" ] && msg="$msg Shim points at the wrong skill:${wrong}."
    [ -n "$dangling" ] && msg="$msg dangling links:${dangling}."
    [ -n "$extra" ] && msg="$msg Not a current skill name:${extra}."
    _doctor_row "Marketing shims" "warning" "$msg Run ./scripts/sync-marketing-manifest.sh"
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

# _doctor_have_jq — the plugin probe reads JSON with jq only ($DOCTOR_JQ,
# default jq). Hand-written JSON parsing produced wrong verdicts in review, so
# without jq the plugin state is reported as not checked, never guessed.
_doctor_have_jq() { command -v "${DOCTOR_JQ:-jq}" >/dev/null 2>&1; }

# _doctor_plugin_info <plugin-list-json> <id-prefix>
# "<version>\t<enabled>" for the first plugin whose id starts with <id-prefix>
# (exact prefix: "superskills@" never matches "superskills-marketing@"), or
# nothing. <enabled> is "false" only when the CLI says so explicitly.
_doctor_plugin_info() {
  printf '%s' "$1" | "${DOCTOR_JQ:-jq}" -r --arg p "$2" \
    '[.[]? | select(type == "object" and ((.id // "") | startswith($p)))] | first // empty
     | "\(.version // "")\t\(if .enabled == false then "false" else "true" end)\t\(.installPath // "")"' 2>/dev/null
}

# _doctor_plugin_version <plugin-list-json> <id-prefix> — the version field of
# _doctor_plugin_info (enabled or not).
_doctor_plugin_version() { _doctor_plugin_info "$1" "$2" | cut -f1; }

# _doctor_is_json_array <text> — true when <text> parses as a JSON array (jq).
_doctor_is_json_array() {
  printf '%s' "$1" | "${DOCTOR_JQ:-jq}" -e 'type == "array"' >/dev/null 2>&1
}

# _doctor_run_bounded <seconds> <out_file> <cmd…>
# Run <cmd> with stdout to <out_file>, killing it after <seconds>. Output goes
# to a file, not a pipe, so a child that keeps stdout open cannot hold the
# caller; the wait is a builtin loop, so no timeout/gtimeout/perl is needed.
# Returns the command's status, or 124 when it was killed.
_doctor_run_bounded() {
  local secs="$1" out="$2" pid ticks=0 limit
  shift 2
  limit=$((secs * 10))
  # A new process group (setsid when available, else bash job control) so the
  # kill below reaches anything the command forks, not just the direct child —
  # and killing this function itself (e.g. the whole script) still leaves the
  # group to become a set of unreaped orphans, so also trap our own exit.
  if command -v setsid >/dev/null 2>&1; then
    setsid "$@" > "$out" 2>/dev/null &
  else
    set -m
    "$@" > "$out" 2>/dev/null &
  fi
  pid=$!
  trap 'kill -TERM -- -"$pid" 2>/dev/null; kill -KILL -- -"$pid" 2>/dev/null' EXIT
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge "$limit" ]; then
      kill -TERM -- -"$pid" 2>/dev/null; sleep 0.1; kill -KILL -- -"$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      trap - EXIT
      return 124
    fi
    sleep 0.1; ticks=$((ticks + 1))
  done
  wait "$pid"
  trap - EXIT
  command -v setsid >/dev/null 2>&1 || set +m
}

# _doctor_cli_json <claude_bin> [home]
# `claude plugin list --json`, bounded by DOCTOR_CLI_TIMEOUT seconds, asked
# about <home> (the install being inspected): when <home> is not the caller's
# own HOME, the CLI runs with HOME=<home> and without CLAUDE_CONFIG_DIR, so the
# caller's plugins are never reported as the inspected install's. Prints the
# JSON, or DOCTOR_CLI_UNAVAILABLE when the binary is missing, fails, times out,
# or (jq present) prints anything that is not a JSON array.
_doctor_cli_json() {
  local bin="$1" home="${2:-$HOME}" secs="${DOCTOR_CLI_TIMEOUT:-$DOCTOR_CLI_TIMEOUT_DEFAULT}" tmp rc out
  command -v "$bin" >/dev/null 2>&1 || { printf '%s' "$DOCTOR_CLI_UNAVAILABLE"; return 0; }
  tmp="$(mktemp "${TMPDIR:-/tmp}/superskills-doctor.XXXXXX")" || { printf '%s' "$DOCTOR_CLI_UNAVAILABLE"; return 0; }
  if [ "$home" = "$HOME" ]; then
    _doctor_run_bounded "$secs" "$tmp" "$bin" plugin list --json; rc=$?
  else
    _doctor_run_bounded "$secs" "$tmp" env -u CLAUDE_CONFIG_DIR HOME="$home" "$bin" plugin list --json; rc=$?
  fi
  out="$(cat "$tmp" 2>/dev/null)"; rm -f "$tmp"
  if [ "$rc" -ne 0 ]; then printf '%s' "$DOCTOR_CLI_UNAVAILABLE"; return 0; fi
  if _doctor_have_jq && ! _doctor_is_json_array "$out"; then printf '%s' "$DOCTOR_CLI_UNAVAILABLE"; return 0; fi
  printf '%s' "$out"
}

# doctor_check_plugin <root> [claude_bin] [plugin_list_json] [kind]
# Whether the plugin-install path (claude plugin install superskills@superskills)
# is in step with the repo. Not being installed as a plugin is fine: the
# ./setup symlink install is the primary path. doctor_report passes the JSON
# it already fetched so the CLI runs once; direct callers may omit it.
doctor_check_plugin() {
  local root="$1" bin="${2:-claude}" out="${3-}" kind="${4:-}" v info installed enabled
  v="$(tr -d '[:space:]' < "$root/VERSION" 2>/dev/null)"
  [ $# -ge 3 ] || out="$(_doctor_cli_json "$bin")"
  if [ "$out" = "$DOCTOR_CLI_UNAVAILABLE" ]; then
    _doctor_row "Plugin" "unverified" "could not read '$bin plugin list --json' (not on PATH, failed, printed non-JSON, or exceeded ${DOCTOR_CLI_TIMEOUT:-$DOCTOR_CLI_TIMEOUT_DEFAULT}s)"
    return 0
  fi
  if ! _doctor_have_jq; then
    # For a plugin install the plugin IS the install, so not checking it leaves
    # readiness unknown; for a ./setup install it is only an optional extra.
    if [ "$kind" = "plugin" ]; then
      _doctor_row "Plugin" "unverified" "plugin install, but its state (enabled, version) was not checked: jq is not installed (brew install jq / apt install jq)"
    else
      _doctor_row "Plugin" "warning" "plugin state not checked: jq is not installed (brew install jq / apt install jq)"
    fi
    return 0
  fi
  info="$(_doctor_plugin_info "$out" "superskills@")"
  installed="$(printf '%s' "$info" | cut -f1)"; enabled="$(printf '%s' "$info" | cut -f2)"
  if [ -z "$info" ]; then
    _doctor_row "Plugin" "ready" "not installed as a Claude Code plugin (skills are linked by ./setup); optional: /plugin marketplace add ariadoss/superskills"
  elif [ "$enabled" = "false" ]; then
    _doctor_row "Plugin" "warning" "plugin superskills@superskills${installed:+ v$installed} is installed but disabled — its skills are not loaded (claude plugin enable superskills@superskills, or uninstall it)"
  elif [ "$installed" = "$v" ]; then
    _doctor_row "Plugin" "ready" "plugin superskills@superskills v$installed matches VERSION"
  else
    _doctor_row "Plugin" "warning" "plugin superskills@superskills is v${installed:-unknown} but the repo is v$v — update the marketplace, then /reload-plugins"
  fi
}

# doctor_check_hook <root>
doctor_check_hook() {
  local root="$1" hooks hook
  hooks="$(git -C "$root" rev-parse --git-path hooks 2>/dev/null || true)"
  case "$hooks" in "") _doctor_row "Post-merge hook" "warning" "$root is not a git checkout — git pull cannot auto-link new skills"; return 0 ;; /*) : ;; *) hooks="$root/$hooks" ;; esac
  hook="$hooks/post-merge"
  if [ -f "$hook" ] && grep -qF "superskills post-merge hook" "$hook" 2>/dev/null && [ ! -x "$hook" ]; then
    _doctor_row "Post-merge hook" "warning" "installed but not executable, so git will not run it — chmod +x $hook (or re-run ./setup)"
  elif [ -f "$hook" ] && grep -qF "superskills post-merge hook" "$hook" 2>/dev/null; then
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
  local plugin_json cli_state="unavailable" info plugin_install_path=""
  plugin_json="$(_doctor_cli_json "$bin" "$home")"
  plugin_version=""
  if [ "$plugin_json" != "$DOCTOR_CLI_UNAVAILABLE" ] && _doctor_have_jq; then
    cli_state="ok"
    info="$(_doctor_plugin_info "$plugin_json" "superskills@")"
    # Only an enabled plugin serves skills, so only it can make this a plugin install.
    if [ -n "$info" ] && [ "$(printf '%s' "$info" | cut -f2)" != "false" ]; then
      plugin_version="$(printf '%s' "$info" | cut -f1)"
      plugin_install_path="$(printf '%s' "$info" | cut -f3)"
    fi
  fi
  kind="$(doctor_install_kind "$root" "$skills" "$plugin_version" "$cli_state")"
  rows="$(
    doctor_check_repo "$root"
    doctor_check_install "$root" "$skills" "$plugin_version" "$kind"
    doctor_check_links "$root" "$skills" "$kind" "$plugin_install_path" "$home"
    doctor_check_manifests "$root"
    doctor_check_shims "$root"
    doctor_check_gstack "$skills/gstack" "$kind"
    doctor_check_plugin "$root" "$bin" "$plugin_json" "$kind"
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
