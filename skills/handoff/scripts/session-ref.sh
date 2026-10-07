#!/usr/bin/env bash
# session-ref.sh — detect the agent harness and resolve this session's
# reference: the absolute session/transcript path (when one exists) plus the
# verified resume command. Output is prose lines the handoff note embeds
# verbatim. Exit 0 always (an unresolvable reference is information, not an
# error). Hook-provided values win: set HANDOFF_SESSION_FILE (absolute path)
# and/or HANDOFF_SESSION_ID when the caller got them from hook stdin.
#
# Detection order (env markers, gstack's proven set):
#   Claude Code: CLAUDECODE            Codex: CODEX_THREAD_ID | CODEX_SANDBOX
#   OpenCode:    OPENCODE              anything else: unknown
# Hook-provided override: HANDOFF_SESSION_FILE (absolute path) wins over
# discovery in both harnesses that have files.
set -u
HOME_DIR="${HOME:-$PWD}"
MAX_AGE_MIN=360   # transcripts older than this are not this session
munge() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
# newest_within <dir>: newest *.jsonl (<= MAX_AGE_MIN old) via [ -nt ] — no
# xargs: GNU xargs runs the command once on EMPTY input, which would list the
# cwd and fabricate a session file out of whatever is newest there.
newest_within() {
  local best="" c
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    if [ -z "$best" ] || [ "$c" -nt "$best" ]; then best="$c"; fi
  done < <(find "$1" -maxdepth 1 -name '*.jsonl' -mmin "-$MAX_AGE_MIN" -print 2>/dev/null)
  [ -n "$best" ] && printf '%s\n' "$best"
}

emit() { printf '%s\n' "$*"; }

# --- Claude Code ---------------------------------------------------------
if [ -n "${CLAUDECODE:-}" ]; then
  file="${HANDOFF_SESSION_FILE:-}"
  caution=""
  discovered=0
  if [ -n "$file" ] && [ ! -f "$file" ]; then
    emit "caution: the hook-supplied session file was named but does not exist: $file"
    file=""
  fi
  if [ -z "$file" ]; then
    discovered=1
    # Claude Code munges EVERY non-alphanumeric path char to '-' (verified
    # against real ~/.claude/projects: 'Google Drive' -> 'Google-Drive').
    # An exactly-munged dir is authoritative; a munged-basename suffix match
    # is only a guess, so it says so. Either way the newest transcript within
    # MAX_AGE_MIN wins (newest_within: no xargs — GNU xargs lists the cwd on
    # empty input and would fabricate a session file out of whatever is there).
    munged_name="$(munge "$(basename "$PWD")")"
    d="$HOME_DIR/.claude/projects/$(munge "$PWD")"
    [ -d "$d" ] || for d in "$HOME_DIR/.claude/projects"/*"$munged_name"; do
      [ -d "$d" ] && break
    done
    [ -d "$d" ] && file="$(newest_within "$d")"
    if [ -n "$file" ] && [ "$d" != "$HOME_DIR/.claude/projects/$(munge "$PWD")" ]; then
      caution="project dir matched by basename only — verify this transcript belongs to the current project before resuming"
    fi
  fi
  if [ -n "$file" ] && [ -f "$file" ]; then
    sid="$(basename "$file" .jsonl)"
    [ -n "$caution" ] && emit "caution: $caution"
    emit "session file: $file"
    emit "resume: claude --resume $sid -p \"<prompt>\""
    [ "$discovered" = 0 ] \
      || emit "caution: newest-transcript discovery — a parallel session in this project may own this file; confirm it is THIS session's before relying on it"
    emit "fallback: claude -c -p \"<prompt>\"   (most recent session in this directory)"
  else
    emit "session file: not found (no transcript modified in the last $((MAX_AGE_MIN / 60))h)"
    emit "resume: claude -c -p \"<prompt>\"   (continue the most recent session here)"
  fi
  exit 0
fi

# --- Codex ----------------------------------------------------------------
if [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; then
  file="${HANDOFF_SESSION_FILE:-}"
  if [ -n "$file" ] && [ ! -f "$file" ]; then
    emit "caution: the hook-supplied session file was named but does not exist: $file"
    file=""
  fi
  if [ -z "$file" ]; then
    file="$(find "$HOME_DIR/.codex/sessions" -name 'rollout-*.jsonl' -mmin "-$MAX_AGE_MIN" -print 2>/dev/null \
            | sort | tail -1)"
  fi
  if [ -n "$file" ] && [ -f "$file" ]; then
    emit "session file: $file"
    [ -n "${CODEX_THREAD_ID:-}" ] \
      && emit "current thread id: $CODEX_THREAD_ID (prefer resuming this thread if your codex supports it)" \
      || emit "caution: newest rollout may belong to another thread — verify before trusting it"
  else
    emit "session file: not found (no rollout modified in the last 6h)"
  fi
  emit "resume: codex exec resume --last \"<prompt>\""
  exit 0
fi

# --- OpenCode ---------------------------------------------------------------
if [ -n "${OPENCODE:-}" ]; then
  emit "resume: opencode run -c \"<prompt>\"   (continue the most recent session)"
  emit "note: no stable on-disk session path is published; handoff.md is the bridge"
  exit 0
fi

# --- Unknown / minimal harness --------------------------------------------
emit "harness: unrecognized — no verified headless resume path (do not guess one)"
emit "handoff.md is the only bridge: the successor session must rebuild state from it and git"
exit 0
