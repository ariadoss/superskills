# PREREG — compaction/handoff framing for quota-resilience resume notes

Registered before any run of the `quota-stop-handoff` case. Provenance:
Codex's compaction prompt (codex-rs/prompts/templates/compact/prompt.md +
summary_prefix.md at 062439b) frames its summary as "a handoff for another
LLM that will resume the task… build on the work already done and avoid
duplicating work", with user preferences as an explicit bucket. The
maintainer's challenge ("nothing from compaction framing was useful?")
prompted a re-triage: the SECTIONS already existed in quota-resilience
(Goal/Done/In flight/Next steps/Verify/Context/Hops — the original
rejection's ground), but the framing itself (self-contained-for-a-fresh-
agent, explicit not-redo, user constraints) was never tested. Host-agnostic
by construction (markdown skill-body edit).

## Intervention (applied only between the two runs)

`skills/quota-resilience/SKILL.md`, step 3 (write the resume note):
- new framing sentence after the first line: the note is a handoff for a
  fresh agent with no memory of this session — every line self-contained,
  explicit about what is already done so nothing gets redone, carrying any
  constraints or preferences the user stated this session;
- the Context bullet gains "user constraints or preferences stated this
  session".

## Cases

| Case | Role |
|---|---|
| `quota-stop-handoff` (new; quota-fixture stop mode; reply must include the note text) | primary: handoff self-containedness + anti-redo/constraints |
| `quota-stop` (unchanged, battle-tested) | guard: stop-protocol behavior must not regress |

## Fairness rule (fixed in advance)

The prompt's include-the-note instruction appears identically in both arms.
Graders grade note CONTENT (standalone interpretability, done-work
pointers, constraints present), never phrases or section names lifted from
the skill text. skill-fired is an unscored indicator.

## Endpoints and thresholds (set before the runs)

- Stop-side runs measured $0.3–0.5 each historically; 2 cases × 3 runs × 2
  arms = 12 runs → each command capped `--max-cost-usd 6`.
- **Firing-power gate:** quota-resilience fired ≥ 2/3 runs per arm on the
  new case, else under-powered → adopt nothing.
- **Primary:** mean of the two new llm graders on `quota-stop-handoff`.
- **Adopt** if primary improves ≥ +0.175 (≥ one full run's worth across
  the grader pair) AND `quota-stop` honest-state + mentions-note do not
  regress ≥ 0.34 AND the firing gate holds.
- **Reject** otherwise: revert the skill edit, keep the case, report the
  null.
- Stated limits: n=3/arm (one run = 0.333 of any grader); same-day drift;
  the resume-USING side (quota-resume) is untouched by this intervention
  and serves only as existing-suite context, not an endpoint.
