#!/usr/bin/env bash
# mirror-lib.sh — turn an upstream slash-command markdown file into a valid
# SKILL.md. The repomap/dbmap upstream ships plain markdown (no frontmatter);
# every plugin validator (Claude Code --strict, Codex plugin-creator) requires a
# frontmatter block, so the mirror adds one. Unit-tested in tests/mirror-lib.bats.

MIRROR_UPSTREAM_URL="https://github.com/ariadoss/repomap"

# mirror_wrap <name> <src-file>
# Print <src-file> as a SKILL.md. If it already carries frontmatter (an opening
# AND a closing `---`), keep it but pin `name:` to <name> (inserting it when absent): the mirror lives in skills/<name>/ and every
# consumer (setup, the plugin loader, the doctor) treats the frontmatter name
# as canonical, so an upstream rename must not silently move the command.
# Otherwise prefix name / description (first non-empty line) / upstream.
mirror_wrap() {
  local name="$1" src="$2" first
  # Frontmatter only counts when a closing `---` exists after the opening one;
  # a lone leading rule is treated as body so we never emit an unterminated block.
  # awk reads the whole file, so an early match cannot SIGPIPE a producer and
  # fail the test under `set -o pipefail` (sync-mirrors.sh sets it).
  if [ "$(head -c 3 "$src")" = "---" ] && awk 'NR > 1 && /^---[[:space:]]*$/ { f = 1 } END { exit !f }' "$src"; then
    awk -v name="$name" '
      NR == 1 { print; next }
      !closed && /^---[[:space:]]*$/ { if (!seen) print "name: " name; closed = 1 }
      !closed && /^name:[[:space:]]*/ { print "name: " name; seen = 1; next }
      { print }' "$src"
    return 0
  fi
  first="$(grep -m1 -v '^[[:space:]]*$' "$src" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  # Double-quoted YAML scalar: a ': ', a leading '#', or quotes in the upstream
  # line would otherwise produce invalid or silently different frontmatter.
  first="$(printf '%s' "$first" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf -- '---\nname: %s\ndescription: "%s"\nmetadata:\n  upstream: %s\n---\n' "$name" "$first" "$MIRROR_UPSTREAM_URL"
  cat "$src"
}
