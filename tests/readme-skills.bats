#!/usr/bin/env bats
# The README's "## Skills (N)" header, its command table, and skills/ drifted
# apart twice (41 in the header while two skills had no row, then 44 with 42
# rows). All three are checked together so the next skill added without a
# README row fails here instead of shipping a wrong count.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  README="$REPO_ROOT/README.md"
  section="$(awk '/^## Skills \(/{f=1} f&&/^## /&&!/^## Skills \(/{exit} f' "$README")"
}

@test "the Skills header count equals the number of skills/ directories" {
  header="$(printf '%s\n' "$section" | head -1 | sed -E 's/^## Skills \(([0-9]+)\).*/\1/')"
  dirs="$(find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
  [ "$header" = "$dirs" ] || { echo "header says $header, skills/ has $dirs"; return 1; }
}

@test "every skills/ directory has a row in the Skills table" {
  missing=""
  for d in "$REPO_ROOT"/skills/*/; do
    n="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || continue
    printf '%s\n' "$section" | grep -q "^| \`/$n\`" || missing="$missing $n"
  done
  [ -z "$missing" ] || { echo "no README row for:$missing"; return 1; }
}
