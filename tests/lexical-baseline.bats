#!/usr/bin/env bats
# Tests for evals/_lib/lexical-baseline.py — the deterministic lexical
# (BM25-over-frontmatter) skill-selection baseline imported from Codex's
# shadow-selector method. Its selftest builds a two-skill catalog and one
# keyed case under a temp dir beside the script and asserts the grader
# input_match regex (the repo's exact skill-fired.md format) yields the key
# and BM25 ranks it top-1, then removes the temp dir.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "lexical baseline selftest passes" {
  run python3 "$REPO_ROOT/evals/_lib/lexical-baseline.py" --selftest
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "selftest OK"
}
