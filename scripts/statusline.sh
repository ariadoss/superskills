#!/bin/bash
# Claude Code statusline: model · dir · context% · 5h · 7d · spend · cache
#
# Design notes, because the obvious implementations are all slower or wrong:
#
# ONE PARSING SUBPROCESS. Claude Code debounces statusline updates at 300ms and cancels
# an in-flight script when a new update arrives, so every fork costs. A single
# jq call does all parsing, the cache merge, the clock arithmetic and the
# rendering, then prints the line and cache records. The only
# other processes are `mv` calls when an account window or this session's
# context percentage actually changed: no
# awk (context % is a documented field), no date (jq has `now`), no stat
# (freshness comes from `resets_at`, not mtime), no tr, no sleep, no lock, and no
# subshell for umask (it is set once below).
#
# rate_limits is absent until the session's first API response and Claude Code
# drops each window once its `resets_at` passes, so a fresh session would show
# "--" for minutes. Hence the cache: it covers that absence and is itself
# dropped when its `resets_at` passes. When the payload does carry a window,
# that reading wins outright — the windows are rolling, so used_percentage
# decays within a window and must never be held at an earlier peak.
#
# Concurrency: sessions share one cache (rate limits are account-wide) and write
# it last-writer-wins via an atomic rename. Deliberately no lock. A racing write
# can drop one update; the next render corrects it, and the value is a rounded
# percentage. Do not add a lock here: it buys nothing and costs a fork per render
# on the hot path.
#
# Env: CLAUDE_CODE_AUTO_COMPACT_WINDOW (read when set below the model window).
# NO_COLOR=1 plain output. STATUSLINE_DEBUG=1 surfaces stderr.
# Input schema: https://code.claude.com/docs/en/statusline

[ "${STATUSLINE_DEBUG:-}" = "1" ] || exec 2>/dev/null
set -u
# Everything this script creates (the cache dir and file) is private to the user.
umask 077

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
CACHE_FILE="$CACHE_DIR/rate-limits.json"

# $(<file) is a bash builtin read: no fork. Missing/unreadable file -> empty,
# which jq's fromjson? turns into null. Corrupt JSON degrades the same way
# instead of failing the render.
cache_text=""
# A directory someone else owns (a shared XDG_CACHE_HOME) is not our cache: it
# could hold spoofed numbers or a FIFO. -O is a builtin, so this costs no fork.
use_cache=1
[ -e "$CACHE_DIR" ] && [ ! -O "$CACHE_DIR" ] && use_cache=0
# -f, not just -r: a FIFO or device planted at this path would block $(<...)
# forever, and Claude Code would kill and re-run a hung render on every update.
[ "$use_cache" = 1 ] && [ -f "$CACHE_FILE" ] && [ -r "$CACHE_FILE" ] && cache_text=$(<"$CACHE_FILE")

use_color=1
[ -n "${NO_COLOR:-}" ] && use_color=0

