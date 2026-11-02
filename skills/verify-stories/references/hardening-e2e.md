# Hardening story checks into Playwright tests

## Setup (only if the project has no Playwright config)

Ask before adding dependencies. For JS/TS projects:

```bash
npm install -D @playwright/test
npx playwright install chromium
```

Minimal `playwright.config.ts` at the project root (merge with any existing config instead of replacing it):

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'npm run dev',          // from agent-os/testing.yml app.start
    url: 'http://localhost:3000',     // app.base_url + app.health
    reuseExistingServer: !process.env.CI,
  },
});
```

Python projects: use `pytest-playwright` with the same tagging (`@pytest.mark.us_012` plus the ID in the test name). Ruby/Rails: Playwright via `capybara-playwright-driver` or a JS Playwright suite against the running server; prefer the JS suite unless the project already uses Capybara.

## File layout

- One file per story: `{e2e_dir}/US-012.spec.ts` (default `tests/e2e/stories/`).
- One `test()` per browser AC, named `US-012 AC1: <short then clause> @US-012`.
- Group with `test.describe('US-012 Revoke a pending invite', ...)`.
- Shared login or seeding goes in a fixture or `beforeEach`, not copied per test.

```ts
import { test, expect } from '@playwright/test';

test.describe('US-012 Revoke a pending invite', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('owner@example.test');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();
  });

  test('US-012 AC1: revoked invite disappears from the list @US-012', async ({ page }) => {
    await page.goto('/team');
    const row = page.getByRole('row', { name: /new@example\.test/ });
    await row.getByRole('button', { name: 'Revoke' }).click();
    await expect(row).toHaveCount(0);
  });
});
```

## Rules

- Locators: `getByRole`, `getByLabel`, `getByText`, `getByTestId` in that order of preference. No CSS chains, no XPath, no nth-child.
- Assertions: web-first `expect(...).toBeVisible()`, `toHaveText`, `toHaveURL`. Never `waitForTimeout`.
- Each test sets up its own data and does not depend on test order.
- Assert the AC's Then, nothing more. Extra assertions make tests brittle.
- Known bugs: if a story is failing and the user wants the suite green, mark the test with `test.fail()` plus a comment linking the story, never delete it. Remove `test.fail()` when fixed (Playwright will flag it when it starts passing).
- Selecting by story: `npx playwright test --grep @US-012`, or all stories: `--grep @US`.
