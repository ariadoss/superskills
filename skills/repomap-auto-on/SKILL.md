Enable automatic repo map updates. When enabled, REPOMAP.md is incrementally updated every time a file is edited.

Run this command:

```bash
touch .repomap-auto
```

Confirm that auto-updating is now enabled. Remind the user that REPOMAP.md must already exist (run `/repomap` first if it doesn't). The `.repomap-auto` file is a toggle — delete it to disable auto-updates.
