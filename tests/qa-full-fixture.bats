#!/usr/bin/env bats
# Tests for evals/_lib/qa-full-fixture.sh (the /qa-full eval repo), the ledger
# hook installer, and the plugin hooks file. Hermetic: builds under BATS_TEST_TMPDIR.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  D="$BATS_TEST_TMPDIR/fx"
}

@test "fixture: feature branch checked out, clean tree, main pushed to a local origin" {
  bash "$REPO_ROOT/evals/_lib/qa-full-fixture.sh" "$D"
  [ "$(git -C "$D" branch --show-current)" = "feature/checkout" ]
  [ -z "$(git -C "$D" status --porcelain)" ]
  [ "$(git -C "$D" rev-parse origin/main)" = "$(git -C "$D" rev-parse main)" ]
  run git -C "$D" rev-parse --verify -q origin/feature/checkout
  [ "$status" -ne 0 ]
}

@test "fixture: main is green and the feature branch has exactly one failing test" {
  command -v node >/dev/null || skip "node not installed"
  bash "$REPO_ROOT/evals/_lib/qa-full-fixture.sh" "$D"
  run bash -c "cd '$D' && npm test 2>&1"
  printf '%s\n' "$output" | grep -q '^# fail 1$' || false
  git -C "$D" switch -q main
  run bash -c "cd '$D' && npm test 2>&1"
  printf '%s\n' "$output" | grep -q '^# fail 0$' || false
}

@test "fixture: plants the Stripe-format key in the fixture but not as a literal in this repo" {
  bash "$REPO_ROOT/evals/_lib/qa-full-fixture.sh" "$D"
  grep -q 'sk_live_51Fake' "$D/src/payments.js" || false
  grep -q 'sk_live_51Fake' "$D/Dockerfile" || false
  run grep -c 'sk_live' "$REPO_ROOT/evals/_lib/qa-full-fixture.sh"
  [ "$output" = "0" ]
}

@test "installer: prints Stop and SubagentStop entries pointing at the absolute hook path" {
  run "$REPO_ROOT/scripts/install-qa-full-ledger-hook.sh"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '"Stop"' || false
  printf '%s\n' "$output" | grep -q '"SubagentStop"' || false
  printf '%s\n' "$output" | grep -qF "$REPO_ROOT/scripts/qa-full-ledger-hook.sh" || false
}

@test "hooks.json: valid JSON registering the ledger hook for Stop and SubagentStop" {
  command -v jq >/dev/null || skip "jq not installed"
  run jq -r '.hooks | to_entries[] | "\(.key) \(.value[0].hooks[0].command)"' "$REPO_ROOT/hooks/hooks.json"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '^Stop .*qa-full-ledger-hook.sh' || false
  printf '%s\n' "$output" | grep -q '^SubagentStop .*qa-full-ledger-hook.sh' || false
}

@test "daily-qa fixture: main holds both commits, only the planted one is inside a 24h window" {
  bash "$REPO_ROOT/evals/_lib/daily-qa-fixture.sh" "$D"
  [ "$(git -C "$D" branch --show-current)" = "main" ]
  [ -z "$(git -C "$D" status --porcelain)" ]
  [ "$(git -C "$D" rev-list --count HEAD)" = "2" ]
  run git -C "$D" log --since="24 hours ago" --format=%s
  [ "$output" = "feature: checkout (discounts, payments, orders, form, container)" ]
  run git -C "$D" branch --list feature/checkout
  [ -z "$output" ]
}
