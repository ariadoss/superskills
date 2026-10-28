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
           .cursor-plugin/plugin.json .cursor-plugin/marketplace.json marketing-skills/.claude-plugin/plugin.json \
           design-skills/.claude-plugin/plugin.json; do
    [ -f "$REPO_ROOT/$f" ] || { echo "missing $f"; return 1; }
    [ "$(grep -c "\"version\"[[:space:]]*:[[:space:]]*\"$VERSION\"" "$REPO_ROOT/$f")" -ge 1 ] || { echo "$f has no version $VERSION"; return 1; }
    stale=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$REPO_ROOT/$f" | grep -v "\"$VERSION\"" || true)
    [ -z "$stale" ] || { echo "$f has stale version: $stale"; return 1; }
  done
}

@test "claude plugin validate accepts the marketplace and plugin dirs under the established warning policy" {
  command -v claude >/dev/null 2>&1 || skip "claude CLI not installed"
  # Read structured warnings: human-readable output gives informational notes
  # the same bullet marker. Keep the existing CLAUDE.md and ICON_MISSING exceptions.
  for target in . marketing-skills design-skills skills; do
    run claude plugin validate "$REPO_ROOT/$target" --json
    [ "$status" -eq 0 ] || { echo "validate failed for $target: $output"; return 1; }
    printf '%s\n' "$output" | python3 "$REPO_ROOT/tests/plugin-validation-report.py" || return 1
  done
}

@test "the root plugin.json itself validates, with CLAUDE.md-at-root as the only accepted warning" {
  command -v claude >/dev/null 2>&1 || skip "claude CLI not installed"
  # Validating the repo directory only reaches marketplace.json; the manifest
  # file must be validated directly. CLAUDE.md at the root is contributor
  # context, deliberately not plugin context, so that one warning is expected.
  run claude plugin validate "$REPO_ROOT/.claude-plugin/plugin.json" --json
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | python3 "$REPO_ROOT/tests/plugin-validation-report.py" || return 1
  # Loud-guard the accepted-warning contract: the sibling tests above filter
  # on this exact text, so if the CLI rewords or stops emitting it, the
  # filters would pass vacuously. Fail here instead, and a human decides
  # whether to restore --strict or re-pin the wording.
  accepted="$(printf '%s\n' "$output" | grep -c 'CLAUDE.md at the plugin root is not loaded' || true)"
  [ "$accepted" -ge 1 ] || { echo "accepted CLAUDE.md warning missing from validate output (CLI format drift?): $output"; return 1; }
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
