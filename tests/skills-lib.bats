#!/usr/bin/env bats
# Unit tests for scripts/lib/skills-lib.sh — the skill name/desc/body resolution
# and symlink logic used by setup. Fully hermetic: a fixture skill tree and a
# temp target dir under BATS_TEST_TMPDIR, no real HOME, no network.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  load_lib() { source "$REPO_ROOT/scripts/lib/skills-lib.sh"; }
  load_lib

  FIX="$BATS_TEST_TMPDIR/src"
  TARGET="$BATS_TEST_TMPDIR/dst"
  mkdir -p "$FIX" "$TARGET"

  # Skill with an explicit `name:` and a sibling extra file.
  mkdir -p "$FIX/alpha"
  cat > "$FIX/alpha/SKILL.md" <<'EOF'
---
name: alpha-cmd
description: Does the alpha thing well.
---
# Alpha
body line 1
body line 2
EOF
  printf 'ref\n' > "$FIX/alpha/reference.md"

  # Skill with no `name:` field (must fall back to the provided name).
  mkdir -p "$FIX/beta"
  cat > "$FIX/beta/SKILL.md" <<'EOF'
---
description: |
  A block-form description whose first
  real line should be extracted.
---
# Beta
EOF
}

@test "skill_name_from reads the name: frontmatter" {
  run skill_name_from "$FIX/alpha/SKILL.md" "fallback-name"
  [ "$status" -eq 0 ]
  [ "$output" = "alpha-cmd" ]
}

@test "skill_name_from falls back when no name: field" {
  run skill_name_from "$FIX/beta/SKILL.md" "beta"
  [ "$status" -eq 0 ]
  [ "$output" = "beta" ]
}

@test "skill_desc_from reads a single-line description" {
  run skill_desc_from "$FIX/alpha/SKILL.md"
  [ "$output" = "Does the alpha thing well." ]
}

@test "skill_desc_from extracts first line of a block description" {
  run skill_desc_from "$FIX/beta/SKILL.md"
  [ "$output" = "A block-form description whose first" ]
}

@test "skill_desc_from falls back to 'skill' when no description: field" {
  mkdir -p "$FIX/gamma"
  cat > "$FIX/gamma/SKILL.md" <<'EOF'
---
name: gamma-cmd
---
# Gamma
EOF
  run skill_desc_from "$FIX/gamma/SKILL.md"
  [ "$output" = "skill" ]
}

@test "skill_body_from returns content after the second fence" {
  run skill_body_from "$FIX/alpha/SKILL.md"
  [[ "$output" == *"# Alpha"* ]] || false
  [[ "$output" == *"body line 1"* ]] || false
  [[ "$output" != *"name: alpha-cmd"* ]] || false
}

@test "link_skill_into links SKILL.md under the resolved name" {
  run link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ "$status" -eq 0 ]
  [ "$output" = "alpha-cmd" ]
  [ -L "$TARGET/alpha-cmd/SKILL.md" ]
  [ "$(readlink "$TARGET/alpha-cmd/SKILL.md")" = "$FIX/alpha/SKILL.md" ]
}

@test "link_skill_into links sibling extras by default" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" >/dev/null
  [ -L "$TARGET/alpha-cmd/reference.md" ]
}

@test "link_skill_into with link_extras=0 links only SKILL.md" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" 0 >/dev/null
  [ -L "$TARGET/alpha-cmd/SKILL.md" ]
  [ ! -e "$TARGET/alpha-cmd/reference.md" ]
}

@test "link_skill_into applies a name prefix (opencode style)" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" 0 "superskills-" >/dev/null
  [ -L "$TARGET/superskills-alpha-cmd/SKILL.md" ]
}

@test "link_skill_into uses the fallback name when no name: field" {
  run link_skill_into "$TARGET" "$FIX/beta/SKILL.md" "beta-fallback"
  [ "$output" = "beta-fallback" ]
  [ -L "$TARGET/beta-fallback/SKILL.md" ]
}

@test "link_skill_into is idempotent (re-link does not error)" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" >/dev/null
  run link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/alpha-cmd/SKILL.md" ]
}

@test "link_skill_into returns 1 and links nothing when no name is resolvable" {
  mkdir -p "$FIX/gamma"
  cat > "$FIX/gamma/SKILL.md" <<'EOF'
---
description: no name field and no fallback given
---
# Gamma
EOF
  run link_skill_into "$TARGET" "$FIX/gamma/SKILL.md" ""
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ ! -e "$TARGET/gamma" ]
}

