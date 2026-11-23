#!/usr/bin/env bats
# Secret values are assembled at runtime so this file never holds a whole key.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$REPO_ROOT/scripts/secrets-prepush-hook.sh"
  ORIGIN="$BATS_TEST_TMPDIR/o.git"; WORK="$BATS_TEST_TMPDIR/w"
  git init -q --bare "$ORIGIN"; git clone -q "$ORIGIN" "$WORK" 2>/dev/null
  git -C "$WORK" config user.email t@example.com; git -C "$WORK" config user.name t
  git -C "$WORK" checkout -q -b main
  git -C "$WORK" commit -q --allow-empty -m seed
  git -C "$WORK" push -q origin main
  git -C "$WORK" branch -q --set-upstream-to=origin/main main
}

need_gitleaks() { command -v gitleaks >/dev/null || skip "gitleaks not installed"; }
# run_hook <cwd> <command>: feed the hook the JSON Claude Code sends.
run_hook() { jq -n --arg c "$2" --arg d "$1" '{tool_input:{command:$c},cwd:$d}' | "$HOOK"; }
commit_key() {  # commit_key [suffix]: add a key-shaped value to cfg.py and commit it
  printf 'aws_key = "AKIA%s"%s\n' "QYLPMST7ZXCVBNMA" "${1:-}" > "$WORK/cfg.py"
  git -C "$WORK" add cfg.py; git -C "$WORK" commit -qm k
}

@test "blocks a push that carries a secret, and never prints it" {
  need_gitleaks; commit_key
  run run_hook "$WORK" "git push"
  [[ "$output" == *'"decision": "block"'* ]] || false
  [[ "$output" == *"found secrets"* ]] || false
  [[ "$output" == *"cfg.py"* ]] || false
  [[ "$output" != *"QYLPMST7ZXCVBNMA"* ]] || false
}
@test "allows a clean push silently" {
  need_gitleaks
  printf 'x = 1\n' > "$WORK/a.py"; git -C "$WORK" add a.py; git -C "$WORK" commit -qm a
  run run_hook "$WORK" "git push"
  [ -z "$output" ]
}
@test "SECRETS_PREPUSH=0 bypasses" {
  need_gitleaks; commit_key
  SECRETS_PREPUSH=0 run run_hook "$WORK" "git push"
  [ -z "$output" ]
}
@test "ignores commands that are not a push" {
  need_gitleaks; commit_key
  run run_hook "$WORK" "git status"
  [ -z "$output" ]
}
@test "the repo's own allowlist, ignore file and inline allow comment do not hide a key" {
  need_gitleaks
  printf '[allowlist]\npaths = [".*"]\n' > "$WORK/.gitleaks.toml"
  commit_key '  # gitleaks:allow'
  printf '%s\n' "*" > "$WORK/.gitleaksignore"
  run run_hook "$WORK" "git push"
  [[ "$output" == *'"decision": "block"'* ]] || false
}
@test "a new branch with no upstream is still scanned" {
  need_gitleaks
  git -C "$WORK" checkout -q -b feature; commit_key
  run run_hook "$WORK" "git push -u origin feature"
  [[ "$output" == *'"decision": "block"'* ]] || false
}
@test "a key on another local branch is caught when pushing that branch from elsewhere" {
  need_gitleaks
  git -C "$WORK" checkout -q -b other; commit_key; git -C "$WORK" checkout -q main
  run run_hook "$WORK" "git push origin other"
  [[ "$output" == *'"decision": "block"'* ]] || false
}
@test "git -C scans the repo it names, not the hook's directory" {
  need_gitleaks; commit_key
  run run_hook "$BATS_TEST_TMPDIR" "git -C $WORK push"
  [[ "$output" == *'"decision": "block"'* ]] || false
}
@test "cd into the repo then push scans that repo" {
  need_gitleaks; commit_key
  run run_hook "$BATS_TEST_TMPDIR" "cd $WORK && git push"
  [[ "$output" == *'"decision": "block"'* ]] || false
}
@test "a quoted subcommand is still scanned" {
  need_gitleaks; commit_key
  run run_hook "$WORK" 'git "push" origin main'
  [[ "$output" == *'"decision": "block"'* ]] || false
}
@test "a scanner error fails closed" {
  need_gitleaks
  . "$REPO_ROOT/scripts/lib/secrets-gate-lib.sh"
  cd "$WORK"
  run sg_scan_unpushed /nonexistent/gate.toml
  [ "$status" -eq 2 ]
}
@test "missing gitleaks allows with a stderr note" {
  commit_key
  # Shadow only gitleaks: a stub dir holding jq and git but no gitleaks.
  STUB="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUB"
  ln -s "$(command -v jq)" "$STUB/jq"; ln -s "$(command -v git)" "$STUB/git"
  run bash -c "jq -n --arg c 'git push' --arg d '$WORK' '{tool_input:{command:\$c},cwd:\$d}' | PATH='$STUB:/usr/bin:/bin' '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gitleaks not installed"* ]] || false
  [[ "$output" != *'"decision"'* ]] || false
}
