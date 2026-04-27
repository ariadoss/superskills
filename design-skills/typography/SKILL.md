---
name: typography
description: Apply professional typographic rules to screen-based UI. Use when generating any UI with visible text, auditing typography violations, or when the user asks about font sizing, line height, spacing, quotes, dashes, or text formatting in interfaces.
metadata:
  author: bencium
---

# UI Typography

Professional typographic rules for screen-based interfaces. Based on Matthew Butterick's *Practical Typography*.

## Mode

**Enforcement** — when generating ANY UI with visible text, apply every rule automatically and silently.

**Audit** — when reviewing existing code, flag violations.

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

---

**Attribution:** Rules distilled from *Practical Typography* by Matthew Butterick (practicaltypography.com).
