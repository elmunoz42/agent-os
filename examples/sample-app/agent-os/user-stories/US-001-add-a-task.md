---
id: US-001
title: Add a task
status: verified
priority: must
source: manual
tags: [tasks]
verify: [browser, unit]
tests:
  e2e: [tests/e2e/stories/US-001.spec.ts]
  unit: [src/tasks.test.js]
last_verified: 2026-11-01
---

As a person with things to do, I want to add a task by typing it, so that I don't forget it.

## Acceptance criteria

- AC1: Given I am on the task page, when I type a title and click Add, then the task appears in the list, the input clears, and the count reads 1 task left.
- AC2 (unit): Titles are trimmed; blank titles and titles over 120 characters are rejected.
- AC3: Given an empty input, when I click Add, then I see Title is required and no task is added.

## Test data

- Empty task list (tests call POST /api/reset)

## Notes

- Out of scope: editing or deleting tasks.
