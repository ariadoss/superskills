Generate a repo map for the current project.

First, verify this is a git repository. If not, let the user know.

Then locate the repomap install. Search in this order and use the first hit:

1. `$REPOMAP_HOME` (if set)
2. `$HOME/claude-repomap-command`
3. `$HOME/.claude-repomap-command`
4. `$HOME/.local/share/claude-repomap-command`

If none of those contain a `scripts/run.sh` file, tell the user to clone the repo:

```bash
git clone https://github.com/ariadoss/repomap.git ~/claude-repomap-command
```

Once located, run the tool via the helper (replace `<REPOMAP_DIR>` with the path you found):

```bash
<REPOMAP_DIR>/scripts/run.sh repomap -o REPOMAP.md
```

The helper auto-detects a Python interpreter >= 3.8, auto-installs `tree-sitter-languages` on first run, and falls back to `uv`/`pyenv`/`asdf` if no compatible Python is on PATH. If it errors with "no compatible Python found", share the printed install options with the user.

After the command completes:
- If REPOMAP.md has content, confirm success and summarize what was mapped. Then ask the user: "Want me to add a rule to CLAUDE.md so Claude automatically references this map in future sessions?" If yes:
  - Check whether CLAUDE.md at the project root already contains the marker `<!-- repomap-rule -->`. If it does, the rule is already present — skip and tell the user.
  - Otherwise, append the block below to CLAUDE.md (create the file if it doesn't exist). Leave a blank line before the block if appending to existing content.

    ```
    <!-- repomap-rule -->
    ## REPOMAP.md

    REPOMAP.md at the project root is a structural outline of the codebase (files, classes, functions, types). Read it when the task benefits from a map: broad exploration, "where does X live", cross-module refactors, onboarding to an unfamiliar area, or planning changes that touch multiple files. Skip it for narrow lookups where Grep or a known file path is faster — a single symbol search doesn't need the whole map.
    ```
  If no, just let them know they can read it manually anytime.
- If REPOMAP.md is empty (0 bytes or only whitespace), delete the empty file and let the user know that the project may use unsupported languages
- If the command errored, share the error output so the user can troubleshoot
