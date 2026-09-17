#!/usr/bin/env bats
# Unit tests for scripts/eval-traces.sh — archives the per-run transcripts of a
# `claude plugin eval --keep-temp --json` run (they live in /tmp and vanish)
# and prints one open-coding summary per run.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  W="$BATS_TEST_TMPDIR"
  TRACE="$W/kept/out/trace.jsonl"; mkdir -p "$(dirname "$TRACE")"
  cat > "$TRACE" <<'T'
{"type":"user","message":{"content":"hi"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"superskills:superskills-doctor"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bash doctor.sh --root r --home h"}}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"Verdict: blocked. clean-code is not linked."}]}}
T
  RESULT="$W/run.json"
  cat > "$RESULT" <<J
{"cases":[{"name":"doctor-direct","arms":{"with":[{"score":1,"error":null,"tracePath":"$TRACE","graders":[{"name":"skill-fired","passed":true,"scored":false}]}],"without":[{"score":0.5,"error":null,"tracePath":"$W/missing.jsonl","graders":[{"name":"read-only","passed":false,"scored":true,"explanation":"Bash called 1x"}]}]}}]}
J
}

@test "archives each run's trace under <out>/<case>/<arm>-<n>.jsonl" {
  run bash "$REPO_ROOT/scripts/eval-traces.sh" "$RESULT" "$W/out"
  [ "$status" -eq 0 ]
  [ -f "$W/out/doctor-direct/with-1.jsonl" ]
  [ ! -f "$W/out/doctor-direct/without-1.jsonl" ]   # source was missing; not fatal
}

@test "prints a per-run summary: case, arm, score, tool calls, failed graders, final text" {
  run bash "$REPO_ROOT/scripts/eval-traces.sh" "$RESULT" "$W/out"
  [[ "$output" == *"doctor-direct / with-1 / score 1"* ]] || false
  [[ "$output" == *"Skill superskills:superskills-doctor"* ]] || false
  [[ "$output" == *"Bash bash doctor.sh --root r --home h"* ]] || false
  [[ "$output" == *"Verdict: blocked."* ]] || false
  [[ "$output" == *"doctor-direct / without-1 / score 0.5"* ]] || false
  [[ "$output" == *"FAILED read-only"* ]] || false
  [[ "$output" == *"trace missing"* ]] || false
}

@test "a case or arm name that is not a plain path component is skipped, never written outside the archive" {
  RESULT2="$W/evil.json"
  cat > "$RESULT2" <<J
{"cases":[{"name":"../../outside-archive","arms":{"with":[{"score":1,"tracePath":"$TRACE","graders":[]}]}},
          {"name":"ok-case","arms":{"../x":[{"score":1,"tracePath":"$TRACE","graders":[]}]}}]}
J
  run bash "$REPO_ROOT/scripts/eval-traces.sh" "$RESULT2" "$W/out2"
  [ ! -e "$W/outside-archive" ] || false
  [ ! -e "$W/out2/x-1.jsonl" ] && [ ! -e "$W/x-1.jsonl" ] || false
  [[ "$output" == *"skipped"* ]] || false
}

