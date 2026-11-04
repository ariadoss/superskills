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

@test "skill body in the following isMeta user message counts toward by_skill and total" {
  B="$BATS_TEST_TMPDIR/body.jsonl"
  {
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"s","name":"Skill","input":{"skill":"qa-full"}}]}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"s","content":"Launching"}]}}'
    printf '%s\n' '{"type":"user","isMeta":true,"message":{"content":[{"type":"text","text":"Base directory for this skill: /x\nBODY"}]}}'
  } > "$B"
  run python3 "$REPO_ROOT/evals/_lib/transcript-context.py" "$B"
  [ "$status" -eq 0 ]
  body=$(printf 'Base directory for this skill: /x\nBODY' | wc -c | tr -d ' ')
  [ "$(printf '%s' "$output" | jq '.by_skill["qa-full"]')" = "$((9 + body))" ]
  [ "$(printf '%s' "$output" | jq '.total')" = "$((9 + body))" ]
  [ "$(printf '%s' "$output" | jq '.by_tool.Skill')" = "$((9 + body))" ]
}

@test "references and skill_calls are ordered with a shared seq" {
  run python3 "$REPO_ROOT/evals/_lib/transcript-context.py" "$T"
  [ "$(printf '%s' "$output" | jq -c '.skill_calls')" = '[{"seq":1,"skill":"defense"}]' ]
  [ "$(printf '%s' "$output" | jq -c '.references')" = '[{"bytes":5,"path":"/x/skills/qa-full/references/step-5-db.md","seq":2}]' ]
}

@test "non-object JSON lines are skipped" {
  printf '[1,2]\n' >> "$T"
  run python3 "$REPO_ROOT/evals/_lib/transcript-context.py" "$T"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq '.total')" = "27" ]
}

@test "tool_use ids reused across files do not collide" {
  U="$BATS_TEST_TMPDIR/u.jsonl"
  {
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"a","name":"Bash","input":{}}]}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a","content":"zz"}]}}'
  } > "$U"
  run python3 "$REPO_ROOT/evals/_lib/transcript-context.py" "$T" "$U"
  [ "$(printf '%s' "$output" | jq '.by_tool.Bash')" = "4" ]
  [ "$(printf '%s' "$output" | jq '.by_skill.defense')" = "20" ]
}
