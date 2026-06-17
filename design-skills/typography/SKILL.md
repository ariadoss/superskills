---
name: typography
description: Apply professional typographic rules to screen-based UI, including font selection that escapes the generic AI monoculture (no Inter/Roboto/Geist/Fraunces) using only open-licensed, free-for-commercial fonts. Use when generating any UI with visible text, choosing or replacing fonts, avoiding generic/AI-looking type, auditing typography violations, or when the user asks about font sizing, line height, spacing, quotes, dashes, or text formatting.
metadata:
  author: bencium
---

# UI Typography

Professional typographic rules for screen-based interfaces. Based on Matthew Butterick's *Practical Typography*.

## Mode

**Enforcement** — when generating ANY UI with visible text, apply every rule automatically and silently.

**Audit** — when reviewing existing code, flag violations.

---

## Font Selection

Font choice is the single biggest signal of whether an interface looks designed or auto-generated. Two filters must **both** pass: the face must be **non-generic** (escape the AI monoculture) and it must be **open-licensed** (free for commercial use). These are independent — many open fonts are also the most overused.

### Register first

- **Product UI** (dashboards, admin panels, tools): system stacks and familiar sans are legitimate. One well-tuned family carries the whole UI. Fixed `rem` scale, 1.125–1.2 ratio. Don't over-brand a utility.
- **Brand / marketing / content**: the design *is* the product. Generic type here reads as mediocre. Run the selection procedure below.

### Selection procedure (brand register — never skip)

1. **Voice words.** Write three concrete, physical-object brand-voice words — "warm and mechanical and opinionated", not "modern" or "elegant".
2. **Reject your reflex.** List the three fonts you'd reach for first. If any appear on the ban list below, drop them — they're training-data defaults and create monoculture.
3. **Search by physical object.** Browse a real **open-license** catalog with the voice words in mind. Find the face for the brand as a thing: a 1970s terminal manual, a fabric label, a concert poster, a museum caption. Reject the first thing that "looks designy".
4. **Cross-check.** "Elegant" is not necessarily serif. "Technical" is not necessarily sans. "Warm" is not Fraunces. If the final pick matches your original reflex, start over.

### Ban list — overused faces (do not use as primary)

Two waves of monoculture. Reflex-reject all of these:

- **Older**: Inter, Roboto, Open Sans, Lato, Montserrat, Arial, Helvetica
- **Newer** (the AI-skill / Vercel / GitHub default wave): Fraunces, Geist, Mona Sans, Plus Jakarta Sans, Space Grotesk / Space Mono, Instrument Sans / Instrument Serif, DM Sans / DM Serif, Outfit, Recoleta, Newsreader, Lora, Crimson, Playfair Display, Cormorant, Syne, IBM Plex (any)

Also reject the **editorial-typographic *lane***, not just the fonts: oversized italic serif headline + tiny uppercase tracked labels + ruled separators + monochrome restraint. It reads as taste in isolation but is now the universal AI landing-page hero. Use it only for a brief that is *literally* editorial.

### Open-license only — never recommend a font that needs a paid license

Pull exclusively from free, commercially-usable sources (SIL OFL / Apache / ITF Free License):

- **Google Fonts** — OFL/Apache. Use the *deep* catalog, not the front-page defaults (which are the overused faces above).
- **Fontshare** (Indian Type Foundry) — free for commercial use; rich source of distinctive, non-monoculture faces.
- **Velvetyne**, **The League of Moveable Type**, **Collletttivo**, **Open Foundry** — open-source type.

If a face you want requires a commercial license (Klim, ABC Dinamo, Pangram Pangram, Adobe Fonts subscription faces, etc.), **do not use it** — find the closest open-licensed equivalent and note the substitution. Never replace one default with a new default: the goal is a face that fits *this* brand, not a fresh monoculture.

### Pairing & hierarchy

- You often need only **one** family in multiple weights — cleaner than two competing faces. Add a second only for genuine contrast (serif + sans, geometric + humanist).
- Never exceed 2–3 families. Never use a decorative/display face for body text.
- Build hierarchy with a modular scale (≥1.25 ratio for brand display; 1.125–1.2 for dense product UI). Flat scales (sizes 1.1× apart) read as uncommitted.

