---
name: app-store-screenshots
description: Generate App Store and Google Play marketing screenshots using Next.js. Use when the user wants to create app store screenshots, marketing screenshots, or device mockup exports for iOS, iPad, or Android.
metadata:
  author: ParthJadhav
---

# App Store & Google Play Screenshots Generator

Build a Next.js application for creating exportable App Store and Google Play marketing screenshots across multiple device types and platforms.

## Core Philosophy

"Screenshots are advertisements, not documentation. Every screenshot sells one idea."

## Key Capabilities

Supports rendering screenshots for:
- **iPhone** (portrait with mockup.png frame)
- **iPad** (portrait, CSS-rendered frame)
- **Android Phone** (portrait, CSS-rendered)
- **Android Tablets** (7" and 10", portrait + landscape)
- **Google Play Feature Graphic** (1024×500 banner)

## Core Workflow

**Before coding, gather these inputs:**

1. Screenshot image locations
2. App icon PNG path
3. Brand colors (accent, text, background)
4. Typography selection
5. Feature prioritization
6. Desired slide count
7. Visual style direction
8. Target platform(s)
9. Language localization needs
10. Theme customization preferences

## Technical Foundation

Uses `html-to-image` for export, not `html2canvas`, due to superior CSS handling.

Critical implementation patterns:

- **Pre-load images as base64 data URIs** to prevent non-deterministic fetch failures
- **Double-call export technique** (first warm-up, second production)
- **Device-agnostic width formulas** that scale proportionally across canvas sizes
- **Slide factory pattern** for reusable device-specific templates

## Canvas Dimensions

Design at largest resolution per category; exports scale down automatically:

| Device | Dimensions |
|--------|-----------|
| iPhone | 1320×2868px |
| iPad | 2064×2752px |
| Android phone | 1080×1920px |
| Android tablets (portrait) | 1200×1920 and 1600×2560 |
| Android tablets (landscape) | 1920×1200 and 2560×1600 |
| Google Play Feature Graphic | 1024×500px |

## Layout Patterns

- **Portrait phones**: device centered, slightly lower than canvas center
- **Landscape tablets**: caption occupies left 34%, device on right with negative space
- **Visual variation**: layouts differ between adjacent slides to avoid templated feel

## Architecture

The entire generator lives in a **single `page.tsx`** with:

- Canvas dimensions matching the largest required resolution per device
- Width formula functions that scale device frames proportionally
- Device components using CSS frames (Android, iPad) or PNG mockups (iPhone)
- Slide factories accepting a device component and returning reusable slide definitions
- Pre-loaded image cache converting all assets to base64 data URIs

## Export Strategy

```typescript
// Double-call pattern — first primes fonts/images, second produces clean output
async function exportSlide(element: HTMLElement): Promise<string> {
  await toPng(element); // warm-up call
  return toPng(element); // production call
}
```

This prevents blank or transparent regions common in single-pass exports.

## Additional Features

- Localization with RTL text direction support
- Theme presets
- Bulk export with numbered filenames for correct sorting

## Implementation Notes

- Never use `html2canvas` — use `html-to-image` instead
- Pre-convert all images (screenshots, icon) to base64 before rendering
- Landscape tablet slides exclusively use caption-left + device-right composition
- Avoid repeated layouts on adjacent slides
