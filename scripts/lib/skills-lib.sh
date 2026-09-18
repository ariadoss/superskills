#!/usr/bin/env bash
# skills-lib.sh — pure, sourceable helpers for resolving and linking skills.
#
# Extracted from setup so the linking logic has a single source of truth (DRY)
# and one responsibility per function (SOLID), and can be unit-tested in
# isolation without running the full installer (which clones gstack, installs
# bun, etc.). See tests/skills-lib.bats.
#
# These functions never mutate the source tree. link_skill_into only writes
# symlinks under the target dir it is given.

# ── Pack selection (profiles) ─────────────────────────────────────────────────
#
# SS_PACKS is a comma-separated list of pack names held in
# ~/.superskills/packs.conf as plain text — the value is parsed, never sourced.
# Packs: coding (default), core, design, marketing, media, gstack, all.
# skill_selected answers for one skill: setup's per-tool linkers and the
# output adapters consult it; gstack links by name with a category hint.

PACK_CODING="specify clarify write-plan analyze repomap dbmap worktrees tdd debug verify test-coverage qa-full finish-branch daily-qa superskills-doctor superskills-upgrade clean-code defense db-optimize web-perf a11y playwright checklist design-review"

packs_conf_path() {
  printf '%s' "${SS_PACKS_CONF:-$HOME/.superskills/packs.conf}"
}

packs_load() {
  local conf line
  conf="$(packs_conf_path)"
  [ -f "$conf" ] || { SS_PACKS="coding"; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    # Only a packs= line speaks; anything else (a stray note, a typo) is
    # ignored so a hand-edit cannot silently reset the selection.
    case "$line" in packs=*) SS_PACKS="${line#packs=}" ;; esac
  done < "$conf"
  return 0
}

packs_save() {
  local packs="$1" conf
  case ",$packs," in *,all,*) packs="all" ;; esac
  conf="$(packs_conf_path)"
  mkdir -p "$(dirname "$conf")"
  printf '# superskills pack selection — parsed by setup, never sourced\npacks=%s\n' "$packs" > "$conf"
}

packs_validate() {
  local input="$1" pack
  case ",$input," in
    *,,) echo "invalid pack list: $input" >&2; return 1 ;;
  esac
  local -a list
  IFS=',' read -r -a list <<<"$input" || return 1
  for pack in "${list[@]}"; do
    case "$pack" in
      coding|core|design|marketing|media|gstack|all) : ;;
      *) echo "invalid pack: $pack" >&2; return 1 ;;
    esac
  done
  return 0
}

packs_all_included() {
  case ",${SS_PACKS:-coding}," in *",all,"*) return 0 ;; *) return 1 ;; esac
}

# pack_category_included <category> — is a tree's category installed? The
# coding pack's roster is served by the skills/ tree, so a selection that
# lists coding (or defaults to it) includes the core tree.
pack_category_included() {
  packs_all_included && return 0
  case ",${SS_PACKS:-coding}," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

# skill_selected <name> <category> — the shared predicate. Exit 0 means the
# skill is installed under the active pack selection. <category> is coding,
# core, design, marketing, media or gstack: the tree that walks it (coding and
# core share the skills/ roster; design, marketing, media are their own trees;
# a gstack-installed skill passes its own category, so the same predicate
# drives gstack links by name).
# Contract: `all` includes every tree. For every other selection the coding
# roster is UNCONDITIONAL — a roster name is selected whenever its tree is
# walked, whatever SS_PACKS says, because coding is the always-on base of the
# product: listing `coding` in --packs is accepted but decorative, and no pack
# list excludes it. Every non-roster skill is selected exactly when its
# category is listed in SS_PACKS. design-review ships in gstack but is a
# coding-pack default, so its roster entry claims it when its tree is gstack's
# too (the gstack install gate itself lives in setup's gstack section).
skill_selected() {
  local name="$1" category="$2" roster
  roster=0
  packs_category_of "$name" >/dev/null && roster=1
  if [ "$roster" -eq 1 ]; then
    case "$category" in
      design) [ "$name" = "design-review" ] && return 0 ;;
      coding|core) return 0 ;;
      *) return 1 ;;
    esac
  fi
  pack_category_included "$category" || return 1
  case "$category" in
    core) pack_category_included core ;;
    *) return 0 ;;
  esac
}

# gstack_pack_action — echo "ensure" when the gstack pack is selected (setup
# then installs/promotes gstack and its bun dependency) or "skip" when it is
# not (setup leaves any existing gstack install untouched and installs
# nothing). The single decision point for the gstack pack's install gate.
gstack_pack_action() {
  pack_category_included gstack && { printf 'ensure'; return 0; }
  printf 'skip'
}

