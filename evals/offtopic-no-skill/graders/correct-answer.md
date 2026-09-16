---
type: llm
focus: last_message
---

PASS if the reply says a hard link is another directory entry for the same inode/data (so the file survives deleting the original name) and a symbolic link is a separate file that holds a path (so it can dangle and can cross filesystems or point at directories).
FAIL if it gets either of those backwards or omits both distinctions.
