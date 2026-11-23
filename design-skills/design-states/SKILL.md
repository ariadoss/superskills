---
name: design-states
description: Add and check every interaction state (hover, focus, active, disabled, loading, error, empty, success) on a page or component. Use when UI feels dead, forms lack feedback, or before shipping interactive UI. Not a full accessibility audit (use /a11y).
---

# Design states

List every interactive element (links, buttons, inputs, selects, toggles, cards, rows, tabs, menus), then check each against what applies. Do not skip a state because the page is small:

- **Hover:** a visible change on every button, link, card, tab **and every input, select and textarea** (border or background shift), wrapped in `@media (hover: hover)`. Never the only cue.
- **Focus:** `:focus-visible` ring, at least 2px, 3:1 contrast, offset. Never `outline: none` without a replacement.
- **Active/pressed:** a small, fast response (scale or shade, 100-160ms).
- **Disabled:** lowered contrast, `not-allowed` cursor, the real `disabled` attribute, still readable. Every submit button gets a disabled style.
- **Loading:** spinner or skeleton, button locks, label says what is happening.
- **Error:** message beside the field, says what to fix, color is not the only signal (`aria-invalid`, `aria-describedby`).
- **Success/empty:** every form needs a visible success state after submit (inline message or confirmation panel), not only an error state. Empty states explain and offer the next step.
- **Motion:** transitions 150-250ms, only on `transform`/`opacity`/color; honor `prefers-reduced-motion`.

Use real elements (`button`, `a`, `input`), never `div` with `onclick`. Add missing states as CSS variables-driven rules, not one-offs. Report what was missing and added.
