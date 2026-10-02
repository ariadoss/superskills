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

@test "each prune_dangling_links call in setup targets its own tool's skills dir" {
  # Claude's dir is pruned twice by design — once per source (this checkout,
  # then the gstack clone); so are Codex and ZCode since they started walking
  # gstack. OpenCode only ever sees this checkout's.
  run grep -c 'prune_dangling_links "$CLAUDE_SKILLS_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 2 ] || { echo "CLAUDE_SKILLS_DIR: $output occurrences (want exactly 2)"; return 1; }
  for var in CODEX_SKILLS_DIR ZCODE_SKILLS_DIR; do
    run grep -c "prune_dangling_links \"\$$var\"" "$REPO_ROOT/setup"
    [ "$output" -eq 2 ] || { echo "$var: $output occurrences (want exactly 2)"; return 1; }
  done
  run grep -c 'prune_dangling_links "$OPENCODE_SKILLS_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || { echo "OPENCODE_SKILLS_DIR: $output occurrences (want exactly 1)"; return 1; }
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

@test "prune_dangling_links leaves an unrelated empty skill dir alone (only dirs it pruned are removed)" {
  SRC="$BATS_TEST_TMPDIR/src-real"; DST="$BATS_TEST_TMPDIR/skills-dst"; mkdir -p "$SRC/skills" "$DST/users-new-empty-skill"
  run prune_dangling_links "$DST" "$SRC"
  [ -d "$DST/users-new-empty-skill" ] || false
}

@test "prune_dangling_links does not treat $src/../elsewhere as inside the source tree" {
  SRC="$BATS_TEST_TMPDIR/work/superskills"; DST="$BATS_TEST_TMPDIR/skills-dst"; mkdir -p "$SRC/skills" "$DST/personal"
  ln -s "$SRC/../personal/pending.md" "$DST/personal/SKILL.md"
  run prune_dangling_links "$DST" "$SRC"
  [ -L "$DST/personal/SKILL.md" ] || false
}

@test "marketing_skill_files refuses a root containing a newline instead of silently returning nothing" {
  run marketing_skill_files "$BATS_TEST_TMPDIR/bad
root"
  [ "$status" -ne 0 ] || false
}


@test "skill_names_from_files survives a SKILL.md that is a directory and keeps every later entry" {
  E="$BATS_TEST_TMPDIR/dirs"; mkdir -p "$E/a/SKILL.md" "$E/b"
  printf -- '---\nname: bee\n---\n' > "$E/b/SKILL.md"
  out="$(printf '%s\n%s\n' "$E/a/SKILL.md" "$E/b/SKILL.md" | skill_names_from_files)"
  [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 2 ] || false
  [[ "$out" == *"$E/b/SKILL.md	bee"* ]] || false
}

@test "link_skill_into does not double a name prefix the skill name already has" {
  mkdir -p "$BATS_TEST_TMPDIR/pfx/src/superskills-doctor" "$BATS_TEST_TMPDIR/pfx/dst"
  printf -- '---\nname: superskills-doctor\n---\n' > "$BATS_TEST_TMPDIR/pfx/src/superskills-doctor/SKILL.md"
  run link_skill_into "$BATS_TEST_TMPDIR/pfx/dst" "$BATS_TEST_TMPDIR/pfx/src/superskills-doctor/SKILL.md" "" 0 "superskills-"
  [ -L "$BATS_TEST_TMPDIR/pfx/dst/superskills-doctor/SKILL.md" ] || false
  [ ! -e "$BATS_TEST_TMPDIR/pfx/dst/superskills-superskills-doctor" ] || false
}

@test "skill_names_from_files only reads name: at the start of a line, not a substring inside another field" {
  D="$BATS_TEST_TMPDIR/embed"; mkdir -p "$D"
  printf -- '---\ndescription: the name: field below is canonical\nname: real-name\n---\n' > "$D/SKILL.md"
  expected="$(skill_name_from "$D/SKILL.md" real-name)"
  actual="$(printf '%s\n' "$D/SKILL.md" | skill_names_from_files | cut -f2)"
  [ "$actual" = "$expected" ] || false
  [ "$actual" = "real-name" ] || false
}

# ── link_skill_dir_into (codex shape: a symlinked skill FOLDER) ──

@test "link_skill_dir_into creates a directory symlink to the skill dir" {
  run link_skill_dir_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ "$status" -eq 0 ]
  [ "$(cat "$TARGET/alpha-cmd/SKILL.md")" = "$(cat "$FIX/alpha/SKILL.md")" ] || false
  [ -L "$TARGET/alpha-cmd" ] || false
  [ "$(readlink "$TARGET/alpha-cmd")" = "$FIX/alpha" ] || false
}

