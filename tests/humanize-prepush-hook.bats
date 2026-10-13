#!/usr/bin/env bats
# Tests for scripts/humanize-prepush-hook.sh — the deterministic half of the
# humanize pre-push gate. The judgement half (exemptions for eval-bound and
# historical text) belongs to /humanize, not the hook; HUMANIZE_PREPUSH=0 is
# its registered bypass. Every failure path must degrade to silent allow.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$REPO_ROOT/scripts/humanize-prepush-hook.sh"
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  WORK="$BATS_TEST_TMPDIR/work"
  git init -q --bare "$ORIGIN"
  git clone -q "$ORIGIN" "$WORK" 2>/dev/null
  git -C "$WORK" config user.email t@example.com
  git -C "$WORK" checkout -q -b main
  git -C "$WORK" config user.name t
  # Seed one pushed commit so @{push}/origin refs resolve for every test:
  # a clone of an empty origin has neither until the first push lands.
  git -C "$WORK" commit -q --allow-empty -m seed
  git -C "$WORK" push -q origin main 2>/dev/null || git -C "$WORK" push -q origin HEAD:main
  git -C "$WORK" branch -q --set-upstream-to=origin/main main 2>/dev/null || true
}

# commit_md <file> <content…>: commit one .md file on the work branch.
commit_md() {
  local f="$1"; shift
  mkdir -p "$WORK/$(dirname "$f")"
  printf '%s\n' "$@" > "$WORK/$f"
  git -C "$WORK" add "$f"
  git -C "$WORK" commit -qm "add $f"
}

run_hook() {  # run_hook <cwd> — feeds a git-push JSON payload on stdin
  local cwd="$1"
  (cd "$cwd" && printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | HUMANIZE_PREPUSH=1 bash "$HOOK")
}

@test "blocks a push carrying slop-flagged markdown" {
  commit_md README.md "I couldn't help but smile. He took a deep breath and began. She nodded, a ghost of a smile playing at her lips. The room seemed to hold its breath."
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' >/dev/null
  echo "$output" | jq -e '.reason' | grep -qi "humanize pre-push gate"
}

@test "allows a push whose markdown scans clean" {
  commit_md README.md "Install the tool. Run the checks. Ship when green."
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$(echo "$output" | jq -r '.decision // empty')" ]
}

@test "allows a push with no markdown changes" {
  commit_md src/app.py "print('hi')"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$(echo "$output" | jq -r '.decision // empty')" ]
}

@test "ignores non-push Bash commands entirely" {
  commit_md README.md "He took a deep breath and began. The room seemed to hold its breath."
  run bash -c "cd '$WORK' && printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"}}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "HUMANIZE_PREPUSH=0 disables the gate" {
  commit_md README.md "He took a deep breath and began. The room seemed to hold its breath."
  run bash -c "cd '$WORK' && printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push\"}}' | HUMANIZE_PREPUSH=0 bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "already-pushed markdown is not re-gated" {
  commit_md ONCE.md "It is crucial to delve deeply, fostering comprehensive understanding."
  git -C "$WORK" push -q origin main 2>/dev/null || git -C "$WORK" push -q origin HEAD:main
  commit_md NEXT.py "x = 1"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$(echo "$output" | jq -r '.decision // empty')" ]
}

@test "skill bodies and MODIFIED internal docs are never gated" {
  mkdir -p "$WORK/skills/demo" "$WORK/evals/reports" "$WORK/docs"
  printf 'Install the tool. Run the checks. Ship when green.\n' > "$WORK/NOTES.md"
  cp "$WORK/NOTES.md" "$WORK/evals/reports/r.md"
  cp "$WORK/NOTES.md" "$WORK/docs/guide.md"
  git -C "$WORK" add -A && git -C "$WORK" commit -qm "seed internal docs"
  git -C "$WORK" push -q origin main 2>/dev/null || git -C "$WORK" push -q origin HEAD:main
  # now MODIFY them with flagged text, and CREATE a flagged SKILL.md — none may gate
  cat > "$WORK/NOTES.md" <<'SLOP'
I couldn't help but smile. He took a deep breath and began.
SLOP
  cp "$WORK/NOTES.md" "$WORK/evals/reports/r.md"
  cp "$WORK/NOTES.md" "$WORK/docs/guide.md"
  cp "$WORK/NOTES.md" "$WORK/skills/demo/SKILL.md"
  git -C "$WORK" add -A && git -C "$WORK" commit -qm "flagged internal + skill text"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$(echo "$output" | jq -r '.decision // empty')" ]
}

