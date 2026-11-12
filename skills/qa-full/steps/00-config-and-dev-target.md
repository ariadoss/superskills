## Project configuration (`CLAUDE.md`)

This pipeline reads the project's root `CLAUDE.md` for a few optional settings.
They are plain prose (CLAUDE.md is agent instructions, not a config file) — look
for a `## qa-full` section and honor whatever it states. Example:

```markdown
## qa-full

- Mandatory checks (must RUN with evidence — a skip is a blocker): `/pentest`, `/defense`
- Hard perf gate: LCP ≤ 2.5s and INP ≤ 200ms on `/` and `/checkout` (breach blocks)
- Design: skip `/design-review` (design is owned by the design team, do not auto-fix visuals)
- Dev URL: http://localhost:3000   (for `/web-perf`, `/qa`, `/a11y`, `/fuzz`)
- Test/build: `pnpm test` and `pnpm build`
- Fast tests: `pnpm test:unit`   (unit-only fallback when no related tests are found; Step 2)
- QA tier: exhaustive
```

Recognized settings (all optional; absence = the defaults in the steps below):
- **Mandatory checks** — listed commands must read RAN-CLEAN or FIXED in the
  ledger; SKIPPED is a blocker (any step; Step 10 enforces it). MANDATORY
  overrides the check's own diff trigger: run it on the diff even when the
  trigger didn't fire, so NOT-TRIGGERED is not an acceptable state either. Use
  for compliance-critical surfaces (payments, auth, PII).
- **Hard perf gate** — turns a `/web-perf` budget breach that survives the fix
  round from a warning into a blocker (Step 6).
- **Design: skip `/design-review`** — opt *out* of the visual-fix pass (Step 8)
  entirely; by default it runs on any UI change. This skips the check (ledger:
  SKIPPED("project opt-out")) — it does not turn it into a report-only run.
- **Test/build commands** — feed Steps 2 and 10. **Fast tests** — the
  unit-only command Step 2 falls back to when no related tests are found; absent, it
  is inferred. **Dev URL** — feeds Steps 4
  (`/fuzz`), 6, 7 and 8. **QA tier** — feeds Step 7; defaults to `standard`.

If there is no `## qa-full` section, run with the built-in defaults — nothing here
is required.

## Resolve a dev target for browser checks

Use this flow when a triggered `/fuzz`, `/web-perf`, `/qa`, `/design-review`, or
dynamic `/a11y` check needs a running app. Resolve the target once and reuse it;
keep any server you start alive through the final browser check.

1. Read the project's `CLAUDE.md` `Dev URL`, `AGENTS.md`, `README.md`, and
   development/setup docs. Check the project's declared `dev`/`start` script or
   equivalent and probe documented local ports. A responding localhost port is
   usable only after you verify it serves this project, not another app.
2. If the app is not running, follow the project's setup instructions. Install
   its declared dependencies when needed, start its documented dev command,
   and wait for a reachable URL. Record the command, URL, and startup result in
   the ledger. Do not invent a port, command, credential, or external service.
3. If the URL or startup command is still unknown, or startup needs user-owned
   configuration, **ask the user** for the dev/preview URL or the missing setup
   detail. Tell them what you already checked. Let the user configure secrets
   locally; never request credentials in chat. Pause the affected check and
   resume it after their answer. An unanswered question is pending context,
   not a SKIPPED check or a final refusal.
4. If a documented start fails, inspect its error and attempt a bounded fix to
   the local setup. If it still cannot run, ask for the missing information or
   user action. Only record SKIPPED after documenting discovery and startup
   attempts and the user confirms there is no runnable target or declines the
   needed setup. For a triggered `/qa`, that SKIPPED result is a NOT READY
   blocker: the feature has not been browser-tested.

`/qa` has its own diff-aware target discovery and browser setup. Invoke it
without a URL when this flow has not resolved one; follow its question or
setup path rather than replacing browser testing with unit tests or `curl`.
