---
name: deep-interview
description: |
  Clarify vague requirements into an approvable spec through a scored, one-question-
  at-a-time interview — BEFORE planning. Use when the user wants something built or
  changed but the goal, constraints, or success criteria are fuzzy, or when they ask
  to be interviewed about a feature. Produces a spec marked "pending approval"; it
  never writes code or runs the build. Use /write-plan AFTER this, when a spec
  already exists — write-plan turns a clear spec into tasks, it does not create one.
  Use this instead of write-plan when "what" is still undefined; use it instead of
  /plan-eng-review when the problem is the requirements, not the plan.
triggers:
  - interview me about this feature
  - requirements are unclear
  - help me figure out what to build
  - clarify the spec before planning
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
metadata:
  upstream: https://github.com/Yeachan-Heo/oh-my-claudecode
---

# Deep Interview

Turn a vague request into a spec worth planning from — by interviewing the user one
question at a time, always at the requirement's weakest point, until the residual
ambiguity is low enough that `/write-plan` can do its job.

**Announce at start:** "I'm using the deep-interview skill to clarify requirements
before any planning."

**Never mutate anything but the spec file.** No code, no commands that change state,
no plan, no execution — until the user approves the spec. A spec is
`Status: pending approval` until they say so.

## Score before you ask

Rate the requirement as it stands, 0.0–1.0 on each dimension:

| Dimension | 1.0 looks like | 0.0 looks like |
|---|---|---|
| **Goal** | One sentence says what changes for whom | "Make the inbox better" |
| **Constraints** | Tech, budget, compat, and non-goals named | Anything goes, nothing excluded |
| **Success criteria** | Each criterion is checkable by running something | "It works well" |

**Ambiguity = 1 − (average of the three scores).**

- Ambiguity ≤ **0.2**: don't interview. Say "requirements are already clear enough
  to plan" with the score table, and offer `/write-plan` directly.
- Ambiguity > 0.2: interview, targeting the weakest dimension every round.

Re-score after every answer. The table (dimension → score) is part of the spec.

## Interview rules

1. **One question per turn.** Never a batch, never a form. A user answering ten
   questions at once is a user guessing on half of them.
2. **Always ask at the current weakest dimension** — re-scored after the last
   answer. Do not polish what is already clear.
3. **Repo before user.** If a question can be answered by reading the codebase
   (what library, what endpoint exists, what the current behavior is), answer it
   yourself with Read/Grep and state the finding — never spend a user question on it.
4. **Every question is answerable.** No "what's your vision" — ask "should billing
   emails route to the billing queue even when the classifier is unsure, or go to
   the human queue?" Concrete forks, not essays.
5. **Lock the topology first (multi-component work).** Before depth on any one
   part, list the components (max 6) and get the user to confirm the list. One
   well-described component must not hide two fuzzy siblings; score per component.
6. **Challenge modes, once each**, injected as the round's framing when the count
   hits: round 4 **Contrarian** ("what breaks this? what's the failure case?"),
   round 6 **Simplifier** ("what if we cut this entirely — what's actually
   load-bearing?"), round 8 **Ontologist** ("do these two terms mean the same
   thing? name each precisely").
7. **Caps.** Warn the user at round 10 that the interview is running long. At
   round 20, stop: write the spec with everything known, and list what remains
   unresolved under open questions.

## The spec

Save to `docs/superpowers/specs/YYYY-MM-DD-<slug>.md` (user preferences for spec
location override this default), with exactly these sections:

```markdown
# <Feature> Spec

Status: pending approval

## Goal
[one sentence: what changes, for whom]

## Components
[the locked list, one line each — or "single-component"]

## Constraints
[tech, budget, compatibility, and explicit non-goals]

## Acceptance criteria
- [ ] [each criterion checkable by running something]
- [ ] ...

## Assumptions
| Assumption | Basis | Reversible? |
|---|---|---|

## Clarity
| Dimension | Score |
|---|---|
| Goal | 0.0–1.0 |
| Constraints | 0.0–1.0 |
| Success criteria | 0.0–1.0 |

## Open questions
[anything still unresolved at the cap — else "none"]
```

Acceptance criteria are the contract `/write-plan` decomposes into tasks and
`/qa-full` verifies at ship time — an uncheckable criterion is a defect in this
spec, not a detail for later.

## Approval and handoff

Present the spec. The user approves, edits, or rejects — the skill never proceeds
on its own guess about approval. On approval, hand off:

**"Spec approved. Ready for /write-plan — say the word and I'll run it."**

If the user instead wants changes, fold them in and re-present. Do not run
`/write-plan` unasked; the handoff above is the whole offer.
