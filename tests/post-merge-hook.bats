#!/usr/bin/env bats
# Tests for scripts/git-hooks/post-merge — the hook that re-runs setup after a
# pull so new skills get linked. Hermetic: a throwaway git repo in
# BATS_TEST_TMPDIR with a fake setup, never the real installer.

setup() {
  HOOK="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/git-hooks/post-merge"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
}

@test "hook is executable and syntactically valid" {
  [ -x "$HOOK" ]
  run bash -n "$HOOK"
  [ "$status" -eq 0 ]
}

@test "hook no-ops (exit 0) outside a git repo" {
  run bash "$HOOK"  # BATS_TEST_TMPDIR is not a git repo
  [ "$status" -eq 0 ]
}

@test "hook no-ops when the repo has no executable setup" {
  cd "$REPO"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "hook invokes ./setup -q when present" {
  cd "$REPO"
  # Fake setup records that it ran and with what args.
  cat > setup <<EOF
#!/usr/bin/env bash
echo "ran:\$*" > "$REPO/setup-was-called"
EOF
  chmod +x setup
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -f "$REPO/setup-was-called" ]
  [ "$(cat "$REPO/setup-was-called")" = "ran:-q" ]
}