@test "link_skill_dir_into replaces an old file-link shape it owns (migration)" {
  mkdir -p "$TARGET/alpha-cmd"
  ln -s "$FIX/alpha/SKILL.md" "$TARGET/alpha-cmd/SKILL.md"
  ln -s "$FIX/alpha/reference.md" "$TARGET/alpha-cmd/reference.md"
  run link_skill_dir_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/alpha-cmd" ] || false
  [ "$(readlink "$TARGET/alpha-cmd")" = "$FIX/alpha" ] || false
}

@test "link_skill_dir_into never touches a foreign real dir at the target name" {
  mkdir -p "$TARGET/alpha-cmd"
  printf 'user content\n' > "$TARGET/alpha-cmd/SKILL.md"
  run link_skill_dir_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ "$status" -eq 1 ]
  [ "$(cat "$TARGET/alpha-cmd/SKILL.md")" = "user content" ] || false
  [ ! -L "$TARGET/alpha-cmd" ] || false
}

@test "prune_dangling_links removes a dangling dir symlink owned by src, keeps a foreign one" {
  ln -s "$FIX/gone-skill" "$TARGET/old-owned"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$TARGET/foreign-dir"
  run prune_dangling_links "$TARGET" "$FIX"
  [ "$status" -eq 0 ]
  [ ! -e "$TARGET/old-owned" ] && [ ! -L "$TARGET/old-owned" ] || false
  [ -L "$TARGET/foreign-dir" ] || false
}

@test "prune_deselected_skills prunes owned dir symlinks under a narrowed pack selection" {
  SS_PACKS=coding
  ln -s "$FIX/alpha" "$TARGET/alpha-cmd"
  ln -s "$FIX/beta" "$TARGET/beta"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$TARGET/foreign-dir"
  run prune_deselected_skills "$TARGET" "$FIX"
  [ "$status" -eq 0 ]
  [ ! -e "$TARGET/alpha-cmd" ] && [ ! -L "$TARGET/alpha-cmd" ] || false
  [ ! -e "$TARGET/beta" ] && [ ! -L "$TARGET/beta" ] || false
  [ -L "$TARGET/foreign-dir" ] || false
  SS_PACKS=all
  ln -s "$FIX/alpha" "$TARGET/alpha-cmd"
  prune_deselected_skills "$TARGET" "$FIX" >/dev/null
  [ -L "$TARGET/alpha-cmd" ] || false
}

@test "link_skill_into rejects a name that is not one safe path segment" {
  mkdir -p "$FIX/evil"
  printf -- '---\nname: ../../evil\ndescription: x\n---\n' > "$FIX/evil/SKILL.md"
  run link_skill_into "$TARGET" "$FIX/evil/SKILL.md" "fallback"
  [ "$status" -eq 1 ]
  [ -z "$(ls -A "$TARGET" 2>/dev/null)" ] || false
}

@test "link_skill_dir_into rejects a name that is not one safe path segment" {
  mkdir -p "$FIX/evil2"
  printf -- '---\nname: sub/dir\ndescription: x\n---\n' > "$FIX/evil2/SKILL.md"
  run link_skill_dir_into "$TARGET" "$FIX/evil2/SKILL.md" "fallback"
  [ "$status" -eq 1 ]
  [ -z "$(ls -A "$TARGET" 2>/dev/null)" ] || false
}

