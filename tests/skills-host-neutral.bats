#!/usr/bin/env bats
# Host-neutrality lint: shared skill bodies must not name host-EXCLUSIVE
# tools (the six tokens in the lib). Superskills installs into Claude Code,
# Codex, ZCode, OpenCode and minimal harnesses; a skill that tells the model
# to call another host's tool teaches a call that cannot succeed here. This
# is not a general host-syntax checker — see the lib header for scope.

setup() {
  # dirname, not $(cd .. && pwd): the cd-in-subshell form interacts badly with
  # the tracked-files test's ~1.9k process substitutions under bats (spins at
  # 100% CPU; the dirname form is instant and equivalent here).
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
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

@test "host-neutral lint passes the allowlist escape naming the token" {
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

@test "an escape comment that does not name the token does not exempt the line" {
  cat > "$TMPDIR_FIXTURE/SNEAKY_SKILL.md" <<'EOF'
---
name: sneaky
description: Instructs a host-exclusive call with a blanket escape comment.
---
Call TodoWrite now to track this. <!-- host-tool-allow: something-else -->
EOF
  run host_neutral_check "$TMPDIR_FIXTURE/SNEAKY_SKILL.md"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "TodoWrite"
}

@test "host-neutral lint fails loudly on an unreadable file" {
  run host_neutral_check "$TMPDIR_FIXTURE/does-not-exist.md"
  [ "$status" -eq 2 ]
}

@test "tracked skill bodies (incl. vendor/gstack snapshot) name no host-specific tools" {
  run bash -c 'source "${0}/tests/lib/host-neutral-lib.sh" && git ls-files -- "skills/*/SKILL.md" "design-skills/*/SKILL.md" "marketing-skills/*/SKILL.md" "vendor/gstack/**/SKILL.md" | host_neutral_check_tree' "$REPO_ROOT"
  [ "$status" -eq 0 ]
}

@test "host-token lists in the lint lib and the lexical baseline stay in sync" {
  bash_tokens="$(grep -oE 'multi_tool_use|TodoWrite|update_plan|write_stdin|exec_command|get_context_remaining' "$REPO_ROOT/tests/lib/host-neutral-lib.sh" | sort -u)"
  py_tokens="$(grep -oE '"(multi_tool_use|TodoWrite|update_plan|write_stdin|exec_command|get_context_remaining)"' "$REPO_ROOT/evals/_lib/lexical-baseline.py" | tr -d '"' | sort -u)"
  [ -n "$bash_tokens" ]
  [ "$bash_tokens" = "$py_tokens" ]
}
