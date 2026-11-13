#!/usr/bin/env bats
# Tests for evals/_lib/qa-full-token-audit.py: run classification, attribution
# (tool results + attachments) and the arm-prefix mode. Hermetic synthetic
# subagents/ dir; a run transcript needs usage + tool_use/tool_result pairs,
# a child references the same fx/ path, an unrelated one does not.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  S="$BATS_TEST_TMPDIR/subs"
  mkdir -p "$S"
  R="$S/agent-run1.jsonl"
  {
    printf '%s\n' '{"type":"user","message":{"content":"pre-ship QA pipeline as a test on fx/Ch-heavy-1"}}'
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"a","name":"Skill","input":{"skill":"review"}}],"usage":{"input_tokens":100,"cache_creation_input_tokens":50,"cache_read_input_tokens":900,"output_tokens":40}}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a","content":"0123456789"}]}}'
    printf '%s\n' '{"type":"attachment","attachment":{"stdout":"/qa-full step file steps/03-correctness-quality.md, supplied by the hook\nSTEP BODY 20 chars.."}}'
  } >"$R"
  C="$S/agent-child1.jsonl"
  printf '%s\n' '{"type":"user","message":{"content":"review fx/Ch-heavy-1 briefly"}}' >"$C"
  U="$S/agent-unrel.jsonl"
  printf '%s\n' '{"type":"user","message":{"content":"unrelated work"}}' >"$U"
}

@test "classifies runs, children and unrelated agents; sums run tokens" {
  run python3 -I "$REPO_ROOT/evals/_lib/qa-full-token-audit.py" "$S"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 qa-full runs, 1 child agents, 1 unrelated"* ]] || false
  [[ "$output" == *"Ch-heavy-1"* ]] || false
  # 100 + 50 + 900 = 1050 tokens -> 0.00M, but output tokens (40) appear in the row
  [[ "$output" == *"40"* ]] || false
}

@test "attributes tool-result bytes to the call and hook attachments to the step" {
  run python3 -I "$REPO_ROOT/evals/_lib/qa-full-token-audit.py" "$S" Ch-
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -E 'skill-call:review' | grep -q '10 ' || false
  printf '%s\n' "$output" | grep -q 'hook-step:steps/03-correctness-quality.md' || false
}

@test "the prefix mode with no matching arm prints an empty attribution" {
  run python3 -I "$REPO_ROOT/evals/_lib/qa-full-token-audit.py" "$S" Zz-
  [ "$status" -eq 0 ]
  [[ "$output" == *"combined tool-result + attachment bytes: 0"* ]] || false
}
