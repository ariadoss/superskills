---
# Anchored to the command field: a bare `git commit` pattern would also fire
# on "check whether there is anything to commit". Requires commit, not add
# alone — a run that stages but never commits has not salvaged anything.
type: tool_used
tool: Bash
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?\bgit\s+(-C\s+(?:[^"\\]|\\.)*?\s+)?commit\b'
min: 1
---
