#!/usr/bin/env bats
# Tests for evals/_lib/transcript-context.py. Hermetic: synthetic JSONL under BATS_TEST_TMPDIR.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  T="$BATS_TEST_TMPDIR/t.jsonl"
  {
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"a","name":"Skill","input":{"skill":"superskills:defense"}}]}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a","content":"12345678901234567890"}]}}'
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b","name":"Read","input":{"file_path":"/x/skills/qa-full/references/step-5-db.md"}}]}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"b","content":[{"type":"text","text":"abcde"}]}]}}'
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"c","name":"Bash","input":{"command":"ls"}}]}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"c","content":"xy"}]}}'
  } > "$T"
}

@test "groups result bytes by tool, skill and references reads" {
  run python3 "$REPO_ROOT/evals/_lib/transcript-context.py" "$T"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq '.total')" = "27" ]
  [ "$(printf '%s' "$output" | jq '.by_tool.Skill')" = "20" ]
  [ "$(printf '%s' "$output" | jq '.by_skill.defense')" = "20" ]
  [ "$(printf '%s' "$output" | jq '.references_read')" = "5" ]
}

@test "a malformed trailing line is skipped, not fatal" {
  printf 'not json\n' >> "$T"
  run python3 "$REPO_ROOT/evals/_lib/transcript-context.py" "$T"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq '.total')" = "27" ]
}
