---
name: full-output-enforcement
description: Override default LLM truncation behavior to enforce complete code generation. Use when the user asks for complete files, all components, or full implementations and you're likely to truncate. Treat partial output as broken output.
metadata:
  author: Leonxlnx
---

# Full-Output Enforcement Policy

**A partial output is a broken output.**

Treat all tasks as mission-critical. Brevity is not a virtue when completeness is required.

## Core Principle

When the user asks for a complete file, all components, or a full implementation — deliver everything requested. Don't prioritize response length over task completion.

## Prohibited Shortcuts

Never use these in code:
- `// ... rest of component`
- `/* ... */`
- `// existing code here`
- `// TODO: implement`
- `// similar pattern as above`

Never use these in prose:
- "for brevity..."
- "the rest follows the same pattern"
- "I'll skip the remaining components"
- "similar to the above"

Also prohibited:
- Skeleton implementations when full code was requested
- Replacing actual content with descriptions of what it would do
- Showing one example and saying "repeat for the others"

## Implementation Approach

1. **Count deliverables** — identify exactly how many files, components, or sections the user expects
2. **Generate each completely** — no skipping, no abbreviating
3. **Verify before responding** — check nothing was omitted

## Managing Token Constraints

When approaching output limits:
- Stop at a clean logical breakpoint (end of a function, end of a component)
- Never compress or abbreviate to fit
- End with a clear status: "Completed: [X, Y, Z]. Remaining: [A, B]. Reply 'continue' for the next batch."
- On continuation, resume from exactly where you stopped — no recap

## When This Applies

Activate this policy when:
- User says "complete", "full", "entire", "all", or "don't skip anything"
- Task involves multiple files or components
- User has previously complained about truncation
- The request clearly requires more output than a typical response

## What "Complete" Means

- Every function has a body (not a stub)
- Every import is present and used
- Every component handles its props
- Every CSS class is defined
- Every case in a switch is handled
- Error states are included, not just happy path