@test "skill_desc_from unwraps a double-quoted description and its escapes" {
  Q="$BATS_TEST_TMPDIR/quoted/SKILL.md"; mkdir -p "$(dirname "$Q")"
  printf -- '---\nname: q\ndescription: "Generate a map: fast, say \\"hi\\" \\\\ bye"\n---\n' > "$Q"
  run skill_desc_from "$Q"
  [ "$output" = 'Generate a map: fast, say "hi" \ bye' ]
}


# ── prune_dangling_links ──

@test "prune_dangling_links removes dangling links into the source tree and the emptied skill dir" {
  SRC="$BATS_TEST_TMPDIR/src-real"; DST="$BATS_TEST_TMPDIR/skills-dst"; mkdir -p "$SRC/design-skills" "$DST/old-name"
  ln -s "$SRC/design-skills/renamed-away/SKILL.md" "$DST/old-name/SKILL.md"
  run prune_dangling_links "$DST" "$SRC"
  [ "$status" -eq 0 ]
  [ ! -e "$DST/old-name" ] && [ ! -L "$DST/old-name/SKILL.md" ] || false
  [[ "$output" == *"old-name"* ]] || false
}

@test "prune_dangling_links keeps resolving links, links elsewhere, and the user's own files" {
  SRC="$BATS_TEST_TMPDIR/src-real"; DST="$BATS_TEST_TMPDIR/skills-dst"
  mkdir -p "$SRC/skills/live" "$DST/live" "$DST/foreign" "$DST/mixed"
  printf 'x\n' > "$SRC/skills/live/SKILL.md"
  ln -s "$SRC/skills/live/SKILL.md" "$DST/live/SKILL.md"                 # resolves → keep
  ln -s "$BATS_TEST_TMPDIR/other-repo/gone/SKILL.md" "$DST/foreign/SKILL.md"  # dangling, not ours → keep
  ln -s "$SRC/skills/gone/SKILL.md" "$DST/mixed/SKILL.md"                # dangling, ours → remove link
  printf 'mine\n' > "$DST/mixed/notes.md"                                 # user file → dir kept
  run prune_dangling_links "$DST" "$SRC"
  [ -L "$DST/live/SKILL.md" ]
  [ -L "$DST/foreign/SKILL.md" ]
  [ ! -L "$DST/mixed/SKILL.md" ] && [ -f "$DST/mixed/notes.md" ] || false
}

@test "prune_dangling_links refuses an empty or root source (would match every link)" {
  DST="$BATS_TEST_TMPDIR/skills-dst"; mkdir -p "$DST/x"; ln -s /gone/SKILL.md "$DST/x/SKILL.md"
  run prune_dangling_links "$DST" ""
  [ "$status" -eq 1 ]
  run prune_dangling_links "$DST" "/"
  [ "$status" -eq 1 ]
  [ -L "$DST/x/SKILL.md" ]
}

@test "setup calls prune_dangling_links for the tools it links into" {
  run grep -c 'prune_dangling_links' "$REPO_ROOT/setup"
  [ "$output" -ge 3 ]
}

@test "prune_dangling_links never descends into a symlinked directory (another tool's or the user's own tree)" {
  SRC="$BATS_TEST_TMPDIR/src-real"; DST="$BATS_TEST_TMPDIR/skills-dst"; FOREIGN="$BATS_TEST_TMPDIR/foreign-tree"
  mkdir -p "$SRC/skills" "$DST" "$FOREIGN"
  printf 'keep\n' > "$FOREIGN/keepme.txt"
  ln -s "$SRC/skills/realskill/DELETED.md" "$FOREIGN/dangling_but_foreign"
  ln -s "$FOREIGN" "$DST/user_custom_tree"
  run prune_dangling_links "$DST" "$SRC"
  [ "$status" -eq 0 ]
  [ -L "$FOREIGN/dangling_but_foreign" ]
  [ -f "$FOREIGN/keepme.txt" ]
  [ -L "$DST/user_custom_tree" ]
}

@test "skill_desc_from unwraps a single-quoted description ('' is a literal quote)" {
  Q="$BATS_TEST_TMPDIR/single/SKILL.md"; mkdir -p "$(dirname "$Q")"
  cat > "$Q" <<'MD'
---
name: q
description: 'Say ''hi'' fast: go'
---
MD
  run skill_desc_from "$Q"
  [ "$output" = "Say 'hi' fast: go" ]
}

