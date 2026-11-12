## Step 3: Correctness + quality — `/review` then `/clean-code` (always)

Two halves. Both sub-skills are in-tree, so they are invocable from inside any
session or tool, and Step 1.5 guarantees you are on a non-base branch, which
`/review`'s own branch guard requires.

**Correctness — `/review`.** `/review` is not a report-only audit: one
invocation reads the diff, auto-applies its mechanical (AUTO-FIX) findings to
the working tree, asks you about the rest (ASK items) via its own
AskUserQuestion, and never commits. Treat one call as one atomic
audit + fix + ask unit:
1. **Run `/review`** against the base this pipeline resolved in Step 1. It has
   no argument channel, so it always diffs `merge-base(origin/<base>, HEAD)` —
   if Step 1 resolved a non-default base or a `--scope`, say so in the ledger
   evidence: `/review` reviewed the full default-base diff.
2. **Commit what it changed** as one commit attributed to `/review` (e.g.
   `review: apply AUTO-FIX + approved ASK findings`), so the tree is clean
   before `/clean-code` and nothing `/review` fixed can be lost by a later
   revert. If `--scope` was given, stage and commit only files under scope;
   any out-of-scope edits `/review` made stay uncommitted (stash them so the
   tree is clean, noting the stash ref) and are flagged in the ledger with that
   ref for the user — never silently committed. For any CRITICAL it reported but could not fix, root-cause
   (`/debug`), write the failing test first (`/tdd`), fix, commit atomically.
3. **Verify:** run `/review` once more. It re-scans the full base diff
   including the fix commits — that's the point. A CRITICAL still present ⇒
   UNFIXED blocker. Commit anything this second pass auto-fixed the same way.
   Do not run it a third time in this step.

`/review`'s adversarial section runs a free Claude subagent **and**, when the
Codex CLI is installed and enabled, `codex exec` / `codex review` passes that
spend OpenAI tokens. Those Codex passes are **ask-first** under the money rule.
You are the one executing `/review`'s instructions, so no config change is
needed: when its Codex preflight says Codex would run — `CODEX_MODE: ready`
in current gstack, `CODEX_AVAILABLE` with `OLD_CFG` not `disabled` in older
versions — ask the user once whether to spend on Codex for this run; if
declined, do not run the `codex exec` / `codex review` commands and proceed
exactly as the section's disabled/unavailable branch describes (Claude
adversarial subagent still runs). Record
the Codex state and the user's answer in the ledger. Never flip the global
`codex_reviews` config on the user's behalf.

`CODEX_MODE: not_authed` can be a false negative: gstack's preflight only
recognises a Codex login, so a Codex CLI configured for a custom provider
(e.g. `model_provider = "azure"` with an API key in the environment) reads as
unauthenticated while working fine. When the preflight says `not_authed` but
`${CODEX_HOME:-$HOME/.codex}/config.toml` sets a `model_provider`:

1. **Ask first** — fold it into the one Codex question above: the probe is
   itself a billed call on the user's provider. Declined ⇒ skip the probe and
   the passes.
2. **Probe the model the passes will use**, bounded, so a working default
   model cannot hide an unusable review model and a stalled endpoint cannot
   hang the pipeline:

   ```bash
   source ~/.claude/skills/gstack/bin/gstack-codex-probe 2>/dev/null
   if ! command -v _gstack_codex_timeout_wrapper >/dev/null 2>&1 \
      || ! command -v _gstack_codex_select_model >/dev/null 2>&1; then
     echo "CODEX_PROBE: broken_install (gstack-codex-probe helper not found)"
   elif _gstack_codex_select_model exec; then
     # gstack's own resolver: GSTACK_CODEX_MODEL, then the model in config.toml,
     # then gstack's default, so the probe tests the model the passes will use.
     echo "CODEX_MODEL: $_GSTACK_CODEX_SEL ($_GSTACK_CODEX_SEL_SRC)"
     _gstack_codex_timeout_wrapper 120 codex exec -s read-only \
       -c "model=\"$_GSTACK_CODEX_SEL\"" "Reply with exactly: PONG" < /dev/null
   fi
   ```

3. Answers `PONG` ⇒ treat Codex as `ready` and run the passes with that
   provider and model. `CODEX_PROBE: broken_install`, or exit code 126/127 ⇒
   treat it as `broken_install` (gstack's branch: reinstall advice, no model
   advice). Any other error, timeout or text ⇒ `model_unusable`: skip the
   passes, tell the user to set `GSTACK_CODEX_MODEL` (or `model` in config.toml)
   to a deployment their provider serves. A `CODEX_MODEL: invalid` line from the
   resolver means the same: no call was made.

Record the probe command, model and result in the ledger either way.

**If `/review` is unavailable** (gstack is not installed, the Skill tool cannot
load `review`, or its preamble fails), do not skip the correctness step. Run the
in-tree fallback, `/basic-review <diff-ref>...HEAD`, instead:
1. **Audit:** invoke `/basic-review` with the diff ref Step 1 resolved. It is
   read-only and reports findings as `file:line` with severity.
2. **Fix:** for each CRITICAL/HIGH (and cheap MEDIUM) finding, root-cause it
   (`/debug`), write the failing test first (`/tdd`), apply the smallest fix,
   and commit it atomically, naming `basic-review` and the finding.
3. **Verify:** run `/basic-review` once more on the same range; a CRITICAL
   still reported is an UNFIXED blocker.

Name both in the ledger row's first cell, `/review (fallback: /basic-review)`,
and put the reason `/review` was unavailable in its evidence. The row's status
is the fallback's result (RAN-CLEAN, FIXED(n) or UNFIXED), never SKIPPED: the
correctness check ran.

**Quality — `/clean-code`.** After correctness is green and committed, run
`/clean-code <diff-ref> [--scope <paths>]` with the diff ref and scope this
pipeline resolved. It audits KISS / DRY / SOLID / YAGNI against `ENGINEERING_STANDARDS.md`,
applies the smallest safe refactor per finding under a green suite
(characterization test first where none exists), commits each atomically,
re-audits, and reverts a failed refactor with `git checkout` on only the files
it touched. Its findings left UNFIXED are warnings here, not blockers — quality
debt ships with a note; bugs don't.

`/code-review ultra` (deep multi-agent cloud review) is **billed** — when a
`/review` finding is high-stakes (payments, auth, data loss, concurrency), ask
the user whether to launch it. Do not launch it unasked. Claude Code's
built-in `/code-review` and `/simplify` are not part of this step: `/review`
already covers correctness here, and an optional extra pass would have no
ledger row.
