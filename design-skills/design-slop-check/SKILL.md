---
name: design-slop-check
description: Detect and fix the visual tropes that make UI look AI-generated or templated (rainbow gradients, emoji, left-border cards, default fonts, pure white and black, off-scale spacing, the cream-serif-terracotta house look). Use on a built page or stylesheet. Not a live-browser review (use /design-review).
---

# Design slop check

Slop is anything that reads as default rather than chosen: a templated look, or a page too thin and vague to belong to anyone. Read the file and its CSS so you see real values, and look at a render if you can. Report every hit with confidence and severity; fix directly. Removing a trope is half the fix: put something chosen in its place.

| # | Reach for | Detect and replace |
|---|---|---|
| 1 | Flat color, or a subtle on-tone two-stop gradient | 3+ color or purple-pink style gradients on heroes, buttons, large surfaces |
| 2 | No emoji unless the brand uses them or they carry status | Emoji on headlines, buttons, list items. Use one real icon set or type |
| 3 | Cards separated by shadow, thin border or background | `border-left: 4px solid` + large radius as the default card. Keep it for alerts and status only |
| 4 | The product built in code, simple flat drawings of objects or patterns in brand colors, one icon set, real photos | A placeholder box in the first screen or larger than a card; a broken or missing `<img>`; drawn people, faces, hands; blob art |
| 5 | Fonts chosen for tone, named and loaded | Silent Inter, Roboto, Arial or a bare system stack. With no brand font, choose a named one, load it, and say which |
| 6 | Tinted whites and blacks | Pure `#fff` background with pure `#000` text |
| 7 | Every color from a token or `oklch()` ramp | Near-identical shades invented inline |
| 8 | 4px or 8px spacing scale | `7px 15px`, `18px`, `13px` |
| 9 | A direction taken from the subject (/design-direction) | Cream background + serif display + italic accent word + terracotta together by reflex. Any one alone can be right |
| 10 | Copy that says what it does, for whom | One-word feature cards, "made easy", "all-in-one", "powered by AI" with no mechanism. Rewrite it specific; do not just restyle it |
| 11 | A page with the sections a visitor needs to decide (/design-principles) | A hero plus one card row and nothing else; a section that is only a heading; a headline smaller than the text under it |
| 12 | A first screen that shows the product or subject working | An idle mockup with no telling detail; decoration where the product should be |
| 13 | A first screen and section layouts composed for this subject | Split hero with a floating card, one highlighted headline word and a 01/02/03 three-step row, all together by reflex |

When fixing an existing page, rows 10 to 13 count as much as rows 1 to 9: a clean stylesheet around empty content is still an empty page. Keep the page's facts and intent, and write what is missing.

Finish with: hits by rule, fixes made, content you wrote and defaults you picked (so the user can override), open questions.