@test "link_skill_dir_into replaces an existing symlink at the same name (later walks win)" {
  mkdir -p "$FIX/marketing-x" "$FIX/core-x"
  printf -- '---\nname: same-name\ndescription: m\n---\n' > "$FIX/marketing-x/SKILL.md"
  printf -- '---\nname: same-name\ndescription: c\n---\n' > "$FIX/core-x/SKILL.md"
  link_skill_dir_into "$TARGET" "$FIX/marketing-x/SKILL.md" "m-fallback" >/dev/null
  [ "$(readlink "$TARGET/same-name")" = "$FIX/marketing-x" ] || false
  link_skill_dir_into "$TARGET" "$FIX/core-x/SKILL.md" "c-fallback" >/dev/null
  [ "$(readlink "$TARGET/same-name")" = "$FIX/core-x" ] || false
}

# ── file-writing adapters (Continue / Augment / Cursor) ──
# Extracted from setup so the frontmatter-name guard is behaviorally testable
# like the symlink linkers'. ss_selected lives in setup; stub it per test.

@test "link_skill_continue writes the prompt file and echoes nothing on success" {
  ss_selected() { return 0; }
  link_skill_continue "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ -f "$TARGET/alpha-cmd.prompt" ] || false
  grep -q 'name: alpha-cmd' "$TARGET/alpha-cmd.prompt" || false
  grep -q 'body line 1' "$TARGET/alpha-cmd.prompt" || false
}

@test "the writer adapters reject a traversal name and write NOTHING" {
  ss_selected() { return 0; }
  mkdir -p "$FIX/evil"
  printf -- '---\nname: ../../.config/foo\ndescription: x\n---\n' > "$FIX/evil/SKILL.md"
  for fn in link_skill_continue link_skill_augment link_skill_cursor; do
    rc=0; "$fn" "$TARGET" "$FIX/evil/SKILL.md" "fallback" || rc=$?
    [ "$rc" -eq 2 ] || { echo "$fn returned $rc, expected 2"; return 1; }
  done
  # Nothing landed inside the target, and nothing escaped it either.
  [ -z "$(ls -A "$TARGET" 2>/dev/null)" ] || false
  [ ! -e "$BATS_TEST_TMPDIR/.config" ] || { echo "traversal escaped the target dir"; return 1; }
}

@test "the writer adapters skip silently when the skill is not selected" {
  ss_selected() { return 1; }
  rc=0; link_skill_continue "$TARGET" "$FIX/alpha/SKILL.md" "fallback" || rc=$?
  [ "$rc" -eq 1 ] || false
  rc=0; link_skill_augment "$TARGET" "$FIX/alpha/SKILL.md" "fallback" || rc=$?
  [ "$rc" -eq 1 ] || false
  rc=0; link_skill_cursor "$TARGET" "$FIX/alpha/SKILL.md" "fallback" || rc=$?
  [ "$rc" -eq 1 ] || false
  [ -z "$(ls -A "$TARGET" 2>/dev/null)" ] || false
}

@test "link_skill_cursor prefixes its rule file and link_skill_augment writes the command" {
  ss_selected() { return 0; }
  link_skill_cursor "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ -f "$TARGET/superskills-alpha-cmd.mdc" ] || false
  grep -q 'alwaysApply: false' "$TARGET/superskills-alpha-cmd.mdc" || false
  link_skill_augment "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ -f "$TARGET/alpha-cmd.md" ] || false
  head -1 "$TARGET/alpha-cmd.md" | grep -q '^# /alpha-cmd$' || false
}

@test "the writer adapters return 1 and write nothing when no name is resolvable" {
  ss_selected() { return 0; }
  mkdir -p "$FIX/noname"
  printf -- '---\ndescription: x\n---\n' > "$FIX/noname/SKILL.md"
  for fn in link_skill_continue link_skill_augment link_skill_cursor; do
    rc=0; "$fn" "$TARGET" "$FIX/noname/SKILL.md" "" || rc=$?
    [ "$rc" -eq 1 ] || { echo "$fn returned $rc, expected 1"; return 1; }
  done
  [ -z "$(ls -A "$TARGET" 2>/dev/null)" ] || false
}
