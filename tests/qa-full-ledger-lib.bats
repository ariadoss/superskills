#!/usr/bin/env bats
# Unit tests for scripts/lib/qa-full-ledger-lib.sh and the Stop hook that uses
# it (scripts/qa-full-ledger-hook.sh). Hermetic: synthetic JSONL transcripts
# and a synthetic qa-full report under BATS_TEST_TMPDIR.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/lib/qa-full-ledger-lib.sh"
  HOOK="$REPO_ROOT/scripts/qa-full-ledger-hook.sh"
  T="$BATS_TEST_TMPDIR/transcript.jsonl"
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$PROJ/qa-full-reports"
  : > "$T"
}

# skill_call <name> — append an assistant turn that invokes the Skill tool.
skill_call() {
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"%s"}}]}}\n' "$1" >> "$T"
}
bash_call() {
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"%s"}}]}}\n' "$1" >> "$T"
}
report() {
  cat > "$PROJ/qa-full-reports/feature-2026-09-24.md" <<'R'
# QA-Full — feature @ 2026-09-24

## Accounting ledger (RAN-CLEAN / FIXED(n) / UNFIXED / SKIPPED(reason) / NOT-TRIGGERED / MANDATORY-FAIL)
| Check | Status | Evidence / fixes / reason |
|-------|--------|---------------------------|
| Tests & build (Step 2)   | FIXED(1) | npm test green, fix a1b2c3d |
| /review (Step 3)         | RAN-CLEAN | no findings |
| /defense (Step 4)        | FIXED(2) | secret externalized |
| /iac-scan (Step 4)       | UNFIXED | base image pin needs a decision |
| /pentest (Step 4)        | SKIPPED(not authorized) | — |
| /db-optimize (Step 5)    | NOT-TRIGGERED | no DB files |
| /test-coverage + /playwright (Step 9) | FIXED(1) | tests added |
| Final pass (Step 10)     | RAN-CLEAN | green |
R
}
hook_input() {
  printf '{"transcript_path":"%s","cwd":"%s","stop_hook_active":%s}' "$T" "$PROJ" "${1:-false}"
}

@test "ran_qafull: true when the Skill tool loaded qa-full, with or without a plugin prefix" {
  skill_call "superskills:qa-full"
  run qfl_ran_qafull "$T"
  [ "$status" -eq 0 ]
}

@test "ran_qafull: true when the user typed the /qa-full slash command" {
  printf '{"type":"user","message":{"content":"<command-name>/qa-full</command-name>"}}\n' >> "$T"
  run qfl_ran_qafull "$T"
  [ "$status" -eq 0 ]
}

@test "ran_qafull: true when the session read qa-full's SKILL.md directly instead of invoking it" {
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/superskills/skills/qa-full/SKILL.md"}}]}}\n' >> "$T"
  run qfl_ran_qafull "$T"
  [ "$status" -eq 0 ]
}

@test "ran_qafull: false for a session that never touched qa-full" {
  skill_call "tdd"
  bash_call "echo qa-full is mentioned in a command, not invoked"
  run qfl_ran_qafull "$T"
  [ "$status" -ne 0 ]
}

@test "invoked_skills: lists Skill tool calls with plugin prefixes stripped, once each" {
  skill_call "qa-full"; skill_call "superskills:defense"; skill_call "defense"; bash_call "ls"
  run qfl_invoked_skills "$T"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'defense\nqa-full')" ]
}

@test "ran_rows: only RAN-CLEAN, FIXED and UNFIXED rows that name a /skill" {
  report
  run qfl_ran_rows "$PROJ/qa-full-reports/feature-2026-09-24.md"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'review\ndefense\niac-scan\ntest-coverage playwright')" ]
}

@test "missing: a row whose skill was never invoked is reported" {
  report
  skill_call "qa-full"; skill_call "review"; skill_call "iac-scan"; skill_call "playwright"
  run qfl_missing "$PROJ/qa-full-reports/feature-2026-09-24.md" "$T"
  [ "$output" = "defense" ]
}

@test "missing: any one skill of a multi-skill row satisfies it" {
  report
  skill_call "review"; skill_call "defense"; skill_call "iac-scan"; skill_call "test-coverage"
  run qfl_missing "$PROJ/qa-full-reports/feature-2026-09-24.md" "$T"
  [ -z "$output" ]
}

