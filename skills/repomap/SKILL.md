Generate a repo map for the current project.

First, verify this is a git repository. If not, let the user know.

Then run this command:

```bash
PYTHONPATH=/Users/danilosapad/claude-repomap-command python3.11 -m repomap -o REPOMAP.md
```

The tool will auto-install `tree-sitter-languages` if it's not already installed.

If the command fails because the repomap package isn't found, tell the user to clone it:

```bash
git clone https://github.com/ariadoss/repomap.git ~/claude-repomap-command
```

After the command completes:
- If REPOMAP.md has content, confirm success and summarize what was mapped. Then ask the user: "Want me to add a rule so Claude automatically references this map in future sessions?" If yes, create `.claude/rules/repomap.md` in the project directory with the content: "Reference REPOMAP.md at the project root for a structural overview of the codebase. Use it to understand file layout, class/function locations, and module structure before exploring code." Create the `.claude/rules/` directory if needed. If no, just let them know they can read it manually anytime.
- If REPOMAP.md is empty (0 bytes or only whitespace), delete the empty file and let the user know that the project may use unsupported languages
- If the command errored, share the error output so the user can troubleshoot
