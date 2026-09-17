#!/usr/bin/env bats
# Script-level test for scripts/sync-version.sh: it stamps every manifest
# (including the Cursor ones) and regenerates the marketing plugin, and it
# fails when a manifest is missing. Runs on a copy of the repo's scripts so the
# real manifests are never touched.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  R="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$R/scripts/lib" "$R/.claude-plugin" "$R/.codex-plugin" "$R/.cursor-plugin" "$R/marketing-skills/seo/local"
  cp "$REPO_ROOT/scripts/sync-version.sh" "$REPO_ROOT/scripts/sync-marketing-manifest.sh" "$R/scripts/"
  cp "$REPO_ROOT/scripts/lib/version-lib.sh" "$REPO_ROOT/scripts/lib/manifest-lib.sh" "$REPO_ROOT/scripts/lib/skills-lib.sh" "$R/scripts/lib/"
  printf '3.1.4\n' > "$R/VERSION"
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .cursor-plugin/marketplace.json; do
    printf '{ "name": "superskills", "version": "0.0.0" }\n' > "$R/$f"
  done
  printf -- '---\nname: local-seo\n---\n' > "$R/marketing-skills/seo/local/SKILL.md"
}

@test "stamps all five manifests and regenerates the marketing plugin at VERSION" {
  run bash "$R/scripts/sync-version.sh"
  [ "$status" -eq 0 ]
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .cursor-plugin/plugin.json .cursor-plugin/marketplace.json; do
    grep -q '"version": "3.1.4"' "$R/$f" || { echo "$f not stamped"; return 1; }
  done
  grep -q '"version": "3.1.4"' "$R/marketing-skills/.claude-plugin/plugin.json"
  [ -L "$R/marketing-skills/plugin-skills/local-seo" ]
}

@test "exits non-zero and names the file when a manifest is missing" {
  rm "$R/.cursor-plugin/marketplace.json"
  run bash "$R/scripts/sync-version.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[skip] .cursor-plugin/marketplace.json"* ]] || false
}

@test "exits non-zero when VERSION is empty" {
  : > "$R/VERSION"
  run bash "$R/scripts/sync-version.sh"
  [ "$status" -eq 1 ]
}
