#!/usr/bin/env bats
# qa-full-step-hook.sh hands a /qa-full step file to the agent that is about to
# invoke that step's sub-skill. Fixtures are tiny JSONL transcripts.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$REPO_ROOT/scripts/qa-full-step-hook.sh"
  export QA_FULL_STEP_STATE="$BATS_TEST_TMPDIR/state"
  T="$BATS_TEST_TMPDIR/session.jsonl"
  : >"$T"
}

tool_use() { # <name> <json input>
  jq -nc --arg n "$1" --argjson i "$2" \
    '{type:"assistant",message:{content:[{type:"tool_use",name:$n,input:$i}]}}' >>"$T"
}

call() { # <skill> [agent_id]
  jq -nc --arg t "$T" --arg s "$1" --arg a "${2:-}" \
    '{session_id:"sess1",transcript_path:$t,tool_name:"Skill",tool_input:{skill:$s}}
     + (if $a == "" then {} else {agent_id:$a} end)' | "$HOOK"
}

@test "a non-Skill tool call produces no output" {
  tool_use Skill '{"skill":"qa-full"}'
  run bash -c "jq -nc --arg t '$T' '{session_id:\"s\",transcript_path:\$t,tool_name:\"Bash\",tool_input:{command:\"ls\"}}' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a skill outside every step produces no output" {
  tool_use Skill '{"skill":"qa-full"}'
  run call tdd
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "main session that invoked qa-full gets the step file before /review" {
  tool_use Skill '{"skill":"qa-full"}'
  run call review
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null
  body="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')"
  [[ "$body" == *"steps/03-correctness-quality.md"* ]]
  [[ "$body" == *"$(head -1 "$REPO_ROOT/skills/qa-full/steps/03-correctness-quality.md")"* ]]
}

@test "a plugin-prefixed skill name maps to its step" {
  tool_use Skill '{"skill":"qa-full"}'
  run call superskills:db-optimize
  body="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')"
  [[ "$body" == *"steps/05-database.md"* ]]
}

@test "a main session that only read qa-full/SKILL.md gets nothing" {
  tool_use Read '{"file_path":"/x/skills/qa-full/SKILL.md"}'
  run call review
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a subagent that read an arm's SKILL.md gets that arm's step file" {
  arm="$BATS_TEST_TMPDIR/arm/qa-full"
  mkdir -p "$arm/steps" "$BATS_TEST_TMPDIR/session/subagents"
  echo "ARM-SPECIFIC STEP TEXT" >"$arm/steps/03-correctness-quality.md"
  T="$BATS_TEST_TMPDIR/session.jsonl"
  : >"$T"
  S="$BATS_TEST_TMPDIR/session/subagents/agent-a1.jsonl"
  jq -nc --arg p "$arm/SKILL.md" \
    '{type:"assistant",message:{content:[{type:"tool_use",name:"Read",input:{file_path:$p}}]}}' >"$S"
  run call review a1
  [ "$status" -eq 0 ]
  [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" == *"ARM-SPECIFIC STEP TEXT"* ]]
}

@test "the same agent gets a step file once" {
  tool_use Skill '{"skill":"qa-full"}'
  run call review
  [ -n "$output" ]
  run call clean-code
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "two skills of one step share one injection" {
  tool_use Skill '{"skill":"qa-full"}'
  run call defense
  [ -n "$output" ]
  run call fuzz
  [ -z "$output" ]
}

@test "an agent that already read the step file is not sent it again" {
  tool_use Skill '{"skill":"qa-full"}'
  tool_use Bash '{"command":"cat /x/skills/qa-full/steps/05-database.md"}'
  run call db-optimize
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a bulk cat of bare step names counts as a read" {
  tool_use Skill '{"skill":"qa-full"}'
  tool_use Bash '{"command":"cd /x/skills/qa-full/steps && cat 05-database.md 06-frontend-perf.md"}'
  run call db-optimize
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a cat heredoc write that names a step file is not a read" {
  tool_use Skill '{"skill":"qa-full"}'
  tool_use Bash '{"command":"cat > steps/05-database.md.new <<'"'"'EOF'"'"'\nsee 05-database.md\nEOF"}'
  run call db-optimize
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "different agents each get their own copy" {
  tool_use Skill '{"skill":"qa-full"}'
  run call review
  [ -n "$output" ]
  mkdir -p "$BATS_TEST_TMPDIR/session/subagents"
  jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Read",input:{file_path:"/x/skills/qa-full/SKILL.md"}}]}}' \
    >"$BATS_TEST_TMPDIR/session/subagents/agent-b2.jsonl"
  run call review b2
  [ -n "$output" ]
}

@test "fails open on garbage input and a missing transcript" {
  run bash -c "echo 'not json' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run bash -c "echo '{\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"review\"},\"transcript_path\":\"/nope\"}' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

zline() { # <json> — one ZCode model_io line; \n inside stays a literal 2 chars
  printf '%s\n' "$1" >>"$T"
}

zfooter() { # <dir> — the skill-load footer ZCode leaves in request messages
  zline "{\"type\":\"model_io\",\"request\":{\"messages\":[{\"role\":\"user\",\"content\":\"Base directory for this skill: $1\\nRelative paths in this skill are relative to this base directory.\"}]}}"
}

@test "zcode transcript: footer with no reads gets the step file from that folder" {
  arm="$BATS_TEST_TMPDIR/zarm/qa-full"
  mkdir -p "$arm/steps"
  echo "ZARM STEP TEXT" >"$arm/steps/05-database.md"
  : >"$arm/SKILL.md"
  zfooter "$arm"
  run call db-optimize
  [ "$status" -eq 0 ]
  [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" == *"ZARM STEP TEXT"* ]]
}

@test "zcode transcript: a Read toolCall counts as a read, no injection" {
  arm="$BATS_TEST_TMPDIR/zarm2/qa-full"
  mkdir -p "$arm/steps"
  echo "ZARM2 STEP TEXT" >"$arm/steps/05-database.md"
  : >"$arm/SKILL.md"
  zfooter "$arm"
  zline '{"type":"model_io","response":{"toolCalls":[{"id":"c1","name":"Read","input":{"file_path":"/zarm2/qa-full/steps/05-database.md"}}]}}'
  run call db-optimize
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prose that quotes the base-directory line does not start a run" {
  zline '{"type":"model_io","request":{"messages":[{"role":"user","content":"the lib greps for Base directory for this skill: /no/such/dir/qa-full somewhere"}]}}'
  run call db-optimize
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "claude listing suffix after the dir is trimmed, dir must still exist" {
  arm="$BATS_TEST_TMPDIR/carm/qa-full"
  mkdir -p "$arm/steps"
  echo "CARM STEP TEXT" >"$arm/steps/04-security.md"
  : >"$arm/SKILL.md"
  zline "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"Base directory for this skill: $arm  # /qa-full  Full per-feature QA pipeline\"}]}}"
  run call defense
  [ "$status" -eq 0 ]
  [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" == *"CARM STEP TEXT"* ]]
}

@test "every mapped skill has a step file that names it" {
  . "$REPO_ROOT/scripts/lib/qa-full-step-lib.sh"
  for s in $(qfs_all_skills); do
    f="$(qfs_step_for_skill "$s")"
    [ -n "$f" ] || { echo "no step for $s"; false; }
    [ -f "$REPO_ROOT/skills/qa-full/steps/$f" ] || { echo "missing $f"; false; }
    grep -q "/$s\b" "$REPO_ROOT/skills/qa-full/steps/$f" || { echo "$f does not name /$s"; false; }
  done
}

@test "hooks.json registers the hook on the Skill matcher" {
  run jq -e '.hooks.PreToolUse[] | select(.matcher=="Skill") | .hooks[].command | contains("qa-full-step-hook.sh")' "$REPO_ROOT/hooks/hooks.json"
  [ "$status" -eq 0 ]
}
