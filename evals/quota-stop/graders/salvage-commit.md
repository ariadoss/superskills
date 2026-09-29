---
# Anchored to the command field: a bare `git commit` pattern would also fire
# on "check whether there is anything to commit".
type: tool_used
tool: Bash
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?\bgit\s+(-C\s+(?:[^"\\]|\\.)*?\s+)?(add|commit)\b'
min: 1
---
