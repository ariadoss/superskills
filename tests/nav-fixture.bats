#!/usr/bin/env bats
# Unit tests for evals/_lib/nav-fixture.sh — the repomap experiment's fixture.

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  source "$REPO_ROOT/evals/_lib/nav-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "fixture builds the scattered notifications feature" {
  nav_fixture "$FIX"
  for f in app/services/notification_service.py app/models/notification.py \
            app/controllers/notification_controller.py app/jobs/digest_job.py \
            app/services/user_service.py web/hooks/notification_hook.py; do
    [ -f "$FIX/$f" ] || { echo "missing $f"; return 1; }
  done
  # the two consumers the task must update, verifiable by content.
  # (Brief deviation: the brief's grep was `notification_service.send`, but its
  # own verbatim fixture imports send_digest directly — the grader text agrees
  # the job "calls send_digest". Grep fixed to match the committed fixture.)
  grep -q "send_digest" "$FIX/app/jobs/digest_job.py"
  grep -q "Notification(" "$FIX/web/hooks/notification_hook.py"
}

@test "nav_fixture is idempotent and leaves cwd alone" {
  start_dir="$PWD"
  nav_fixture "$FIX"
  nav_fixture "$FIX"
  [ "$PWD" = "$start_dir" ]
  git -C "$FIX" rev-parse HEAD >/dev/null
}