# packs_category_of <name> — echo the pack category owning <name>; exit 1 when
# no pack claims it. Only the coding roster resolves by name; every other tree
# walks under its category.
packs_category_of() {
  local name="$1" word
  for word in $PACK_CODING; do
    [ "$word" = "$name" ] && { printf 'core\n'; return 0; }
  done
  return 1
}

# selected_source_paths <skills_dir> <design_dir> <marketing_dir>
# Read-only: for --list-skills and the doctor's pack-filtered Links check.
# Walks the three superskills trees the same way setup links them (marketing
# nested via marketing_skill_files, media subtree split by
# pack_category_for_path) and echoes the SKILL.md path of every skill the
# active pack selection keeps. Echoes nothing for deselected skills; never
# touches the filesystem beyond reading.
selected_source_paths() {
  local skills_dir="$1" design_dir="$2" marketing_dir="$3"
  local name skill_md fallback category
  if [ -d "$marketing_dir" ]; then
    while IFS= read -r skill_md; do
      category="$(pack_category_for_path "$skill_md" "$marketing_dir")"
      fallback="$(basename "$(dirname "$skill_md")")"
      name="$(skill_name_from "$skill_md" "$fallback")"
      skill_selected "$name" "$category" && printf '%s\n' "$skill_md"
    done < <(marketing_skill_files "$marketing_dir")
  fi
  if [ -d "$design_dir" ]; then
    for skill_md in "$design_dir"/*/SKILL.md; do
      [ -f "$skill_md" ] || continue
      [ "$(basename "$(dirname "$skill_md")")" = "node_modules" ] && continue
      name="$(skill_name_from "$skill_md" "$(basename "$(dirname "$skill_md")")")"
      skill_selected "$name" design && printf '%s\n' "$skill_md"
    done
  fi
  for skill_md in "$skills_dir"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    [ "$(basename "$(dirname "$skill_md")")" = "node_modules" ] && continue
    name="$(skill_name_from "$skill_md" "$(basename "$(dirname "$skill_md")")")"
    category=core
    packs_category_of "$name" >/dev/null && category=coding
    skill_selected "$name" "$category" && printf '%s\n' "$skill_md"
  done
  return 0
}

# pack_category_for_path <skill_md> <marketing_dir>
# The pack category a SKILL.md belongs to, by its tree. The marketing walk's
# media subtree (content/video-editing) answers to the media pack, everything
# else under marketing-skills to marketing, design-skills to design, and the
# skills/ tree to core (a roster name upgrades it to coding at the
# skill_selected call sites). One mapping shared by setup's link gates, the
# --list-skills walk and the deselected-prune.
pack_category_for_path() {
  local skill_md="$1" marketing_dir="${2:-}" rel
  if [ -n "$marketing_dir" ]; then
    rel="${skill_md#"$marketing_dir"/}"
    if [ "$rel" != "$skill_md" ]; then
      case "$rel" in content/video-editing/*) printf 'media' ;; *) printf 'marketing' ;; esac
      return 0
    fi
  fi
  case "$skill_md" in
    */design-skills/*) printf 'design' ;;
    *) printf 'core' ;;
  esac
}

# prune_deselected_skills <target_dir> <source_root>
# Echo nothing; remove the installs of THIS checkout under <target_dir> that
# the active pack selection no longer includes (via remove_owned_skill, which
# fails closed per dir). Only dirs whose SKILL.md is a resolving symlink into
# <source_root> are candidates — gstack, other tools' skills and the user's
# own entries are never touched. Dangling links belong to
# prune_dangling_links, so they are skipped here. Callers gate on a persisted
# selection: no packs.conf means a pre-packs install and nothing is pruned.
prune_deselected_skills() {
  local base="$1" src="${2%/}" src_canon dir target resolved name category
  [ -d "$base" ] || return 0
  [ -n "$src" ] || return 0
  # readlink -f canonicalises (macOS /tmp → /private/tmp): the resolved target
  # is compared against both the raw and the canonical source root, while
  # remove_owned_skill sees the raw root, matching the raw symlink values it
  # reads (the same convention as prune_dangling_links).
  src_canon="$(readlink -f "$src" 2>/dev/null)" || src_canon=""
  for dir in "$base"/*/; do
    dir="${dir%/}"
    [ -L "$dir" ] && continue
    target="$dir/SKILL.md"
    [ -L "$target" ] && [ -e "$target" ] || continue
    resolved="$(readlink -f "$target" 2>/dev/null)" || resolved=""
    [ -n "$resolved" ] || continue
    case "$resolved" in
      "$src"/*) : ;;
      "$src_canon"/*) [ -n "$src_canon" ] || continue ;;
      *) continue ;;
    esac
    name="$(skill_name_from "$resolved" "")"
    [ -n "$name" ] || name="$(basename "$dir")"
    if packs_category_of "$name" >/dev/null; then
      category=coding
    else
      category="$(pack_category_for_path "$resolved" "${src_canon:-$src}/marketing-skills")"
    fi
    skill_selected "$name" "$category" && continue
    SS_OWNED_SRC="$src" remove_owned_skill "$dir"
  done
  return 0
}

# skill_name_from <skill_md> [fallback]
# Echo a skill's canonical name from its `name:` frontmatter, else the fallback.
# Echoes empty string if neither is available.
skill_name_from() {
  local skill_md="$1" fallback="${2:-}" name
  name=$(grep -m1 '^name:' "$skill_md" 2>/dev/null | sed 's/^name:[[:space:]]*//' | tr -d '[:space:]')
  [ -z "$name" ] && name="$fallback"
  printf '%s' "$name"
}

