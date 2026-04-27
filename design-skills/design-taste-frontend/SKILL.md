---
name: design-taste-frontend
description: Senior UI/UX engineering system that enforces metric-based design rules, strict component architecture, CSS hardware acceleration, and balanced design engineering. Use when building premium frontend interfaces, dashboards, or SaaS UIs. Combats generic AI design patterns.
metadata:
  author: Leonxlnx
---

# Design Taste Frontend — High-Agency UI/UX Engineering System

A comprehensive frontend architecture guide establishing baseline configurations and engineering directives for premium interface design.

## Core Configuration Dials

Three primary dials (adjustable per request):

| Dial | Default | Range | Effect |
|------|---------|-------|--------|
| **Design Variance** | 8 | 1–10 | How distinctive vs. conventional the design is |
| **Motion Intensity** | 6 | 1–10 | Amount and complexity of animations |
| **Visual Density** | 4 | 1–10 | Information density (4 = comfortable) |

Users can override via explicit requests ("make it more minimal", "less animation").

## Architectural Requirements

- **Framework**: React/Next.js with Server Components as default
- **Styling**: Tailwind CSS for 90% of styling coverage
- **Viewport**: `min-h-[100dvh]` not `h-screen` (prevents iOS Safari layout issues)
- **Dependencies**: Always verify in `package.json` before importing

## Design Engineering Directives

### Typography
- Avoid Inter for premium contexts — choose distinctive alternatives
- Never generic system font stacks for display text
- Establish typographic hierarchy before layout

### Color
- Maximum one accent color below 80% saturation
- No pure black (`#000000`) — use off-black (`#0a0a0a`, `#111111`)
- No purple/blue AI aesthetic gradients (most identifiable AI design fingerprint)

### Layout
- Reject centered Hero sections when Design Variance > 4
- Use asymmetric grids, not three equal columns for feature rows
- Bento grid layouts for dashboard-style content

### Motion
- Spring physics: `stiffness: 100, damping: 20` (Framer Motion)
- Staggered animations with `staggerChildren`
- Perpetual micro-interactions on dashboard cards (not on every click)

## Bias Correction — Anti-AI-Default Patterns

Combat common AI design defaults:
- Liquid Glass refraction effects for depth
- Magnetic micro-physics for interactive elements
- Motion that responds to cursor proximity without React state

## Performance Standards

- Animate exclusively via `transform` and `opacity` (GPU-accelerated)
- Grain/noise filters only on fixed, non-interactive `::before`/`::after` pseudo-elements
- Z-index strictly constrained (document z-index layers at component level)

## Strictly Forbidden

- Emojis anywhere in code, markup, or text content (replace with icon library)
- Pure neon glows or oversaturated accent colors
- Text-fill gradients
- Inter font for premium/display contexts
- Three-column equal card layouts as feature rows
- Generic placeholder names ("John Doe", "Acme Corp")
- AI startup terminology ("Nexus", "Streamline", "Elevate")
- Broken Unsplash image links

## The Bento 2.0 Dashboard Paradigm

Modern SaaS dashboards use five card archetypes:

1. **Intelligent Lists** — sortable, filterable, with status indicators
2. **Command Inputs** — search/filter bars with keyboard shortcuts
3. **Live Status** — real-time indicators with subtle pulse animations
4. **Wide Data Streams** — sparklines, mini-charts, trend indicators
5. **Contextual UI Focus** — detail panels that expand in-place

Each card type has perpetual micro-interactions using spring physics. Cards breathe — they're never static.

## Pre-Flight Checklist

Before delivering any UI:
- [ ] No pure black colors used
- [ ] No Inter font in display/hero contexts
- [ ] Animations use only transform/opacity
- [ ] Design Variance setting respected
- [ ] No emojis present
- [ ] No three-column equal-width feature grid
- [ ] Viewport uses dvh not vh
- [ ] Dependencies verified in package.json
