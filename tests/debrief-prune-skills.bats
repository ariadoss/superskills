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

@test "debrief: name equals directory and boundaries name the neighbours" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  [ -f "$f" ]
  grep -q '^name: debrief$' "$f"
  grep -q '/skillify' "$f"
  grep -q '/handoff' "$f"
  grep -q '/prune-skills' "$f"
}

@test "debrief: proposes only and protects public repos" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  grep -qi 'never write' "$f"
  grep -qi 'public repo' "$f"
}

@test "debrief: checks existing coverage with the overlap tool" {
  grep -q 'skill_overlap.py" query' "$REPO_ROOT/skills/debrief/SKILL.md"
}

@test "debrief: states the low-recall limit and the no-quoting rule" {
  f="$REPO_ROOT/skills/debrief/SKILL.md"
  grep -qi 'low recall' "$f"
  grep -qi 'does NOT mean no skill covers' "$f"
  grep -qi 'never quote' "$f"
  grep -qi 'explicit yes' "$f"
}
