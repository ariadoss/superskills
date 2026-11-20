#!/usr/bin/env bash
# suite-stamp-lib.sh — records that an exact tree of code passed the whole
# suite. Keyed on the git TREE hash (a fingerprint of file contents), so a
# fast-forward, squash or rebase of identical code reuses a stamp and a merge
# that pulled in new work does not. Stored in the git common dir: per repo,
# shared by worktrees, never committed. Only passing runs are ever written.

# ssl_stamp_file — path of the stamp file (creates its directory).
ssl_stamp_file() {
  local d
  d="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  mkdir -p "$d/superskills" || return 1
  printf '%s/suite-stamps' "$d"
}

# ssl_tree [ref] — tree hash of a ref (default HEAD); fails if the ref is unknown.
ssl_tree() { git rev-parse --verify --quiet "${1:-HEAD}^{tree}"; }

# ssl_command — the repo's configured whole-suite command (empty = not opted in).
ssl_command() { git config --local --get superskills.suiteCommand; }

# ssl_record <tree> <command> — append a stamp.
ssl_record() {
  local f
  f="$(ssl_stamp_file)" || return 1
  printf '%s\t%s\t%s\n' "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" >> "$f"
}

# ssl_revoke <tree> — drop every stamp for a tree (a failing re-run revokes an old pass).
ssl_revoke() {
  local f tmp; f="$(ssl_stamp_file)" || return 1
  [ -f "$f" ] || return 0
  tmp="$f.$$"; awk -F'\t' -v t="$1" '$1 != t' "$f" > "$tmp" && mv "$tmp" "$f"
}

# ssl_has <tree> — true when a stamp for that tree AND the currently configured
# suite command exists (a stamp made by `true` or a narrower command does not count).
ssl_has() {
  local f c
  c="$(ssl_command)"
  [ -n "$c" ] || return 1   # no command configured: nothing can be trusted
  f="$(ssl_stamp_file)" || return 1
  # awk on the file directly: `cut | grep -q` under pipefail can SIGPIPE the
  # producer on a big file and report a false "no stamp" (qa-triggers.sh pitfall).
  [ -f "$f" ] && awk -F'\t' -v t="$1" -v c="$c" '$1 == t && $3 == c { found = 1; exit } END { exit !found }' "$f"
}
