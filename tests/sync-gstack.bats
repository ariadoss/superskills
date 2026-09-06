#!/usr/bin/env bats
# Tests for scripts/sync-gstack.sh — refreshes vendor/gstack/ from a gstack git
# checkout. The vendor copy is a markdown-only snapshot of the skill definitions
# (SKILL.md plus the sections/, specialists/, templates/, references/ and
# checklist files those bodies load), VERSION, CLAUDE.md and docs/*.md.
# Hermetic: builds a fake upstream git repo in BATS_TEST_TMPDIR.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/sync-gstack.sh"

  UP="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$UP/review/sections" "$UP/review/specialists" "$UP/browse/dist" "$UP/docs" "$UP/scripts" "$UP/node_modules/x"
  echo "1.80.0.0" > "$UP/VERSION"
  echo "# gstack" > "$UP/CLAUDE.md"
  echo "# root index" > "$UP/SKILL.md"
  printf '#!/bin/sh\necho setup\n' > "$UP/setup"; chmod +x "$UP/setup"
  echo "# review" > "$UP/review/SKILL.md"
  echo "adversarial" > "$UP/review/sections/adversarial.md"
  echo "testing" > "$UP/review/specialists/testing.md"
  echo "checklist" > "$UP/review/checklist.md"
  echo "console.log(1)" > "$UP/review/index.ts"
  echo "# browse" > "$UP/browse/SKILL.md"
  echo "bundled" > "$UP/browse/dist/browse.js"
  echo "split rules" > "$UP/docs/askuserquestion-split.md"
  echo "#!/bin/sh" > "$UP/scripts/gen.sh"
  echo "junk" > "$UP/node_modules/x/README.md"
  echo "untracked" > "$UP/review/untracked.md"
  git -C "$UP" init -q -b main
  git -C "$UP" -c user.name=t -c user.email=t@t add VERSION CLAUDE.md SKILL.md setup review browse docs scripts node_modules
  git -C "$UP" -c user.name=t -c user.email=t@t commit -qm init
  # untracked.md was added above by path, so remove it from the index to keep it untracked
  git -C "$UP" rm -q --cached review/untracked.md
  git -C "$UP" -c user.name=t -c user.email=t@t commit -qm "untrack" >/dev/null

  VENDOR="$BATS_TEST_TMPDIR/vendor/gstack"
  mkdir -p "$VENDOR/old-skill"
  echo "1.15.0.0" > "$VENDOR/VERSION"
  echo "# gone upstream" > "$VENDOR/old-skill/SKILL.md"
}

@test "copies SKILL.md, sections, specialists, checklist, docs, VERSION, CLAUDE.md, setup" {
  run "$SCRIPT" --upstream "$UP" --vendor "$VENDOR"
  [ "$status" -eq 0 ]
  [ -f "$VENDOR/review/SKILL.md" ]
  [ -f "$VENDOR/review/sections/adversarial.md" ]
  [ -f "$VENDOR/review/specialists/testing.md" ]
  [ -f "$VENDOR/review/checklist.md" ]
  [ -f "$VENDOR/browse/SKILL.md" ]
  [ -f "$VENDOR/docs/askuserquestion-split.md" ]
  [ "$(cat "$VENDOR/VERSION")" = "1.80.0.0" ]
  [ "$(cat "$VENDOR/CLAUDE.md")" = "# gstack" ]
  [ -x "$VENDOR/setup" ]
  [ "$(cat "$VENDOR/SKILL.md")" = "# root index" ]
}

@test "does not copy code, build output, scripts, node_modules, or untracked files" {
  run "$SCRIPT" --upstream "$UP" --vendor "$VENDOR"
  [ "$status" -eq 0 ]
  [ ! -e "$VENDOR/review/index.ts" ]
  [ ! -e "$VENDOR/browse/dist" ]
  [ ! -e "$VENDOR/scripts" ]
  [ ! -e "$VENDOR/node_modules" ]
  [ ! -e "$VENDOR/review/untracked.md" ]
}

@test "removes vendor content that no longer exists upstream" {
  run "$SCRIPT" --upstream "$UP" --vendor "$VENDOR"
  [ "$status" -eq 0 ]
  [ ! -e "$VENDOR/old-skill" ]
}

@test "prints the version it synced and the skill count" {
  run "$SCRIPT" --upstream "$UP" --vendor "$VENDOR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.80.0.0"* ]]
  [[ "$output" == *"2 skills"* ]]
}

@test "is idempotent" {
  "$SCRIPT" --upstream "$UP" --vendor "$VENDOR" >/dev/null
  first="$(cd "$VENDOR" && find . -type f | sort | xargs shasum)"
  "$SCRIPT" --upstream "$UP" --vendor "$VENDOR" >/dev/null
  second="$(cd "$VENDOR" && find . -type f | sort | xargs shasum)"
  [ "$first" = "$second" ]
}

@test "fails clearly when the upstream is not a git checkout" {
  run "$SCRIPT" --upstream "$BATS_TEST_TMPDIR/nope" --vendor "$VENDOR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"git checkout"* ]]
}
