#!/usr/bin/env bash
# secrets-prepush-hook.sh: Claude Code PreToolUse hook.
# Blocks a `git push` when any unpushed local commit holds a secret gitleaks
# finds, using the gate's own config. Bypass: SECRETS_PREPUSH=0.
set -u
input="$(cat 2>/dev/null || true)"
case "$input" in *git*push*) : ;; *) exit 0 ;; esac
[ "${SECRETS_PREPUSH:-1}" = "0" ] && exit 0
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/secrets-gate-lib.sh"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
case "$cmd" in *git*push*) : ;; *) exit 0 ;; esac
cd "$(sg_target_dir "$cmd" "${cwd:-$PWD}")" 2>/dev/null || exit 0
TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$TOP" || exit 0
if ! sg_available; then echo "secrets pre-push gate: gitleaks not installed, scan skipped" >&2; exit 0; fi
report="$(sg_scan_unpushed "$ROOT/scripts/gitleaks-gate.toml")"; rc=$?
[ "$rc" -eq 0 ] && exit 0
if [ "$rc" -eq 1 ]; then
  msg="secrets pre-push gate: gitleaks found secrets in local commits no remote holds (values redacted):"
else
  msg="secrets pre-push gate: gitleaks could not finish, so the gate fails closed:"
fi
jq -n --arg m "$msg" --arg r "$report" '{decision:"block",reason:($m + "\n" + $r + "\n\nFix it before pushing. For a deliberate test fixture, build the value at runtime instead of committing it, or push once with SECRETS_PREPUSH=0.")}'
