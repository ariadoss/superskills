## Step 7: Browser QA pipeline — `/qa` (auto-run if triggered)

> Run **`/qa`** — the full test → fix → re-verify loop — not `/qa-only`. This is
> the check that replaces manual click-through QA, and a human is present.

Trigger when the diff includes anything a human would manually QA in a browser:
UI/frontend code, pages/routes, forms, route handlers serving HTML, API
endpoints the UI consumes, auth/session flows, or config that changes
user-facing behavior. Server-rendered templates (Jinja, ERB, Blade, Twig,
plain `.html`) and static JS/CSS count as UI. Decide with the
`ui` trigger helper in `SKILL.md`, not by eye.

1. **Invoke `/qa` whenever this trigger fires, even if no dev URL is known.**
   Give it the resolved URL if Step 4 or 6 found one; otherwise invoke it
   without a URL so its diff-aware mode can discover the app or ask. Scope it
   to the affected surface at the project's **QA tier** (`CLAUDE.md`, default
   `standard`: critical + high + medium). If it needs a server, follow the
   target-resolution flow in `steps/00-config-and-dev-target.md` and resume `/qa` after setup or the user's
   answer. A missing URL alone never justifies SKIPPED, stopping the pipeline,
   or declaring browser QA complete. Let `/qa` finish its audit → fix →
   re-verify loop with atomic commits and before/after health scores.
2. Fold its before/after health score, fixed-bug list (with commits), and any
   bugs it could not fix into the ledger.

- User-facing CRITICAL/HIGH bugs that `/qa` could not fix ⇒ UNFIXED blocker.
- If the target-resolution flow ends without a runnable app, record
  SKIPPED(reason) and a NOT READY blocker. Say what setup was attempted and
  what the user needs to provide before browser QA can run.
