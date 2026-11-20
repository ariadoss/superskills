#!/usr/bin/env bats
# The repo-locating block is copied into three skills because a skill needs the
# repo path before it can source any library. This file keeps the copies
# identical, and runs the block against the link shapes ./setup really creates
# (built by the same lib functions, in a temp HOME).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/scripts/lib/skills-lib.sh"
  H="$BATS_TEST_TMPDIR/home"; mkdir -p "$H"
}

# extract_block <skill>: the lines from NAME= to the closing fi of the probe loop.
extract_block() {
  awk '/^NAME=/{f=1} f{print} f && /^fi$/{exit}' "$REPO_ROOT/skills/$1/SKILL.md"
}

@test "the locate block is identical in superskills-doctor, debrief and prune-skills" {
  ref="$(extract_block debrief | sed '/^NAME=/d;/^WANT=/d')"
  [ -n "$ref" ]
  for s in prune-skills superskills-doctor; do
    got="$(extract_block "$s" | sed '/^NAME=/d;/^WANT=/d')"
    [ "$got" = "$ref" ] || { echo "$s differs"; return 1; }
  done
}

@test "each block names its own skill and an existing sentinel file" {
  for s in debrief prune-skills superskills-doctor; do
    extract_block "$s" | grep -qx "NAME=$s"
    want="$(extract_block "$s" | sed -n 's/^WANT=//p')"
    [ -f "$REPO_ROOT/$want" ] || { echo "$s: $want missing"; return 1; }
  done
}

# locate <skill>: run that skill's block under the temp HOME and print ROOT.
locate() {
  { extract_block "$1"; echo 'echo "ROOT=$ROOT"'; } > "$BATS_TEST_TMPDIR/b.sh"
  (cd "$BATS_TEST_TMPDIR" && env -u CLAUDE_PLUGIN_ROOT HOME="$H" bash "$BATS_TEST_TMPDIR/b.sh")
}

@test "every shape ./setup creates for a skill resolves back to this checkout" {
  for s in debrief prune-skills superskills-doctor; do
    md="$REPO_ROOT/skills/$s/SKILL.md"
    for shape in claude codex opencode zcode; do
      rm -rf "$H"; mkdir -p "$H/.claude/skills" "$H/.zcode/skills" "$H/.codex/skills" "$H/.config/opencode/skills"
      case "$shape" in
        claude)   link_skill_into "$H/.claude/skills" "$md" "$s" 1 >/dev/null ;;
        zcode)    link_skill_into "$H/.zcode/skills" "$md" "$s" 1 >/dev/null ;;
        codex)    link_skill_dir_into "$H/.codex/skills" "$md" "$s" >/dev/null ;;
        opencode) link_skill_into "$H/.config/opencode/skills" "$md" "$s" 0 "superskills-" >/dev/null ;;
      esac
      run locate "$s"
      [ "$output" = "ROOT=$REPO_ROOT" ] || { echo "$s/$shape -> $output"; return 1; }
    done
  done
}

@test "a missing link leaves ROOT empty" {
  run locate debrief
  [ "$output" = "ROOT=" ]
}
