#!/usr/bin/env bats
# debrief and prune-skills: file shape, boundaries, and registration.

setup() { REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"; }

@test "prune-skills: name equals directory and a boundary names the neighbours" {
  f="$REPO_ROOT/skills/prune-skills/SKILL.md"
  [ -f "$f" ]
  grep -q '^name: prune-skills$' "$f"
  grep -q '/skillify' "$f"
  grep -q '/debrief' "$f"
}

@test "prune-skills: refuses to delete without overlap evidence and a usage window" {
  f="$REPO_ROOT/skills/prune-skills/SKILL.md"
  grep -qi 'never delete' "$f"
  grep -q '30 sessions' "$f"
}