read -r -d '' JQ <<'JQPROG'
now as $now
| (.session_id // null) as $sid
| def esc: if $color == 1 then "\u001b[" else "" end;
def sgr($c): if $color == 1 then esc + $c + "m" else "" end;
def dim: sgr("2");
def off: sgr("0");
def paint($c; $s): sgr($c) + ($s | tostring) + off;
# Input-derived text (a directory name comes from whatever repo the user is in)
# must not smuggle terminal control sequences: ESC ] 52 writes the clipboard.
def clean: tostring | gsub("[[:cntrl:]]"; "");

# Colour by severity. Blue below warn, magenta at warn, red at danger: the
# red/magenta pair stays distinguishable for red-green colour blindness in a way
# red/green does not.
def sev($pct; $warn; $danger):
  if $pct >= $danger then "31" elif $pct >= $warn then "95" else "94" end;

def ctx_sev($pct): if $pct >= 85 then "31" elif $pct >= 70 then "33" else "32" end;

# "4h23m", "1d21h", "12m". Empty when already elapsed or unknown.
def until($ts):
  if ($ts | type) != "number" then "" else
    (($ts - $now) | floor) as $d
    | if $d <= 0 then "" else
        ($d / 60 | floor) as $m | ($m / 60 | floor) as $h | ($h / 24 | floor) as $dy
        | if $dy >= 1 then "\($dy)d\($h % 24)h"
          elif $h >= 1 then "\($h)h\($m % 60)m"
          else "\($m)m" end
      end
  end;

# A window is usable only while its reset is in the future. Claude Code drops a
# live window at reset; a cached one has to be dropped by us.
def live($w): ($w | type) == "object"
              and ($w.used_percentage | type) == "number"
              and ($w.resets_at | type) == "number"
              and $w.resets_at > $now;

# live beats cache. Both windows are rolling — old usage drops out, so
# used_percentage falls as well as rises within one resets_at — and a lower
# live reading is normally that decay, not staleness, so it must be shown. The
# cache exists only for a payload without rate_limits (a session before its
# first API response). A concurrent session's older response can transiently
# walk the number back for one render; accepted, because the alternative —
# keeping the higher reading — latches a rolling window's peak until its reset.
def merge($l; $c):
  if live($l) then $l
  elif live($c) then $c
  else null end;

def window($w; $label; $warn; $danger):
  if $w == null then "" else
    ($w.used_percentage | round) as $p
    | (until($w.resets_at)) as $r
    | dim + $label + " " + off + paint(sev($p; $warn; $danger); "\($p)%")
      + (if $r == "" then "" else " " + dim + "(" + $r + ")" + off end)
  end;

# Both sources are untrusted in shape: anything but an object of windows counts
# as no windows, so a bad cache (say `[]`) is overwritten instead of aborting
# the render forever.
def windows: if type == "object" and (.rate_limits | type) == "object" then .rate_limits else {} end;
($cachetext | fromjson? // null | windows) as $cl
| windows as $rl
| merge($rl.five_hour;  $cl.five_hour)  as $w5
| merge($rl.seven_day;  $cl.seven_day)  as $w7
| merge($rl.spend_limit; $cl.spend_limit) as $ws

# Prefer the documented pre-calculated field; fall back to the token sum it is
# defined as, so an older Claude Code still renders a context number.
# used_percentage is measured against the model's full window (1M on the long
# context models), but CLAUDE_CODE_AUTO_COMPACT_WINDOW makes Claude Code compact
# far earlier. When that window is smaller, recompute against it so the number
# reads as distance to auto-compaction rather than to a limit never reached.
| ( (.context_window.context_window_size // 0) as $size
    | ($compactwin | tonumber? // 0) as $cw
    | ( (.context_window.current_usage.input_tokens // 0)
      + (.context_window.current_usage.cache_creation_input_tokens // 0)
      + (.context_window.current_usage.cache_read_input_tokens // 0) ) as $tokens
    | if $cw > 0 and ($size == 0 or $cw < $size)
         and (.context_window.current_usage | type) == "object"
      then $tokens / $cw * 100
      elif (.context_window.used_percentage | type) == "number"
      then .context_window.used_percentage
      elif $size > 0 then $tokens / $size * 100
      else null end ) as $ctx

| [
    (if (.model.display_name // "") != "" then paint("1"; .model.display_name | clean) else empty end),
    (if (.workspace.current_dir // "") != ""
       then dim + (.workspace.current_dir | sub(".*/"; "") | clean) + off else empty end),
    (if $ctx == null then dim + "ctx --" + off
       else dim + "ctx " + off + paint(ctx_sev($ctx | floor); "\($ctx | floor)%") end),
    (window($w5; "5h"; 70; 90)),
    (window($w7; "7d"; 70; 90)),
    # Over-limit spend is the one number worth shouting about, so it reddens at 100.
    (window($ws; "spend"; 80; 100)),
    (if .prompt_cache.warm == true and (.prompt_cache.ttl // "") != ""
       then dim + "cache " + (.prompt_cache.ttl | clean) + off
     elif .prompt_cache.caching_observed == true and .prompt_cache.warm == false
       then dim + "cache cold" + off
     else empty end)
  ]
| map(select(. != "")) | join("  " )
,
# Second record: the cache to persist. Only real windows, so a session that
# never saw rate_limits cannot blank a good cache.
( def keep($k; $w): if $w == null then empty else {($k): ($w | {used_percentage, resets_at})} end;
  { rate_limits: ([keep("five_hour"; $w5), keep("seven_day"; $w7), keep("spend_limit"; $ws)] | add // {}) }
  | if (.rate_limits | length) == 0 then "" else tojson end )
,
(if ($sid | type) == "string" and ($sid | test("^[A-Za-z0-9_-]+$"))
    and ($ctx | type) == "number"
 then "\($sid)\t\($ctx)" else empty end)
JQPROG

if ! command -v jq >/dev/null 2>&1; then
  printf 'ctx --  (jq not found)\n'
  exit 0
fi

# jq supplies its own clock via `now`, so not even date/1 forks here.
out=$(jq -r --argjson color "$use_color" --arg cachetext "$cache_text" \
  --arg compactwin "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}" "$JQ" 2>/dev/null) || out=""

# Line 1 is the statusline, line 2 is the account cache (possibly empty),
# and line 3, when present, is this session's context reading.
line=${out%%$'\n'*}
remaining=${out#*$'\n'}
rest=${remaining%%$'\n'*}
context_record=""
[[ "$remaining" == *$'\n'* ]] && context_record=${remaining#*$'\n'}

if [ -z "$line" ]; then
  printf 'ctx --\n'
  exit 0
fi
printf '%s\n' "$line"

# Persist out of band. Temp file sits in the same directory so the rename is
# atomic, and carries $$ so two concurrent renders cannot share it. Claude Code
# may cancel this script mid-write; a partial temp file is then simply orphaned
# and the real cache is never truncated.
# Skip the write when nothing changed: once any window is live, every render
# would otherwise rename a byte-identical file, one mv fork each time. $(<file)
# drops trailing newlines and jq emits none, so the comparison is exact.
persist_cache() {
  local file="$1" content="$2" old="$3" tmp
  [ -n "$content" ] && [ "$content" != "$old" ] || return 0
  # [ -d ] is a builtin; skip the mkdir fork on every render after the first.
  if [ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR" 2>/dev/null; then
    # $RANDOM is a builtin, so the name costs no fork and cannot be predicted;
    # noclobber then makes `>` refuse any path that already exists. Together a
    # symlink planted in a shared-writable XDG_CACHE_HOME is never written
    # through. A refused write skips this render's persist; rm -f on a symlink
    # removes the link, never its target. The final `mv` renames over the cache
    # entry itself, so a symlink planted there is replaced, not followed.
    tmp="$file.$$.$RANDOM.tmp"
    set -C
    if printf '%s\n' "$content" 2>/dev/null > "$tmp"; then
      mv -f "$tmp" "$file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
    else
      rm -f "$tmp" 2>/dev/null
    fi
    set +C
  fi
}

if [ "$use_cache" = 1 ] && [[ "$out" == *$'\n'* ]]; then
  persist_cache "$CACHE_FILE" "$rest" "$cache_text"
fi

# The prompt hook has no context-window field, so publish this session's latest
# statusline reading under its own key. Never let an input session id become a
# path component without checking it first.
if [ "$use_cache" = 1 ] && [ -n "$context_record" ]; then
  session_id=${context_record%%$'\t'*}
  context_pct=${context_record#*$'\t'}
  case "$session_id" in
    ''|*[!a-zA-Z0-9_-]*) ;;
    *)
      context_file="$CACHE_DIR/context-$session_id.json"
      old_context=""
      [ -f "$context_file" ] && [ -r "$context_file" ] && old_context=$(<"$context_file")
      persist_cache "$context_file" "{\"used_percentage\":$context_pct}" "$old_context"
      ;;
  esac
fi
