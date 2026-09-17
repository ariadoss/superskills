#!/usr/bin/env bats
# The locate-and-run snippet in skills/superskills-doctor/SKILL.md (Step 1) is
# executed verbatim by an agent, so it is tested verbatim: extracted from the
# markdown and run under controlled HOME / cwd / CLAUDE_PLUGIN_ROOT. It must be
# ONE command: agent shells do not keep variables between separate commands.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  SNIPPET="$BATS_TEST_TMPDIR/discover.sh"
  awk '/^### Step 1/{s=1} s && /^```bash$/{f=1; next} f && /^```$/{exit} f' \
    "$REPO_ROOT/skills/superskills-doctor/SKILL.md" > "$SNIPPET"
  [ -s "$SNIPPET" ]
  EMPTY_HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$EMPTY_HOME"
}

@test "no plugin root and no linked skill: reports missing, even with cwd two levels inside a checkout" {
  cd "$REPO_ROOT/marketing-skills/content"
  run env -u CLAUDE_PLUGIN_ROOT HOME="$EMPTY_HOME" bash "$SNIPPET" --bin definitely-not-claude
  [ "$output" = "DOCTOR=missing" ]
}

@test "a setup-linked skill resolves back to its checkout and the same command runs the doctor" {
  mkdir -p "$EMPTY_HOME/.claude/skills/superskills-doctor"
  ln -s "$REPO_ROOT/skills/superskills-doctor/SKILL.md" "$EMPTY_HOME/.claude/skills/superskills-doctor/SKILL.md"
  cd "$BATS_TEST_TMPDIR"
  run env -u CLAUDE_PLUGIN_ROOT HOME="$EMPTY_HOME" bash "$SNIPPET" --bin definitely-not-claude
  [ "${lines[0]}" = "DOCTOR=$REPO_ROOT/scripts/doctor.sh" ]
  [[ "$output" == *"| Check | Status |"* ]] || false
  [[ "$output" == *"Verdict:"* ]] || false
}

@test "a dangling skill link reports missing instead of guessing" {
  mkdir -p "$EMPTY_HOME/.claude/skills/superskills-doctor"
  ln -s "$BATS_TEST_TMPDIR/gone/skills/superskills-doctor/SKILL.md" "$EMPTY_HOME/.claude/skills/superskills-doctor/SKILL.md"
  cd "$REPO_ROOT/marketing-skills/content"
  run env -u CLAUDE_PLUGIN_ROOT HOME="$EMPTY_HOME" bash "$SNIPPET" --bin definitely-not-claude
  [ "$output" = "DOCTOR=missing" ]
}

@test "CLAUDE_PLUGIN_ROOT wins when it holds the doctor" {
  cd "$BATS_TEST_TMPDIR"
  run env CLAUDE_PLUGIN_ROOT="$REPO_ROOT" HOME="$EMPTY_HOME" bash "$SNIPPET" --bin definitely-not-claude
  [ "${lines[0]}" = "DOCTOR=$REPO_ROOT/scripts/doctor.sh" ]
  [[ "$output" == *"Verdict:"* ]] || false
}

@test "no later step of the skill relies on a shell variable set in Step 1" {
  run awk '/^### Step 1/{s=1} /^### Step 2/{s=2} s==2' "$REPO_ROOT/skills/superskills-doctor/SKILL.md"
  [[ "$output" != *'$ROOT'* ]] || false
}

@test "a host-provided skill directory (SKILL_DIR) locates the doctor when no Claude plugin root or link exists" {
  cd "$BATS_TEST_TMPDIR"
  run env -u CLAUDE_PLUGIN_ROOT SKILL_DIR="$REPO_ROOT/skills/superskills-doctor" HOME="$EMPTY_HOME" bash "$SNIPPET" --bin definitely-not-claude
  [ "${lines[0]}" = "DOCTOR=$REPO_ROOT/scripts/doctor.sh" ] || false
}

@test "a Codex or OpenCode ./setup link locates the doctor" {
  for d in .codex/skills/superskills-doctor .config/opencode/skills/superskills-doctor; do
    H="$BATS_TEST_TMPDIR/h-$(echo "$d" | tr '/.' '__')"; mkdir -p "$H/$d"
    ln -s "$REPO_ROOT/skills/superskills-doctor/SKILL.md" "$H/$d/SKILL.md"
    cd "$BATS_TEST_TMPDIR"
    run env -u CLAUDE_PLUGIN_ROOT HOME="$H" bash "$SNIPPET" --bin definitely-not-claude
    [ "${lines[0]}" = "DOCTOR=$REPO_ROOT/scripts/doctor.sh" ] || { echo "$d -> ${lines[0]}"; return 1; }
  done
}

@test "a SKILL_DIR that does not hold the doctor is ignored, not trusted" {
  mkdir -p "$BATS_TEST_TMPDIR/fake/skills/superskills-doctor"
  cd "$REPO_ROOT/marketing-skills/content"
  run env -u CLAUDE_PLUGIN_ROOT SKILL_DIR="$BATS_TEST_TMPDIR/fake/skills/superskills-doctor" HOME="$EMPTY_HOME" bash "$SNIPPET" --bin definitely-not-claude
  [ "$output" = "DOCTOR=missing" ] || false
}

@test "a relative SKILL_DIR is ignored (never trusted against the shell's cwd)" {
  mkdir -p "$BATS_TEST_TMPDIR/decoy/skills/superskills-doctor"
  cp "$REPO_ROOT/scripts/doctor.sh" "$BATS_TEST_TMPDIR/decoy-doctor.sh" 2>/dev/null || true
  mkdir -p "$BATS_TEST_TMPDIR/decoy/scripts"
  printf '#!/bin/sh
echo DECOY_RAN
' > "$BATS_TEST_TMPDIR/decoy/scripts/doctor.sh"
  cd "$BATS_TEST_TMPDIR/decoy"
  run env -u CLAUDE_PLUGIN_ROOT SKILL_DIR="skills/superskills-doctor" HOME="$EMPTY_HOME" bash "$SNIPPET" --bin definitely-not-claude
  [ "$output" = "DOCTOR=missing" ] || { echo "$output"; return 1; }
}

