#!/usr/bin/env bash
# version-lib.sh — pure helper for propagating the canonical VERSION into the
# plugin manifests that drive native update detection (Claude Code, Codex).
# Dependency-free (perl only, always present on macOS/Linux) so it works in a
# fresh clone without jq. Unit-tested in tests/version-lib.bats.

# stamp_json_version <version> <file>
# Set every `"version": "..."` value in <file> to <version>. Idempotent.
# Returns 0 on success, 1 if the file is missing or has no version field
# (so callers can distinguish "stamped" from "nothing to stamp").
stamp_json_version() {
  local version="$1" file="$2"
  [ -n "$version" ] || return 1
  [ -f "$file" ] || return 1
  grep -q '"version"[[:space:]]*:' "$file" || return 1
  VERSION_TO_SET="$version" perl -0pi -e \
    's/("version"\s*:\s*")[^"]*(")/$1 . $ENV{VERSION_TO_SET} . $2/ge' "$file"
}
