---
name: playwright
description: |
  End-to-end testing with Playwright — generate, run, and debug E2E tests.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Playwright E2E Testing

Generate and run Playwright end-to-end tests for web applications.

## Prerequisites

```bash
npx playwright --version
```

If not installed:
```bash
npm init playwright@latest
# or add to existing project:
npm install -D @playwright/test && npx playwright install
```

## Workflow

### 1. Analyze
Read the source files for the page/component to test. Understand routes, interactive elements, and expected behaviors.

### 2. Generate Test File
Create a test file following the project's existing patterns and directory structure.

```typescript
import { test, expect } from '@playwright/test';

test.describe('Feature Name', () => {
  test.beforeEach(async ({ page }) => {
    // Setup: navigate, authenticate, seed data
  });

  test('should do expected behavior', async ({ page }) => {
    // Arrange
    // Act
    // Assert
  });
});
```

### 3. Run Tests
```bash
npx playwright test <file>           # Run specific test file
npx playwright test --headed          # With visible browser
npx playwright test --ui              # Playwright UI mode
npx playwright test --trace on        # Capture trace for debugging
```

### 4. Debug Failures
- Read error output carefully
- Use `--trace on` and open trace viewer: `npx playwright show-trace trace.zip`
- Take screenshots on failure: `await page.screenshot({ path: 'debug.png' })`
- Use `page.pause()` for step-by-step debugging in headed mode

## Capabilities

- **Navigation**: `page.goto()`, URL assertions, redirect verification
- **Forms**: `page.fill()`, `page.selectOption()`, `page.check()`, multi-step wizards
- **Assertions**: `expect(page).toHaveURL()`, `expect(locator).toBeVisible()`, `toHaveText()`
- **Screenshots**: `page.screenshot()`, full-page, element-level
- **Visual regression**: `expect(page).toHaveScreenshot()` with thresholds
- **Accessibility**: `@axe-core/playwright`, ARIA role selectors, keyboard navigation
- **Network**: `page.route()` for mocking, `page.waitForResponse()` for API calls

## Tips

- Use `data-testid` attributes for stable selectors
- Prefer user-visible text and ARIA roles over CSS selectors
- Use `test.step()` for complex multi-step flows
- Set `baseURL` in `playwright.config.ts`
- Use `page.waitForResponse()` for async navigation
- Place test files alongside existing test patterns in the project
