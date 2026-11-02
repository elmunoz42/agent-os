# Story verification 2026-11-01 20:30

App: http://localhost:4173 (npm run dev) | Browser tool: playwright-cli (chrome channel, headless)
Scope: all

| Story | AC | Browser | Unit | Test | Result |
|---|---|---|---|---|---|
| US-001 | AC1 | pass | | tests/e2e/stories/US-001.spec.ts | pass |
| US-001 | AC2 | | pass | src/tasks.test.js | pass |
| US-001 | AC3 | pass | | tests/e2e/stories/US-001.spec.ts | pass |
| US-002 | AC1 | pass | | tests/e2e/stories/US-002.spec.ts | pass |
| US-002 | AC2 | | pass | src/tasks.test.js | pass |
| US-003 | AC1 | fail | | tests/e2e/stories/US-003.spec.ts (test.fail) | fail |

Verified: 2 | Failing: 1 | Blocked: 0
Console: favicon.ico 404 only (not related to any AC)

## Failures

### US-003 AC1: Active filter hides completed tasks
- Steps: add Buy milk and Ship release, check Buy milk, click Active
- Expected: only Ship release is listed
- Actual: both tasks listed; Active button shows pressed
- Evidence: screenshots/US-003-AC1.png
- Suspected area: public/index.html render() ignores the filter variable
