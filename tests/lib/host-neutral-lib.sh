#!/usr/bin/env bash
# host_neutral_check <file> — exit 1 naming violations, exit 0 when clean.
# Tokens are host-specific tool names that must never appear as instructions
# in a shared skill body. A line containing "host-tool-allow:" is exempt
# (documenting a host's behavior is fine; instructing a call is not).
host_neutral_check() {
  local file="$1"
  local tokens=(multi_tool_use TodoWrite update_plan write_stdin exec_command get_context_remaining)
  local bad=0 t line
  for t in "${tokens[@]}"; do
    while IFS= read -r line; do
      case "$line" in
        *host-tool-allow:*) continue ;;
        *"$t"*)
          echo "host-specific tool '$t' in $file: $line"
          bad=1
          ;;
      esac
    done < <(grep -F "$t" "$file" 2>/dev/null)
  done
  return "$bad"
}
