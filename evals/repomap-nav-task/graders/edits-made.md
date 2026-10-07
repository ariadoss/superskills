---
# Mechanical edit-proof (plan-eng-review finding 6): task-correct's claim
# check anchors here. Three carrier sites — one Edit each satisfies the
# alternation with min: 3. A Write to the same path also satisfies the
# intent; that cross-check happens at analysis time from the archived
# traces (scripts/eval-traces.sh), not in this grader.
type: tool_used
tool: Edit
input_match: '"file_path"\s*:\s*"[^"]*(digest_job|notification_controller|notification_hook)"'
min: 3
---
