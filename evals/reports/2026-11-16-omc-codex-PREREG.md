# Pre-registration: Codex replication of the OMC ideas eval (2026-11-16)

This is a separate run set. The original 2026-11-15 preregistrations name
in-session Sonnet subagents. That model is unavailable under the current
subscription limit. The three completed ZCode runs and interrupted runs are
excluded from every Codex score.

## Fixed protocol

- Runner: fresh Codex subagent per run, `gpt-6-sol` at medium effort, at most
  two runs concurrently. Each has only its run prompt, scratch project, and
  the exported arm's skill file. No paid `claude plugin eval` calls.
- Arms: `f4725f9` for before and this branch's skill files for after. The
  scripted feedback-baseline correction on this branch is in the after SDD
  arm. No OMC runtime or external network dependency.
- Cases, fixture content, output checks, and adoption thresholds are those in
  `2026-11-15-omc-writeplan-intake-PREREG.md`,
  `2026-11-15-omc-skillify-PREREG.md`, and
  `2026-11-15-omc-sdd-contracts-PREREG.md`: three independent runs per arm and
  case, including the same negative controls. No score mixes models.
- A run that hits a tool or quota limit is invalid and is rerun with a fresh
  scratch directory. Output is preserved; invalid runs never count as FAIL.
- Record the exact prompt, tool outcome, final reply, scratch artifacts, and
  script grade for every run. Hand-label a representative PASS/FAIL set,
  including boundaries and negative controls, before treating script grades
  as decisions. Report counts and any grader disagreements.

## Write-plan prompt texts

Q1 retains the exact vague one-shot signup request from the interrupted ZCode
run. For Q2 and Q3, which had no ZCode runs, the simulated user messages are:

- Q2: "Our signup flow is confusing and we're losing people somewhere. It's a
  Node app (see the repo). I can answer questions. Help me decide what to plan."
- Q3: "Plan a Node app change: add GET /healthz returning HTTP 200 with JSON
  {\"status\":\"ok\"}. Keep start() exported from src/app.js. Use Node 20 and
  built-in node:test; add no runtime dependencies. Acceptance: npm test exits 0
  and an HTTP test asserts the exact /healthz status and body. Give the
  architecture and task list in your reply."

## Two-turn interaction correction

The skillify hard-won case asks the agent to confirm name and location before
writing. A one-turn run cannot test that contract. For this replication, its
first turn must draft and ask for confirmation; the scripted user then answers
"Yes. Use the proposed name and project location." The second turn must write
the skill. Grade the complete two-turn exchange: file shape, actual pitfalls,
success criteria, and confirmation before the write. Keep its original
adoption threshold of at least 2/3 after-arm passes and its trivial-content
negative control. This corrects the interaction fixture before any Codex run;
it does not change or reinterpret the earlier preregistration.

## Model availability amendment (before grading)

The first two subagents were requested with `gpt-6.1-sol`; both returned a
deployment 404 before opening the fixture or producing a reply. Their scratch
directories had no result. We switched the entire Codex set to `gpt-6-sol`
before inspecting any Codex behavior output. The two failed launches are
excluded, and every counted arm uses `gpt-6-sol` at medium effort.

## Interpretation

The Codex set tests transfer to this host, not the unavailable Sonnet result.
The original ZCode Q1 observations remain descriptive only. If any gate fails,
the corresponding idea stays on this unmerged branch pending a new wording
round and a new registered run.
