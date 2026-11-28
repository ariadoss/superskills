# Design pack eval protocol (written before the runs)

Question: do the concise `design-*` skills (arm `new`) produce pages as good as
Claude's originals (arm `up`), and better than no skill (arm `none`)?
Method: `/eval` (skills/eval). Positive class for every metric: **FAIL**.

## Dimensions (binary, judged per page from its source)

- **slop** FAIL if the page shows templated-AI tells: gradient hero or text,
  emoji used as icons, left-border accent cards, glow/blur decoration, a
  default font stack (Inter/Roboto/Arial/system only) with no chosen type, or
  pure #fff on #000.
- **hierarchy** FAIL if there is no single dominant heading and one primary
  action per view, or type sizes are near-flat so the eye has no path.
- **states** FAIL if any interactive element lacks hover or focus-visible
  styling, a form lacks an error or success state, or a control that can be
  disabled/loading has no such style.
- **honesty** FAIL if the page presents invented facts as real: made-up
  customer names or logos, fabricated statistics, awards, certifications,
  specific prices or testimonials not marked as placeholder. Clearly labelled
  placeholders (e.g. "Sample", "[price]") are PASS.

Boundary rulings, fixed in advance:
- Google Fonts links to a named non-default family count as a chosen font.
- A neutral palette with one accent is PASS for slop.
- Generic marketing claims with no number ("simple payroll") are PASS for
  honesty; any specific number, name or price not labelled placeholder is FAIL.
- A page with no form has no form-state requirement; links and buttons still
  need hover and focus.
- Judge sees source only. Rendering is not judged. This proved the weak point: on 2026-11-27 a blind human look at the rendered pages contradicted the source-only judge. Judge rendered pages (1280px and 375px screenshots, blind human pick); protocol in `evals/reports/2026-11-27-design-pack-recheck-PREREG.md`, held-out fix fixture `fixture3.html`.

## Grid (cases)

Task kind x domain, 6 cases:

| id | kind | domain |
|----|------|--------|
| B1 | build | B2B payroll landing (existing runs, 3 per arm) |
| B2 | build | clinic appointment booking, consumer, form-heavy |
| B3 | build | open-source CLI tool docs landing, developer audience |
| B4 | build | nonprofit donation page, emotional, one primary action |
| F1 | fix | flawed payroll page (`fixture.html`, existing runs) |
| F2 | fix | flawed account-settings page (`fixture2.html`) |

New runs: B2, B3, B4, F2 x arms {none, new, up} x 1 run = 12 pages.
Existing runs reused: B1 and F1, arms none/new/up, 3 each = 18 pages.
Total 30 pages x 4 dimensions = 120 labels. Existing pages are reused as
cases only; no case text is placed in any skill as an example.

Negative controls (selection): four prompts where a design skill must NOT be
chosen (rate limiter, SQL migration, README rewrite, regex), and four
near-misses that must route elsewhere (live-browser review, accessibility
audit, plan review, image generation).

## Judge

Fresh Sonnet subagent per batch, source only, arm hidden, temperature not
controllable in-session (stated limitation), JSON out. Rubric = this file's
dimensions and boundary rulings, verbatim, plus two worked examples.

## Answer key

Subset of 12 pages x 4 dimensions = 48 labels, spanning arms, kinds and all
four new domains. Labelled by the session agent from screenshots plus targeted
source reads, before seeing any judge output. LIMITATION: not an independent
human; same model family as generator and judge.

## Thresholds (fixed now)

Judge gate (on the 48 labels, FAIL positive): TPR >= 0.70, TNR >= 0.70, and
|TPR - TNR| <= 0.20. If it fails, sharpen the rubric wording once and re-judge;
if it still fails, system numbers are reported as unreliable.

System gate (per dimension, FAIL rate over the 30 judged pages):
- new fail rate <= up fail rate + 0.10
- new fail rate <  none fail rate
Gaps under 0.10 are reported as ties. Overall pass needs all four dimensions
on both lines, or the failing dimension is named and the skill text is
reworded (wording before structure) then re-run once.

Selection gate: 0/4 negative controls pick a design skill; >= 3/4 near-misses
route to the right neighbour.
