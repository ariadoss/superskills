---
name: graphify
description: |
  Turn any folder of code, docs, papers, or images into a queryable knowledge graph — interactive HTML, GraphRAG-ready JSON, and a plain-language audit report.
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# /graphify

Turn any folder of files into a navigable knowledge graph with community detection, an honest audit trail, and three outputs: `graph.html`, `graph.json`, and `GRAPH_REPORT.md`.

Source: [safishamsi/graphify](https://github.com/safishamsi/graphify)

## Usage

```
/graphify                         # full pipeline on current directory
/graphify <path>                  # full pipeline on specific path
/graphify <path> --mode deep      # thorough extraction, richer INFERRED edges
/graphify <path> --update         # incremental — re-process only changed files
/graphify <path> --no-viz         # skip HTML visualization, just report + JSON
/graphify <path> --svg            # also export graph.svg (embeds in Notion, GitHub)
/graphify <path> --neo4j          # generate cypher.txt for Neo4j import
/graphify <path> --watch          # watch folder, auto-rebuild on code changes
/graphify <path> --wiki           # build agent-crawlable wiki (index.md + per-community articles)
/graphify add <url>               # fetch URL, save to ./raw, update graph
/graphify query "<question>"      # BFS traversal — broad context
/graphify query "<question>" --dfs  # DFS — trace a specific path
/graphify explain "<Node>"        # plain-language explanation of a node
/graphify path "A" "B"            # shortest path between two concepts
```

## What graphify is for

graphify is built around Andrej Karpathy's `/raw` folder workflow: drop anything into a folder — papers, code, screenshots, notes — and get a structured knowledge graph that shows you what you didn't know was connected.

Three things it does that Claude alone cannot:
1. **Persistent graph** — relationships are stored in `graphify-out/graph.json` and survive across sessions
2. **Honest audit trail** — every edge tagged EXTRACTED, INFERRED, or AMBIGUOUS
3. **Cross-document surprise** — community detection finds connections across files you'd never think to query

## Step 1 — Ensure graphify is installed

```bash
# Detect the correct Python interpreter
PYTHON=""
GRAPHIFY_BIN=$(which graphify 2>/dev/null)
if [ -z "$PYTHON" ] && command -v uv >/dev/null 2>&1; then
    _UV_PY=$(uv tool run graphifyy python -c "import sys; print(sys.executable)" 2>/dev/null)
    if [ -n "$_UV_PY" ]; then PYTHON="$_UV_PY"; fi
fi
if [ -z "$PYTHON" ] && [ -n "$GRAPHIFY_BIN" ]; then
    _SHEBANG=$(head -1 "$GRAPHIFY_BIN" | tr -d '#!')
    case "$_SHEBANG" in
        *[!a-zA-Z0-9/_.-]*) ;;
        *) "$_SHEBANG" -c "import graphify" 2>/dev/null && PYTHON="$_SHEBANG" ;;
    esac
fi
if [ -z "$PYTHON" ]; then PYTHON="python3"; fi
"$PYTHON" -c "import graphify" 2>/dev/null \
  || "$PYTHON" -m pip install graphifyy -q 2>/dev/null \
  || "$PYTHON" -m pip install graphifyy -q --break-system-packages 2>&1 | tail -3
mkdir -p graphify-out
"$PYTHON" -c "import sys; open('graphify-out/.graphify_python', 'w').write(sys.executable)"
```

If `graphify` is not installed and pip fails, tell the user to install it:

```bash
uv tool install graphifyy   # recommended
# or: pipx install graphifyy
# or: pip install graphifyy
```

**In all subsequent steps, replace `python3` with `$(cat graphify-out/.graphify_python)`.**

## Step 2 — Detect files

```bash
$(cat graphify-out/.graphify_python) -c "
import json
from graphify.detect import detect
from pathlib import Path
result = detect(Path('INPUT_PATH'))
print(json.dumps(result))
" > graphify-out/.graphify_detect.json
```

Replace `INPUT_PATH` with the path the user provided (default: `.`). Read the JSON silently and present a clean summary:

```
Corpus: X files · ~Y words
  code:    N files (.py .ts .go ...)
  docs:    N files (.md .txt ...)
  images:  N files
```

Omit categories with 0 files. Then:
- If `total_files` is 0: stop with "No supported files found in [path]."
- If `total_words` > 2,000,000 or `total_files` > 200: list the top 5 subdirs by file count and ask the user which subfolder to run on. Wait for their answer.
- Otherwise: proceed to Step 3.

## Step 3 — Build the graph

```bash
$(cat graphify-out/.graphify_python) -m graphify INPUT_PATH [FLAGS]
```

Pass through any flags the user specified (`--mode deep`, `--update`, `--no-viz`, etc.). This runs the full pipeline: AST extraction, LLM concept/relationship extraction via Claude subagents, Leiden community detection, and export.

Stream output so the user can see progress. The pipeline can take several minutes on large corpora.

## Step 4 — Report results

After the pipeline completes, read `graphify-out/GRAPH_REPORT.md` and present:

1. **God nodes** — the most-connected concepts (the structural backbone of the codebase)
2. **Surprising connections** — edges between concepts you'd expect to be unrelated
3. **Community summary** — what each cluster contains
4. **Suggested questions** — from the report's recommended queries

Then tell the user:
- `graphify-out/graph.html` — open in any browser for interactive exploration
- `graphify-out/graph.json` — persistent graph, queryable with `/graphify query`
- `graphify-out/GRAPH_REPORT.md` — plain-language audit

Ask: "Want me to add a rule so Claude references this graph in future sessions?" If yes, create `.claude/rules/graphify.md` with:

```
Reference graphify-out/graph.json and graphify-out/GRAPH_REPORT.md for knowledge graph context.
Use /graphify query "<question>" to traverse the graph before exploring unfamiliar code paths.
```

Create `.claude/rules/` if needed.

## Tips

- Use `--update` for incremental runs — only changed files are re-processed
- Use `--mode deep` on smaller corpora for richer relationship extraction
- `graphify add <url>` fetches a URL and adds it to the graph without a full rebuild
- `.graphifyignore` excludes paths (same syntax as `.gitignore`)
- The graph persists across sessions — `graph.json` is your queryable index
