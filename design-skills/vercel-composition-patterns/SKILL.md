---
name: vercel-composition-patterns
description: React composition patterns that scale. Use when refactoring components with boolean prop proliferation, building flexible component libraries, or designing reusable APIs. Triggers on tasks involving compound components, render props, context providers, or component architecture. Includes React 19 API changes.
license: MIT
metadata:
  author: vercel
  version: '1.0.0'
---

# React Composition Patterns

Composition patterns for building flexible, maintainable React components. Avoid boolean prop proliferation by using compound components, lifting state, and composing internals. These patterns make codebases easier for both humans and AI agents to work with as they scale.

## When to Apply

Reference these guidelines when:

- Refactoring components with many boolean props
- Building reusable component libraries
- Designing flexible component APIs
- Reviewing component architecture
- Working with compound components or context providers

## Rule Categories by Priority

| Priority | Category                | Impact | Prefix          |
| -------- | ----------------------- | ------ | --------------- |
| 1        | Component Architecture  | HIGH   | `architecture-` |
| 2        | State Management        | MEDIUM | `state-`        |
| 3        | Implementation Patterns | MEDIUM | `patterns-`     |
| 4        | React 19 APIs           | MEDIUM | `react19-`      |

## Quick Reference

### 1. Component Architecture (HIGH)

- `architecture-avoid-boolean-props` - Don't add boolean props to customize behavior; use composition
- `architecture-compound-components` - Structure complex components with shared context

### 2. State Management (MEDIUM)

- `state-decouple-implementation` - Provider is the only place that knows how state is managed
- `state-context-interface` - Define generic interface with state, actions, meta for dependency injection
- `state-lift-state` - Move state into provider components for sibling access

### 3. Implementation Patterns (MEDIUM)

- `patterns-explicit-variants` - Create explicit variant components instead of boolean modes
- `patterns-children-over-render-props` - Use children for composition instead of renderX props

### 4. React 19 APIs (MEDIUM)

> **⚠️ React 19+ only.** Skip this section if using React 18 or earlier.

- `react19-no-forwardref` - Don't use `forwardRef`; use `use()` instead of `useContext()`

## Core Principle

**Avoid boolean prop proliferation.** When a component accumulates boolean props like `isLarge`, `isLoading`, `hasIcon`, `showFooter`, it becomes a configuration panel instead of a component. This pattern:
- Makes the API surface impossible to understand at a glance
- Creates combinatorial state explosions (2^n possible states for n booleans)
- Prevents tree-shaking and dead code elimination
- Makes AI-assisted refactoring much harder

**Instead, compose.** Create explicit variant components, lift state into providers, and use children for flexible content injection.

## Example: Boolean Props → Composition

```jsx
// ❌ Boolean prop proliferation
<Button isLarge isLoading hasLeftIcon={<IconSpinner />} disabled={isLoading}>
  Submit
</Button>

// ✅ Explicit variants + composition
<Button.Large disabled={isLoading}>
  {isLoading ? <Spinner /> : null}
  Submit
</Button.Large>
```

## Compound Component Pattern

```jsx
// Provider holds shared state
function Tabs({ children, defaultTab }) {
  const [active, setActive] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ active, setActive }}>
      {children}
    </TabsContext.Provider>
  );
}

// Children consume via context
Tabs.Tab = function Tab({ id, children }) {
  const { active, setActive } = useContext(TabsContext);
  return (
    <button
      onClick={() => setActive(id)}
      aria-selected={active === id}
    >
      {children}
    </button>
  );
};

// Usage is readable and composable
<Tabs defaultTab="overview">
  <Tabs.Tab id="overview">Overview</Tabs.Tab>
  <Tabs.Tab id="details">Details</Tabs.Tab>
</Tabs>
```
