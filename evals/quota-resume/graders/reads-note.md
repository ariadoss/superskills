---
# The Read-tool indicator for note-first behavior. A compliant run that
# instead reads the note via Bash (cat, git show) does not match here — that
# path is covered by the completes-from-note llm grader, which fails a reply
# that re-derives the task from the repo instead of following the note.
# Ordering (note before repo exploration) is likewise scored by the llm
# grader; a tool_used matcher cannot see sequence.
type: tool_used
tool: Read
input_match: '"file_path"\s*:\s*"(?:[^"\\]|\\.)*?QUOTA-RESUME'
min: 1
---
