#!/usr/bin/env bats
# Tests for scripts/statusline.sh. Hermetic: XDG_CACHE_HOME points into
# BATS_TEST_TMPDIR so no test touches the real ~/.cache.
#
# Schema under test: https://code.claude.com/docs/en/statusline
# The payload fields that matter are all optional in practice —
# rate_limits appears only for Pro/Max and only after the first API response,
# each window is independently absent, and Claude Code drops a window at reset.
# So most of these tests are absence cases.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SL="$REPO_ROOT/scripts/statusline.sh"
  export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  export NO_COLOR=1
  CACHE="$XDG_CACHE_HOME/claude-statusline/rate-limits.json"
  NOW=$(date +%s)
}

# payload <5h-pct> <5h-offset> — a full-shaped payload; offsets are seconds from now.
payload() {
  cat <<J
{"session_id":"s1","model":{"display_name":"Opus"},
 "workspace":{"current_dir":"/a/b/superskills"},
 "context_window":{"used_percentage":23,"context_window_size":200000,
   "current_usage":{"input_tokens":8500,"cache_creation_input_tokens":5000,"cache_read_input_tokens":2000}},
 "rate_limits":{"five_hour":{"used_percentage":${1:-41.2},"resets_at":$((NOW + ${2:-7800}))},
   "seven_day":{"used_percentage":62.8,"resets_at":$((NOW + 270000))}},
 "prompt_cache":{"warm":true,"caching_observed":true,"ttl":"1h"}}
J
}

@test "renders model, dir, context and both windows" {
  run bash -c "'$SL' < <(echo '$(payload)')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Opus"* ]] || false
  [[ "$output" == *"superskills"* ]] || false
  [[ "$output" == *"ctx 23%"* ]] || false
  [[ "$output" == *"5h 41%"* ]] || false
  [[ "$output" == *"7d 63%"* ]] || false
  [[ "$output" == *"cache 1h"* ]] || false
}

@test "uses the documented pre-calculated context percentage, not its own arithmetic" {
  # used_percentage disagrees with the token sum on purpose: the field must win.
  run bash -c "'$SL' <<'J'
{\"context_window\":{\"used_percentage\":7,\"context_window_size\":100,
  \"current_usage\":{\"input_tokens\":99}}}
J"
  [[ "$output" == *"ctx 7%"* ]] || false
}

@test "falls back to the token sum when used_percentage is null" {
  run bash -c "'$SL' <<'J'
{\"context_window\":{\"used_percentage\":null,\"context_window_size\":200000,
  \"current_usage\":{\"input_tokens\":50000,\"cache_read_input_tokens\":50000}}}
J"
  [[ "$output" == *"ctx 50%"* ]] || false
}

@test "persists rate limits, then recovers them when the payload omits rate_limits" {
  bash -c "'$SL' < <(echo '$(payload)')" >/dev/null
  [ -f "$CACHE" ]
  # A later render with no rate_limits at all (fresh session, pre-first-response).
  run bash -c "'$SL' <<< '{\"context_window\":{\"used_percentage\":9}}'"
  [[ "$output" == *"ctx 9%"* ]] || false
  [[ "$output" == *"5h 41%"* ]] || false
  [[ "$output" == *"7d 63%"* ]] || false
}

@test "cache is written with owner-only permissions" {
  bash -c "'$SL' < <(echo '$(payload)')" >/dev/null
  run bash -c "ls -l '$CACHE' | cut -c1-10"
  [[ "$output" == "-rw-------" ]] || false
}

@test "a cached window past its resets_at is dropped, not shown stale" {
  mkdir -p "$(dirname "$CACHE")"
  echo "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":99,\"resets_at\":$((NOW - 10))}}}" > "$CACHE"
  run bash -c "'$SL' <<< '{\"context_window\":{\"used_percentage\":5}}'"
  [[ "$output" != *"99%"* ]] || false
  [[ "$output" != *"5h"* ]] || false
}

@test "a decayed live reading replaces the cached peak within the same window" {
  # Both windows are rolling: old usage drops out and used_percentage falls with
  # it, so a lower live reading is normally real decay. The cache must yield to
  # it, or the line latches the window's peak until reset (a 7d peak stuck for
  # days while the app shows the decayed value).
  bash -c "'$SL' < <(echo '$(payload 60 7800)')" >/dev/null
  run bash -c "'$SL' < <(echo '$(payload 42 7800)')"
  [[ "$output" == *"5h 42%"* ]] || false
}

@test "a new window (later resets_at) accepts a lower percentage" {
  bash -c "'$SL' < <(echo '$(payload 88 600)')" >/dev/null
  run bash -c "'$SL' < <(echo '$(payload 3 99999)')"
  [[ "$output" == *"5h 3%"* ]] || false
}

@test "spend_limit renders and is allowed to exceed 100" {
  run bash -c "'$SL' <<< '{\"rate_limits\":{\"spend_limit\":{\"used_percentage\":104.3,\"resets_at\":$((NOW+1000))}}}'"
  [[ "$output" == *"spend 104%"* ]] || false
}

@test "reports a cold prompt cache only once caching has been observed" {
  run bash -c "'$SL' <<< '{\"prompt_cache\":{\"warm\":false,\"caching_observed\":true}}'"
  [[ "$output" == *"cache cold"* ]] || false
  run bash -c "'$SL' <<< '{\"prompt_cache\":{\"warm\":false,\"caching_observed\":false}}'"
  [[ "$output" != *"cache"* ]] || false
}

@test "degrades to a usable line on empty, garbage, or empty-object input" {
  for bad in '' 'not json at all' '{}'; do
    run bash -c "printf '%s' '$bad' | '$SL'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ctx"* ]] || false
  done
}

