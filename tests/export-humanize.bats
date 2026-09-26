#!/usr/bin/env bats
# Tests for scripts/export-humanize.sh — assembling the standalone humanize repo.
#
# The invariant worth protecting is that the export is a PURE COPY. A rewriting
# export is the thing that drifts: a sed that half-applies yields a tree whose
# tests pass and whose docs point at paths that no longer exist. So the central
# test here compares every exported file byte-for-byte against its source.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  EXPORT="$REPO_ROOT/scripts/export-humanize.sh"
  OUT="$BATS_TEST_TMPDIR/out"
}

# fake_repo <dir> — a minimal source repo holding just what the export reads,
# with those files staged: the export ships only files git knows about. Junk a
# test plants afterwards is therefore untracked, as it would be for real.
fake_repo() {
  local fake="$1"
  mkdir -p "$fake/scripts" "$fake/tests" "$fake/skills"
  cp -R "$REPO_ROOT/skills/humanize" "$fake/skills/"
  rm -rf "$fake/skills/humanize/toolkit/__pycache__"
  cp -R "$REPO_ROOT/scripts/humanize-dist" "$fake/scripts/"
  cp "$EXPORT" "$fake/scripts/"
  cp "$REPO_ROOT/tests/humanize-toolkit.bats" "$fake/tests/"
  cp "$REPO_ROOT/LICENSE" "$fake/"
  git -C "$fake" init -q && git -C "$fake" add -A
}

@test "exports the standalone layout" {
  run bash "$EXPORT" "$OUT"
  [ "$status" -eq 0 ]
  for f in SKILL.md README.md LICENSE NOTICE.md .gitignore \
           toolkit/emdash_fix.py toolkit/slop_report.py toolkit/NOTICE.md \
           tests/humanize-toolkit.bats; do
    [ -f "$OUT/$f" ] || { echo "missing $f"; return 1; }
  done
}

