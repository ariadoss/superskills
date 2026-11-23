---
name: design-system-extract
description: Pull design tokens and reusable components out of an existing codebase, site, screenshots or files into one documented system. Use before designing inside an existing brand, or to consolidate a messy UI. Not for choosing a new look (use /design-direction).
---

# Design system extract

1. **Gather sources:** CSS/Tailwind config, theme files, component folders, brand docs, screenshots. Read actual values.
2. **Tokens:** colors (group by role, merge near-duplicates), type families, scale and line heights, spacing, radii, shadows, breakpoints, motion durations. Record each value with where it came from. Flag conflicts and pick the dominant value.
3. **Components:** inventory each reusable piece (button, input, card, nav, modal, table...): variants, sizes, states, props, and the files that use it. Mark near-duplicates to merge and one-offs to leave alone.
4. **Output** one file (e.g. `DESIGN_SYSTEM.md` or CSS variables plus a short component list) the next design step can read. Tokens as CSS variables; no prose padding.
5. State what was inferred versus found, and what is missing.
