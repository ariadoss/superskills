#!/usr/bin/env bats
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  GATE="$REPO_ROOT/scripts/suite-gate-prepush.sh"
  CLI="$REPO_ROOT/scripts/suite-stamp.sh"
  BARE="$BATS_TEST_TMPDIR/remote.git"; git init -q --bare -b main "$BARE"
  R="$BATS_TEST_TMPDIR/repo"; mkdir -p "$R"; cd "$R"
  git init -q -b main
  git config user.email t@t && git config user.name t
  git remote add origin "$BARE"
  echo one > a.txt && git add a.txt && git commit -qm one
}

# feed <local-sha> <remote-ref> — what git pipes into pre-push.
feed() { printf 'refs/heads/x %s %s %s\n' "$1" "$2" "0000000000000000000000000000000000000000" | "$GATE" origin "$BARE"; }

@test "gate: repo that never ran init is untouched" {
  run feed "$(git rev-parse HEAD)" refs/heads/main
  [ "$status" -eq 0 ] || false
}

@test "gate: unstamped push to main is blocked and the message names the fix" {
  "$CLI" init true
  run feed "$(git rev-parse HEAD)" refs/heads/main
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"suite-stamp.sh ensure"* ]] || false
}

@test "gate: stamped push to main passes" {
  "$CLI" init true; "$CLI" run
  run feed "$(git rev-parse HEAD)" refs/heads/main
  [ "$status" -eq 0 ] || false
}

@test "gate: push to another branch passes" {
  "$CLI" init true
  run feed "$(git rev-parse HEAD)" refs/heads/feat
  [ "$status" -eq 0 ] || false
}

@test "gate: gates the pushed commit's tree, not HEAD's" {
  "$CLI" init true
  git checkout -q -b feat; echo two > b.txt; git add b.txt; git commit -qm two
  pushed="$(git rev-parse HEAD)"
  git checkout -q main; "$CLI" run            # stamps main's tree only
  run feed "$pushed" refs/heads/main
  [ "$status" -eq 1 ] || false
}

@test "gate: deleting a remote branch is not gated" {
  "$CLI" init true
  run feed 0000000000000000000000000000000000000000 refs/heads/main
  [ "$status" -eq 0 ] || false
}

@test "gate: SUITE_GATE=0 bypasses" {
  "$CLI" init true
  SUITE_GATE=0 run feed "$(git rev-parse HEAD)" refs/heads/main
  [ "$status" -eq 0 ] || false
}

@test "real git: init installs the hook and a real push to main is blocked, then allowed after ensure" {
  "$CLI" init true
  [ -x "$(git rev-parse --git-path hooks)/pre-push" ] || false
  run git push origin main
  [ "$status" -ne 0 ] || false
  [[ "$output" == *"suite-stamp.sh ensure"* ]] || false
  "$CLI" ensure
  run git push origin main
  [ "$status" -eq 0 ] || false
}

@test "real git: a fast-forward push of already-stamped code needs no new run" {
  "$CLI" init "echo x >> '$BATS_TEST_TMPDIR/count'"
  git checkout -q -b feat; echo two > b.txt; git add b.txt; git commit -qm two
  "$CLI" ensure
  git checkout -q main; git merge -q --ff-only feat
  run git push origin main
  [ "$status" -eq 0 ] || false
  [ "$(wc -l < "$BATS_TEST_TMPDIR/count" | tr -d ' ')" = 1 ] || false
}

@test "gate: master is gated like main, tags are not" {
  "$CLI" init true
  run bash -c "printf 'refs/heads/x %s refs/heads/master 0\n' '$(git rev-parse HEAD)' | '$GATE'"
  [ "$status" -eq 1 ] || false
  run bash -c "printf 'refs/tags/v1 %s refs/tags/v1 0\n' '$(git rev-parse HEAD)' | '$GATE'"
  [ "$status" -eq 0 ] || false
}

@test "gate: one unstamped main ref blocks a multi-ref push" {
  "$CLI" init true
  run bash -c "printf 'refs/heads/a %s refs/heads/a 0\nrefs/heads/x %s refs/heads/main 0\n' '$(git rev-parse HEAD)' '$(git rev-parse HEAD)' | '$GATE'"
  [ "$status" -eq 1 ] || false
}

@test "a stamp made in a linked worktree is honored from the main checkout" {
  "$CLI" init true
  git worktree add -q "$BATS_TEST_TMPDIR/wt" -b feat
  (cd "$BATS_TEST_TMPDIR/wt" && "$CLI" run)
  run "$CLI" check
  [ "$status" -eq 0 ] || false
}

@test "a stamp made with a different suite command does not satisfy the gate" {
  git config --local superskills.suiteCommand true
  source "$REPO_ROOT/scripts/lib/suite-stamp-lib.sh"
  ssl_record "$(ssl_tree HEAD)" true
  git config --local superskills.suiteCommand "make test"
  run ssl_has "$(ssl_tree HEAD)"
  [ "$status" -ne 0 ] || false
}

@test "status says plainly when the push gate is not active" {
  git config --local superskills.suiteCommand true
  run "$CLI" status
  [[ "$output" == *"NOT active"* ]] || false
}

@test "init honors core.hooksPath" {
  mkdir -p "$BATS_TEST_TMPDIR/hp"; git config core.hooksPath "$BATS_TEST_TMPDIR/hp"
  "$CLI" init true
  [ -x "$BATS_TEST_TMPDIR/hp/pre-push" ] || false
}

@test "init leaves a foreign pre-push hook alone and says so" {
  mkdir -p "$(git rev-parse --git-path hooks)"
  printf '#!/bin/sh\necho mine\n' > "$(git rev-parse --git-path hooks)/pre-push"
  chmod +x "$(git rev-parse --git-path hooks)/pre-push"
  run "$CLI" init true
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"not installed"* ]] || false
  grep -q "echo mine" "$(git rev-parse --git-path hooks)/pre-push" || false
}

@test "init is idempotent" {
  "$CLI" init true; "$CLI" init true
  [ "$(grep -c 'superskills suite gate' "$(git rev-parse --git-path hooks)/pre-push")" = 1 ] || false
}

@test "status: shows whether HEAD's tree is stamped and the recent stamps" {
  "$CLI" init true
  run "$CLI" status
  [[ "$output" == *"not stamped"* ]] || false
  "$CLI" run
  run "$CLI" status
  [[ "$output" == *"stamped"* && "$output" == *"true"* ]] || false
}
