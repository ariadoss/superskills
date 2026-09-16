#!/usr/bin/env bash
# mirror-lib.sh — turn an upstream slash-command markdown file into a valid
# SKILL.md. The repomap/dbmap upstream ships plain markdown (no frontmatter);
# every plugin validator (Claude Code --strict, Codex plugin-creator) requires a
# frontmatter block, so the mirror adds one. Unit-tested in tests/mirror-lib.bats.

MIRROR_UPSTREAM_URL="https://github.com/ariadoss/repomap"

# mirror_wrap <name> <src-file>
# Print <src-file> as a SKILL.md: unchanged if it already starts with `---`,
# otherwise prefixed with name / description (first non-empty line) / upstream.
mirror_wrap() {
  local name="$1" src="$2" first
  if [ "$(head -c 3 "$src")" = "---" ]; then
    cat "$src"
    return 0
  fi
  first="$(grep -m1 -v '^[[:space:]]*$' "$src" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  printf -- '---\nname: %s\ndescription: %s\nmetadata:\n  upstream: %s\n---\n' "$name" "$first" "$MIRROR_UPSTREAM_URL"
  cat "$src"
}
