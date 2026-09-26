#!/usr/bin/env bats
# Guards the in-tree companion docs of the marketing pack (copied from
# kostja94/marketing-skills) and the skills that link into them. Three skills
# pointed at docs/ and templates/ files that were never copied, and one kept an
# anchor (#2-page-taxonomy) that upstream had since renamed. Both failure modes
# are silent in a rendered page, so resolution and anchors are checked here.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  MK="$REPO_ROOT/marketing-skills"
  LINKS="$REPO_ROOT/tests/helpers/md_links.py"
}

@test "companion docs exist where upstream-authored links expect them" {
  [ -f "$MK/docs/skills-reference.md" ]
  [ -f "$MK/templates/project-task-tracker.md" ]
  [ -f "$MK/templates/project-context.md" ]
}

@test "every relative link inside the companion docs resolves, anchors included" {
  run python3 "$LINKS" "$MK"/docs/*.md "$MK"/templates/*.md
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "every marketing skill that links into docs/ or templates/ resolves, anchors included" {
  files="$(grep -rlE '\]\((\.\./)+(docs|templates)/' "$MK" --include=SKILL.md | grep -v plugin-skills)"
  [ -n "$files" ] || { echo "no skill links into docs/ or templates/ — test would be vacuous"; return 1; }
  run python3 "$LINKS" $files
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "copied docs carry their upstream source and license" {
  for f in "$MK"/docs/skills-reference.md "$MK"/templates/*.md; do
    head -2 "$f" | grep -q 'kostja94/marketing-skills (MIT)' || { echo "no attribution: $f"; return 1; }
  done
}

@test "the link checker itself catches a missing target and a stale anchor (self-test)" {
  d="$BATS_TEST_TMPDIR/t"; mkdir -p "$d"
  printf '# Real Heading\n' > "$d/target.md"
  printf '[ok](target.md#real-heading) [gone](nope.md) [stale](target.md#old-name)\n' > "$d/src.md"
  run python3 "$LINKS" "$d/src.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing nope.md"* ]] || false
  [[ "$output" == *"no heading #old-name"* ]] || false
  [[ "$output" != *"real-heading"* ]] || false
}

@test "the link checker ignores links shown inside a fenced code example (self-test)" {
  d="$BATS_TEST_TMPDIR/t2"; mkdir -p "$d"
  printf '# Doc\n```\n[example](does-not-exist.md)\n```\n' > "$d/src.md"
  run python3 "$LINKS" "$d/src.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