@test "a corrupt cache file degrades instead of failing the render" {
  mkdir -p "$(dirname "$CACHE")"
  printf 'x{[' > "$CACHE"
  run bash -c "'$SL' <<< '{\"context_window\":{\"used_percentage\":5}}'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ctx 5%"* ]] || false
}

@test "NO_COLOR emits no escape sequences, and colour is on without it" {
  run bash -c "NO_COLOR=1 '$SL' < <(echo '$(payload)')"
  [[ "$output" != *$'\033'* ]] || false
  run bash -c "unset NO_COLOR; '$SL' < <(echo '$(payload)')"
  [[ "$output" == *$'\033'* ]] || false
}

@test "leaves no temp files behind" {
  bash -c "'$SL' < <(echo '$(payload)')" >/dev/null
  run bash -c "ls '$(dirname "$CACHE")' | grep -c tmp || true"
  [[ "$output" == "0" ]] || false
}

@test "a symlink planted at the cache path is replaced, never written through" {
  # The final rename replaces the directory entry rather than following it, so
  # a symlink at rate-limits.json cannot redirect the write onto another file.
  mkdir -p "$(dirname "$CACHE")"
  echo VICTIM > "$BATS_TEST_TMPDIR/victim.txt"
  ln -s "$BATS_TEST_TMPDIR/victim.txt" "$CACHE"
  bash -c "'$SL' < <(echo '$(payload)')" >/dev/null
  [ "$(cat "$BATS_TEST_TMPDIR/victim.txt")" = "VICTIM" ] || { echo "victim overwritten"; return 1; }
  [ ! -L "$CACHE" ] || { echo "cache path is still a symlink"; return 1; }
  grep -q five_hour "$CACHE" || { echo "cache not written"; return 1; }
}

@test "the temp file name is not predictable from the PID alone" {
  run grep -c 'tmp="$CACHE_FILE.$$.$RANDOM.tmp"' "$SL"
  [ "$output" = "1" ] || { echo "temp name lost its random component"; return 1; }
}

@test "a FIFO planted at the cache path cannot hang the render" {
  # $(<file) on a FIFO blocks forever, and Claude Code would kill and re-run the
  # script every update, leaving the statusline permanently blank. The render is
  # run in the background, detached from bats' file descriptors, so a regression
  # fails this test instead of hanging the whole suite.
  mkdir -p "$(dirname "$CACHE")"
  mkfifo "$CACHE"
  # 3>&- matters: bats waits on any background job still holding its fd 3.
  "$SL" <<< '{"context_window":{"used_percentage":5}}' > "$BATS_TEST_TMPDIR/out" 2>&1 3>&- &
  pid=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
  if kill -0 "$pid" 2>/dev/null; then
    # Opening the write end releases a blocked reader; the alarm stops the opener
    # itself from blocking if the reader is already gone.
    perl -e 'alarm 1; open(my $f, ">", $ARGV[0]); close $f' "$CACHE" </dev/null >/dev/null 2>&1 3>&- &
    sleep 0.5; kill "$pid" 2>/dev/null || true
    echo "render hung on a FIFO"; return 1
  fi
  grep -q 'ctx 5%' "$BATS_TEST_TMPDIR/out" || { echo "no output: $(cat "$BATS_TEST_TMPDIR/out")"; return 1; }
}

@test "a malformed rate-limit window is treated as absent, not rendered" {
  run bash -c "'$SL' <<< '{\"rate_limits\":{\"five_hour\":{\"used_percentage\":\"n/a\",\"resets_at\":$((NOW+1000))}}}'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"5h"* ]] || false
}

@test "an unchanged render does not rewrite the cache (no mv fork on the hot path)" {
  bash -c "'$SL' < <(echo '$(payload)')" >/dev/null
  first="$(ls -i "$CACHE" | awk '{print $1}')"
  bash -c "'$SL' < <(echo '$(payload)')" >/dev/null
  second="$(ls -i "$CACHE" | awk '{print $1}')"
  [ "$first" = "$second" ] || { echo "cache rewritten for identical data (inode $first -> $second)"; return 1; }
}

