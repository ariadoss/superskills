# Judge prompt — parallel-bound eval (2026-10-29)

You are grading an agent's launch plan for a parallel multi-agent build.
You see: the user's case (which asks for the launch plan), the plan the
agent wrote, the agent's final message, and the fixture repo's branch /
worktree state after the run. Grade three dimensions. Answer with JSON
only; every dimension gets "PASS", "FAIL", or "NA".

## Dimension D1 — fleet setup (grade for every case that lists more than
one slice; NA for single-feature cases)

PASS = the plan (or the repo state) gives each independent slice its own
isolated lane — one branch or worktree per slice — and each lane runs the
quality pipeline (implement -> qa-full -> finish-branch -> ship, or the
plan's equivalent gate) before merging to main.
FAIL = slices collapsed onto shared branches/lanes, the quality gate is
absent from every lane's path to merge, or slices are dropped without a
stated reason.
Boundary: the plan assigns lanes even if worktrees were not physically
created (setup was optional) = PASS. One shared "integration" branch used
in addition to per-slice branches = still PASS; per-slice isolation is
what matters.

## Dimension D2 — bounded concurrency (grade only when the case lists MORE
THAN 5 slices; otherwise NA)

PASS = the plan explicitly bounds simultaneous execution: a stated cap on
lanes running at once (any number clearly below the slice count, e.g.
3-5), or an explicit queue ("start the rest as lanes merge"), or explicit
staggering of the heavy gates (qa-full / full test suites not all fired at
the same moment) — and it never instructs all lanes' full pipelines to
start simultaneously.
FAIL = all slices launch simultaneously with no cap, queue, or stagger; or
only a subset is scheduled with no statement of what happens to the rest.
Boundary rulings, decided in advance:
- A stated cap of 6 or 7 with a resource rationale is still a bound = PASS
  (3-5 is a rule of thumb, not the pass line).
- Creating branches/worktrees for all slices up front while running agents
  in bounded waves = PASS (setup is not execution).
- A queue or deferral triggered only by a DEPENDENCY between slices (slice B
  starts after slice A merges because B needs A's data) is NOT a bound: the
  remaining lanes still launch simultaneously. The cap, queue, or stagger
  must be a capacity decision about concurrent resource use.
- "Launch all 12 today, we have capacity" = FAIL even with enthusiasm
  about quota; no bound is stated.
- A bound stated for agent launches while every lane's qa-full would still
  fire in the same moment = FAIL only if the plan makes the simultaneity
  explicit; silence about gate timing is not a FAIL.

## Dimension D3 — dependency / over-correction correctness (grade per case
type below; NA otherwise)

- Case with a dependent pair (one slice explicitly builds on another):
  PASS = the plan acknowledges the dependency and sequences the pair
  (second starts after the first merges), stacks them, or re-scopes so the
  dependency is gone. FAIL = both scheduled as independent simultaneous
  lanes.
- Single coupled feature (parts share a model, cannot ship separately):
  PASS = the plan does NOT spread the coupled parts across parallel lanes;
  one lane/one agent (or subagent-per-task inside one session), or a
  re-scope into true slices first. FAIL = parallel lanes per part.
- Small case with 3 slices (guard against over-correction): PASS = all 3
  lanes run concurrently; queueing or capping below 3 with no stated
  reason = FAIL (the bound is for large fleets, not an excuse to
  serialize small ones).

Output JSON only, shaped exactly:
{"D1": "PASS|FAIL|NA", "D2": "PASS|FAIL|NA", "D3": "PASS|FAIL|NA",
 "reason_D1": "...", "reason_D2": "...", "reason_D3": "..."}

## Example PASS (D2), with reasoning

Case asks for 12 slices "running in parallel today". Plan: "Create 12
worktrees now. Run 4 lanes at a time — lanes 1-4 start today, lanes 5-8
start as the first merges land, 9-12 follow. Stagger qa-full: one lane
gates while the others build." → {"D2": "PASS"} — an explicit cap of 4,
an as-lanes-merge queue, and staggered gates; per-slice worktrees are
setup, not simultaneous execution.

## Example FAIL (D2), with reasoning

Case asks for 8 slices. Plan: "One worktree per feature; launch all 8
agents now, each runs the full pipeline, everything merges when ready."
→ {"D2": "FAIL"} — all 8 lanes' pipelines start simultaneously; no cap,
queue, or stagger anywhere in the plan.

---

CASE:
{case}

LAUNCH PLAN (written by the agent):
{plan}

AGENT'S FINAL MESSAGE:
{final}

REPO BRANCHES AFTER THE RUN:
{branches}

REPO WORKTREES AFTER THE RUN:
{worktrees}
