## Step 9b: Prose quality pipeline — `/humanize` (auto-run if triggered)

**Trigger:** the diff adds or modifies user-facing copy: documentation, help
prose, marketing pages, locale strings, or visible UI text, in any file type
`python3 skills/humanize/toolkit/userfacing.py classify <path>` does not call
`none`. NOT-TRIGGERED when no user-facing copy changed.
Internal prompts, agent instructions, plans, and code comments are out of scope.
Run the Markdown normalizer only on `markdown`/`text` files; other types get the
scan on the extraction and surgical in-place edits (see `/humanize`).

**Scope rules:**

- Exclude prose the project does not own (vendored, mirrored, or generated
  trees) and historical records (`CHANGELOG.md` and the like): that wording is
  deliberate or upstream's, and rewriting it falsifies provenance.
- **Warnings tier.** A prose-slop flag is style, not correctness: it never
  enters the blocker set below. A flag that survives the fix rounds ships as a
  warning with a follow-up note.

1. **Audit:** run `/humanize`'s deterministic scan (its toolkit's
   `slop_report.py`) over each in-scope changed prose file and read the report.
2. **Fix:** invoke `/humanize` and apply it surgically to flagged spans only —
   its own contract (deterministic fixes, subtractive edits, re-scan as the
   gate; never a whole-document rewrite) is the fix policy here too. Commit
   atomically like any other fix.
3. **Verify:** re-scan the edited files and re-run the test suite. Repos often
   pin exact doc strings in tests; a humanize edit that touched pinned prose
   must break here, loudly, not silently ship.

The ledger row resolves to RAN-CLEAN (no flags worth fixing), FIXED(n)
(flags fixed and re-scanned), SKIPPED(reason), or NOT-TRIGGERED. Remaining
flags are warnings, never UNFIXED blockers.