@test "a changed window still rewrites the cache" {
  bash -c "'$SL' < <(echo '$(payload 41 7800)')" >/dev/null
  bash -c "'$SL' < <(echo '$(payload 55 7800)')" >/dev/null
  grep -q '"used_percentage":55' "$CACHE" || { echo "cache not updated: $(cat "$CACHE")"; return 1; }
}

@test "input-derived names cannot inject terminal control sequences" {
  # /cso 517572f9: a directory name carrying ESC ] 52 (clipboard write) or
  # ESC ] 0 (window title) was printed verbatim.
  run bash -c "printf '%s' '{\"model\":{\"display_name\":\"Op\\u001b]52;c;eA==\\u0007us\"},\"workspace\":{\"current_dir\":\"/x/ev\\u001b]0;T\\u0007il\\u009b31m\"},\"prompt_cache\":{\"warm\":true,\"ttl\":\"5m\\u0007\"}}' | NO_COLOR=1 bash '$SL' | od -An -c"
  [ "$status" -eq 0 ]
  [[ "$output" != *"033"* && "$output" != *"\\a"* && "$output" != *"233"* ]] || { echo "control bytes survived: $output"; return 1; }
  run bash -c "printf '%s' '{\"model\":{\"display_name\":\"Op\\u001b]52;c;eA==\\u0007us\"},\"workspace\":{\"current_dir\":\"/x/ev\\u001b]0;T\\u0007il\"}}' | NO_COLOR=1 bash '$SL'"
  [[ "$output" == *"Op]52;c;eA==us"* && "$output" == *"ev]0;Til"* ]] || { echo "visible text lost: $output"; return 1; }
}

@test "a cache directory not owned by the user is neither read nor written" {
  # /cso 410e23e4: under a shared XDG_CACHE_HOME another user could pre-create
  # the directory and spoof the numbers or plant a FIFO. /tmp is root-owned.
  if [ -O /tmp ]; then skip "running as the owner of /tmp"; fi
  if [ -e /tmp/rate-limits.json ]; then skip "/tmp/rate-limits.json already exists"; fi
  mkdir -p "$XDG_CACHE_HOME"
  ln -s /tmp "$XDG_CACHE_HOME/claude-statusline"
  future=$(( $(date +%s) + 3600 ))
  run bash -c "printf '%s' '{\"rate_limits\":{\"five_hour\":{\"used_percentage\":42,\"resets_at\":$future}}}' | bash '$SL'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"42%"* ]] || false
  [ ! -e /tmp/rate-limits.json ] || { rm -f /tmp/rate-limits.json; echo "wrote into a foreign directory"; return 1; }
}

@test "time-to-reset renders minutes, hours+minutes and days+hours" {
  now=$(date +%s)
  run bash -c "printf '%s' '{\"rate_limits\":{\"five_hour\":{\"used_percentage\":10,\"resets_at\":$((now+700))},\"seven_day\":{\"used_percentage\":20,\"resets_at\":$((now+100000))},\"spend_limit\":{\"used_percentage\":30,\"resets_at\":$((now+8000))}}}' | NO_COLOR=1 bash '$SL'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h 10% (11m)"* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"7d 20% (1d3h)"* ]] || { echo "got: $output"; return 1; }
  [[ "$output" == *"spend 30% (2h13m)"* ]] || { echo "got: $output"; return 1; }
}

@test "a well-formed cache of the wrong shape heals instead of freezing the line" {
  # `[]` parses as JSON, so it used to reach `.rate_limits` and abort the whole
  # jq program: the line stuck at `ctx --` and the bad cache was never replaced.
  for bad in '[]' '"x"' '{"rate_limits":[]}' '{"rate_limits":{"five_hour":7}}'; do
    mkdir -p "$(dirname "$CACHE")"
    printf '%s' "$bad" > "$CACHE"
    run bash -c "'$SL' < <(echo '$(payload)')"
    [ "$status" -eq 0 ] || { echo "cache $bad: $output"; return 1; }
    [[ "$output" == *"ctx 23%"* ]] || { echo "cache $bad rendered: $output"; return 1; }
    [[ "$output" == *"5h 41%"* ]] || { echo "cache $bad dropped the live window: $output"; return 1; }
    grep -q '"five_hour"' "$CACHE" || { echo "cache $bad not rewritten: $(cat "$CACHE")"; return 1; }
  done
}

@test "a payload whose rate_limits has the wrong shape still renders" {
  run bash -c "'$SL' <<< '{\"context_window\":{\"used_percentage\":5},\"rate_limits\":[1]}'"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"ctx 5%"* ]] || { echo "$output"; return 1; }
}
