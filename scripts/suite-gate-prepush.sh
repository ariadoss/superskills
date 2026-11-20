#!/usr/bin/env bash
# suite-gate-prepush.sh — the git pre-push gate behind scripts/suite-stamp.sh.
# Git feeds one line per ref on stdin: <local ref> <local sha> <remote ref> <remote sha>.
# Blocks (exit 1) a push to main/master whose commit tree has no suite stamp.
# Repos that never ran `suite-stamp.sh init` are untouched. Fails open when
# git or the library is unavailable. Bypass: SUITE_GATE=0 or `git push --no-verify`.
set -u
[ "${SUITE_GATE:-1}" = "0" ] && exit 0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib/suite-stamp-lib.sh" ] || exit 0
# shellcheck source=scripts/lib/suite-stamp-lib.sh
. "$HERE/lib/suite-stamp-lib.sh"
[ -n "$(ssl_command 2>/dev/null)" ] || exit 0

while read -r _lref lsha rref _rsha; do
  case "$rref" in refs/heads/main|refs/heads/master) : ;; *) continue ;; esac
  [[ "$lsha" =~ ^0+$ ]] && continue                    # branch deletion
  tree="$(ssl_tree "$lsha" 2>/dev/null)" || continue   # unknown object: not ours to judge
  ssl_has "$tree" && continue
  {
    echo "Blocked: ${rref#refs/heads/} would receive code that has not passed the whole suite."
    echo "Run:  $HERE/suite-stamp.sh ensure   (runs the suite once and stamps this exact code)"
    echo "Then push again. A fast-forward or squash of already-tested code needs no re-run."
    echo "See what has run and whether this gate is live:  $HERE/suite-stamp.sh status"
  } >&2
  exit 1
done
exit 0
