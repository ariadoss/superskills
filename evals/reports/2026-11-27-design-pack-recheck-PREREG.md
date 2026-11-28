# Design pack recheck: protocol and thresholds (written before any run)

Why: on 2026-11-27 the repo owner looked at the rendered pages from the 2026-11-21 eval, blind. The `new` arm was top pick on 0 of 3 build tasks he ranked and last on one; all fix outputs were weak. The source-only judge had reported `new` equal to `up`. The human read of rendered pages is the ground truth; the earlier report's system numbers are withdrawn.

Change under test: rewritten `design-principles`, `design-direction`, `design-slop-check`, plus edits to `design-hierarchy` and `design-polish` (whole page, product shown working, specific labelled content, brand kit, render-and-look step).

## Dimensions (binary, positive class FAIL)

- **pick** (human, blind, per task): FAIL if `new` is not the owner's top pick or a stated tie for top.
- **last** (human, blind, per task): FAIL if `new` is the owner's bottom pick.
- **defect** (from a 1280px and a 375px screenshot of each `new` page): FAIL if any of: a placeholder box or broken image in the first screen, a headline not the largest text, horizontal overflow at 375px, a section with a heading and no content, or a build page shorter than two desktop screens.

No LLM judge is used for pick or last, so there is nothing to calibrate: the human is the key. Defect is read off screenshots by the session agent and listed per page with the screenshot path so it can be checked.

## Cases

Arms `none`, `up`, `new`; generator is a Sonnet general-purpose subagent with the 2026-11-21 prompt wording, so the stored `none` and `up` pages stay comparable.

- Seen (the rewrite was informed by these; a retest, not a fresh sample): B1 to B4, F1, F2. Only `new` is regenerated.
- Held out (new briefs, all three arms generated): B5 language-tutor marketplace landing, B6 usage-priced developer API landing, B7 bakery pre-order page with a form, F3 a time-tracking pricing page with real content and poor styling (`evals/design-pack/fixture3.html`).

F1 and F2 fixtures hold almost no content, so they test content repair as much as design. F3 is the fairer fix case.

## Thresholds (fixed now)

1. defect: 0 of 10 `new` pages FAIL.
2. Held-out, 4 tasks: pick PASS on at least 2, last FAIL on 0.
3. All 10 tasks: pick PASS on at least 5, last FAIL on at most 1.

n is small; results are reported as counts. If a gate fails, reword once (wording before structure) and rerun the failing tasks once.

## Round 1 result and the one reword (2026-11-27, before any human pick)

Round 1 `new` pages, session-agent screenshot check: defect FAIL on 1 of 10 (F2 settings page scrolls sideways at 375px, 450px wide). Gate 1 failed. Not in the defect list but seen on every page: 10 of 10 chose the same display face, and most shared one layout (headline left, card right, three numbered steps). Only 1 of 10 generators rendered the page before finishing.

Reword, wording only: design-direction gains a three-candidate font step and a layout axis; design-slop-check gains row 13 (the template layout); design-principles makes the render step mandatory and names phone overflow. Thresholds unchanged. All ten `new` pages are regenerated once (the reword touches every page); round 2 is what the owner sees.

Tooling note added to design-principles after B1 to B6 of round 2 had started (two generators misread a clipped headless-Chrome phone screenshot): how to render at 375px. B7, F1, F2, F3 of round 2 read it; B1 to B6 did not.

## Round 2 defect check and a second reword (outside the one-reword allowance)

Round 2 `new` pages: defect FAIL on 1 of 10 again, the same task (F2 scrolls sideways at 375px, 472px wide). Gate 1 failed twice. Cause this time: a table with a minimum width inside a grid child that could not shrink. The F2 generator did not render at 375px.

A second reword was made anyway, because the fix is a plain CSS fact worth having in the skill: design-principles "Systems" now says grid and flex children need `min-width: 0`. F2 alone is rerun (run `F2-new3`). This is a third attempt on F2 and is reported as such, not as a pass of gate 1.

F2 third attempt (`F2-new3`): 375px wide at 375px, no sideways scroll. Shown to the owner as the F2 `new` page.

Read strictly, the "headline not the largest text" rule also fails on round-2 pages where a price figure lower on the page is set larger than the h1: B1 (112px price vs 92px h1 at desktop), and at 375px only B4 (44 vs 41.7), B5 (48 vs 44) and F1 (48 vs 40). In every case the h1 is the largest text in the first screen. The rule was meant for the first screen but was not written that way, so these are recorded as FAIL by the letter: gate 1 stands at 5 of 10 FAIL in round 2 (F2 overflow plus these four), not 0.
