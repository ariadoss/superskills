#!/usr/bin/env bats
# Unit tests for scripts/lib/mirror-lib.sh — wrapping an upstream slash-command
# file into a valid SKILL.md (frontmatter with name + description) for the
# dbmap/repomap mirrors. Both `claude plugin validate --strict` and Codex's
# plugin validator reject a SKILL.md without frontmatter.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/lib/mirror-lib.sh"
  SRC="$BATS_TEST_TMPDIR/dbmap.md"
  printf 'Generate a database schema map for the current project.\n\nFirst, locate the install.\n' > "$SRC"
  FM="$BATS_TEST_TMPDIR/with-fm.md"
  printf -- '---\nname: upstream-name\ndescription: already there\n---\nBody.\n' > "$FM"
}

@test "mirror_wrap prepends frontmatter using the dir name and the first line as description" {
  run mirror_wrap dbmap "$SRC"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | sed -n '1p')" = "---" ]
  [ "$(printf '%s\n' "$output" | sed -n '2p')" = "name: dbmap" ]
  [ "$(printf '%s\n' "$output" | sed -n '3p')" = "description: Generate a database schema map for the current project." ]
  [ "$(printf '%s\n' "$output" | sed -n '6p')" = "---" ]
  [[ "$output" == *"First, locate the install."* ]]
}

@test "mirror_wrap records the upstream in metadata so the source stays traceable" {
  run mirror_wrap dbmap "$SRC"
  [[ "$output" == *"upstream: https://github.com/ariadoss/repomap"* ]]
}

@test "mirror_wrap keeps upstream frontmatter but pins name: to the mirror's directory name" {
  run mirror_wrap dbmap "$FM"
  [ "$(printf '%s\n' "$output" | sed -n '2p')" = "name: dbmap" ]
  [[ "$output" == *"description: already there"* ]]
  [[ "$output" == *"Body."* ]]
  [[ "$output" != *"upstream-name"* ]]
}

@test "mirror_wrap leaves a file whose frontmatter name already matches untouched" {
  run mirror_wrap upstream-name "$FM"
  [ "$output" = "$(cat "$FM")" ]
}

@test "mirror_wrap is idempotent (wrapping the wrapped output changes nothing)" {
  mirror_wrap dbmap "$SRC" > "$BATS_TEST_TMPDIR/once.md"
  run mirror_wrap dbmap "$BATS_TEST_TMPDIR/once.md"
  [ "$output" = "$(cat "$BATS_TEST_TMPDIR/once.md")" ]
}

@test "mirror_wrap treats an opening --- with no closing --- as no frontmatter (never emits an unterminated block)" {
  BAD="$BATS_TEST_TMPDIR/bad.md"
  printf -- '---\nthis file starts with a rule but has no frontmatter\nname: not-a-key\n' > "$BAD"
  run mirror_wrap dbmap "$BAD"
  [ "$(printf '%s\n' "$output" | sed -n '2p')" = "name: dbmap" ]
  [ "$(printf '%s\n' "$output" | grep -c '^---$')" -eq 3 ]   # synthetic open+close, then the original line
  [[ "$output" == *"name: not-a-key"* ]]                        # body untouched
}

@test "mirror_wrap adds name: when upstream frontmatter has none" {
  NO_NAME="$BATS_TEST_TMPDIR/no-name.md"
  printf -- '---\ndescription: already there\n---\nBody.\n' > "$NO_NAME"
  run mirror_wrap dbmap "$NO_NAME"
  # name: lands inside the frontmatter (before the closing ---), position is irrelevant
  [ "$(printf '%s\n' "$output" | awk 'NR>1 && /^---$/ {exit} /^name: dbmap$/ {found=1} END {print found+0}')" -eq 1 ]
  [[ "$output" == *"description: already there"* ]]
  [ "$(printf '%s\n' "$output" | grep -c '^---$')" -eq 2 ]
}

