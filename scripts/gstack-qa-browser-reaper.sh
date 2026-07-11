#!/usr/bin/env bash
# gstack-qa-browser-reaper.sh — reap idle gstack QA browsers.
#
# gstack's /qa, /browse, and /benchmark skills launch a persistent per-project
# "Chrome for Testing" browser under ~/.gstack/chromium-profile-<name>. The
# profile dir is meant to persist (keeps logins/cookies between runs), but the
# browser *process* has no idle teardown: when a skill or Claude session ends
# via SIGTERM / Ctrl-C / crash (the ungraceful paths), the browser is orphaned
# and can sit for hours pegging a CPU core. Several stacked up = load average
# past core count and a sluggish machine.
#
# This reaps QA browsers idle past a threshold. It is:
#   - Scoped: touches ONLY ~/.gstack/chromium-profile-<suffix> QA profiles.
#     Your real Chrome/Firefox and the bare `chromium-profile` browser are
#     never matched.
#   - Idle-based: uses the profile dir mtime (Chrome writes it on navigation /
#     cookies; it goes stale when the browser sits idle). Never kills a browser
#     you're actively driving in another window.
#   - Graceful: SIGTERM first (lets Chrome tear down its own children), then
#     SIGKILL only if it ignores the polite ask.
#
# Trigger it from a launchd agent (periodic safety net) and/or a Claude Code
# SessionEnd hook. Both just exec this script.
#
# Env:
#   GSTACK_QA_REAP_IDLE_MIN   idle minutes before reaping  (default: 30)
#   GSTACK_HOME               gstack state dir             (default: ~/.gstack)
#   GSTACK_QA_REAP_PS_FILE    test seam: read the process list from this file
#                             instead of `ps` (one "PID COMMAND" line per proc)
# Flags:
#   --dry-run   report what would be reaped, kill nothing
#
# Exit: always 0 (best-effort cleanup; never fail a hook or launchd run).

set -u

IDLE_MINUTES="${GSTACK_QA_REAP_IDLE_MIN:-30}"
GHOME="${GSTACK_HOME:-$HOME/.gstack}"
LOG="$GHOME/qa-reaper.log"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

now=$(date +%s)
ts() { date -u +%FT%TZ; }
mtime() { stat -f %m "$1" 2>/dev/null || echo 0; }
log() { printf '%s %s\n' "$(ts)" "$1" >> "$LOG" 2>/dev/null; }

reaped=0

# Process list, with a test seam. Real runs read live `ps`; tests feed a fixture.
ps_list() {
  if [ -n "${GSTACK_QA_REAP_PS_FILE:-}" ]; then
    cat "$GSTACK_QA_REAP_PS_FILE"
  else
    ps -axww -o pid= -o command=
  fi
}

# Walk main "Chrome for Testing" processes. read splits pid off the front;
# the rest (which contains spaces) lands in cmd.
while read -r pid cmd; do
  case "$pid" in ''|*[!0-9]*) continue ;; esac          # pid must be numeric
  case "$cmd" in *"Chrome for Testing"*) ;; *) continue ;; esac
  case "$cmd" in *chromium-profile-*) ;; *) continue ;; esac
  case "$cmd" in *"--type="*) continue ;; esac          # skip renderer/gpu/etc helpers
  case "$cmd" in *chrome_crashpad_handler*) continue ;; esac

  # Profile name = the token right after the first "chromium-profile-".
  rest="${cmd#*chromium-profile-}"
  name="${rest%% *}"
  [ -z "$name" ] && continue                            # bare chromium-profile: not a QA profile

  prof="$GHOME/chromium-profile-$name"
  [ -d "$prof" ] || continue                            # only reap profiles we can verify on disk

  pm=$(mtime "$prof")
  [ "$pm" -eq 0 ] && continue                           # no signal -> be safe, skip
  idle_min=$(( (now - pm) / 60 ))

  if [ "$idle_min" -ge "$IDLE_MINUTES" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'WOULD REAP  profile=%s pid=%s idle=%dmin\n' "$name" "$pid" "$idle_min"
      log "dry-run would reap profile=$name pid=$pid idle=${idle_min}min"
    else
      log "reaping profile=$name pid=$pid idle=${idle_min}min"
      kill -TERM "$pid" 2>/dev/null
      # Escalate to SIGKILL if it's still alive after a grace window.
      ( sleep 8; kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null ) &
      reaped=$((reaped + 1))
    fi
  fi
done < <(ps_list)

if [ "$DRY_RUN" -eq 0 ] && [ "$reaped" -gt 0 ]; then
  log "reaped $reaped idle QA browser(s) (idle >= ${IDLE_MINUTES}min)"
fi
exit 0
