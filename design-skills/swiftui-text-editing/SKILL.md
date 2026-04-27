---
name: swiftui-text-editing
description: SwiftUI text styling and rich text editing patterns. Use when displaying styled text, building rich text editors, working with AttributedString, implementing TextEditor with formatting, rendering Markdown, or creating selection-based formatting controls in SwiftUI.
metadata:
  author: rshankras
---

# Styled Text Editing in SwiftUI

Patterns for displaying styled text and building rich text editors in SwiftUI.

## When This Skill Activates

Use this skill when the user needs to:
- Display styled text (bold, italic, colored, linked)
- Build rich text editors with formatting toolbars
- Work with AttributedString
- Implement TextEditor with selection-based formatting
- Render Markdown in SwiftUI
- Create custom text formatting definitions

## Decision Tree

```
What text task do you need?
|
+-- Display styled text (read-only)
|   +-- Simple modifiers -> Text("Hello").bold().foregroundStyle(.blue)
|   +-- Mixed styles -> AttributedString
|   +-- Markdown -> Text(try! AttributedString(markdown: "**Bold**"))
|
+-- Editable text
    +-- Plain text -> TextEditor(text: $text)
    +-- Rich/styled text -> TextEditor with AttributedString binding (iOS 18+)
    +-- With formatting toolbar -> iOS 18+ AttributedTextFormattingDefinition
```

## API Availability

| API | Minimum iOS | Notes |
|-----|------------|-------|
| `Text` modifiers (`.bold()`, `.italic()`) | iOS 13 | Read-only |
| `AttributedString` | iOS 15 | Rich text model |
| Markdown in `Text` | iOS 15 | Inline Markdown only |
| `TextEditor(text:)` | iOS 14 | Plain text editing |
| `TextEditor` with `AttributedString` | iOS 18 | Rich text editing |
| `AttributedTextFormattingDefinition` | iOS 18 | Custom formatting constraints |
| Text selection reading | iOS 18 | `textEditorSelection` |

## Text Styling Quick Reference

```swift
// Simple modifiers
Text("Hello world")
    .font(.headline)
    .bold()
    .foregroundStyle(.blue)
    .italic()

// AttributedString for mixed styles
var attributed = AttributedString("Hello world")
attributed[attributed.range(of: "Hello")!].font = .boldSystemFont(ofSize: 16)
attributed[attributed.range(of: "world")!].foregroundColor = .blue
Text(attributed)
```

## Rich Text Editor (iOS 18+)

```swift
struct RichTextEditor: View {
    @State private var text = AttributedString("Start typing...")
    @State private var isBold = false

    var body: some View {
        VStack {
            HStack {
                Button("B") { isBold.toggle() }
                    .bold(isBold)
            }
            TextEditor(text: $text)
        }
    }
}
```

## Markdown Support

```swift
// ✅ Works: inline Markdown
Text("**Bold**, _italic_, `code`, [link](https://apple.com)")

// ❌ Does not work in Text: block Markdown
Text("# Heading\n- List items\n> Blockquote")
```

**Text supports only inline Markdown:**
- ✅ Bold (`**`), italic (`_`), inline code (`` ` ``), links (`[]()`)
- ❌ Line breaks, block formatting, lists, tables, code blocks, images, blockquotes

For full Markdown rendering, use a third-party library or render to AttributedString first.

## Top 5 Mistakes

| # | Mistake | Fix |
|---|---------|-----|
| 1 | Using deprecated `.foregroundColor()` | Use `.foregroundStyle()` |
| 2 | Missing `value:` in `.animation()` | `.animation(.default, value: someState)` |
| 3 | Expecting full Markdown in `Text` | Only inline Markdown works; block Markdown requires conversion |
| 4 | Recreating AttributedString every render | Cache it with `@State` or compute once |
| 5 | Using `TextEditor(text:)` for rich text | Use `AttributedString` binding for styled editing (iOS 18+) |

## Review Checklist

- [ ] Using `.foregroundStyle()` not `.foregroundColor()`
- [ ] AttributedString cached, not recreated on every render
- [ ] Markdown expectations match what `Text` actually supports
- [ ] iOS version requirements checked for APIs used
- [ ] Accessibility: Dynamic Type support in custom styled text
