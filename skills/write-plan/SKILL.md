---
name: write-plan
description: Use when you have a spec or requirements for a multi-step task, before touching code. Produces an engineering plan complete with TDD tasks, DRY/SOLID/YAGNI principles, a required Test Plan & Verification section, and a coverage target — then auto-runs /plan-eng-review as an independent double-check before execution.
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. SOLID. YAGNI. TDD. Frequent commits. Every plan ends with a required **Test Plan & Verification** section and a coverage target, then gets an automatic second-pass engineering review (`/plan-eng-review`) before any code is written.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

If the spec is a **user-facing feature**, scope the plan as a **vertical slice**: one branch containing every layer the feature needs to work — UI, API, business logic, data, and tests — independently shippable and safely reversible (full definition in `DEVELOPER_WORKFLOW.md` in the superskills install). If it's a **bugfix, refactor, or single-layer change**, scope only the layers it actually touches — do not add layers to make the slice look complete; that's a YAGNI violation.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Design Principles (call these out explicitly in the plan)

> This skill operationalizes the superskills quality standard (TDD, DRY, SOLID,
> YAGNI) at plan time; `/qa-full` enforces it at ship time. The principles are
> defined inline in the sections below — work from those. The canonical written
> copy is `ENGINEERING_STANDARDS.md` in the superskills install (not in the
> project you're planning for), so you don't need to fetch it.

The plan must *show* it respects these — not as a checkbox, but by naming where each applies in the File Structure and tasks:

- **DRY** — before adding code, name the existing helper/module to reuse (Grep for it). If two tasks introduce similar logic, factor the shared piece into its own earlier task. Flag any duplication you knowingly accept and why.
- **SOLID** — each unit has one reason to change (SRP); depend on interfaces/abstractions, not concretions (DIP); keep interfaces narrow (ISP); extend via new code rather than editing stable cores (OCP). For each new unit in the File Structure, note its single responsibility and the seam (interface/boundary) it exposes.
- **YAGNI** — build only what the spec requires. No speculative extensibility, no "might need it later" hooks.

If satisfying these requires restructuring existing code, scope that restructure as its own task — don't smuggle it into a feature task.

## Security & threat model (when the feature crosses a trust boundary)

Threat modeling is a **design-time** activity — it must shape the plan, not be discovered at the ship gate. If this feature does any of the following, run `/cso` (OWASP Top 10 + STRIDE) on the design *before* writing tasks, and fold the result in:

- handles authentication, authorization, sessions, or tokens
- accepts untrusted input (user input, uploads, webhooks, external APIs)
- reads/writes sensitive or regulated data (PII, payments, credentials, health)
- adds a new public endpoint, a new external integration, or deserialization
- changes a trust boundary (new service-to-service call, new cross-tenant path)

What to fold into the plan:
- **Design tasks** for each material threat — input validation, authz checks at the boundary, rate limiting, output encoding, least-privilege, secrets handling. Name them as their own tasks (don't bury them inside feature tasks).
- **Test Plan entries** — abuse/negative cases per threat (e.g. "rejects forged JWT", "blocks IDOR on `/orders/:id`"), so `/qa-full`'s `/defense` step has something concrete to verify against.

If the feature crosses **no** trust boundary, state that in one line and skip — don't manufacture security tasks (YAGNI applies here too).

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Test Plan & Verification (required section in every plan)

After the tasks, every plan **MUST** end with a `## Test Plan & Verification` section. A plan without it is incomplete. This is the rollup that `/qa-full`, `/qa`, `/qa-only`, and `/verify` consume, and the artifact `/plan-eng-review` double-checks. The per-task TDD steps stay where they are; this section ties them to coverage, critical paths, and acceptance criteria.

```markdown
## Test Plan & Verification

**Coverage target:** [concrete, e.g. "≥90% lines on new modules; every new public function and error path has a test"]

**Critical paths (must pass before ship):**
- [end-to-end flow] → [how it's verified]

**Edge cases & error paths:**
- [input/state] → [expected handling] → [test that covers it]

**Regression guards:**
- [existing behavior that must not break] → [test protecting it]

**Verification commands:**
- Unit: `[exact command]` — expected: all pass
- Coverage: `[exact command]` — expected: ≥ target above
- E2E (if applicable): `[exact command]`

**Acceptance criteria (from spec):**
- [ ] [criterion] → covered by [task / test name]
```

The coverage-target line is exactly what `/qa-full` Step 9 checks and `/verify` confirms — make it concrete, not "good coverage."

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, SOLID, YAGNI, TDD, frequent commits
- Every plan ends with a `## Test Plan & Verification` section and a coverage target

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**4. TDD & test-plan completeness:** Does every task that writes code have a failing-test-first step? Is the `## Test Plan & Verification` section present with a concrete coverage target, critical paths, edge cases, and exact verification commands? If any task ships code with no test, fix it.

**5. Principles check (DRY / SOLID / YAGNI):** For each new unit, can you name its single responsibility (SRP) and the existing helper it reuses (DRY)? Any duplicated logic across tasks, god-object, or speculative extensibility (YAGNI)? Fix or justify inline.

**6. Trust-boundary check:** Does the feature cross any trust boundary (auth, untrusted input, sensitive data, new endpoint/integration, deserialization)? If yes, did you run `/cso` and turn each material threat into a design task **and** a negative test? If it crosses none, is that stated? Fix gaps — a trust-boundary feature with no security tasks is an incomplete plan.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Engineering Review (automatic second pass — do not skip)

Once the plan passes self-review, hand it to `/plan-eng-review` for an independent engineering double-check **before any code is written**. This is automatic — don't ask permission, just run it:

1. Invoke `/plan-eng-review` on the saved plan file. It locks in architecture and data flow, pressure-tests edge cases and **test coverage**, and writes a **Test Plan Artifact** that `/qa`, `/qa-only`, and `/qa-full` consume as primary test input.
2. It raises issues interactively (one at a time) with opinionated recommendations. Work through each and fold the resolutions back into the plan file — including any gaps it finds in the `## Test Plan & Verification` section or the DRY/SOLID structure.
3. Only after `/plan-eng-review` is satisfied do you offer the execution handoff below.

Full chain: **/write-plan (DRY · SOLID · YAGNI · TDD · Test Plan · coverage) → self-review → /plan-eng-review (double-check + Test Plan Artifact) → execution.**

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review
