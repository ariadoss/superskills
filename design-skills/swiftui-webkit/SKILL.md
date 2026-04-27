---
name: swiftui-webkit
description: Embed and control web content in SwiftUI apps using WebView and WebPage. Use when displaying URLs or HTML in a SwiftUI app, implementing JavaScript interop, controlling web navigation, capturing snapshots, or handling custom URL schemes. Core APIs require iOS/macOS 26+.
metadata:
  author: rshankras
---

# WebKit Integration for SwiftUI

Embed and control web content in SwiftUI using `WebView` and `WebPage`.

## When This Skill Activates

Use this skill when the user needs to:
- Display web content within SwiftUI applications
- Load URLs, HTML strings, or data blobs
- Execute JavaScript from SwiftUI
- Control navigation (back, forward, reload)
- Customize web view behavior
- Capture snapshots or generate PDFs
- Intercept navigation requests
- Configure private browsing or custom user agents

## API Availability

| API | Minimum Version | Notes |
|-----|----------------|-------|
| `WebView` | iOS/macOS 26 | Main SwiftUI web view |
| `WebPage` | iOS/macOS 26 | Observable web page controller |
| `WebPage.Configuration` | iOS/macOS 26 | Configuration object |
| `WKContentWorld` | iOS 14 / macOS 11 | JavaScript execution worlds |
| `WKSnapshotConfiguration` | iOS 11 / macOS 10.13 | Snapshot capture |

## Quick Start

### Minimal — Just a URL

```swift
import SwiftUI
import WebKit

struct SimpleWebView: View {
    var body: some View {
        WebView(url: URL(string: "https://apple.com")!)
    }
}
```

### Full Control — with WebPage

```swift
import SwiftUI
import WebKit

struct ControlledWebView: View {
    @State private var page = WebPage()

    var body: some View {
        VStack {
            HStack {
                Button("Back") { page.goBack() }
                    .disabled(!page.canGoBack)
                Button("Forward") { page.goForward() }
                    .disabled(!page.canGoForward)
                Button("Reload") { page.reload() }
            }
            WebView(page)
        }
        .onAppear {
            page.load(URLRequest(url: URL(string: "https://apple.com")!))
        }
    }
}
```

## JavaScript Execution

```swift
// Execute after page loads
let result = try await page.callJavaScript("document.title")

// Inject script
await page.evaluateJavaScript("document.body.style.backgroundColor = 'red'")
```

Wait for page load before executing JavaScript — check `page.isLoading` or observe load events.

## Navigation Control

```swift
page.load(URLRequest(url: url))
page.loadHTMLString("<h1>Hello</h1>", baseURL: nil)
page.goBack()
page.goForward()
page.reload()
page.stopLoading()
```

## Critical Mistakes to Avoid

| # | Mistake | Fix |
|---|---------|-----|
| 1 | Using `WebView(url:)` when you need navigation control | Use `WebPage` for any interactivity |
| 2 | Missing `import WebKit` | Required alongside `import SwiftUI` |
| 3 | Not observing navigation events | Observe `page.isLoading` and navigation callbacks |
| 4 | Executing JavaScript before DOM is ready | Wait for page load completion |
| 5 | Using persistent data store in private mode | Use ephemeral data store for private browsing |
| 6 | String interpolation in JavaScript | Sanitize all user input before injecting into JS |

## Review Checklist

- [ ] `import WebKit` present alongside `import SwiftUI`
- [ ] Using `WebPage` for any navigation or JavaScript needs
- [ ] JavaScript execution waits for page load
- [ ] User input sanitized before JavaScript injection
- [ ] Navigation events observed for loading states
- [ ] iOS/macOS 26+ requirement documented