@test "the export is a pure copy: every file is byte-identical to its source" {
  bash "$EXPORT" "$OUT" >/dev/null
  cmp "$OUT/SKILL.md"                  "$REPO_ROOT/skills/humanize/SKILL.md" || return 1
  cmp "$OUT/LICENSE"                   "$REPO_ROOT/LICENSE" || return 1
  cmp "$OUT/NOTICE.md"                 "$REPO_ROOT/skills/humanize/toolkit/NOTICE.md" || return 1
  cmp "$OUT/README.md"                 "$REPO_ROOT/scripts/humanize-dist/README.md" || return 1
  cmp "$OUT/tests/humanize-toolkit.bats" "$REPO_ROOT/tests/humanize-toolkit.bats" || return 1
  for f in "$REPO_ROOT"/skills/humanize/toolkit/*; do
    [ -f "$f" ] || continue   # e.g. a local __pycache__/, which is never exported
    cmp "$f" "$OUT/toolkit/$(basename "$f")" || { echo "differs: $(basename "$f")"; return 1; }
  done
}

@test "the exported tree passes its own tests, and the script says so" {
  run bash "$EXPORT" "$OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tests pass in the exported tree"* ]] || false
}

@test "re-running is idempotent" {
  bash "$EXPORT" "$OUT" >/dev/null
  first="$(cd "$OUT" && find . -type f -exec shasum {} \; | LC_ALL=C sort)"
  bash "$EXPORT" "$OUT" >/dev/null
  second="$(cd "$OUT" && find . -type f -exec shasum {} \; | LC_ALL=C sort)"
  [ "$first" = "$second" ] || { echo "export is not idempotent"; return 1; }
}

@test "re-export preserves a real checkout's .git and unrelated files" {
  bash "$EXPORT" "$OUT" >/dev/null
  mkdir -p "$OUT/.git" && echo marker > "$OUT/.git/HEAD"
  echo "local note" > "$OUT/NOTES.local.md"
  # A file it no longer owns inside toolkit/ SHOULD be cleared, so assert both.
  echo stale > "$OUT/toolkit/stale.json"
  bash "$EXPORT" "$OUT" >/dev/null
  [ "$(cat "$OUT/.git/HEAD")" = "marker" ] || { echo ".git was clobbered"; return 1; }
  [ -f "$OUT/NOTES.local.md" ] || { echo "unrelated file was removed"; return 1; }
  [ ! -f "$OUT/toolkit/stale.json" ] || { echo "stale toolkit file survived"; return 1; }
}

@test "the exported README points at toolkit/ and never at a path the export does not create" {
  bash "$EXPORT" "$OUT" >/dev/null
  run grep -c 'humanize_toolkit' "$OUT/README.md"
  [ "$output" = "0" ] || { echo "README references a nonexistent humanize_toolkit/ path"; return 1; }
  run grep -c 'toolkit/' "$OUT/README.md"
  [ "$output" -ge 1 ] || false
}

@test "fails loudly when the skill is missing rather than exporting an empty repo" {
  fake="$BATS_TEST_TMPDIR/fakerepo"
  mkdir -p "$fake/scripts" "$fake/tests"
  cp "$EXPORT" "$fake/scripts/"
  run bash "$fake/scripts/export-humanize.sh" "$BATS_TEST_TMPDIR/out2"
  [ "$status" -ne 0 ] || { echo "exported despite a missing skill"; return 1; }
  [[ "$output" == *"no skill at"* ]] || false
}

@test "the default output path is inside the repo's dist/" {
  run bash -c "grep -n 'dist/humanize' '$EXPORT'"
  [ "$status" -eq 0 ]
}

@test "fails loudly when the toolkit dir is missing rather than exporting an empty toolkit" {
  fake="$BATS_TEST_TMPDIR/fakerepo2"
  mkdir -p "$fake/scripts" "$fake/skills/humanize"
  cp "$EXPORT" "$fake/scripts/"
  echo skill > "$fake/skills/humanize/SKILL.md"
  run bash "$fake/scripts/export-humanize.sh" "$BATS_TEST_TMPDIR/out3"
  [ "$status" -ne 0 ] || { echo "exported despite a missing toolkit"; return 1; }
  [[ "$output" == *"no toolkit at"* ]] || false
}

@test "a __pycache__ inside the toolkit neither aborts the export nor ships" {
  # Importing any toolkit module creates toolkit/__pycache__/. A wildcard cp of
  # the toolkit then hit a directory, failed under set -e, and killed the export.
  fake="$BATS_TEST_TMPDIR/pyrepo"
  fake_repo "$fake"
  mkdir -p "$fake/skills/humanize/toolkit/__pycache__"
  echo junk > "$fake/skills/humanize/toolkit/__pycache__/emdash_fix.cpython-311.pyc"
  run bash "$fake/scripts/export-humanize.sh" "$BATS_TEST_TMPDIR/pyout"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ ! -e "$BATS_TEST_TMPDIR/pyout/toolkit/__pycache__" ] || { echo "__pycache__ shipped"; return 1; }
}

@test "hidden files (e.g. a macOS .DS_Store) in the toolkit never ship to the public tree" {
  # Regression from switching to find -type f, which unlike the toolkit/* glob
  # also matches dotfiles.
  fake="$BATS_TEST_TMPDIR/dotrepo"
  fake_repo "$fake"
  printf 'finder junk\n' > "$fake/skills/humanize/toolkit/.DS_Store"
  run bash "$fake/scripts/export-humanize.sh" "$BATS_TEST_TMPDIR/dotout"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ ! -e "$BATS_TEST_TMPDIR/dotout/toolkit/.DS_Store" ] || { echo ".DS_Store shipped"; return 1; }
}

@test "only git-tracked toolkit files ship; a stray untracked file does not" {
  # The public tree is built from an allowlist (the index), not a denylist, so
  # scratch notes or a misnamed secret left in the toolkit cannot be published.
  fake="$BATS_TEST_TMPDIR/strayrepo"
  fake_repo "$fake"
  printf 'private scratch\n' > "$fake/skills/humanize/toolkit/zz_stray_notes.txt"
  run bash "$fake/scripts/export-humanize.sh" "$BATS_TEST_TMPDIR/strayout"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ ! -e "$BATS_TEST_TMPDIR/strayout/toolkit/zz_stray_notes.txt" ] || { echo "untracked file shipped"; return 1; }
  [[ "$output" == *"zz_stray_notes.txt"* ]] || { echo "did not warn about the skipped file"; return 1; }
}

@test "without bats the export fails instead of shipping an unverified tree" {
  command -v bats | grep -qvE '^/(usr/)?bin/' || skip "bats lives in /usr/bin or /bin here"
  run env PATH=/usr/bin:/bin bash "$EXPORT" "$OUT"
  [ "$status" -ne 0 ] || { echo "exited 0 unverified: $output"; return 1; }
  [[ "$output" == *"bats"* ]] || false
}

@test "an untracked file named like a glob is reported literally, not expanded" {
  # $untracked was expanded unquoted, so a file named '*' listed the cwd.
  fake="$BATS_TEST_TMPDIR/globrepo"
  fake_repo "$fake"
  printf 'x\n' > "$fake/skills/humanize/toolkit/*"
  run bash -c "cd '$fake/skills/humanize/toolkit' && bash '$fake/scripts/export-humanize.sh' '$BATS_TEST_TMPDIR/globout' 2>&1 >/dev/null"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(printf '%s\n' "$output" | grep -c 'not exported')" = "1" ] || { echo "$output"; return 1; }
  [[ "$output" == *"publish): *"* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"slop_report.py"* ]] || { echo "glob expanded: $output"; return 1; }
}
