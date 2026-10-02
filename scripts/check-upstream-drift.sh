#!/usr/bin/env bash
# check-upstream-drift.sh — periodic "should we upgrade the vendored pentest
# tools?" check, run by /daily-qa. Report-only: it NEVER upgrades anything
# (refreshes are deliberate via scripts/sync-*.sh, by design).
#
# Compares, for each tool:
#   shannon    vendored tag (vendor/shannon/UPSTREAM) vs upstream's latest
#              stable tag
#   clearwing  installed commit (uv direct_url.json) vs the vendored pin
#              (vendor/clearwing/UPSTREAM) vs upstream HEAD — by COMMIT,
#              because upstream's version string is ambiguous (tag v1.0.0
#              points at an older commit than the code that reports 1.0.0)
#
# Offline-tolerant: a failed network probe prints "unverified", never
# "up to date" (never infer success). Exit status is always 0 — the output
# is evidence for a report, not a gate.
#
# Sourced for its pure functions by tests/upstream-drift.bats; run directly
# for the live check.

cwdrift_repo_root() { cd "$(dirname "$1")/.." && pwd; }

# cwdrift_field <upstream-file> <Field> — first matching "Field: value" line.
cwdrift_field() {
  sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1
}

# cwdrift_latest_tag <ls-remote-tags output> — highest stable semver tag
# (v-prefixed or bare), ignoring peeled ^{} entries, branches and
# pre-release/non-semver names. Numeric compare in awk: no sort -V, which
# macOS BSD sort lacks.
cwdrift_latest_tag() {
  printf '%s\n' "$1" | awk '
    {
      if ($2 !~ /^refs\/tags\//) next
      tag = substr($2, 11)
      if (tag ~ /\^\{\}$/) next
      if (tag !~ /^v?[0-9]+\.[0-9]+\.[0-9]+$/) next
      v = tag; sub(/^v/, "", v); split(v, p, ".")
      key = p[1] * 1000000 + p[2] * 1000 + p[3]
      if (key > best) { best = key; besttag = tag }
    }
    END { if (besttag != "") print besttag }
  '
}

cwdrift_shannon_report() {
  local vendor="$1" latest="$2" tag
  tag="$(cwdrift_field "$vendor/UPSTREAM" "Tag")"
  if [ -z "$latest" ]; then
    echo "shannon: vendored ${tag:-unknown}, upstream latest unverified (offline or no tags reachable) — not claimed up to date"
    return 0
  fi
  if [ "$latest" = "$tag" ]; then
    echo "shannon: vendored $tag, upstream latest $latest — up to date"
  else
    echo "shannon: vendored $tag, upstream latest $latest — upgrade available:"
    echo "  scripts/sync-shannon.sh --tag $latest && ./tests/run.sh   # then shannon-agent-driven.sh prepare"
  fi
}

cwdrift_clearwing_report() {
  local vendor="$1" installed="$2" head="$3" latest="$4" pin pinsha
  pin="$(cwdrift_field "$vendor/UPSTREAM" "Pin")"
  pinsha="$(printf '%s' "$pin" | grep -oE '[0-9a-f]{40}' | head -1)"
  echo "clearwing: installed $(printf %.8s "${installed:-unknown}") / vendored pin $(printf %.8s "${pinsha:-unknown}") (latest tag: ${latest:-unverified})"
  if [ -n "$pinsha" ] && [ -n "$installed" ] && [ "$installed" != "$pinsha" ]; then
    echo "  RUNTIME DRIFT: the installed tool is not the verified snapshot — re-pin the install"
    echo "  (see vendor/clearwing/UPSTREAM) or re-verify the Mode 3 bridge contract against it."
  fi
  if [ -z "$head" ]; then
    echo "  upstream HEAD unverified (offline?) — not claimed up to date"
  elif [ "$head" != "$pinsha" ]; then
    echo "  upstream HEAD $(printf %.8s "$head") is AHEAD of the pin — upgrade available:"
    echo "  scripts/sync-clearwing.sh --rev <commit-or-tag> && ./tests/run.sh"
  else
    echo "  up to date (installed = pin = upstream HEAD)"
  fi
}

# The installed clearwing's source commit, from uv's direct_url.json record.
cwdrift_installed_rev() {
  local receipt
  receipt="$(find "${UV_TOOL_DIR:-$HOME/.local/share/uv}/tools/clearwing" -name direct_url.json 2>/dev/null | head -1)"
  [ -n "$receipt" ] || return 0
  grep -oE '"commit_id": *"[0-9a-f]{40}"' "$receipt" | grep -oE '[0-9a-f]{40}' | head -1
}

cwdrift_main() {
  local root; root="$(cwdrift_repo_root "${BASH_SOURCE[0]}")"
  local shannon_tags cw_tags cw_head installed
  shannon_tags="$(git ls-remote --tags https://github.com/KeygraphHQ/shannon 2>/dev/null || true)"
  cw_tags="$(git ls-remote --tags https://github.com/Lazarus-AI/clearwing 2>/dev/null || true)"
  cw_head="$(git ls-remote https://github.com/Lazarus-AI/clearwing HEAD 2>/dev/null | awk '{print $1}')"
  installed="$(cwdrift_installed_rev)"

  echo "== vendored-tool upstream drift (report-only; upgrades are deliberate, never automatic) =="
  if [ -f "$root/vendor/shannon/UPSTREAM" ]; then
    cwdrift_shannon_report "$root/vendor/shannon" "$(cwdrift_latest_tag "$shannon_tags")"
  else
    echo "shannon: no vendor/shannon/UPSTREAM — is the vendored snapshot missing?"
  fi
  if [ -f "$root/vendor/clearwing/UPSTREAM" ]; then
    cwdrift_clearwing_report "$root/vendor/clearwing" "$installed" "$cw_head" "$(cwdrift_latest_tag "$cw_tags")"
  else
    echo "clearwing: no vendor/clearwing/UPSTREAM — is the vendored snapshot missing?"
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cwdrift_main "$@"
fi