# skill_names_from_files
# Batch form of skill_name_from for many files at once (one awk process instead
# of three per file): reads SKILL.md paths on stdin, prints "<path>\t<name>" in
# the same order. Same rule: the first line starting with `name:`, whitespace
# removed; else the parent directory name. tests/skills-lib.bats checks it
# agrees with skill_name_from on every skill in the repo.
skill_names_from_files() {
  # Tag each path R (regular, readable) or X (anything else) with builtins
  # first: macOS awk aborts the whole run on `getline < dir`, which would
  # silently drop every later skill from the caller's loop.
  local f
  while IFS= read -r f; do
    if [ -f "$f" ] && [ -r "$f" ]; then printf 'R\t%s\n' "$f"; else printf 'X\t%s\n' "$f"; fi
  done | awk -F'\t' '{
    f = substr($0, 3); name = ""
    if ($1 == "R") {
      while ((getline line < f) > 0) {
        if (line ~ /^name:/) { sub(/^name:/, "", line); gsub(/[ \t\r\n\v\f]/, "", line); name = line; break }
      }
      close(f)
    }
    if (name == "") { d = f; sub(/\/[^\/]*$/, "", d); sub(/.*\//, "", d); name = d }
    print f "\t" name
  }'
}

# skill_desc_from <skill_md>
# Echo the first line of a skill's description (single-line or block form).
# Falls back to "skill" if none is found.
skill_desc_from() {
  local skill_md="$1" desc
  desc=$(grep -m1 '^description:' "$skill_md" 2>/dev/null \
        | sed 's/^description:[[:space:]]*//' \
        | sed 's/[[:space:]]*|[[:space:]]*$//')
  if [ -z "$desc" ] || [ "$desc" = "|" ]; then
    desc=$(awk '
      /^description:/ { found=1; next }
      found && /^[[:space:]]/ { gsub(/^[[:space:]]+/, ""); if (length > 0) { print; exit } }
      found && /^[^[:space:]]/ { exit }
    ' "$skill_md" 2>/dev/null)
  fi
  # A quoted YAML scalar is unwrapped so every tool receives the same text as an
  # unquoted description: "…" resolves \" and \\; '…' resolves '' to '.
  case "$desc" in
    \'*\') desc="${desc#\'}"; desc="${desc%\'}"
          desc="$(printf '%s' "$desc" | sed "s/''/'/g")" ;;
    \"*\") desc="${desc#\"}"; desc="${desc%\"}"
          desc="$(printf '%s' "$desc" | sed 's/\\"/"/g; s/\\\\/\\/g')" ;;
  esac
  printf '%s' "${desc:-skill}"
}

# skill_body_from <skill_md>
# Echo the markdown body (everything after the second `---` frontmatter fence).
skill_body_from() {
  awk 'BEGIN{n=0}/^---/{n++;next}n>=2{print}' "$1"
}

# link_skill_into <base_dir> <skill_md> [fallback] [link_extras] [name_prefix]
# Symlink a skill's SKILL.md (and, when link_extras=1, its sibling files) into
# <base_dir>/<name_prefix><name>. Echoes the resolved name on success.
# Returns 1 (no output) when the skill has no resolvable name.
#   link_extras : 1 (default) also links sibling files; 0 links only SKILL.md
#   name_prefix : optional prefix on the target dir name (e.g. "superskills-")
link_skill_into() {
  local base_dir="$1" skill_md="$2" fallback="${3:-}" link_extras="${4:-1}" name_prefix="${5:-}"
  local skill_dir name target extra extra_name
  skill_dir="$(dirname "$skill_md")"
  name="$(skill_name_from "$skill_md" "$fallback")"
  [ -z "$name" ] && return 1
  # A skill already named with the prefix (superskills-doctor) is not doubled.
  case "$name" in "$name_prefix"*) target="$base_dir/$name" ;; *) target="$base_dir/${name_prefix}${name}" ;; esac
  mkdir -p "$target"
  [ -L "$target/SKILL.md" ] && rm "$target/SKILL.md"
  ln -snf "$skill_md" "$target/SKILL.md"
  if [ "$link_extras" = "1" ]; then
    for extra in "$skill_dir"/*; do
      extra_name="$(basename "$extra")"
      [ "$extra_name" = "SKILL.md" ] && continue
      [ -L "$target/$extra_name" ] && rm "$target/$extra_name"
      ln -snf "$extra" "$target/$extra_name"
    done
  fi
  printf '%s' "$name"
}

# marketing_skill_files <marketing_root>
# Every marketing SKILL.md, nested at any depth, sorted — the one tree walk
# shared by ./setup, the doctor and the marketing plugin generator. Skips the
# generated plugin-skills/ shim tree and vendored project environments
# (.venv, node_modules), which a skill's own tooling may create in-tree.
marketing_skill_files() {
  local root="${1%/}"
  case "$root" in *$'\n'*) echo "marketing_skill_files: path contains a newline: $root" >&2; return 1 ;; esac
  [ -d "$root" ] || return 0
  # Run from inside the root so the plugin-skills prune is the literal "./plugin-skills";
  # a root path containing [ ] * ? would otherwise be read as a -path glob.
  (cd "$root" && find . \( -name .venv -o -name node_modules -o -path ./plugin-skills \) -prune -o \
    -name SKILL.md -type f -print 2>/dev/null) | sed "s|^\.|$(printf '%s' "$root" | sed 's/[&|\\]/\\&/g')|" | LC_ALL=C sort
}

# prune_dangling_links <base_dir> <source_dir>
# Remove symlinks under <base_dir>/*/ that point INTO <source_dir> but no longer
# resolve (a skill renamed, moved or deleted upstream), then remove a skill dir
# left empty. Links pointing anywhere else, links that resolve, real files, and
# anything inside a symlinked directory are never touched, so another tool's or
# the user's own entries are safe.
# Echoes each removed link. Returns 1 for an empty or "/" source.
prune_dangling_links() {
  local base="$1" src="${2%/}" dir entry target pruned
  [ -n "$src" ] || return 1
  [ -d "$base" ] || return 0
  for dir in "$base"/*/; do
    dir="${dir%/}"
    # A trailing-slash glob also matches symlinks to directories; those trees
    # belong to someone else (gstack, another tool, the user), never descend.
    [ -L "$dir" ] && continue
    pruned=0
    for entry in "$dir"/* "$dir"/.[!.]*; do
      [ -L "$entry" ] || continue
      [ -e "$entry" ] && continue
      target="$(readlink "$entry")"
      # Ownership is a literal, normalised path under the source: a target with
      # . or .. segments can name a place outside it despite the prefix.
      case "$target" in */./*|*/../*|*/.|*/..) continue ;; esac
      case "$target" in "$src"/*) rm -f "$entry"; printf '%s\n' "$entry"; pruned=1 ;; esac
    done
    # Only a directory this run emptied is removed — never one that was already
    # empty (a user's or another installer's).
    [ "$pruned" -eq 1 ] && { rmdir "$dir" 2>/dev/null || true; }
  done
  return 0
}

# remove_owned_skill <skill_dir>... — safe removal of OUR deselected installs.
# Judged per directory: a directory qualifies only when it is NOT a symlink,
# not "/" and not empty, and every entry inside is a symlink owned by this
# checkout: its target lies under the caller's source root (passed via
# SS_OWNED_SRC), the target has no . or .. traversal. Directory symlinks count
# as ours when their target is under the source root — our own installer links
# sibling directories (references/, scripts/, …) exactly that way — but the
# removal never descends: only the links themselves are deleted. A directory
# containing anything else — a regular file, a link pointing outside the
# source root — is skipped and left untouched; the remaining directories in
# the argument list are still processed. Fail-closed, never partial within one
# directory. Echoes each removed symlink path; exit status is always 0
# (callers log from the echoed lines).
remove_owned_skill() {
  local dir entry target owned
  [ "$#" -ge 1 ] || return 0
  local src_root="${SS_OWNED_SRC%/}"
  [ -n "$src_root" ] || return 1
  for dir in "$@"; do
    dir="${dir%/}"
    [ -n "$dir" ] || continue
    case "$dir" in /|"") continue ;; esac
    [ -d "$dir" ] || continue
    [ -L "$dir" ] && continue
    owned=1
    for entry in "$dir"/* "$dir"/.[!.]*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      if [ ! -L "$entry" ]; then owned=0; break; fi
      target="$(readlink "$entry")"
      case "$target" in */./*|*/../*|*/.|*/..) owned=0; break ;; esac
      case "$target" in "$src_root"/*) : ;; *) owned=0; break ;; esac
    done
    [ "$owned" -eq 1 ] || continue
    for entry in "$dir"/* "$dir"/.[!.]*; do
      [ -L "$entry" ] || continue
      rm -f "$entry"
      printf '%s\n' "$entry"
    done
    rmdir "$dir" 2>/dev/null || true
  done
  return 0
}
