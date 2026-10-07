#!/usr/bin/env bats
# Unit tests for evals/_lib/db-fixture.sh — the dbmap experiment's fixture.

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  source "$REPO_ROOT/evals/_lib/db-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "fixture builds the schema with the un-indexed FK trap" {
  db_fixture "$FIX"
  # (Brief deviation: the brief's bare `&&` chain trips the repo's own
  # bash-3.2 errexit guard — tests/bats-assertions.bats — which requires
  # `|| false` terminators; the brief itself uses one on the idx line.)
  [ -f "$FIX/app.db" ] && [ -f "$FIX/.env" ] || false
  tables="$(sqlite3 "$FIX/app.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")"
  [ "$tables" -ge 8 ]
  # orders.user_id is deliberately un-indexed; users.id is the PK
  idx="$(sqlite3 "$FIX/app.db" "SELECT COUNT(*) FROM pragma_index_list('orders');")"
  [ "$idx" -eq 0 ] || false
  grep -q "orders" "$FIX/app/queries/orders_by_user.py"
}

@test "db_fixture is idempotent and leaves cwd alone" {
  start_dir="$PWD"
  db_fixture "$FIX" && db_fixture "$FIX"
  [ "$PWD" = "$start_dir" ]
}
