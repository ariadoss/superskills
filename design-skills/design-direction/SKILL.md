---
name: design-direction
description: Commit to a concrete visual direction (type, color, density, shape, motion) when there is no brand or design system, before any high-fidelity work. Use for greenfield UI. Skip if a brand or system exists (use /design-system-extract instead).
---

# Design direction

1. **Confirm it is greenfield.** No brand guide, existing product, reference site or partial system. If any exists, use it and stop.
2. **Get the intent:** three adjectives, audience, industry, references (and what you like about them), off-limits looks. If unsure, propose **four directions** that do not share a palette family, each with background and accent hex, display and body fonts, one-line rationale. Make one deliberately unexpected.
3. **Commit on every axis** (vague words like "clean and modern" yield generic output):
   - **Type:** named fonts, weights, one scale, max 2 families. Do not default to Inter, Roboto, Arial, system stacks, Fraunces, Playfair or Georgia. Give a free alternative to any paid font.
   - **Color:** one brand color, at most one accent, semantic colors, a 5-10 step tinted neutral ramp, in `oklch()`.
   - **Density:** 4px or 8px scale; tight, normal or loose.
   - **Shape:** radius sharp (0-2), soft (4-8) or pill; one elevation system.
   - **Motion:** quiet, expressive or playful. Pick one.
   - **Imagery:** real photos, an icon set, or labelled placeholders. No hand-drawn SVG people or scenes.
4. **Avoid the house look.** Cream background + serif display + terracotta accent is the model default. Use it only for editorial, hospitality or portfolio work, and say why. Never on dashboards, fintech, health or developer tools by default.
5. **Write it down** as a comment block at the top of the file naming the direction and tokens, and define the tokens as CSS variables. Then build within it.
