#!/usr/bin/env bats
# Host-neutrality lint: shared skill bodies must not name host-EXCLUSIVE
# tools (the six tokens in the lib). Superskills installs into Claude Code,
# Codex, ZCode, OpenCode and minimal harnesses; a skill that tells the model
# to call another host's tool teaches a call that cannot succeed here. This
# is not a general host-syntax checker — see the lib header for scope.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/tests/lib/host-neutral-lib.sh"
  TMPDIR_FIXTURE="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_FIXTURE"
}

@test "host-neutral lint flags a planted violation" {
  cat > "$TMPDIR_FIXTURE/BAD_SKILL.md" <<'EOF'
---
name: bad
description: Calls a tool that only exists on one host.
---
Use multi_tool_use.parallel to batch your reads.
EOF
  run host_neutral_check "$TMPDIR_FIXTURE/BAD_SKILL.md"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "multi_tool_use"
}

@test "host-neutral lint passes the allowlist escape" {
  cat > "$TMPDIR_FIXTURE/OK_SKILL.md" <<'EOF'
---
name: ok
description: Documents a host tool without instructing its use.
---
The Codex harness names a tool multi_tool_use.parallel. <!-- host-tool-allow: multi_tool_use -->
EOF
  run host_neutral_check "$TMPDIR_FIXTURE/OK_SKILL.md"
  [ "$status" -eq 0 ]
}

@test "host-neutral lint fails loudly on an unreadable file" {
  run host_neutral_check "$TMPDIR_FIXTURE/does-not-exist.md"
  [ "$status" -eq 2 ]
}

@test "tracked skill bodies name no host-specific tools" {
  files="$(git ls-files -- 'skills/*/SKILL.md' 'design-skills/*/SKILL.md' 'marketing-skills/*/SKILL.md')"
  [ -n "$files" ]
  saw_violation=0
  while IFS= read -r f; do
    host_neutral_check "$f" || saw_violation=1
  done <<< "$files"
  [ "$saw_violation" -eq 0 ]
}
