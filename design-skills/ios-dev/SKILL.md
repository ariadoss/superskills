---
name: ios-dev
description: iOS and Swift development expert covering Swift best practices, SwiftUI patterns, Human Interface Guidelines compliance, accessibility audits, navigation patterns, and app architecture. Use when building iOS apps, reviewing Swift code, or planning app architecture.
metadata:
  author: rshankras
---

# iOS Development Expert

Comprehensive guidance for iOS app development across multiple specialized areas.

## When This Skill Activates

Use this skill when the user needs help with:
- Swift code quality and modern idioms
- SwiftUI component patterns
- Apple HIG compliance checks
- Accessibility assessment (VoiceOver, color contrast, Dynamic Type)
- Navigation architecture (NavigationStack, NavigationSplitView, TabView)
- App planning and architecture decisions

## Available Modules

### Coding Best Practices
Modern Swift patterns, architectural approaches, and code quality standards:

- **Architecture**: MVVM, Clean Architecture, The Composable Architecture (TCA)
- **Swift idioms**: value types, protocol-oriented programming, async/await, actors
- **Performance**: lazy loading, background processing, memory management
- **Testing**: XCTest, snapshot testing, UI testing

### UI Review
Evaluate designs for HIG compliance:

- **Typography**: Dynamic Type support, custom fonts with scaling
- **Accessibility**: VoiceOver labels, color contrast (4.5:1 minimum), touch targets (44×44pt)
- **Layout**: Safe area handling, adaptivity across device sizes
- **Components**: Use of native controls vs. custom implementations

### Navigation Patterns

**NavigationStack** (iOS 16+):
```swift
NavigationStack {
    ContentView()
        .navigationDestination(for: Item.self) { item in
            DetailView(item: item)
        }
}
```

**NavigationSplitView** (iPad/macOS):
```swift
NavigationSplitView {
    Sidebar()
} detail: {
    DetailView()
}
```

**Programmatic navigation with NavigationPath**:
```swift
@State private var path = NavigationPath()

NavigationStack(path: $path) {
    ContentView()
        .navigationDestination(for: Route.self) { route in
            // ...
        }
}
```

### App Planner
Concept-to-architecture development:

1. Define core use cases (3–5 maximum for MVP)
2. Choose data persistence strategy (SwiftData, Core Data, CloudKit, UserDefaults)
3. Select networking approach (URLSession, async/await)
4. Plan state management (ObservableObject, @Observable, TCA)
5. Define navigation structure (tab-based, navigation stack, split view)

## Reference Points

Always reference Apple's official documentation:
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Swift Documentation](https://docs.swift.org/swift-book/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)

## Usage Approach

1. Identify the user's specific need (code review, architecture planning, HIG compliance, etc.)
2. Apply the relevant module's guidance
3. Reference official Apple documentation for precise API details
4. Check iOS version requirements for APIs used
