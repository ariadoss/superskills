#!/usr/bin/env bats
# scripts/superskills-load.sh backs the /superskills command: load one pack's
# index or one skill's full text on demand, from a fixture checkout.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  SCRIPT="$REPO_ROOT/scripts/superskills-load.sh"
  FX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FX/skills/tdd" "$FX/design-skills/typography" "$FX/design-skills/tdd" \
           "$FX/marketing-skills/seo/audit" "$FX/marketing-skills/plugin-skills/audit"
  mk() { printf -- '---\nname: %s\ndescription: |\n  %s\n---\n\nBODY-%s\n' "$2" "$3" "$2" > "$1/SKILL.md"; }
  mk "$FX/skills/tdd" tdd "Test first."
  mk "$FX/design-skills/typography" typography "Type scale rules."
  mk "$FX/design-skills/tdd" tdd "Shadowed design copy."
  mk "$FX/marketing-skills/seo/audit" seo-audit "Audit a site for SEO."
  ln -s "$FX/marketing-skills/seo/audit/SKILL.md" "$FX/marketing-skills/plugin-skills/audit/SKILL.md"
}

@test "--list shows each pack with its skill count; the plugin shim tree is not counted" {
  run bash "$SCRIPT" --root "$FX" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"design"*"2"* ]] || false
  [[ "$output" == *"marketing"*"1"* ]] || false
}

@test "a pack name prints a count header, then one line per skill: name and description; no bodies, no paths" {
  run bash "$SCRIPT" --root "$FX" design
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "PACK design: 2 skills. Load one with /superskills <skill-name>." ]
  [[ "$output" == *"typography"*"Type scale rules."* ]] || false
  [[ "$output" != *"BODY-"* ]] || false
  [[ "$output" != *"$FX"* ]] || false
}

@test "a long description is cut to 80 characters so a pack index stays small" {
  long="$(printf 'x%.0s' $(seq 1 300))"
  printf -- '---\nname: wordy\ndescription: |\n  %s\n---\n' "$long" > "$FX/design-skills/typography/SKILL.md"
  run bash "$SCRIPT" --root "$FX" design
  line="$(printf '%s\n' "$output" | grep '^wordy')"
  desc="${line#*$'\t'}"
  [ "${#desc}" -le 80 ] || { echo "desc is ${#desc} chars"; return 1; }
}

@test "the real marketing index fits one tool result (under 25000 characters)" {
  run bash "$SCRIPT" marketing
  [ "$status" -eq 0 ]
  [ "${#output}" -lt 25000 ] || { echo "index is ${#output} chars"; return 1; }
  [[ "${lines[0]}" == "PACK marketing: "*" skills."* ]] || false
}

@test "a skill name prints its path and full text" {
  run bash "$SCRIPT" --root "$FX" typography
  [ "$status" -eq 0 ]
  [[ "$output" == *"$FX/design-skills/typography/SKILL.md"* ]] || false
  [[ "$output" == *"BODY-typography"* ]] || false
}

@test "nested marketing skills resolve by frontmatter name" {
  run bash "$SCRIPT" --root "$FX" seo-audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"BODY-seo-audit"* ]] || false
}

@test "a name in two trees resolves like setup does (skills/ beats design-skills) and says so" {
  run bash "$SCRIPT" --root "$FX" tdd
  [ "$status" -eq 0 ]
  [[ "$output" == *"$FX/skills/tdd/SKILL.md"* ]] || false
  [[ "$output" != *"Shadowed design copy"* ]] || false
  [[ "$output" == *"also in"*"design-skills/tdd"* ]] || false
}

@test "an unknown target fails with status 1 and names the packs" {
  run bash "$SCRIPT" --root "$FX" nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"nope"* ]] || false
  [[ "$output" == *"design"*"marketing"* ]] || false
}

@test "no target is a usage error" {
  run bash "$SCRIPT" --root "$FX"
  [ "$status" -eq 2 ]
}

@test "--root with no value is a usage error naming the flag" {
  run bash "$SCRIPT" --root
  [ "$status" -eq 2 ]
  [[ "$output" == *"--root"* ]] || false
}

@test "a target with path separators is refused, never read as a path" {
  run bash "$SCRIPT" --root "$FX" ../../etc/passwd
  [ "$status" -eq 1 ]
}

@test "runs against the real repo: the design pack lists skills" {
  run bash "$SCRIPT" design
  [ "$status" -eq 0 ]
  [[ "$output" == *"typography"* ]] || false
}

# The locate-and-run snippet in skills/superskills/SKILL.md is run verbatim by
# an agent, so it is tested verbatim, as one command, under a controlled HOME.
snippet() {
  awk '/^### Step 1/{s=1} s && /^```bash$/{f=1; next} f && /^```$/{exit} f' \
    "$REPO_ROOT/skills/superskills/SKILL.md" > "$BATS_TEST_TMPDIR/snippet.sh"
  [ -s "$BATS_TEST_TMPDIR/snippet.sh" ]
}

@test "skill snippet: a setup-linked skill resolves to its checkout and loads a pack" {
  snippet
  H="$BATS_TEST_TMPDIR/home"; mkdir -p "$H/.claude/skills/superskills"
  ln -s "$REPO_ROOT/skills/superskills/SKILL.md" "$H/.claude/skills/superskills/SKILL.md"
  cd "$BATS_TEST_TMPDIR"
  run env -u CLAUDE_PLUGIN_ROOT HOME="$H" bash "$BATS_TEST_TMPDIR/snippet.sh" design
  [ "$status" -eq 0 ]
  [[ "$output" == *"typography"* ]] || false
}

@test "skill snippet: no install reports LOADER=missing and never guesses from the cwd" {
  snippet
  H="$BATS_TEST_TMPDIR/empty"; mkdir -p "$H"
  cd "$REPO_ROOT/marketing-skills/content"
  run env -u CLAUDE_PLUGIN_ROOT HOME="$H" bash "$BATS_TEST_TMPDIR/snippet.sh" design
  [ "$output" = "LOADER=missing" ]
}
