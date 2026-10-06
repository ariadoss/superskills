#!/usr/bin/env bats
# session-ref.sh: harness detection and session-reference resolution, tested
# against fixture HOME trees (no real ~/.claude or ~/.codex is touched).

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  # Dual lookup: skills/handoff/scripts/ in superskills, scripts/ in the
  # exported standalone repo (the export relocates the file).
  for cand in "$REPO_ROOT/skills/handoff/scripts/session-ref.sh" "$REPO_ROOT/scripts/session-ref.sh"; do
    [ -f "$cand" ] && REF="$cand" && break
  done
  [ -n "${REF:-}" ]
  HOME_FIX="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME_FIX"
}

@test "claude code: newest transcript in the exactly-munged project dir wins" {
  work="$BATS_TEST_TMPDIR/work/fixture-repo"; mkdir -p "$work"; cd "$work"
  proj="$HOME_FIX/.claude/projects/$(printf '%s' "$PWD" | sed 's:[/.]:-:g')"
  mkdir -p "$proj"
  printf '{}' > "$proj/11111111-1111-1111-1111-111111111111.jsonl"
  sleep 0.05
  printf '{}' > "$proj/22222222-2222-2222-2222-222222222222.jsonl"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "22222222-2222-2222-2222-222222222222.jsonl"
  echo "$output" | grep -q 'claude --resume 22222222-2222-2222-2222-222222222222'
  ! echo "$output" | grep -q "caution:" || false
}

@test "claude code: basename-only match emits the verify caution" {
  work="$BATS_TEST_TMPDIR/other/fixture-repo"; mkdir -p "$work"; cd "$work"
  proj="$HOME_FIX/.claude/projects/-somewhere-else-fixture-repo"
  mkdir -p "$proj"; printf '{}' > "$proj/22222222-2222-2222-2222-222222222222.jsonl"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "caution: project dir matched by basename only"
}

@test "claude code: HANDOFF_SESSION_FILE overrides discovery (hook-provided path)" {
  printf '{}' > "$HOME_FIX/explicit.jsonl"
  run env -i HOME="$HOME_FIX" CLAUDECODE=1 HANDOFF_SESSION_FILE="$HOME_FIX/explicit.jsonl" bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "explicit.jsonl"
}

@test "codex: newest rollout file and codex exec resume --last" {
  sess="$HOME_FIX/.codex/sessions/2026/10/06"
  mkdir -p "$sess"
  printf '{}' > "$sess/rollout-2026-10-06T10-00-00-11111111.jsonl"
  sleep 0.05
  printf '{}' > "$sess/rollout-2026-10-06T11-00-00-22222222.jsonl"
  run env -i HOME="$HOME_FIX" CODEX_SANDBOX=read-only bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "rollout-2026-10-06T11-00-00-22222222.jsonl"
  echo "$output" | grep -q "codex exec resume --last"
}

@test "opcode/opencode: opencode run -c with no file claim" {
  run env -i HOME="$HOME_FIX" OPENCODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "opencode run -c"
  ! echo "$output" | grep -q "session file:" || false
}

@test "unknown harness: prints no-resume instructions, exit 0" {
  run env -i HOME="$HOME_FIX" bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "no verified headless resume path"
}

@test "stale transcripts (older than 6h) are ignored" {
  proj="$HOME_FIX/.claude/projects/-Users-fixture-repo"
  mkdir -p "$proj"
  old="$proj/33333333-3333-3333-3333-333333333333.jsonl"
  printf '{}' > "$old"
  touch -t "$(date -v-8H +%Y%m%d%H%M)" "$old" 2>/dev/null || touch -d "8 hours ago" "$old"
  run env -i HOME="$HOME_FIX" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "claude -c"   # falls back to continue-most-recent
  ! echo "$output" | grep -q "33333333" || false
}
