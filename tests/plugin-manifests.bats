#!/usr/bin/env bats
# Regression guard for the plugin manifests: every manifest's version equals
# VERSION (scripts/sync-version.sh keeps them in step), and Claude Code's own
# validator accepts the marketplace and each plugin directory.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"
}

@test "every plugin manifest carries the canonical VERSION" {
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json \
           .cursor-plugin/plugin.json .cursor-plugin/marketplace.json marketing-skills/.claude-plugin/plugin.json; do
    [ -f "$REPO_ROOT/$f" ] || { echo "missing $f"; return 1; }
    stale=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$REPO_ROOT/$f" | grep -v "\"$VERSION\"" || true)
    [ -z "$stale" ] || { echo "$f has stale version: $stale"; return 1; }
  done
}

@test "claude plugin validate --strict accepts the marketplace, both plugin dirs and every core skill" {
  command -v claude >/dev/null 2>&1 || skip "claude CLI not installed"
  for target in . marketing-skills skills; do
    run claude plugin validate --strict "$REPO_ROOT/$target"
    [ "$status" -eq 0 ] || { echo "validate failed for $target: $output"; return 1; }
  done
}

@test "every skill dir in the root plugin is named exactly like its frontmatter name (the loader uses the dir name)" {
  # Claude Code exposes a plugin skill as /<plugin>:<directory basename>, ignoring
  # frontmatter `name:`. A mismatch silently publishes the skill under the wrong
  # slash name (found by evals/ on 2.1.273 — four vercel-* design skills).
  bad=""
  for f in "$REPO_ROOT"/skills/*/SKILL.md "$REPO_ROOT"/design-skills/*/SKILL.md; do
    d="$(basename "$(dirname "$f")")"
    n="$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//' | tr -d '[:space:]')"
    [ -z "$n" ] || [ "$n" = "$d" ] || bad="$bad $d→$n"
  done
  [ -z "$bad" ] || { echo "dir/name mismatch:$bad"; return 1; }
}
