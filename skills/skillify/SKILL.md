---
name: skillify
description: |
  Turn a just-finished, hard-won piece of work into a reusable skill file — a
  SKILL.md another agent can follow next time. Use when the user says "save this
  as a skill", "make a skill out of what we just did", or when a session solved
  something non-obvious worth preserving as a repeatable procedure. Applies a
  three-question quality gate first: trivia gets pointed at docs instead. Not for
  prose knowledge (that is /kb-advisor) and not for one-off fixes unlikely to recur.
triggers:
  - save this as a skill
  - make a skill from this session
  - extract a reusable skill
  - we keep re-doing this manually
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
metadata:
  upstream: https://github.com/Yeachan-Heo/oh-my-claudecode
---

# Skillify

Extract a reusable skill from finished work. The unit of extraction is a
**procedure that will be needed again**, not a fact that was learned.

**Announce at start:** "I'm using the skillify skill to turn this into a reusable
skill."

## The quality gate (all three must pass)

Before writing anything, answer these about the work — if any answer is NO or
"not sure", do not create a skill:

1. **Not searchable in 5 minutes.** Would a competent engineer (or agent) find
   this by reading the docs or a quick search? If yes, it belongs in a README or
   doc comment, not a skill.
2. **Specific to this context.** Is it tied to this repo, this toolchain, this
   team's workflow? Generic advice ("write tests first") is not a skill.
3. **Hard-won.** Did it take real effort, debugging, or iteration to establish?
   The first attempt that worked is not a skill; the third attempt that finally
   worked, with the reasons the first two failed, is.

On a failed gate, say which test failed and where the content belongs instead
(doc, README, comment, or nowhere). Creating low-value skills is not harmless —
every skill loads its description into selection and dilutes the triggers of the
ones that matter.

## What to capture

Reconstruct from the session's actual work (transcript, diff, files — Read them;
do not rely on memory of the conversation alone):

- **Trigger** — the exact situations (and phrasings) where this skill should
  fire, and the boundary: the near-miss situation where it must NOT fire.
- **Steps** — the ordered procedure with the real commands, paths, and values,
  not "run the tests" but the command that worked.
- **Pitfalls** — what went wrong before it worked; each one with its symptom.
  This is the hard-won part; a skill without pitfalls is the docs answer again.
- **Success criteria** — how the next agent knows it worked (command + expected
  output).

## Where it lands

Ask the user for scope if not obvious; propose a default:

- **In a superskills checkout** → `skills/<name>/SKILL.md` (new skill: run
  `./setup` to link it — tell the user, don't run it yourself) and follow the
  skill-authoring conventions in `ENGINEERING_STANDARDS.md`.
- **Other project** → `.claude/skills/<name>/SKILL.md` (shared with the team) or
  `~/.claude/skills/<name>/SKILL.md` (user-level) — propose the project dir by
  default.

## Format rules

Frontmatter, always — a skill without frontmatter never triggers:

```markdown
---
name: <kebab-case, equals the directory name>
description: <when to use — and when NOT to: the near-miss boundary>
---

# <Name>
[steps, pitfalls, success criteria per above]
```

`name` must equal the directory name in flat skill trees (`skills/`,
`design-skills/`); the description is trigger text, not a summary — write it as
the sentence that wins the selection contest at the moment this skill should
fire.

## Draft, confirm, write

1. Draft the SKILL.md and show it in full.
2. Confirm name and location with the user (one question, once).
3. Write the file. Report the path and the linking step. Do not run `./setup`,
   installers, or anything mutating — the user links the skill themselves.

## Self-check

Before showing the draft: would the trigger fire on the original session's
starting situation, and not fire on the near-miss you named? If you cannot
construct both examples, the description is not ready.
