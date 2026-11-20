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

# ssl_install_hook — put a small forwarding pre-push hook where git will run
# it (honors core.hooksPath). Idempotent; never overwrites a hook that is not ours.
ssl_install_hook() {
  local dir hook here
  dir="$(git rev-parse --path-format=absolute --git-path hooks)" || return 1
  hook="$dir/pre-push"
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [ -e "$hook" ] && ! grep -qF "superskills suite gate" "$hook"; then
    echo "suite-stamp: $hook exists and is not ours, so the push gate is not installed." >&2
    # shellcheck disable=SC2016  # literal text for the user to copy
    echo 'suite-stamp: call "'"$here"'/suite-gate-prepush.sh" "$@" from it. If your hook also reads git'"'"'s stdin, save it once (in=$(cat)), replay it to each (printf '"'%s\n'"' "$in" | cmd), and stop on a non-zero exit.' >&2
    return 0
  fi
  mkdir -p "$dir" || return 1
  printf '#!/usr/bin/env bash\n# superskills suite gate (managed by suite-stamp.sh init)\ng=%q\n[ -x "$g" ] || { echo "suite-stamp gate: $g is missing, so this push is not gated (re-run suite-stamp.sh init)" >&2; exit 0; }\nexec "$g" "$@"\n' \
    "$here/suite-gate-prepush.sh" > "$hook"
  chmod +x "$hook"
}
