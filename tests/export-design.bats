#!/usr/bin/env bats
# Tests for scripts/export-design.sh: regenerating the public
# ariadoss/design-skills repo from the ten design-* skills here.
#
# Same invariant as the other exports: a PURE COPY. Every exported
# <name>/SKILL.md is byte-identical to design-skills/<name>/SKILL.md, and the
# export owns only its paths, so a real checkout keeps its .git and anything
# else it holds.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  EXPORT="$REPO_ROOT/scripts/export-design.sh"
  OUT="$BATS_TEST_TMPDIR/out"
  SKILLS=(design-principles design-brief design-direction design-variations
          design-prototype design-system-extract design-slop-check
          design-hierarchy design-states design-polish)
}

@test "exports each skill as <name>/SKILL.md plus README and LICENSE" {
  run bash "$EXPORT" "$OUT"
  [ "$status" -eq 0 ]
  for n in "${SKILLS[@]}"; do
    [ -f "$OUT/$n/SKILL.md" ] || { echo "missing $n/SKILL.md"; return 1; }
  done
  [ -f "$OUT/README.md" ]
  [ -f "$OUT/LICENSE" ]
}

@test "the export is a pure copy: every SKILL.md is byte-identical to its source" {
  bash "$EXPORT" "$OUT" >/dev/null
  for n in "${SKILLS[@]}"; do
    cmp "$OUT/$n/SKILL.md" "$REPO_ROOT/design-skills/$n/SKILL.md" || { echo "differs: $n"; return 1; }
  done
  cmp "$OUT/README.md" "$REPO_ROOT/scripts/design-dist/README.md"
  cmp "$OUT/LICENSE" "$REPO_ROOT/LICENSE"
}

@test "the script verifies byte-identity itself and says so" {
  run bash "$EXPORT" "$OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"byte-identical"* ]] || false
}

@test "exports every design-* skill the repo ships, and only those" {
  bash "$EXPORT" "$OUT" >/dev/null
  want="$(cd "$REPO_ROOT/design-skills" && ls -d design-*/ | tr -d / | grep -Ev '^design-(sprint|motion)$' | LC_ALL=C sort)"
  got="$(cd "$OUT" && ls -d */ | tr -d / | LC_ALL=C sort)"
  [ "$want" = "$got" ] || { echo "want: $want"; echo "got: $got"; return 1; }
}

@test "the README names every exported skill" {
  bash "$EXPORT" "$OUT" >/dev/null
  for n in "${SKILLS[@]}"; do
    grep -q "/$n" "$OUT/README.md" || { echo "README does not mention /$n"; return 1; }
  done
}

@test "re-running is idempotent" {
  bash "$EXPORT" "$OUT" >/dev/null
  first="$(cd "$OUT" && find . -type f -exec shasum {} \; | LC_ALL=C sort)"
  bash "$EXPORT" "$OUT" >/dev/null
  second="$(cd "$OUT" && find . -type f -exec shasum {} \; | LC_ALL=C sort)"
  [ "$first" = "$second" ]
}

@test "re-export preserves a real checkout's .git and files it does not own" {
  bash "$EXPORT" "$OUT" >/dev/null
  mkdir -p "$OUT/.git" && echo marker > "$OUT/.git/HEAD"
  echo "local note" > "$OUT/NOTES.local.md"
  bash "$EXPORT" "$OUT" >/dev/null
  [ "$(cat "$OUT/.git/HEAD")" = "marker" ]
  [ -f "$OUT/NOTES.local.md" ]
}

@test "a stale file inside an owned skill directory is removed on re-export" {
  bash "$EXPORT" "$OUT" >/dev/null
  echo stale > "$OUT/design-polish/OLD.md"
  bash "$EXPORT" "$OUT" >/dev/null
  [ ! -e "$OUT/design-polish/OLD.md" ]
}

@test "refuses to export into the source tree" {
  run bash "$EXPORT" "$REPO_ROOT/design-skills"
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing"* ]] || false
  [ -f "$REPO_ROOT/design-skills/design-polish/SKILL.md" ]
}

@test "refuses a symlinked owned destination" {
  mkdir -p "$OUT" "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$OUT/design-polish"
  run bash "$EXPORT" "$OUT"
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/elsewhere")" ]
}
