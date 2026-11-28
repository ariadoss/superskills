# Design pack recheck: results (2026-11-27)

Protocol and thresholds: `2026-11-27-design-pack-recheck-PREREG.md`, written before any run. This report replaces the system numbers in `2026-11-21-design-pack-eval.md`, which a blind human look at the rendered pages contradicted.

## What was run

Ten tasks, three arms (`none`, `up`, `new`), one Sonnet subagent per page. Six tasks were seen before the rewrite (B1 to B4, F1, F2; only `new` regenerated). Four were held out (B5 tutor marketplace, B6 email API, B7 bakery pre-order, F3 pricing-page fix; all arms generated). Every page was screenshotted at 1280px and 375px. The owner saw all ten tasks in a shuffled blind A/B/C page.

## Gate 1, defect (positive class FAIL, threshold 0 of 10)

Failed.

- Round 1: 1 of 10 FAIL (F2 scrolls sideways at 375px).
- Round 2, after the one allowed reword: 5 of 10 FAIL. F2 overflowed again (472px wide at 375px). Four pages set a price figure below the first screen larger than the h1: B1 at desktop, and B4, B5 and F1 at 375px only. The h1 is the largest text in the first screen on all four; the rule as written does not say "first screen", so they count.
- A second reword outside the allowance (grid and flex children need `min-width: 0`) and a third F2 run produced a page with no overflow. That is a third attempt, not a pass.

No `new` page in round 2 had a placeholder or broken image in the first screen, a heading-only section, or a build shorter than two desktop screens.

## Gates 2 and 3, pick and last (human, blind)

Not scored. The owner looked at the round-2 comparison and gave one overall verdict, "Rewritten design-* skills looks great", without per-task rankings. That is a positive read of the `new` arm, and it is the basis for shipping, but the per-task counts the thresholds call for were not collected, so gates 2 and 3 are neither passed nor failed.

For contrast, on the 2026-11-21 pages the same owner ranked `new` top on 0 of 3 build tasks and last on one.

## Open failure classes

- **Display-font sameness.** 10 of 10 round-1 pages chose Bricolage Grotesque; 8 of 10 in round 2 after the three-candidate step. One `up` page chose it too, so it is a generator default the wording only dents.
- **Phone render skipped.** Most generators rendered at desktop only, although the skill calls the step mandatory. Headless Chrome's roughly 500px minimum window width misled two of them; the skill now says how to render at 375px.
- **Large price figures.** A price set larger than the headline, usually on phones.

## Limits

- One page per arm per task; a single page is an example, not a rate.
- The defect check was read off screenshots by the session agent, with a DOM measurement for overflow and text size.
- F1 and F2 start from nearly empty fixtures, so they test content writing as much as design. F3 is the fairer fix case.
- The seen tasks are a retest, not a fresh sample.
- Generated pages and screenshots lived in a session scratch folder and are not in the repo.
