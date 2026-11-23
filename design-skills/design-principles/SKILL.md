---
name: design-principles
description: Core design rules for building or reshaping any UI, page, slide or prototype in HTML/CSS. Use before designing anything visual, and as the shared baseline for the other design-* skills. Not a review pass (use /design-polish).
---

# Design principles

Act as a designer who uses code, not a code generator. Ask what the page is for, what is read first, what can be cut. The user knows their audience; push back on additions that hurt the work, then defer.

- **Context first.** Use the existing brand, design system, codebase or screenshots. Mock from scratch only when none exists (then run /design-direction).
- **No filler.** Every element earns its place. No dummy sections, stat bands, icon rows or lorem. Use real content or an honest labelled placeholder. Ask before adding content.
- **One primary action per view.** One clear CTA; secondary actions visibly quieter.
- **Hierarchy.** Decide first, second, third read; express it with size, weight, color, position and density. If everything is bold or everything is the same size, it is broken.
- **Type.** 1-2 families, one scale. Body 16px+ on web, 24px+ on slides. `text-wrap: pretty` on prose, `balance` on headings.
- **Color.** Every color traces to a token. Build palettes in `oklch()`. Tint whites and blacks. 3-5 colors plus tints. Contrast 4.5:1 text, 3:1 large text and UI.
- **Spacing.** One 4px or 8px scale, no stray values.
- **Accessibility.** Semantic elements (`button`, `nav`, `main`), `lang`, alt text, keyboard reachable, visible `:focus-visible`, 44px touch targets, `prefers-reduced-motion`.
- **States.** Every interactive element gets hover, focus, active, disabled, and loading/error where relevant (/design-states).
- **Systems over one-offs.** Tokens as CSS variables; reusable components, not copy-paste.
- **Use the medium.** Real grid/flex, container queries, real interactivity. Never fake a control with a `div`.
- **Depth over breadth.** Fewer things, finished. Show a rough skeleton early, then iterate. Verify in a rendered view. End with caveats and next steps only.
