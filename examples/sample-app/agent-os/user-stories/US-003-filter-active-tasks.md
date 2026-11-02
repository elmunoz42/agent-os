---
id: US-003
title: Show only active tasks
status: failing
priority: should
source: manual
tags: [tasks, filters]
verify: [browser]
tests:
  e2e: [tests/e2e/stories/US-003.spec.ts]
  unit: []
last_verified: 2026-11-01
---

As a person with a long list, I want to hide finished tasks, so that I can focus on what is left.

## Acceptance criteria

- AC1: Given one done and one active task, when I click Active, then only the active task is listed.

## Test data

- Two tasks created through the UI, one checked

## Notes

- Failing since 2026-11-01: the Active filter is ignored (see _runs/2026-11-01-2030/report.md). The e2e test is marked test.fail() until fixed; remove that line as part of the fix.
