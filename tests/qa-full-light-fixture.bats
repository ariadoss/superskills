#!/usr/bin/env bats
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  D="$BATS_TEST_TMPDIR/light"
}

@test "light fixture: docs-only branch, clean tree, main pushed, one changed file" {
  bash "$REPO_ROOT/evals/_lib/qa-full-light-fixture.sh" "$D"
  [ "$(git -C "$D" branch --show-current)" = "feature/docs-note" ]
  [ -z "$(git -C "$D" status --porcelain)" ]
  [ "$(git -C "$D" diff --name-only origin/main...HEAD)" = "README.md" ]
}
