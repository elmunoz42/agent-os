---
id: US-002
title: Complete a task
status: verified
priority: must
source: manual
tags: [tasks]
sets: [demo, production]
verify: [browser, unit]
tests:
  e2e: [tests/e2e/stories/US-002.spec.ts]
  unit: [src/tasks.test.js]
verified_level: production
last_verified: 2026-11-01
---

As a person working through my list, I want to check off tasks, so that I can see what is left.

## Acceptance criteria

- AC1: Given two active tasks, when I check one, then it shows as done and the count reads 1 task left.
- AC2 (edge, unit): Toggling a task twice returns it to active.

## Test data

- Two tasks created through the UI

## Notes

- Out of scope: bulk complete.
