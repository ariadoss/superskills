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
set -u
HOME_DIR="${HOME:-$PWD}"

emit() { printf '%s\n' "$*"; }

# --- Claude Code ---------------------------------------------------------
if [ -n "${CLAUDECODE:-}" ]; then
  file="${HANDOFF_SESSION_FILE:-}"
  caution=""
  if [ -z "$file" ]; then
    # Project dirs munge the cwd path (/ and . -> -). An exactly-munged dir
    # is authoritative; a basename-suffix match is only a guess, so it says
    # so. Either way the newest transcript modified within 6h wins.
    # (find | xargs ls -t: this is not a hot path — it runs once per /handoff —
    # so clarity beats the statusline's fork discipline here.)
    cwd_name="$(basename "$PWD")"
    exact="$HOME_DIR/.claude/projects/$(printf '%s' "$PWD" | sed 's:[/.]:-:g')"
    if [ -d "$exact" ]; then
      f="$(find "$exact" -maxdepth 1 -name '*.jsonl' -mmin -360 -print 2>/dev/null \
            | xargs ls -t 2>/dev/null | head -1 || true)"
      [ -n "$f" ] && file="$f"
    fi
    if [ -z "$file" ]; then
      for d in "$HOME_DIR/.claude/projects"/*"$cwd_name"; do
        [ -d "$d" ] || continue
        f="$(find "$d" -maxdepth 1 -name '*.jsonl' -mmin -360 -print 2>/dev/null \
              | xargs ls -t 2>/dev/null | head -1 || true)"
        if [ -n "$f" ] && { [ -z "$file" ] || [ "$f" -nt "$file" ]; }; then
          file="$f"
        fi
      done
      if [ -n "$file" ]; then
        caution="project dir matched by basename only — verify this transcript belongs to the current project before resuming"
      fi
    fi
  fi
  if [ -n "$file" ] && [ -f "$file" ]; then
    sid="$(basename "$file" .jsonl)"
    [ -n "$caution" ] && emit "caution: $caution"
    emit "session file: $file"
    emit "resume: claude --resume $sid -p \"<prompt>\"   (resumes exactly this session)"
    emit "fallback: claude -c -p \"<prompt>\"   (most recent session in this directory)"
  else
    emit "session file: not found (no transcript modified in the last 6h)"
    emit "resume: claude -c -p \"<prompt>\"   (continue the most recent session here)"
  fi
  exit 0
fi

# --- Codex ----------------------------------------------------------------
if [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; then
  file="${HANDOFF_SESSION_FILE:-}"
  if [ -z "$file" ]; then
    file="$(find "$HOME_DIR/.codex/sessions" -name 'rollout-*.jsonl' -mmin -360 -print 2>/dev/null \
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
