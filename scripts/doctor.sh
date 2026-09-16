#!/usr/bin/env bash
# doctor.sh — read-only readiness report for a superskills install.
# Usage: scripts/doctor.sh [--root <repo>] [--home <dir>] [--bin <claude>]
#   --root <repo>  the superskills checkout to inspect (default: this script's repo)
#   --home <dir>   the home directory whose install to inspect (default: $HOME) —
#                  a container, a fixture tree, another user's copy.
#   --bin <claude> the Claude Code CLI used for `plugin list --json` (default: claude)
# Nothing is written, installed, pulled, or authenticated.
set -e
# The library always comes from this script's own repo; --root only changes
# which checkout is inspected.
LIB_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
ROOT="$LIB_ROOT"
HOME_DIR="$HOME"
BIN="claude"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)   ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --home)   HOME_DIR="$2"; shift 2 ;;
    --home=*) HOME_DIR="${1#--home=}"; shift ;;
    --bin)    BIN="$2"; shift 2 ;;
    --bin=*)  BIN="${1#--bin=}"; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
# shellcheck source=scripts/lib/doctor-lib.sh
. "$LIB_ROOT/scripts/lib/doctor-lib.sh"
doctor_report "$ROOT" "$HOME_DIR" "$BIN"
