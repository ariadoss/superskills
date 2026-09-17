#!/usr/bin/env bats
# Script-level tests for scripts/sync-mirrors.sh: it wraps the upstream slash
# command files in frontmatter (scripts/lib/mirror-lib.sh), reports ok/sync per
# mirror, is idempotent, and fails clearly when the upstream is missing. Runs
# on a copy of the script in a fixture repo with REPOMAP_HOME pointed at a
# fixture upstream — never the real checkout.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  R="$BATS_TEST_TMPDIR/repo"; UP="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$R/scripts/lib" "$R/skills/dbmap" "$R/skills/repomap" "$UP"
  cp "$REPO_ROOT/scripts/sync-mirrors.sh" "$R/scripts/"; cp "$REPO_ROOT/scripts/lib/mirror-lib.sh" "$R/scripts/lib/"
  printf 'Generate a database schema map.\n\nBody.\n' > "$UP/dbmap.md"
  printf 'Generate a repo map.\n' > "$UP/repomap.md"
  export REPOMAP_HOME="$UP"
}

@test "wraps each upstream file into skills/<name>/SKILL.md with frontmatter and reports sync" {
  run bash "$R/scripts/sync-mirrors.sh" --no-pull
  [ "$status" -eq 0 ]
  [[ "$output" == *"sync:  dbmap"* ]] || false
  [ "$(sed -n '1p' "$R/skills/dbmap/SKILL.md")" = "---" ]
  [ "$(sed -n '2p' "$R/skills/dbmap/SKILL.md")" = "name: dbmap" ]
  grep -q '^description: "Generate a database schema map."$' "$R/skills/dbmap/SKILL.md"
  grep -q '^Body.$' "$R/skills/dbmap/SKILL.md"
}

@test "a second run reports every mirror ok and changes nothing (idempotent)" {
  bash "$R/scripts/sync-mirrors.sh" --no-pull >/dev/null
  before="$(cat "$R/skills/dbmap/SKILL.md")"
  run bash "$R/scripts/sync-mirrors.sh" --no-pull
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok:    dbmap"* ]] || false
  [[ "$output" == *"all mirrors in sync."* ]] || false
  [ "$before" = "$(cat "$R/skills/dbmap/SKILL.md")" ]
}

@test "skips a mirror whose skills/<name> dir does not exist, and one with no upstream file" {
  run bash "$R/scripts/sync-mirrors.sh" --no-pull
  [[ "$output" == *"skip:  dbmap-auto-on"* ]] || false
}

@test "fails with the clone hint when no upstream can be found" {
  export REPOMAP_HOME="$BATS_TEST_TMPDIR/nowhere"
  HOME="$BATS_TEST_TMPDIR/fakehome" run bash "$R/scripts/sync-mirrors.sh" --no-pull
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not find the repomap upstream"* ]] || false
}

@test "upstream precedence: REPOMAP_HOME, then ~/claude-repomap-command, then ~/.claude-repomap-command, then ~/.local/share/…" {
  H="$BATS_TEST_TMPDIR/fakehome"
  for d in claude-repomap-command .claude-repomap-command .local/share/claude-repomap-command; do
    mkdir -p "$H/$d"; printf 'Generate a database schema map.\n' > "$H/$d/dbmap.md"
  done
  run env HOME="$H" REPOMAP_HOME="$UP" bash "$R/scripts/sync-mirrors.sh" --no-pull
  [[ "$output" == "upstream: $UP"* ]] || false
  run env -u REPOMAP_HOME HOME="$H" bash "$R/scripts/sync-mirrors.sh" --no-pull
  [[ "$output" == "upstream: $H/claude-repomap-command"* ]] || false
  rm -rf "$H/claude-repomap-command"
  run env -u REPOMAP_HOME HOME="$H" bash "$R/scripts/sync-mirrors.sh" --no-pull
  [[ "$output" == "upstream: $H/.claude-repomap-command"* ]] || false
  rm -rf "$H/.claude-repomap-command"
  run env -u REPOMAP_HOME HOME="$H" bash "$R/scripts/sync-mirrors.sh" --no-pull
  [[ "$output" == "upstream: $H/.local/share/claude-repomap-command"* ]] || false
}

@test "an upstream dir without dbmap.md is skipped in favour of the next candidate" {
  H="$BATS_TEST_TMPDIR/fakehome"; mkdir -p "$H/claude-repomap-command" "$H/.claude-repomap-command"
  printf 'Generate a database schema map.\n' > "$H/.claude-repomap-command/dbmap.md"
  run env REPOMAP_HOME="$BATS_TEST_TMPDIR/empty-upstream" HOME="$H" bash "$R/scripts/sync-mirrors.sh" --no-pull
  [[ "$output" == "upstream: $H/.claude-repomap-command"* ]] || false
}

