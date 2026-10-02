#!/usr/bin/env bats
# Contract pins for the vendored clearwing snapshot (vendor/clearwing) that
# skills/pentest Modes 2-4 document and the installed binary is expected to
# match. The snapshot is the REFERENCE, not the runtime: Mode 3 drives the
# installed `clearwing` on PATH, and the drift check compares the installed
# commit against this pin. A snapshot refresh (scripts/sync-clearwing.sh)
# that moves any pinned fact must fail here AND re-verify the Mode 3 bridge
# contract before the upgrade lands.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  VENDOR="$REPO_ROOT/vendor/clearwing"
}

@test "the vendor snapshot exists with commit-pinned provenance" {
  [ -f "$VENDOR/UPSTREAM" ] || { echo "missing vendor/clearwing/UPSTREAM"; return 1; }
  [ -f "$VENDOR/LICENSE" ] || { echo "missing vendor/clearwing/LICENSE (MIT)"; return 1; }
  grep -qF 'https://github.com/Lazarus-AI/clearwing' "$VENDOR/UPSTREAM" || false
  grep -qF '88d3a8a41c22ad9c4d8aaf67bbf5489549740454' "$VENDOR/UPSTREAM" || false
  grep -qi 'MIT' "$VENDOR/UPSTREAM" || false
  # The version string is ambiguous upstream (tag v1.0.0 is an older commit);
  # the snapshot must keep warning to pin by commit.
  grep -qF 'AMBIGUOUS' "$VENDOR/UPSTREAM" || false
  grep -qF 'never auto' "$VENDOR/UPSTREAM" || false
}

@test "environment variables override the config file (the Mode 3 no-provider guarantee)" {
  # SKILL.md promises: "Env vars beat ~/.clearwing/config.yaml (verified in
  # clearwing's providers/env.py)". That fact lives here or nowhere.
  grep -qF 'os.environ.get(ENV_BASE_URL)' "$VENDOR/clearwing/providers/env.py" || false
  grep -qF 'os.environ.get(ENV_API_KEY)' "$VENDOR/clearwing/providers/env.py" || false
  grep -qF 'os.environ.get(ENV_MODEL)' "$VENDOR/clearwing/providers/env.py" || false
}

@test "sourcehunt reads CLEARWING_BASE_URL — the bridge entry point" {
  grep -rqF 'CLEARWING_BASE_URL' "$VENDOR/clearwing/ui/commands/sourcehunt.py" || false
}

@test "sourcehunt exposes --depth and --no-exploit as the skill documents" {
  grep -qF '"--depth"' "$VENDOR/clearwing/ui/commands/sourcehunt.py" || false
  grep -qF '"--no-exploit"' "$VENDOR/clearwing/ui/commands/sourcehunt.py" || false
}

@test "the hunter tool surface the spool protocol names exists" {
  # The Mode 3 answer loop drives record_finding and friends; if the tool
  # moves or renames upstream, the skill's reply examples go stale.
  grep -rqF 'record_finding' "$VENDOR/clearwing/agent/tools/hunt/" || false
}
