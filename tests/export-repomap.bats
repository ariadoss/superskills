#!/usr/bin/env bats
# Tests for scripts/export-repomap.sh — regenerating the public
# ariadoss/repomap repo's six slash-command markdown files from this repo.
#
# The invariant worth protecting is that the export is a PURE COPY of
# skills/<name>/SKILL.md as <name>.md. A rewriting export is the thing that
# drifts: a sed that half-applies yields a file that no longer matches the
# skill the plugin actually ships. So the central test here compares every
# exported file byte-for-byte against its source. The second invariant: the
# export owns only its six paths, so a real git checkout of the public repo
# survives a re-export with .git, README, LICENSE, and code intact.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  EXPORT="$REPO_ROOT/scripts/export-repomap.sh"
  OUT="$BATS_TEST_TMPDIR/out"
  SKILLS=(dbmap repomap dbmap-auto-on dbmap-auto-off repomap-auto-on repomap-auto-off)
}

# fake_repo <dir> — a minimal source repo holding just what the export reads.
# Unlike export-humanize's fixture it needs no git init: the export is a
# plain copy with no tracked-files allowlist.
fake_repo() {
  local fake="$1" n
  mkdir -p "$fake/scripts"
  cp "$EXPORT" "$fake/scripts/"
  for n in "${SKILLS[@]}"; do
    mkdir -p "$fake/skills/$n"
    cp "$REPO_ROOT/skills/$n/SKILL.md" "$fake/skills/$n/SKILL.md"
  done
}

@test "exports the six skills as <name>.md at the repo root" {
  run bash "$EXPORT" "$OUT"
  [ "$status" -eq 0 ]
  for n in "${SKILLS[@]}"; do
    [ -f "$OUT/$n.md" ] || { echo "missing $n.md"; return 1; }
  done
  [ ! -e "$OUT/SKILL.md" ] || { echo "exported a SKILL.md-named file"; return 1; }
}

@test "the export is a pure copy: every <name>.md is byte-identical to skills/<name>/SKILL.md" {
  bash "$EXPORT" "$OUT" >/dev/null
  for n in "${SKILLS[@]}"; do
    cmp "$OUT/$n.md" "$REPO_ROOT/skills/$n/SKILL.md" || { echo "differs: $n"; return 1; }
  done
}

@test "the script verifies byte-identity itself and says so" {
  run bash "$EXPORT" "$OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"byte-identical"* ]] || false
}

@test "re-running is idempotent" {
  bash "$EXPORT" "$OUT" >/dev/null
  first="$(cd "$OUT" && find . -type f -exec shasum {} \; | LC_ALL=C sort)"
  bash "$EXPORT" "$OUT" >/dev/null
  second="$(cd "$OUT" && find . -type f -exec shasum {} \; | LC_ALL=C sort)"
  [ "$first" = "$second" ] || { echo "export is not idempotent"; return 1; }
}

@test "re-export preserves a real checkout's .git and everything it does not own" {
  bash "$EXPORT" "$OUT" >/dev/null
  mkdir -p "$OUT/.git" && echo marker > "$OUT/.git/HEAD"
  echo "standalone readme" > "$OUT/README.md"
  cp "$REPO_ROOT/LICENSE" "$OUT/LICENSE"
  echo "local note" > "$OUT/NOTES.local.md"
  # A path it DOES own (one of the six) SHOULD be replaced, so assert both.
  echo stale > "$OUT/dbmap.md"
  bash "$EXPORT" "$OUT" >/dev/null
  [ "$(cat "$OUT/.git/HEAD")" = "marker" ] || { echo ".git was clobbered"; return 1; }
  [ "$(cat "$OUT/README.md")" = "standalone readme" ] || { echo "README was clobbered"; return 1; }
  cmp "$OUT/LICENSE" "$REPO_ROOT/LICENSE" || { echo "LICENSE was clobbered"; return 1; }
  [ -f "$OUT/NOTES.local.md" ] || { echo "unrelated file was removed"; return 1; }
  cmp "$OUT/dbmap.md" "$REPO_ROOT/skills/dbmap/SKILL.md" || { echo "stale owned file was not replaced"; return 1; }
}

@test "fails loudly when a skill is missing rather than exporting a partial repo" {
  fake="$BATS_TEST_TMPDIR/fakerepo"
  mkdir -p "$fake/scripts" "$fake/skills/dbmap" "$fake/skills/repomap"
  cp "$EXPORT" "$fake/scripts/"
  printf 'only two of six\n' > "$fake/skills/dbmap/SKILL.md"
  printf 'only two of six\n' > "$fake/skills/repomap/SKILL.md"
  run bash "$fake/scripts/export-repomap.sh" "$BATS_TEST_TMPDIR/out2"
  [ "$status" -ne 0 ] || { echo "exported despite a missing skill"; return 1; }
  [[ "$output" == *"no skill at"* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/out2/dbmap-auto-on.md" ] || { echo "partial export was written"; return 1; }
}

@test "refuses an output directory that overlaps the source tree" {
  fake="$BATS_TEST_TMPDIR/overlaprepo"
  fake_repo "$fake"
  # `/` needs its own case: "$OUT/" is then "//", which prefixes nothing.
  for out in "$fake" "$fake/skills" "$BATS_TEST_TMPDIR" /; do
    run bash "$fake/scripts/export-repomap.sh" "$out"
    [ "$status" -eq 1 ] || { echo "exported into $out: $output"; return 1; }
    [[ "$output" == *"refusing to export"* ]] || { echo "$output"; return 1; }
  done
  [ -f "$fake/skills/dbmap/SKILL.md" ] || { echo "the source skills/ was deleted"; return 1; }
}

@test "dist/ itself is an accepted output directory, as the refusal message suggests" {
  fake="$BATS_TEST_TMPDIR/distrepo"
  fake_repo "$fake"
  run bash "$fake/scripts/export-repomap.sh" "$fake/dist"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ -f "$fake/dist/dbmap.md" ] || false
}

@test "the default output path is inside the repo's dist/" {
  run bash -c "grep -n 'dist/repomap' '$EXPORT'"
  [ "$status" -eq 0 ]
}