@test "skill_desc_from on the real single-quoted skills returns no wrapping quotes" {
  for f in marketing-skills/pages/content/api/SKILL.md design-skills/ux-heuristics/SKILL.md design-skills/hooked-ux/SKILL.md; do
    [ -f "$REPO_ROOT/$f" ] || continue
    d="$(skill_desc_from "$REPO_ROOT/$f")"
    case "$d" in "'"*|*"'") echo "$f -> $d"; return 1 ;; esac
  done
}

# ── marketing_skill_files ──

@test "marketing_skill_files lists nested SKILL.md files, sorted, skipping .venv, node_modules and the plugin-skills shim tree" {
  M="$BATS_TEST_TMPDIR/mk"
  mkdir -p "$M/seo/local" "$M/pages/legal/privacy" "$M/content/video/.venv/lib/pkg" "$M/content/video/node_modules/x" "$M/plugin-skills/local-seo"
  for d in seo/local pages/legal/privacy content/video/.venv/lib/pkg content/video/node_modules/x plugin-skills/local-seo; do printf -- '---\nname: n\n---\n' > "$M/$d/SKILL.md"; done
  run marketing_skill_files "$M"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n%s' "$M/pages/legal/privacy/SKILL.md" "$M/seo/local/SKILL.md")" ]
}

@test "marketing_skill_files is the only marketing tree walk in setup, doctor-lib and manifest-lib" {
  run grep -n 'find .*SKILL.md' "$REPO_ROOT/setup" "$REPO_ROOT/scripts/lib/doctor-lib.sh" "$REPO_ROOT/scripts/lib/manifest-lib.sh"
  [ "$status" -eq 1 ]
}

@test "marketing_skill_files prunes plugin-skills even when the root path contains glob characters" {
  M="$BATS_TEST_TMPDIR/mk[x]*?"
  mkdir -p "$M/seo/local" "$M/plugin-skills/real-dir"
  printf -- '---\nname: n\n---\n' > "$M/seo/local/SKILL.md"
  printf -- '---\nname: n\n---\n' > "$M/plugin-skills/real-dir/SKILL.md"
  run marketing_skill_files "$M"
  [ "$output" = "$M/seo/local/SKILL.md" ]
}


# ── skill_names_from_files (batch form of skill_name_from) ──

@test "skill_names_from_files matches skill_name_from on edge cases" {
  E="$BATS_TEST_TMPDIR/edge"; mkdir -p "$E/plain" "$E/noname" "$E/crlf" "$E/spaced" "$E/late" "$E/empty"
  printf -- '---\nname: plain-skill\n---\n' > "$E/plain/SKILL.md"
  printf -- '---\ndescription: x\n---\n' > "$E/noname/SKILL.md"
  printf -- '---\r\nname: crlf-skill\r\n---\r\n' > "$E/crlf/SKILL.md"
  printf -- '---\nname:   spaced  skill  \n---\n' > "$E/spaced/SKILL.md"
  printf -- '---\ndescription: x\n---\nname: body-name\n' > "$E/late/SKILL.md"
  : > "$E/empty/SKILL.md"
  expected="$(for d in plain noname crlf spaced late empty; do printf '%s\t%s\n' "$E/$d/SKILL.md" "$(skill_name_from "$E/$d/SKILL.md" "$d")"; done)"
  actual="$(for d in plain noname crlf spaced late empty; do printf '%s\n' "$E/$d/SKILL.md"; done | skill_names_from_files)"
  [ "$actual" = "$expected" ] || { diff <(echo "$expected") <(echo "$actual"); return 1; }
}

@test "skill_names_from_files matches skill_name_from on every real skill in the repo" {
  files="$( { marketing_skill_files "$REPO_ROOT/marketing-skills"; ls -d "$REPO_ROOT"/design-skills/*/SKILL.md "$REPO_ROOT"/skills/*/SKILL.md; } )"
  expected="$(while IFS= read -r f; do printf '%s\t%s\n' "$f" "$(skill_name_from "$f" "$(basename "$(dirname "$f")")")"; done <<< "$files")"
  actual="$(printf '%s\n' "$files" | skill_names_from_files)"
  [ "$actual" = "$expected" ] || { diff <(echo "$expected") <(echo "$actual") | head; return 1; }
}
