---
name: kb-advisor
description: |
  Knowledge base advisor — search, synthesize, and update your team's knowledge repositories.
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
---

# Knowledge Base Advisor

Search and synthesize answers from your team's knowledge base repositories.

## Configuration

Knowledge bases are configured during `superskills setup` and stored in `~/.superskills/knowledge.conf`.

```bash
# Check configured knowledge bases
cat ~/.superskills/knowledge.conf
```

Each line is: `name|path|description`

Example:
```
docs|~/.superskills/knowledge/docs|Internal documentation and architecture decisions
research|~/.superskills/knowledge/research|Market research and competitive analysis
```

## Workflow

### 1. Discover Available Knowledge

```bash
# List configured knowledge bases
cat ~/.superskills/knowledge.conf | while IFS='|' read -r name path desc; do
  path="${path/#\~/$HOME}"
  if [ -d "$path" ]; then
    count=$(find "$path" -name "*.md" -o -name "*.txt" -o -name "*.html" | wc -l | tr -d ' ')
    echo "  [$name] $count files — $desc"
  else
    echo "  [$name] NOT CLONED — $path"
  fi
done
```

### 2. Search Across Knowledge Bases

```bash
# Search all knowledge bases for a topic
for kb_path in $(awk -F'|' '{print $2}' ~/.superskills/knowledge.conf); do
  kb_path="${kb_path/#\~/$HOME}"
  [ -d "$kb_path" ] && grep -rli "search terms" "$kb_path" --include="*.md" --include="*.txt" --include="*.html"
done
```

### 3. Synthesize Advice

- Read the most relevant files (top 3-5 matches)
- Quote specific passages with attribution (file name and path)
- Cross-reference multiple sources when they agree or disagree
- Connect abstract principles to the user's specific situation

### 4. Update Knowledge Base (Optional)

When the conversation produces novel insights worth preserving:

```bash
# Add new knowledge to the appropriate repo
echo "content" > <kb-path>/new-insight.md

# Commit the update
cd <kb-path> && git add -A && git commit -m "Add: <topic>"
```

## Tips

- Always cite the specific source file
- If the knowledge base doesn't cover a topic, say so — don't fabricate
- Suggest pulling latest: `cd <kb-path> && git pull`
- For questions outside the knowledge base, answer from general knowledge but note the gap
- Multiple knowledge bases can be searched together for cross-domain insights
