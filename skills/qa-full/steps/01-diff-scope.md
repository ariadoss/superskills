## Step 1: Establish the diff scope and a clean tree

1. Detect the base branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`,
   else `git symbolic-ref refs/remotes/origin/HEAD`, else fall back to `main`/`master`.
2. If `$ARGUMENTS` names a base branch or `--scope <paths>`, use it.
3. Resolve the **diff ref**: `git fetch origin <base>` and use `origin/<base>`
   when that ref exists, else local `<base>`. This is what `/review` and `/qa`
   diff against too, and it stays correct after Step 1.5 creates a working
   branch (local `<base>` would then equal HEAD and the set would be empty).
   Compute the changed-file set: `git diff --name-only <diff-ref>...HEAD -- <scope paths>`
   (drop the `--` part when no `--scope` was given) plus
   uncommitted changes (`git status --porcelain`). This set drives every
   trigger below. **Fix commits made by this pipeline extend the set** — later
   steps and the final pass (Step 10) audit the fixes too.
4. **Clean-tree precondition.** The fixers (`/qa`, `/design-review`) need each
   fix to be its own atomic commit, so they stop on a dirty tree. Handle it
   once, here: if `git status --porcelain` is non-empty, ask the user (via
   AskUserQuestion) whether to **commit the in-progress work now** (recommended
   — a descriptive commit so the feature is preserved before fixes land) or
   **stash it**. Do not proceed with a dirty tree.
   **Ask this together with the rest, in ONE AskUserQuestion call** (item 4a).
4a. **Batch every question now.** Put every open yes/no into the same
   AskUserQuestion call so the user answers once and the pipeline then runs
   unattended: the dirty-tree choice above; `/pentest` authorization (skip when
   `CLAUDE.md` already states it); Codex passes for `/review` (skip when
   `CLAUDE.md` already decides it); `/code-review ultra` (default no); the dev
   URL or start command when browser checks are triggered and none is known;
   and the test/build commands when Step 2 cannot determine them from
   `CLAUDE.md` or the project manifest. An unanswered or declined item resolves
   to its safe default (SKIPPED(reason), no spend) and the run continues. After
   this call, Steps 2 to 10 ask the user nothing.
5. **Never run on the base branch itself.** The sub-skills' diff-aware modes
   (`/review`, `/qa`, `/design-review`) key off "current branch ≠ base" and
   diff against `merge-base(origin/<base>, HEAD)`. If `git branch
   --show-current` equals the base and there are unpushed commits, create a
   working branch at HEAD first — `git switch -c qa-full/<base>-<YYYY-MM-DD>`
   (reuse it if a same-day branch already exists from an aborted run) — and
   run the whole pipeline there. Step 10 folds it back: fast-forward the
   base to the working branch (`git switch <base> && git merge --ff-only
   qa-full/...`) and delete the working branch. No history is rewritten; the
   base just gains the fix commits. If there are no unpushed commits either,
   there is nothing to QA.
6. Record at the top of the report: base branch, diff ref, working branch (if
   created), commit range, changed-file count, and the HEAD SHA before any fixes.

If there is no diff against base, stop and say so — there is nothing to QA.
