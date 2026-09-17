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

# doctor_check_links <root> <claude_skills_dir> [kind]
# Every skill ./setup links (skills/, design-skills/, marketing-skills/) must be
# reachable as <skills>/<name>/SKILL.md, where <name> is the frontmatter name
# (falling back to the directory name). Beyond present/absent it reports:
#   shadowed  a name shared by two sources — setup's override order picks one
#             (informational; the status does not change)
#   elsewhere a link that resolves, but into a different checkout, so this
#             checkout's copy is not the one Claude Code loads (warning)
#   stale     a dangling SKILL.md link under <skills> that no expected skill
#             owns, e.g. left by a moved checkout (warning; listed, never removed)
# A plugin install has no links by design: the loader reads skills/ and
# design-skills/ itself.
doctor_check_links() {
  local root="$1" skills="$2" kind="${3:-}" skill_md name link resolved real_root entry
  local total=0 ok=0 missing="" broken="" elsewhere="" shadowed="" stale="" seen=" " status msg
  if [ "$kind" = "plugin" ]; then
    total=$(_doctor_skill_files "$root" plugin | wc -l | tr -d ' ')
    _doctor_row "Links" "ready" "$total skills served by the plugin loader from $root/skills and $root/design-skills (no ./setup symlinks in a plugin install)"
    return 0
  fi
  real_root="$(_doctor_realpath "$root")"
  while IFS= read -r skill_md; do
    [ -f "$skill_md" ] || continue
    name="$(skill_name_from "$skill_md" "$(basename "$(dirname "$skill_md")")")"
    case "$seen" in *" $name "*) shadowed="$shadowed $name"; continue ;; esac
    seen="$seen$name "
    total=$((total + 1))
    link="$skills/$name/SKILL.md"
    if [ ! -L "$link" ] && [ ! -f "$link" ]; then
      missing="$missing $name"
    elif [ ! -e "$link" ]; then
      broken="$broken $name"
    else
      resolved="$(_doctor_realpath "$link")"
      case "$resolved" in
        "$real_root"/*) ok=$((ok + 1)) ;;
        *) elsewhere="$elsewhere ${name} (${resolved})" ;;
      esac
    fi
  done < <(_doctor_skill_files "$root")
  for entry in "$skills"/*/SKILL.md; do
    [ -L "$entry" ] && [ ! -e "$entry" ] || continue
    name="$(basename "$(dirname "$entry")")"
    case "$seen" in *" $name "*) ;; *) stale="$stale $name" ;; esac
  done
  if [ -n "$missing" ] || [ -n "$broken" ]; then status="blocked"
  elif [ -n "$elsewhere" ] || [ -n "$stale" ]; then status="warning"
  else status="ready"; fi
  msg="$ok/$total skills linked into $skills."
  [ -n "$missing" ] && msg="$msg Not linked:${missing} (new skills stay invisible until ./setup runs)."
  [ -n "$broken" ] && msg="$msg Dangling:${broken} (re-run ./setup)."
  [ -n "$elsewhere" ] && msg="$msg Linked to another checkout:${elsewhere} (run ./setup from the checkout you want loaded)."
  [ -n "$stale" ] && msg="$msg Stale links no skill owns:${stale} (safe to delete those dirs)."
  [ -n "$shadowed" ] && msg="$msg Names shadowed by a same-named skill (setup's order: skills > design > marketing):${shadowed}."
  [ "$status" = "blocked" ] && msg="$msg Run ./setup"
  _doctor_row "Links" "$status" "$msg"
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
# marketing-skills/plugin-skills/ is a committed tree of relative symlinks, one
# per marketing skill (the superskills-marketing plugin reads it). Three ways it
# can silently expose fewer skills than exist: a checkout without symlink
# support (Windows, core.symlinks=false) materialises them as text files; a
# moved skill leaves a dangling link; an interrupted sync (it rebuilds the tree
# from scratch) leaves it empty or partial. All three warn with the fix.
doctor_check_shims() {
  local root="$1" shim e ok=0 text=0 dangling=0 expected
  shim="$root/marketing-skills/plugin-skills"   # own line: `local a=$1 b=$a/x` expands b first
  expected="$(_doctor_skill_files "$root" | grep -cF "$root/marketing-skills/" || true)"
  if [ ! -d "$shim" ]; then
    if [ "$expected" -eq 0 ]; then
      _doctor_row "Marketing shims" "ready" "no marketing-skills/plugin-skills tree (older checkout; only the superskills-marketing plugin needs it)"
    else
      _doctor_row "Marketing shims" "warning" "marketing-skills/plugin-skills/ is missing but $expected marketing skills exist — run ./scripts/sync-marketing-manifest.sh (the superskills-marketing plugin loads nothing until then)"
    fi
    return 0
  fi
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
  elif [ "$ok" -lt "$expected" ]; then
    _doctor_row "Marketing shims" "warning" "$ok of $expected marketing skills exposed via plugin-skills/ (interrupted or stale sync) — run ./scripts/sync-marketing-manifest.sh"
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
# Version of the first plugin whose "id" starts with <id-prefix> (and that has
# a version), or empty. Exact-prefix match: "superskills@" never matches
# "superskills-marketing@". Uses jq when present ($DOCTOR_JQ, default jq);
# otherwise a small awk JSON scanner that tracks strings, escapes and nesting
# depth, so "id" and "version" are read only as top-level keys of the same
# array element — never from a nested object or a neighbouring plugin.
_doctor_plugin_version() {
  local json="$1" pfx="$2" jq="${DOCTOR_JQ:-jq}"
  if command -v "$jq" >/dev/null 2>&1; then
    printf '%s' "$json" | "$jq" -r --arg p "$pfx" '[.[]? | select((.id // "") | startswith($p)) | .version // empty] | first // empty' 2>/dev/null
    return 0
  fi
  printf '%s\n' "$json" | awk -v pfx="$pfx" '
    { s = s $0 "\n" }
    END {
      n = length(s); depth = 0; instr = 0; esc = 0; expect = 0; key = ""; buf = ""
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (instr) {
          if (esc) { buf = buf c; esc = 0; continue }
          if (c == "\\") { esc = 1; continue }
          if (c != "\"") { buf = buf c; continue }
          instr = 0
          if (depth == 2) {
            if (expect) { if (key == "id") id = buf; else if (key == "version") ver = buf; expect = 0 }
            else pending = buf
          }
          continue
        }
        if (c == "\"") { instr = 1; buf = ""; continue }
        if (c == ":") { if (depth == 2) { key = pending; expect = 1 }; continue }
        if (c == ",") { if (depth == 2) expect = 0; continue }
        if (c == "{" || c == "[") { if (depth == 2) expect = 0; depth++; if (c == "{" && depth == 2) { id = ""; ver = "" }; continue }
        if (c == "}" || c == "]") {
          if (c == "}" && depth == 2 && index(id, pfx) == 1 && ver != "") { print ver; exit }
          depth--; continue
        }
      }
    }'
}

