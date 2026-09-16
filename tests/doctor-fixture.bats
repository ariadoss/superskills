#!/usr/bin/env bats
# The shared eval scaffold (evals/_lib/doctor-fixture.sh) must build exactly
# the install state the doctor-* cases assume; a drift here silently changes
# what every eval grader measures.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  W="$BATS_TEST_TMPDIR/workspace"; mkdir -p "$W"
  source "$REPO_ROOT/scripts/lib/doctor-lib.sh"
}

@test "builds a checkout the doctor accepts, links only the requested skills, stamps the codex manifest, gstack is the vendor copy" {
  (cd "$W" && bash "$REPO_ROOT/evals/doctor-direct/fixture.sh")
  [ -x "$W/fixture-repo/setup" ]
  [ -L "$W/fixture-home/.claude/skills/tdd/SKILL.md" ]
  [ ! -e "$W/fixture-home/.claude/skills/clean-code" ]
  [ -f "$W/fixture-home/.claude/skills/gstack/.superskills-vendor-copy" ]
  run doctor_report "$W/fixture-repo" "$W/fixture-home" definitely-not-claude-xyz
  [[ "$output" == *"| Repo | ready |"* ]]
  [[ "$output" == *"| Links | blocked | 2/3 linked. Not linked: clean-code"* ]]
  [[ "$output" == *"| Manifests | ready |"* ]]
  [[ "$output" == *"| gstack | warning |"* ]]
  [[ "$output" == *"Verdict: blocked"* ]]
}

@test "release-check delta: all skills linked, codex manifest stale" {
  (cd "$W" && bash "$REPO_ROOT/evals/doctor-release-check/fixture.sh")
  [ -L "$W/fixture-home/.claude/skills/clean-code/SKILL.md" ]
  grep -q '"version": "2.23.0"' "$W/fixture-repo/.codex-plugin/plugin.json"
  run doctor_report "$W/fixture-repo" "$W/fixture-home" definitely-not-claude-xyz
  [[ "$output" == *"| Links | ready | 3/3"* ]]
  [[ "$output" == *"| Manifests | warning | stale version in: .codex-plugin/plugin.json"* ]]
}

@test "the fixture's embedded setup script is real bash (parses) and is executable" {
  (cd "$W" && bash "$REPO_ROOT/evals/doctor-direct/fixture.sh")
  run bash -n "$W/fixture-repo/setup"
  [ "$status" -eq 0 ]
}
