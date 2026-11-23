---
name: design-prototype
description: Build a clickable, interactive HTML prototype with optional live tweak controls (a floating panel for color, type, density, copy). Use when the user wants something they can click through or adjust live. Not for static mockups (use /design-variations).
---

# Design prototype

1. **Scope the flow.** List the screens and the one main path through them. Cut anything off that path.
2. **Build real interactions:** working navigation, form validation, open/close, selection, realistic state changes. Nothing faked with images. One state object drives the UI.
3. **Realistic data:** plausible names, numbers and edge cases (empty, long, error). No lorem.
4. **Cover states** with /design-states: hover, focus, disabled, loading, error, empty.
5. **Tweaks (only if asked or useful):** a small collapsible fixed panel exposing 3-6 controls that bind to CSS variables or state (accent color, type scale, density, dark mode, copy variant). Persist choices in `localStorage` inside try/catch. The panel must not cover the design; it hides cleanly.
6. **Keyboard and mobile:** full flow works by keyboard and at 375px wide.
7. Verify by running it. Report what is real and what is stubbed.
