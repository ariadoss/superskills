---
name: minimalist-ui
description: Create clean editorial-style interfaces with warm monochrome palette, typographic contrast, flat bento grids, and muted pastels. Use when the user wants minimalist design, editorial style, clean typography-driven UI, or "less is more" aesthetic.
metadata:
  author: Leonxlnx
---

# Minimalist UI Protocol

**Premium Utilitarian Minimalism & Editorial UI** — refined, document-style interfaces with deliberate constraints.

## Core Aesthetic

A high-contrast warm monochrome palette, bespoke typographic hierarchies, meticulous structural macro-whitespace, bento-grid layouts, and an ultra-flat component architecture.

**Mantra:** Every element must justify its existence. If it doesn't communicate, remove it.

## Typographic Foundation

### Font Selection

| Role | Options | Notes |
|------|---------|-------|
| **Body/UI** | SF Pro Display, Geist Sans, Switzer | Geometric sans-serif |
| **Headings** | Lyon Text, Newsreader, Playfair Display | Editorial serif, tight tracking |
| **Metadata/Mono** | Geist Mono, JetBrains Mono | Data, timestamps, labels |

**Never use**: Inter, Roboto, Open Sans — too generic.

### Typography Rules
- Off-black text: `#111111` (never pure `#000000`)
- Heading tracking: tight (`letter-spacing: -0.02em`)
- Body line height: 1.6–1.7
- Maximum 2 type sizes in any single component

## Color Palette

| Role | Value | Usage |
|------|-------|-------|
| **Canvas** | `#F7F6F3` | Warm off-white background |
| **Text primary** | `#111111` | Body text, headings |
| **Text secondary** | `#666666` | Labels, metadata |
| **Borders** | `#EAEAEA` | Card borders, dividers |
| **Accent** | Sparse pastel | ONE desaturated accent only |

Accent colors: pale red, pale blue, pale green, pale yellow — never saturated.

## Component Specifications

### Cards
```css
.card {
  border: 1px solid #EAEAEA;
  border-radius: 8px; /* never > 12px */
  background: #FFFFFF;
  padding: 1.5rem;
}

.card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06); /* ultra-soft, not harsh */
}
```

### CTAs / Buttons
```css
.btn-primary {
  background: #111111;
  color: #FFFFFF;
  border-radius: 6px;
  padding: 0.625rem 1.25rem;
  transition: opacity 0.15s ease;
}

.btn-primary:hover {
  opacity: 0.85; /* not scale, not color change — just opacity */
}
```

## Prohibited Elements

- No Inter/Roboto/Open Sans
- No Tailwind heavy shadows (`shadow-lg`, `shadow-xl`)
- No gradients (linear or radial)
- No neon or saturated accent colors
- No pill-shaped buttons
- **No emojis anywhere — not in code, markup, headings, or alt text**
- No glassmorphism
- No three-column equal feature grids

## Motion — Ultra-Subtle Only

```css
/* Entry animation */
@keyframes fade-in {
  from { opacity: 0; transform: translateY(4px); }
  to   { opacity: 1; transform: translateY(0); }
}

.card { animation: fade-in 0.2s ease-out; }

/* Hover */
.card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
```

Rules:
- Animate only `transform` and `opacity`
- Maximum 200ms duration for hover states
- No bouncing, spring physics, or overshooting in minimalist contexts

## Iconography

- Use single-weight, minimal icon sets (Phosphor Thin, Lucide)
- Icons at 16–20px, never larger in body content
- Icon + label always — never icon alone
- SVG preferred, no icon fonts

## Bento Grid

```css
.bento-grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: 1rem;
}

/* Cards span different column widths for visual rhythm */
.card-wide { grid-column: span 8; }
.card-narrow { grid-column: span 4; }
```

## Execution Protocol

1. Establish typographic hierarchy before any color decisions
2. Set spacing scale (base 4px or 8px)
3. Layout in grayscale first — no color until structure is right
4. Add single accent color last
5. Remove anything not earning its place

## Pre-Output Checklist

- [ ] No emojis
- [ ] No pure black (#000000)
- [ ] No generic fonts (Inter/Roboto/Open Sans)
- [ ] No heavy shadows
- [ ] No gradients
- [ ] Single accent color only, desaturated
- [ ] Cards use exactly `border: 1px solid #EAEAEA`
- [ ] Animations ≤ 200ms, transform/opacity only
- [ ] Mobile layout uses `w-full px-4 py-8`
