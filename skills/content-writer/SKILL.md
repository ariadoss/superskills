---
name: content-writer
description: |
  Content creation leveraging knowledge bases — blog posts, docs, marketing copy, investor updates.
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
---

# Content Writer

Create content by researching your knowledge bases before writing.

## Knowledge Bases

Reads from knowledge bases configured in `~/.superskills/knowledge.conf`. Each line: `name|path|description`.

```bash
cat ~/.superskills/knowledge.conf
```

## Content Types

| Type | Audience | Tone |
|------|----------|------|
| Blog post | Developers, users | Technical but accessible |
| Documentation | Developers | Precise, example-driven |
| Marketing copy | Prospects | Benefit-focused, concise |
| Investor update | Investors, board | Data-driven, strategic |
| Product announcement | Users | Exciting but honest |
| Internal memo | Team | Direct, context-rich |

## Workflow

### Phase 1: Research

Search knowledge bases for relevant context:

```bash
# Search across all configured knowledge bases
for kb_path in $(awk -F'|' '{print $2}' ~/.superskills/knowledge.conf); do
  kb_path="${kb_path/#\~/$HOME}"
  [ -d "$kb_path" ] && grep -rli "topic" "$kb_path" --include="*.md" --include="*.txt" --include="*.html"
done
```

Read the top 3-5 most relevant files. Note key quotes, data points, and frameworks.

### Phase 2: Outline

Before writing, create a structured outline:
1. **Hook** — why should the reader care?
2. **Context** — what's the situation?
3. **Core argument** — what's the insight?
4. **Evidence** — data, examples, quotes from knowledge base
5. **Call to action** — what should the reader do next?

### Phase 3: Draft

Write the full draft:
- Match the tone to the content type and audience
- Cite knowledge base sources where relevant (for internal docs)
- Include concrete examples from the project's domain
- Avoid jargon unless writing for a technical audience

### Phase 4: Review

Check the draft against:
- **Accuracy**: Cross-reference claims with knowledge base docs
- **Consistency**: Align with project positioning and strategy docs
- **Completeness**: Cover all key points from the outline
- **Voice**: Match the target audience and content type

## Tips

- Research before writing — always check the knowledge base first
- End with actionable takeaways
- For technical content, include code examples
- For marketing content, lead with benefits not features
