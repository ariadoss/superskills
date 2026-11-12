## Step 6: Frontend perf pipeline — `/web-perf` (+ `/perf-profile`)

Trigger when the diff includes frontend code (`**/*.tsx`, `**/*.jsx`,
`**/*.vue`, `**/*.svelte`, `**/components/**`, `**/pages/**`, `**/styles/**`,
`**/*.css`, `**/*.scss`), new images/fonts/assets, or bundler config
(`next.config.*`, `vite.config.*`, `webpack.config.*`). Server-rendered
templates (Jinja, ERB, Blade, plain `.html`) and static JS/CSS count as
frontend too: the `ui` run of `scripts/qa-triggers.sh` from Step 7 decides it,
so a UI match there triggers this step as well.

1. Resolve the dev URL with the target-resolution flow in `steps/00-config-and-dev-target.md`; start the dev
   server if needed. If the flow establishes that no target is possible ⇒
   SKIPPED with the startup error and the user's answer in the ledger.
2. **Audit:** run `/web-perf` against the affected routes. Record Core Web
   Vitals (LCP, INP, CLS) vs. any known budget.
3. **Fix:** address the measured regressions attributable to the diff —
   render-blocking imports → defer/lazy, oversized image/font → optimize or
   preload, layout shift → reserve dimensions, long task → split/memoize.
   Commit atomically.
4. **Verify:** re-run `/web-perf` on the same routes; report before/after
   numbers.

- A budget breach that survives the fix round is a **warning** by default,
  unless `CLAUDE.md` defines a hard perf gate — then it blocks.
- **`/perf-profile`** (triggered when the diff touches hot server-side paths, the
  change is pre-launch, or `/db-optimize`/`/web-perf` point at a server-side
  bottleneck): run it against the affected endpoint/job, **fix** the localized
  bottleneck (cache, batch, move off the request path), re-profile to verify.
  Needs a representative workload — if none is available ⇒ SKIPPED(reason).
