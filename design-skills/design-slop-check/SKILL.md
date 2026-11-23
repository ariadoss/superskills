---
name: design-slop-check
description: Detect and fix the visual tropes that make UI look AI-generated or templated (rainbow gradients, emoji, left-border cards, default fonts, pure white and black, off-scale spacing, the cream-serif-terracotta house look). Use on a built page or stylesheet. Not a live-browser review (use /design-review).
---

# Design slop check

Read the file and its CSS/tokens so you see real values. Report every hit with confidence and severity; fix directly. For each rule, prefer the default at write time and scan for the detections at review time.

| # | Default | Detect and replace |
|---|---|---|
| 1 | Flat color, or a subtle on-tone two-stop gradient | 3+ color or purple-pink style gradients on heroes, buttons, large surfaces |
| 2 | No emoji unless the brand uses them or they carry status | Emoji on headlines, buttons, list items; emoji bullets. Use a real icon set or type |
| 3 | Cards separated by shadow, thin border or background | `border-left: 4px solid` + large radius as a default card. Keep only for alerts and status; never on small success or note cards either (use a full border, tint or icon) |
| 4 | Real photos, brand assets, or a labelled placeholder (`product shot 1200x800`) | Invented SVG people, scenes, blob art |
| 5 | Font chosen for tone, named, confirmed | Silent Inter, Roboto, Arial, Fraunces, Playfair, bare system stack. Ask, do not swap one generic for another. When fixing a page and no brand font exists, still choose a named font, load it, and say which. A bare system stack counts as a hit |
| 6 | Tinted whites and blacks (`#FAFAFA` / `#1A1A1A`) | Pure `#fff` background with pure `#000` text |
| 7 | Every color from a token or `oklch()` ramp | Five near-identical blues invented inline |
| 8 | 4px or 8px spacing scale | `7px 15px`, `18px`, `13px` |
| 9 | A direction chosen for the brief | Cream background + serif display + italic accent word + terracotta/amber together without a brand reason (any one alone can be fine) |

Finish with: hits by rule, fixes made, defaults you picked (so the user can override), open questions.
