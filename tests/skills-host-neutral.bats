#!/usr/bin/env bats
# Host-neutrality lint: shared skill bodies must not name host-specific tools.
# Superskills installs into Claude Code, Codex, ZCode, OpenCode and minimal
# harnesses; a skill that tells the model to call another host's tool teaches
# a call that cannot succeed here.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/tests/lib/host-neutral-lib.sh"
}

@test "host-neutral lint flags a planted violation" {
  tmp="$(mktemp -d)"
  cat > "$tmp/BAD_SKILL.md" <<'EOF'
---
name: bad
description: Calls a tool that only exists on one host.
---
Use multi_tool_use.parallel to batch your reads.
EOF
  run host_neutral_check "$tmp/BAD_SKILL.md"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "multi_tool_use"
  rm -rf "$tmp"
}

@test "host-neutral lint passes the allowlist escape" {
  tmp="$(mktemp -d)"
  cat > "$tmp/OK_SKILL.md" <<'EOF'
---
name: ok
description: Documents a host tool without instructing its use.
---
The Codex harness names a tool multi_tool_use.parallel. <!-- host-tool-allow: multi_tool_use -->
EOF
  run host_neutral_check "$tmp/OK_SKILL.md"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "tracked skill bodies name no host-specific tools" {
  files="$(git ls-files -- 'skills/*/SKILL.md' 'design-skills/*/SKILL.md' 'marketing-skills/*/SKILL.md')"
  [ -n "$files" ]
  status_sum=0
  while IFS= read -r f; do
    host_neutral_check "$f" || status_sum=1
  done <<< "$files"
  [ "$status_sum" -eq 0 ]
}