# _doctor_is_json_array <text> — true when <text> is a JSON array. Uses jq
# when present ($DOCTOR_JQ, default jq). Without jq, an awk tokenizer checks the
# text is a well-formed array: every character outside strings is structural,
# whitespace, part of a number, or part of true/false/null; strings terminate;
# brackets balance and close exactly once. That rejects error messages that
# merely happen to be wrapped in brackets.
_doctor_is_json_array() {
  local jq="${DOCTOR_JQ:-jq}"
  if command -v "$jq" >/dev/null 2>&1; then
    printf '%s' "$1" | "$jq" -e 'type == "array"' >/dev/null 2>&1
    return
  fi
  printf '%s\n' "$1" | awk '
    { s = s $0 "\n" }
    END {
      n = length(s); depth = 0; instr = 0; esc = 0; started = 0; closed = 0; word = ""; innum = 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (instr) {
          if (esc) esc = 0
          else if (c == "\\") esc = 1
          else if (c == "\"") instr = 0
          continue
        }
        if (innum && c ~ /[0-9.eE+-]/) continue
        innum = 0
        if (c ~ /[a-z]/) { word = word c; continue }
        if (word != "") { if (word != "true" && word != "false" && word != "null") exit 1; word = "" }
        if (c ~ /[0-9-]/ && started && !closed) { innum = 1; continue }
        if (c ~ /[ \t\r\n]/) continue
        if (closed) exit 1
        if (!started) { if (c != "[") exit 1; started = 1; depth = 1; continue }
        if (c == "\"") { instr = 1; continue }
        if (c == "[" || c == "{") { depth++; continue }
        if (c == "]" || c == "}") { depth--; if (depth < 0) exit 1; if (depth == 0) closed = 1; continue }
        if (c == "," || c == ":") continue
        exit 1
      }
      if (word != "" && word != "true" && word != "false" && word != "null") exit 1
      exit (started && closed && !instr) ? 0 : 1
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
  # Exit 0 is not enough: an error printed to stdout must not read as "no plugins".
  if [ "$rc" -ne 0 ] || ! _doctor_is_json_array "$out"; then printf '%s' "$DOCTOR_CLI_UNAVAILABLE"; else printf '%s' "$out"; fi
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
    _doctor_row "Plugin" "unverified" "could not read '$bin plugin list --json' (not on PATH, failed, printed non-JSON, or exceeded ${DOCTOR_CLI_TIMEOUT:-20}s)"
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
    doctor_check_install "$root" "$skills" "$plugin_version" "$kind"
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
