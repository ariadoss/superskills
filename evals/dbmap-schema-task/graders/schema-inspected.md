---
# Inspection proof (replaces the repomap experiment's Edit-tool proof —
# Task-1 lesson: this model edits via Write/Bash heredocs, never Edit, and
# this task expects at most query-file edits, so an Edit-tool proof would
# read 0 across the board). Proves the agent actually inspected the schema
# rather than guessing from the prompt's framing: a sqlite CLI/python
# probe or a tbls run. Anchored to the command field per the RUBRIC
# input_match pitfall. Reported as an indicator; not part of the primary
# endpoint.
type: tool_used
tool: Bash
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?(pragma_index_list|sqlite3|tbls)'
min: 1
---