---

## Character Standards

### Quotes & Apostrophes

Always use curly (typographic) marks:
- Double quotes: `"` `"` (`&ldquo;` `&rdquo;`)
- Single quotes: `'` `'` (`&lsquo;` `&rsquo;`)
- Apostrophes: `'` (curves **downward**, like a comma)

**Critical JSX warning:** Unicode escape sequences (`\u2019`, `\u201C`, etc.) do NOT work in JSX text content. Use actual UTF-8 characters or JSX expressions.

```jsx
// ❌ Wrong
<p>It\u2019s working</p>

// ✅ Correct
<p>It's working</p>
```

### Dashes

Three distinct characters — never substitute:
- **Hyphen** `-` — compounds, phone numbers (`well-designed`)
- **En dash** `–` (`&ndash;`) — ranges (`pages 10–20`, `2020–2024`)
- **Em dash** `—` (`&mdash;`) — breaks in thought, parenthetical statements

### Other Marks

- **Ellipsis**: `…` (`&hellip;`) — never three separate periods
- **Multiplication**: `×` (`&times;`) — never letter x
- **Minus**: `−` (`&minus;`) — never hyphen in math
- **Copyright/trademark**: `©` `™` `®` — always real symbols

---

## Spacing Rules

- **One space** after punctuation — never two
- Use `&nbsp;` to prevent line breaks:
  - Before numeric references (`page&nbsp;12`)
  - After abbreviations (`Dr.&nbsp;Smith`)
  - Between measurements (`10&nbsp;px`)

---

## Text Formatting

- **Bold OR italic** — never both simultaneously
- Sans serif: bold works best; italic barely stands out
- **Never underline** — reserved for hyperlinks
- **All-caps text** requires 5–12% letterspacing (`letter-spacing: 0.08em`)
- Kerning must always be enabled (`font-kerning: normal`)

---

## Layout Standards

### Line Length

45–90 characters per line. The "alphabet test": 2–3 lowercase alphabets fit per line.

```css
.prose {
  max-width: 65ch;
}
```

### Line Spacing

120–145% of point size.

```css
body { line-height: 1.35; }
```

### Body Text First

Set typography before designing other elements.
- Print: 10–12pt
- Web: 15–25px

### Headings

- Maximum 3 levels
- Space above > space below
- Bold preferred over italic
- Don't use heading levels for visual style — use them for semantic hierarchy

### Lists & Tables

- Use semantic markup
- Remove borders from tables; keep only a thin rule under the header row
- Consistent padding replaces visual dividers

---

## Responsive Typography

The rules don't change with screen size. Same line length, line spacing, hierarchy.

```css
body {
  font-size: clamp(16px, 2.5vw, 20px);
}

.content {
  max-width: min(65ch, 100% - 2rem);
}
```

Always use `max-width` on text containers. Use `clamp()` for fluid scaling.

---

## Quick Reference: Common Violations

| Wrong | Right | Rule |
|-------|-------|------|
| `"Hello"` | `"Hello"` | Curly quotes |
| `It's` | `It's` | Curly apostrophe |
| `2020-2024` | `2020–2024` | En dash for ranges |
| `...` | `…` | Real ellipsis |
| `10 x 20` | `10 × 20` | Multiplication sign |
| `font-style: italic; font-weight: bold` | Pick one | Never both |
| `text-decoration: underline` | Remove | Only for links |
| Line height 1.0 | Line height 1.35 | 120–145% |
| Width: 100% on text | `max-width: 65ch` | Line length |
| Inter / Roboto / Geist / Fraunces as primary | Open-license non-monoculture face | Font selection |
| Sizes 14/15/16/18px (muddy) | Fewer sizes, ≥1.25 ratio | Flat hierarchy is an AI tell |
| Italic serif hero + uppercase eyebrow | Roman headline, integrated kicker | Editorial-lane AI tell |
| All-caps body paragraph | Caps for short labels only | All-caps body is an AI tell |
| Gradient text on headings | Solid color | Gradient text is an AI tell |

---

**Attribution:** Rules distilled from *Practical Typography* by Matthew Butterick (practicaltypography.com).
