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
  # Derive the munge with the SAME rule the script uses (every
  # non-alphanumeric char -> '-'): the tmp path contains 'b_', so the old
  # /.-only munge writes the fixture into a differently-named dir.
  proj="$HOME_FIX/.claude/projects/$(printf '%s' "$PWD" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$proj"
  printf '{}' > "$proj/11111111-1111-1111-1111-111111111111.jsonl"
  sleep 1   # 1s apart: distinct on even 1-second-mtime filesystems, and always inside the 6h window
  printf '{}' > "$proj/22222222-2222-2222-2222-222222222222.jsonl"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "22222222-2222-2222-2222-222222222222.jsonl"
  echo "$output" | grep -q 'claude --resume 22222222-2222-2222-2222-222222222222'
  # Discovery always carries the parallel-session caution by design;
  # the basename-only caution must NOT appear for an exact match.
  ! echo "$output" | grep -q "caution: project dir matched by basename only" || false
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

@test "claude code: underscore in the repo name still matches (full munge)" {
  work="$BATS_TEST_TMPDIR/work/my_repo"; mkdir -p "$work"; cd "$work"
  proj="$HOME_FIX/.claude/projects/$(printf '%s' "$PWD" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$proj"
  printf '{}' > "$proj/55555555-5555-5555-5555-555555555555.jsonl"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "55555555-5555-5555-5555-555555555555.jsonl"
  echo "$output" | grep -q 'claude --resume 55555555'
}

@test "claude code: exact-match discovery still carries the parallel-session caution" {
  work="$BATS_TEST_TMPDIR/work/exactrepo"; mkdir -p "$work"; cd "$work"
  proj="$HOME_FIX/.claude/projects/$(printf '%s' "$PWD" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$proj"
  printf '{}' > "$proj/66666666-6666-6666-6666-666666666666.jsonl"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "caution: newest-transcript discovery"
  ! echo "$output" | grep -q "caution: project dir matched by basename only" || false
}

@test "claude code: a hook-supplied file suppresses the discovery caution" {
  printf '{}' > "$HOME_FIX/hook.jsonl"
  run env -i HOME="$HOME_FIX" CLAUDECODE=1 HANDOFF_SESSION_FILE="$HOME_FIX/hook.jsonl" bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "hook.jsonl"
  ! echo "$output" | grep -q "caution: newest-transcript discovery" || false
}

@test "claude code: empty transcript dir fabricates nothing (GNU xargs hazard)" {
  work="$BATS_TEST_TMPDIR/work/emptyrepo"; mkdir -p "$work"; cd "$work"
  touch "$work/README.md"
  proj="$HOME_FIX/.claude/projects/$(printf '%s' "$PWD" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$proj"
  run env -i HOME="$HOME_FIX" PWD="$PWD" CLAUDECODE=1 bash "$REF"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "session file: README.md" || false
  echo "$output" | grep -q "not found"
}

@test "claude code: named-but-missing HANDOFF_SESSION_FILE says so, then falls back" {
  run env -i HOME="$HOME_FIX" CLAUDECODE=1 HANDOFF_SESSION_FILE="$HOME_FIX/missing.jsonl" bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "was named but does not exist"
  echo "$output" | grep -q 'claude -c'
}

@test "codex: thread id emits the preference line without the basename caution" {
  sess="$HOME_FIX/.codex/sessions/2026/10/06"
  mkdir -p "$sess"
  printf '{}' > "$sess/rollout-2026-10-06T11-00-00-22222222.jsonl"
  run env -i HOME="$HOME_FIX" CODEX_THREAD_ID=thread-123 bash "$REF"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "current thread id: thread-123"
  ! echo "$output" | grep -q "caution: newest rollout" || false
}
