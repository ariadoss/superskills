#!/usr/bin/env bash
# host_neutral_check <file> — exit 1 naming violations, exit 0 when clean.
# Scope: exactly the six host-EXCLUSIVE tool tokens below — names that exist
# on one host and not the others. It is not a general host-syntax checker:
# tools shared across hosts (Skill, Bash, Read) and path variables are out
# of scope. A line is exempt for token t only when a "host-tool-allow:"
# comment names t itself after the colon (documenting that host's behavior
# is fine; a blanket escape that does not name the token is not).
# Pure bash on purpose: one file read, no per-token grep/process
# substitution — the grep form spun at 100% CPU under bats when the
# tracked-files test ran ~1.9k of them.
host_neutral_check() {
  local file="$1"
  [[ -r "$file" ]] || { echo "host-neutral: cannot read $file" >&2; return 2; }
  local tokens=(multi_tool_use TodoWrite update_plan write_stdin exec_command get_context_remaining)
  local bad=0 t line contents
  contents="$(<"$file")"
  while IFS= read -r line; do
    for t in "${tokens[@]}"; do
      case "$line" in
        *host-tool-allow:*"$t"*) continue ;;
        *"$t"*)
          echo "host-specific tool '$t' in $file: $line"
          bad=1
          ;;
      esac
    done
  done <<< "$contents"
  return "$bad"
}

# host_neutral_check_tree — read file paths on stdin, check each, exit 1 if
# any violation. The tracked-files bats test runs this inside one child bash
# (git ls-files | host_neutral_check_tree): an in-test while-read loop over
# ~311 files spun at 100% CPU under bats regardless of the check's own
# implementation, while the identical pipeline in a child process is instant.
host_neutral_check_tree() {
  local f bad=0
  while IFS= read -r f; do
    host_neutral_check "$f" || bad=1
  done
  return "$bad"
}