@test "missing: Skill calls in a second transcript (a subagent) count" {
  report
  skill_call "review"; skill_call "iac-scan"; skill_call "test-coverage"
  SUB="$BATS_TEST_TMPDIR/sub.jsonl"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"defense"}}]}}\n' > "$SUB"
  run qfl_missing "$PROJ/qa-full-reports/feature-2026-09-24.md" "$T" "$SUB"
  [ -z "$output" ]
}

@test "latest_report: newest file in qa-full-reports" {
  report
  printf 'old\n' > "$PROJ/qa-full-reports/older.md"; touch -t 202001010000 "$PROJ/qa-full-reports/older.md"
  run qfl_latest_report "$PROJ"
  [ "$output" = "$PROJ/qa-full-reports/feature-2026-09-24.md" ]
}

@test "report_path: the last qa-full report the transcript wrote wins over the cwd" {
  report
  OTHER="$BATS_TEST_TMPDIR/elsewhere/qa-full-reports/b-2026-09-24.md"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"%s","content":"x"}}]}}\n' "$OTHER" >> "$T"
  run qfl_report_path "$PROJ" "$T"
  [ "$output" = "$OTHER" ]
}

@test "report_path: falls back to the newest report under the cwd" {
  report
  run qfl_report_path "$PROJ" "$T"
  [ "$output" = "$PROJ/qa-full-reports/feature-2026-09-24.md" ]
}

@test "hook: also counts Skill calls in the session's subagents/ transcripts" {
  report
  skill_call "qa-full"; skill_call "review"; skill_call "iac-scan"; skill_call "test-coverage"
  mkdir -p "${T%.jsonl}/subagents"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"defense"}}]}}\n' > "${T%.jsonl}/subagents/agent-1.jsonl"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input)'"
  [ "$status" -eq 0 ]
}

@test "hook: a session that only read qa-full's SKILL.md (editing it, not running it) is left alone" {
  report
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/skills/qa-full/SKILL.md"}}]}}\n' >> "$T"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input)'"
  [ "$status" -eq 0 ]
}

@test "hook: a session that read SKILL.md and wrote a report is checked like a real run" {
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/skills/qa-full/SKILL.md"}}]}}\n' >> "$T"
  report
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"%s","content":"x"}}]}}\n' "$PROJ/qa-full-reports/feature-2026-09-24.md" >> "$T"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input)' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"/review"* ]] || false
}

@test "hook: exits 0 and stays silent for a session that did not run qa-full" {
  skill_call "tdd"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook: blocks (exit 2) and names the check when a claimed check was not invoked" {
  report
  skill_call "qa-full"; skill_call "review"; skill_call "iac-scan"; skill_call "test-coverage"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input)' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"/defense"* ]] || false
  [[ "$output" == *"Skill tool"* ]] || false
}

@test "hook: passes when every claimed check has its Skill call" {
  report
  skill_call "qa-full"; skill_call "review"; skill_call "defense"; skill_call "iac-scan"; skill_call "test-coverage"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input)'"
  [ "$status" -eq 0 ]
}

@test "hook: blocks when qa-full ran but wrote no report" {
  skill_call "qa-full"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input)' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"qa-full-reports"* ]] || false
}

@test "hook: never blocks twice in a row (stop_hook_active)" {
  report
  skill_call "qa-full"
  run bash -c "$(printf '%q' "$HOOK") <<< '$(hook_input true)'"
  [ "$status" -eq 0 ]
}

@test "hook: prefers agent_transcript_path (SubagentStop) over transcript_path" {
  report
  A="$BATS_TEST_TMPDIR/agent.jsonl"
  for s in qa-full review defense iac-scan test-coverage; do
    printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"%s"}}]}}\n' "$s" >> "$A"
  done
  input="$(printf '{"transcript_path":"%s","agent_transcript_path":"%s","cwd":"%s","stop_hook_active":false}' "$T" "$A" "$PROJ")"
  run bash -c "$(printf '%q' "$HOOK") <<< '$input'"
  [ "$status" -eq 0 ]
}
