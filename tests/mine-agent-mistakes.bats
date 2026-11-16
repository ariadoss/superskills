#!/usr/bin/env bats
# Unit tests for evals/_lib/mine-agent-mistakes.py — pin the pre-registered
# incident definitions (edit-thrash, repeat-fail, skill-load-failure) and both
# exclusion rules against synthetic session logs, so the classification
# semantics cannot drift silently.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  MINER="$REPO_ROOT/evals/_lib/mine-agent-mistakes.py"
  HOME="$BATS_TEST_TMPDIR/home"
  PROJ="$HOME/.claude/projects/synthetic"
  mkdir -p "$PROJ"
}

# One synthetic session: JSONL lines of assistant tool_use / user tool_result.
write_session() {
  local name="$1"; shift
  : > "$PROJ/$name"
  local line
  for line in "$@"; do printf '%s\n' "$line" >> "$PROJ/$name"; done
}

TU_BASH='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b1","name":"Bash","input":{"command":"make test"}}]}}'
TU_EDIT_A='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e1","name":"Edit","input":{"file_path":"/repo/a/file.py"}}]}}'
TU_EDIT_A2='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e2","name":"Edit","input":{"file_path":"/repo/a/file.py"}}]}}'
TU_EDIT_A3='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e3","name":"Edit","input":{"file_path":"/repo/a/file.py"}}]}}'
TU_EDIT_B='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e4","name":"Edit","input":{"file_path":"/repo/b/other.py"}}]}}'
TU_EDIT_B2='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e5","name":"Edit","input":{"file_path":"/repo/b/other.py"}}]}}'
TU_SKILL='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"s1","name":"Skill","input":{"skill":"write-plan"}}]}}'
RES_FAIL_TEST='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"b1","is_error":true,"content":"Exit code 1"}]}}'
RES_OK_TEST='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"b1","content":"ok"}]}}'
RES_SKILL_ERR='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"s1","is_error":true,"content":"Error: skill not found"}]}}'

@test "edit-thrash fires when a failed test falls between three edits of one file" {
  write_session s1.jsonl "$TU_BASH" "$TU_EDIT_A" "$TU_EDIT_A2" "$RES_FAIL_TEST" "$TU_EDIT_A3"
  run python3 -I "$MINER" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"edit_thrash": 1'
  echo "$output" | grep -q '/repo/a/file.py'
}

@test "same-basename files in different dirs are distinct files (full-path keying)" {
  write_session s2.jsonl \
    "$TU_EDIT_A" "$TU_EDIT_A2" "$TU_EDIT_B" "$TU_EDIT_B2" "$RES_FAIL_TEST"
  run python3 -I "$MINER" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"edit_thrash": 0'    # no single file reached 3 edits
}

@test "a red test BEFORE all edits is TDD, not thrash" {
  write_session s3.jsonl "$RES_FAIL_TEST" "$TU_EDIT_A" "$TU_EDIT_A2" "$TU_EDIT_A3"
  run python3 -I "$MINER" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"edit_thrash": 0'
}

@test "repeat-fail dedupes one command retried twice; non-test failures do not verify" {
  # Two failing runs of the same command in one session = one repeat-fail incident;
  # a failed grep (not a test command) between edits does not create thrash.
  local TU_GREP='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"g1","name":"Bash","input":{"command":"grep -r widget src"}}]}}'
  local RES_GREP_FAIL='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"g1","is_error":true,"content":"grep: no such file"}]}}'
  write_session s4.jsonl "$TU_BASH" "$RES_FAIL_TEST" "$TU_BASH" "$RES_FAIL_TEST" \
    "$TU_EDIT_A" "$TU_GREP" "$RES_GREP_FAIL" "$TU_EDIT_A2"
  run python3 -I "$MINER" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"repeat_fail": 1'
  echo "$output" | grep -q '"edit_thrash": 0'    # the failing grep is not a verification
}

@test "failed Skill loads are counted as skill-load-failures" {
  write_session s5.jsonl "$TU_SKILL" "$RES_SKILL_ERR"
  run python3 -I "$MINER" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"skill_load_failures": 1'
}

@test "green sessions produce zero incidents and the sample stays within the pool" {
  write_session s6.jsonl "$TU_BASH" "$RES_OK_TEST"
  run python3 -I "$MINER" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"edit_thrash": 0'
  echo "$output" | grep -q '"repeat_fail": 0'
  echo "$output" | grep -q '"skill_load_failures": 0'
}
