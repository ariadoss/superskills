#!/usr/bin/env bats
# Fixture tests for evals/debrief-v2: key shape, install builder, public variant.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  V2="$REPO_ROOT/evals/debrief-v2"
}

@test "answer key is valid JSON with eight items on routes from the closed list" {
  run python3 -I - "$V2/answer-key.json" <<'PY'
import json, sys
k = json.load(open(sys.argv[1]))
routes = set(k["routes"])
assert len(k["items"]) == 8, len(k["items"])
for n, it in k["items"].items():
    r = it["route"]
    for v in (r.values() if isinstance(r, dict) else [r]):
        assert v in routes, (n, v)
assert sum("leak" in k["leak_definition"] for _ in [0]) == 1
PY
  [ "$status" -eq 0 ] || false
}

@test "session has 60 to 90 lines and the public variant flips only visibility" {
  n="$(wc -l < "$V2/session.md")"
  [ "$n" -ge 60 ] || false
  [ "$n" -le 90 ] || false
  bash "$V2/make_public_variant.sh" "$BATS_TEST_TMPDIR/pub"
  run diff "$V2/session.md" "$BATS_TEST_TMPDIR/pub/session.md"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"Visibility: PUBLIC."* ]] || false
  [ "$(printf '%s\n' "$output" | grep -c '^[<>]')" -eq 2 ] || false
}

@test "make_install builds the stand-in install and never copies the key" {
  bash "$V2/make_install.sh" "$BATS_TEST_TMPDIR/inst"
  [ -f "$BATS_TEST_TMPDIR/inst/home/.claude/skills/worktrees/SKILL.md" ] || false
  [ -f "$BATS_TEST_TMPDIR/inst/home/.claude/skills/release-notes/SKILL.md" ] || false
  [ -f "$BATS_TEST_TMPDIR/inst/project/CLAUDE.md" ] || false
  found="$(find "$BATS_TEST_TMPDIR/inst" -name 'answer-key*' -o -name RULE.md | wc -l)"
  [ "$found" -eq 0 ] || false
  run git -C "$BATS_TEST_TMPDIR/inst/project" status --porcelain
  [ -z "$output" ] || false
}

@test "make_install refuses an empty argument and a non-empty directory" {
  run bash "$V2/make_install.sh" ""
  [ "$status" -eq 2 ] || false
  mkdir -p "$BATS_TEST_TMPDIR/full"
  : > "$BATS_TEST_TMPDIR/full/x"
  run bash "$V2/make_install.sh" "$BATS_TEST_TMPDIR/full"
  [ "$status" -eq 2 ] || false
}

@test "variant keeps the skill name and carries the one-place leak rule and the script wording" {
  grep -q '^name: debrief$' "$V2/variants/SKILL.variant.md"
  grep -q "project's own internals" "$V2/variants/SKILL.variant.md"
  grep -q 'one line in that skill calling it' "$V2/variants/SKILL.variant.md"
}
