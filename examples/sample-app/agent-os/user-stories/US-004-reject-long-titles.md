---
id: US-004
title: Reject task titles over 120 characters
status: verified
priority: should
source: manual
tags: [tasks, validation]
sets: [production]
verify: [browser, unit]
tests:
  e2e: [tests/e2e/stories/US-004.spec.ts]
  unit: [src/tasks.test.js]
verified_level: production
last_verified: 2026-11-02
---

As a person adding tasks, I want overly long titles rejected with a clear message, so that the list stays readable.

## Acceptance criteria

- AC1 (edge): Given a title of 121 characters, when I click Add, then I see Title must be 120 characters or less, no task is added, and my text stays in the input.
- AC2 (edge, unit): A title of exactly 120 characters is accepted.

## Test data

- Empty task list (tests call POST /api/reset)

## Notes

- Production only: not part of the demo path.
