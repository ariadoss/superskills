# Pre-registration: the /qa-full step-file hook in Codex (2026-11-12)

Written before any run. Thresholds do not change after results come in.
No Codex run happens under this pre-registration without the user's explicit
yes to the Azure spend (gpt-6-astra, metered): an n=1 smoke first, order of
cents; the full grid only after the smoke is reviewed.

## Question

Codex has no Skill tool: skills load when the agent shell-reads a sub-skill's
SKILL.md. Can a PreToolUse hook that matches ANY tool call whose input text
references a mapped sub-skill's `SKILL.md` deliver the matching /qa-full step
file as `additionalContext`, at the delivery rate the Claude Code matcher
achieved (100% of pairs)?

## Design (from the 2026-11-10 research and today's transcript inspection)

- Codex 0.163.0 PreToolUse input includes `session_id`, `transcript_path`,
  `agent_id`, `tool_name`, `tool_input`; output supports `additionalContext`
  (schemas: `codex/codex-rs/hooks/schema/generated/pre-tool-use.*.json` in the
  scratchpad clone).
- Codex transcripts (`~/.codex/sessions/**/rollout-*.jsonl`) are
  `response_item` lines with `.payload = {name, arguments}` where `arguments`
  is a JSON string (and `custom_tool_call` variants with JS `input` strings).
  The matcher therefore works on input TEXT, not parsed structures: if the
  call's command/file/arguments contain `<skills-dir>/<name>/SKILL.md` for a
  name `qfs_step_for_skill` maps, inject that step file. Tool-name-agnostic on
  purpose — Codex tool surfaces vary (`exec`, `shell`, `function_call`).
- Run detection (is /qa-full active): the transcript references the arm's
  `qa-full/SKILL.md` in a tool call or message, and that directory exists on
  disk with a SKILL.md — same exist-validate guard as the ZCode port, since
  Codex prints no "Base directory" line. Doubles as the subagent branch.
- Config: `~/.codex/config.toml` hook registration (Azure provider already
  configured there; no key material in any repo file).
- Reuses `scripts/lib/qa-full-step-lib.sh` (`qfs_step_for_skill`,
  `qfs_step_read` extended with a Codex extractor for `.payload` argument
  strings) behind a small `qa-full-step-hook-codex.sh` wrapper. Fail-open
  everywhere.

## Arm

Same fixtures and graders as the Claude step-hook eval (heavy n=3, light n=3),
run with `codex exec -s workspace-write` against an arm skill folder, hook
registered via config. Reference: Claude heavy delivery 18/18, correct 2/3;
light 12/12, 3/3.

## Measures

- **Delivered**: the step file's text (header `/qa-full step file steps/NN`)
  appears in the session rollout before that step's first sub-skill output.
- **Pairs**: steps whose sub-skill was loaded (a tool call referencing that
  sub-skill's SKILL.md).
- Correct / unbacked / secret-absent per `evals/_lib/qa-full-grade.sh`.

## Gates (all must hold to adopt)

1. **Smoke (n=1, heavy):** at least one injection reaches the model; zero
   injections on a control `codex exec` that loads a mapped sub-skill without
   /qa-full; fail-open confirmed (a broken hook path does not block calls).
2. **Delivery:** at least 90% of heavy pairs across n=3.
3. **No loss of effect:** heavy correct at least 2 of 3; light 3 of 3.
4. **No over-injection:** light runs get no step 05–08 file.
5. **No double work, transcript-checked:** no step file both read and injected
   in one run.

If the smoke shows the hook's stdin or transcript assumptions are wrong, the
result documents them and the run stops there — no threshold loosening.

## Limits

n=3 per cell is a pilot. Azure metered tokens, so runs stay minimal and the
smoke gates the grid. The graders do not see real compaction.
