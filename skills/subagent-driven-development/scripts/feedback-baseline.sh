#!/usr/bin/env bash
# feedback-baseline.sh — ralph-style feedback baseline for an SDD plan workspace.
#
# Records a plan workspace's pre-existing test failures ONCE, then gates later
# runs on failure-signature deltas: NEW failures (not in the baseline) block;
# BASELINE failures are pre-existing warnings, not blockers; GONE failures are
# fixes. Re-baselining is refused unless --force is paired with --reason, which
# is recorded in the file — a silently rewritten baseline hides regressions.
#
# Usage:
#   feedback-baseline.sh record --workspace DIR [--from FILE] [--force --reason "why"]
#   feedback-baseline.sh check  --workspace DIR [--from FILE]
#
# Failure ids come from FILE or stdin, one per line (test id, "file::test",
# whatever the runner's stable signature is). Blank lines are skipped; ids are
# sorted and de-duplicated. The baseline lives at DIR/feedback-baseline.tsv.
#
# Exit codes (check): 0 = no new failures (an absent baseline means the repo
# started green, so any current failure is new);
# 1 = NEW failures exist; 2 = usage/input error.
set -u

BASELINE_NAME="feedback-baseline.tsv"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "feedback-baseline: $*" >&2; exit 2; }

MODE="${1:-}"; shift || true
[ "$MODE" = "record" ] || [ "$MODE" = "check" ] || usage

WORKSPACE=""; FROM=""; FORCE=""; REASON=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) WORKSPACE="${2:?}"; shift 2 ;;
    --from)      FROM="${2:?}"; shift 2 ;;
    --force)     FORCE=1; shift ;;
    --reason)    REASON="${2:?}"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$WORKSPACE" ] || usage
[ -d "$WORKSPACE" ] || die "workspace does not exist: $WORKSPACE"
[ -z "$FROM" ] || [ -r "$FROM" ] || die "input file does not exist: $FROM"
[ -z "$FROM" ] || [ ! -d "$FROM" ] || die "input file is a directory: $FROM"
BASELINE="$WORKSPACE/$BASELINE_NAME"

read_ids() { # -> sorted unique failure ids, one per line (validate --from first: this runs in a pipeline subshell, where exit codes die)
  if [ -n "$FROM" ]; then
    grep -v '^[[:space:]]*$' "$FROM" || true
  else
    grep -v '^[[:space:]]*$' /dev/stdin || true
  fi | LC_ALL=C sort -u
}

case "$MODE" in
record)
  if [ -s "$BASELINE" ]; then
    if [ -z "$FORCE" ]; then
      echo "feedback-baseline: $BASELINE already exists — re-recording hides regressions." >&2
      echo "  To re-record anyway: --force --reason \"<what changed>\"." >&2
      exit 1
    fi
    [ -n "$REASON" ] || die "--force requires --reason (recorded in the baseline file)"
  fi
  IDS="$(read_ids)"
  [ -n "$IDS" ] || die "nothing to record: no failure ids in the input (a green repo needs no baseline)"
  TMP="$(mktemp "$BASELINE.tmp.XXXXXXXX")" || die "could not create temporary baseline file"
  printf '# feedback-baseline v1 recorded=%s reason=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${REASON:-initial}" > "$TMP" || exit 2
  printf '%s\n' "$IDS" >> "$TMP"
  mv "$TMP" "$BASELINE" || exit 2
  echo "RECORDED $(printf '%s\n' "$IDS" | wc -l | tr -d ' ') ids -> $BASELINE"
  ;;
check)
  CURF="$(mktemp)" || exit 2
  BASEF="$(mktemp)" || exit 2
  trap 'rm -f "$CURF" "$BASEF"' EXIT
  read_ids | grep . > "$CURF" || true
  if [ ! -f "$BASELINE" ]; then
    echo "no baseline recorded — every current failure is new"
  else
    grep -v '^#' "$BASELINE" | LC_ALL=C sort -u | grep . > "$BASEF" || true
  fi
  NEW="$(comm -23 "$CURF" "$BASEF")"
  GONE="$(comm -13 "$CURF" "$BASEF")"
  KEEP="$(comm -12 "$CURF" "$BASEF")"
  [ -n "$NEW" ]  && printf '%s\n' "$NEW"  | sed 's/^/NEW /'
  [ -n "$GONE" ] && printf '%s\n' "$GONE" | sed 's/^/GONE /'
  [ -n "$KEEP" ] && printf '%s\n' "$KEEP" | sed 's/^/BASELINE /'
  NN=$(printf '%s\n' "$NEW"  | grep -c .)
  NB=$(printf '%s\n' "$KEEP" | grep -c .)
  NG=$(printf '%s\n' "$GONE" | grep -c .)
  if [ "$NN" -gt 0 ] 2>/dev/null; then
    echo "RESULT: FAIL — $NN new failure(s) beyond baseline ($NB pre-existing, $NG fixed)"
    exit 1
  fi
  echo "RESULT: PASS — no new failures ($NB pre-existing, $NG fixed)"
  ;;
esac