@test "degrades to silent allow outside a git repo" {
  run run_hook "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "degrades to silent allow on malformed stdin" {
  run bash -c "cd '$WORK' && printf 'not json' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a new user-facing doc is gated at creation" {
  mkdir -p "$WORK/docs"
  cat > "$WORK/docs/getting-started.md" <<'SLOP'
He took a deep breath and began. She nodded, a ghost of a smile playing at her lips.
SLOP
  git -C "$WORK" add docs/getting-started.md
  git -C "$WORK" commit -qm "new doc"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' >/dev/null
}

SLOP_LINE="He took a deep breath and began. She nodded, a ghost of a smile playing at her lips. The room seemed to hold its breath."

@test "a new marketing page (html) with slop in visible text is gated" {
  commit_md site/landing.html "<html><body><p>$SLOP_LINE</p></body></html>"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' >/dev/null
}

@test "a new content-collection markdown and mdx page is gated outside docs/" {
  commit_md content/blog/launch.md "$SLOP_LINE"
  commit_md site/pages/pricing.mdx "$SLOP_LINE"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' >/dev/null
  echo "$output" | jq -e '.reason | contains("content/blog/launch.md") and contains("site/pages/pricing.mdx")' >/dev/null
}

@test "a new component with slop in a visible string is gated; the same slop in a comment is not" {
  commit_md src/Hero.tsx "export const Hero = () => <p>$SLOP_LINE</p>;"
  run run_hook "$WORK"
  echo "$output" | jq -e '.decision == "block"' >/dev/null
  git -C "$WORK" reset -q --hard HEAD~1
  commit_md src/Quiet.tsx "// $SLOP_LINE" "export const Quiet = () => null;"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a new locale file with slop in a string value is gated" {
  commit_md locales/en.json "{" "  \"hero\": \"$SLOP_LINE\"" "}"
  run run_hook "$WORK"
  echo "$output" | jq -e '.decision == "block"' >/dev/null
}

@test "new code, prompts and agent instruction files never gate, even carrying slop" {
  commit_md src/util.ts "const s = \"$SLOP_LINE\";"
  commit_md prompts/system.md "$SLOP_LINE"
  commit_md skills/x/SKILL.md "$SLOP_LINE"
  commit_md package.json "{\"description\": \"$SLOP_LINE\"}"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "new internal prompts and agent instructions do not trigger the prose gate" {
  for f in evals/example/prompt.md docs/internal/prompt.md prompts/system.md AGENTS.md CLAUDE.md skills/x/SKILL.md; do
    commit_md "$f" "I couldn't help but smile. He took a deep breath and began. She nodded, a ghost of a smile playing at her lips."
  done
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a MODIFIED internal doc (not the README) is not gated" {
  printf 'Install the tool. Run the checks. Ship when green.\n' > "$WORK/NOTES.md"
  git -C "$WORK" add NOTES.md && git -C "$WORK" commit -qm "seed notes"
  git -C "$WORK" push -q origin main 2>/dev/null || git -C "$WORK" push -q origin HEAD:main
  cat > "$WORK/NOTES.md" <<'SLOP'
I couldn't help but smile. He took a deep breath and began. She nodded, a ghost of a smile playing at her lips.
SLOP
  git -C "$WORK" add NOTES.md && git -C "$WORK" commit -qm "rewrite notes badly"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$(echo "$output" | jq -r '.decision // empty')" ]
}

@test "a renamed .md with a flagged destination path is gated as new" {
  printf 'Install the tool. Run the checks. Ship when green. Then he took a deep breath and began to write more.\n' > "$WORK/OLD.md"
  git -C "$WORK" add OLD.md && git -C "$WORK" commit -qm "seed old"
  git -C "$WORK" push -q origin main 2>/dev/null || git -C "$WORK" push -q origin HEAD:main
  git -C "$WORK" mv OLD.md GUIDE.md
  printf "I couldn't help but smile. She nodded, a ghost of a smile playing at her lips.\n" >> "$WORK/GUIDE.md"
  git -C "$WORK" add -A && git -C "$WORK" commit -qm "rename with appended slop"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' >/dev/null
}

@test "a deleted .md never gates" {
  printf 'He took a deep breath and began.\\n' > "$WORK/GONE.md"
  git -C "$WORK" add GONE.md && git -C "$WORK" commit -qm "seed gone"
  git -C "$WORK" push -q origin main
  git -C "$WORK" rm -q GONE.md && git -C "$WORK" commit -qm "delete"
  run run_hook "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$(echo "$output" | jq -r '.decision // empty')" ]
}
