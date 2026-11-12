## Step 8: Design + accessibility pipeline — `/design-review`, `/a11y`

**`/design-review` (when the diff includes UI changes, unless `CLAUDE.md` opts
out).** Run `/design-review` against the changed screens — it audits visual
consistency, hierarchy, spacing, AI-slop tells and slow interactions, then
**fixes them with atomic commits and before/after screenshots**. Let it complete.
Visual findings it can't fix are warnings, not blockers. If the project opted
out in `CLAUDE.md`, record SKIPPED("project opt-out") and move on.

**`/a11y` (when the UI change is heavy and likely to affect assistive tech —
new/changed interactive components, forms, ARIA/`role`/`tabindex`,
focus/keyboard handling, images, color/contrast, motion; see `/a11y`'s trigger
section).**
1. **Audit:** run the static pass on the diff, and the **dynamic axe pass** when
   the dev URL is reachable (it is, if Step 6/7 ran).
2. **Fix:** every CRITICAL/SERIOUS — native element over ARIA-on-a-div, missing
   label/name, unreachable-by-keyboard control, focus trap, contrast below
   ratio, missing reduced-motion guard. Commit atomically.
3. **Verify:** re-run the same pass; CRITICAL that survive ⇒ UNFIXED blocker.

Scope split: `/design-review` owns *visual* quality; `/a11y` owns WCAG /
assistive-tech correctness. They overlap on contrast — `/a11y`'s measured
contrast finding is authoritative.
