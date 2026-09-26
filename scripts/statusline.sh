#!/bin/bash
# Claude Code statusline: model · dir · context% · 5h · 7d · spend · cache
#
# Design notes, because the obvious implementations are all slower or wrong:
#
# ONE SUBPROCESS. Claude Code debounces statusline updates at 300ms and cancels
# an in-flight script when a new update arrives, so every fork costs. A single
# jq call does all parsing, the cache merge, the clock arithmetic and the
# rendering, then prints the line and the new cache as two records. The only
# other process is one `mv`, and only when a window actually changed: no
# awk (context % is a documented field), no date (jq has `now`), no stat
# (freshness comes from `resets_at`, not mtime), no tr, no sleep, no lock, and no
# subshell for umask (it is set once below).
#
# rate_limits is absent until the session's first API response and Claude Code
# drops each window once its `resets_at` passes, so a fresh session would show
# "--" for minutes. Hence the cache. Staleness is decided by `resets_at`, not by
# a high-water mark: within a window used_percentage only climbs, and a changed
# resets_at means a new window, which is the whole rule.
#
# Concurrency: sessions share one cache (rate limits are account-wide) and write
# it last-writer-wins via an atomic rename. Deliberately no lock. A racing write
# can drop one update; the next render corrects it, and the value is a rounded
# percentage. Do not add a lock here: it buys nothing and costs a fork per render
# on the hot path.
#
# Env: NO_COLOR=1 plain output. STATUSLINE_DEBUG=1 surfaces stderr.
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
def live($w): ($w.used_percentage | type) == "number"
              and ($w.resets_at | type) == "number"
              and $w.resets_at > $now;

# live beats cache; same window keeps the higher reading (a stale lower value
# must not walk the number backwards); a later resets_at means a new window.
def merge($l; $c):
  if live($l) and live($c) then
    if $l.resets_at == $c.resets_at
      then (if $l.used_percentage >= $c.used_percentage then $l else $c end)
      else $l end
  elif live($l) then $l
  elif live($c) then $c
  else null end;

def window($w; $label; $warn; $danger):
  if $w == null then "" else
    ($w.used_percentage | round) as $p
    | (until($w.resets_at)) as $r
    | dim + $label + " " + off + paint(sev($p; $warn; $danger); "\($p)%")
      + (if $r == "" then "" else " " + dim + "(" + $r + ")" + off end)
  end;

($cachetext | fromjson? // null) as $cache
| (.rate_limits // {}) as $rl
| ($cache.rate_limits // {}) as $cl
| merge($rl.five_hour;  $cl.five_hour)  as $w5
| merge($rl.seven_day;  $cl.seven_day)  as $w7
| merge($rl.spend_limit; $cl.spend_limit) as $ws

# Prefer the documented pre-calculated field; fall back to the token sum it is
# defined as, so an older Claude Code still renders a context number.
| ( if (.context_window.used_percentage | type) == "number"
    then .context_window.used_percentage
    else ( (.context_window.context_window_size // 0) as $size
           | if $size > 0 then
               ( ((.context_window.current_usage.input_tokens // 0)
                + (.context_window.current_usage.cache_creation_input_tokens // 0)
                + (.context_window.current_usage.cache_read_input_tokens // 0))
                 / $size * 100 )
             else null end )
    end ) as $ctx

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
  | if (.rate_limits | length) == 0 then empty else tojson end )
JQPROG

if ! command -v jq >/dev/null 2>&1; then
  printf 'ctx --  (jq not found)\n'
  exit 0
fi

# jq supplies its own clock via `now`, so not even date/1 forks here.
out=$(jq -r --argjson color "$use_color" --arg cachetext "$cache_text" "$JQ" 2>/dev/null) || out=""

# Line 1 is the statusline, line 2 (when present) is the cache to persist.
line=${out%%$'\n'*}
rest=${out#*$'\n'}

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
if [ "$use_cache" = 1 ] && [ -n "$rest" ] && [ "$rest" != "$out" ] && [ "$rest" != "$cache_text" ]; then
  # [ -d ] is a builtin; skip the mkdir fork on every render after the first.
  if [ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR" 2>/dev/null; then
    # $RANDOM is a builtin, so the name costs no fork and cannot be predicted;
    # noclobber then makes `>` refuse any path that already exists. Together a
    # symlink planted in a shared-writable XDG_CACHE_HOME is never written
    # through. A refused write skips this render's persist; rm -f on a symlink
    # removes the link, never its target. The final `mv` renames over the cache
    # entry itself, so a symlink planted there is replaced, not followed.
    tmp="$CACHE_FILE.$$.$RANDOM.tmp"
    set -C
    if printf '%s\n' "$rest" 2>/dev/null > "$tmp"; then
      mv -f "$tmp" "$CACHE_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
    else
      rm -f "$tmp" 2>/dev/null
    fi
    set +C
  fi
fi
