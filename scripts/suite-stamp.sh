#!/usr/bin/env bash
# suite-stamp.sh — run the whole suite at most once per distinct tree of code.
#
#   suite-stamp.sh init <command...>   opt this repo in; <command> is its whole suite
#   suite-stamp.sh check [ref]         exit 0 if ref's tree already passed, else 1
#   suite-stamp.sh run                 run the suite on HEAD; stamp it only if it passes
#   suite-stamp.sh ensure              check, and run only when not stamped
#
# `run` refuses a dirty working tree: the stamp names HEAD's tree, so the tested
# files must be exactly that tree. Stamps live in the git common dir (never committed).
set -uo pipefail
# shellcheck source=scripts/lib/suite-stamp-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/suite-stamp-lib.sh"

die() { echo "suite-stamp: $*" >&2; exit 2; }
sub="${1:-}"; [ $# -gt 0 ] && shift

do_check() {
  local tree
  tree="$(ssl_tree "${1:-HEAD}")" || die "unknown ref: ${1:-HEAD}"
  if ssl_has "$tree"; then echo "stamped: $tree"; else echo "not stamped: $tree" >&2; return 1; fi
}

do_run() {
  local suite tree rc
  suite="$(ssl_command)"
  [ -n "$suite" ] || die "no suite command set. Run: suite-stamp.sh init '<your whole-suite command>'"
  [ -z "$(git status --porcelain)" ] || die "working tree is not clean; commit or stash first"
  tree="$(ssl_tree HEAD)" || die "no HEAD commit"
  (cd "$(git rev-parse --show-toplevel)" && bash -c "$suite"); rc=$?
  if [ "$rc" -ne 0 ]; then
    ssl_revoke "$tree"; return "$rc"   # newer failing evidence overrides an older pass
  fi
  # the suite (a formatter, a generator) must not have changed what it tested
  [ "$(ssl_tree HEAD)" = "$tree" ] && [ -z "$(git status --porcelain)" ] || { ssl_revoke "$tree"; die "the suite changed tracked files; commit them and run again"; }
  ssl_record "$tree" "$suite"
  echo "stamped: $tree"
}

case "$sub" in
  init)   [ $# -ge 1 ] || die "usage: init <command...>"; git config --local superskills.suiteCommand "$*" ;;
  check)  do_check "$@" ;;
  run)    do_run ;;
  ensure) do_check "${1:-HEAD}" >/dev/null 2>&1 && { echo "already passed on this tree; skipping"; exit 0; }; do_run ;;
  *)      die "usage: suite-stamp.sh init|check|run|ensure" ;;
esac
