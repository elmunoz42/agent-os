# User Story Format

## Location and naming

- Folder: `agent-os/user-stories/`
- File: `US-###-short-slug.md` (3 digit zero padded ID, slug max 40 chars, lowercase, hyphens)
- Index: `agent-os/user-stories/index.yml`
- Run artifacts: `agent-os/user-stories/_runs/<YYYY-MM-DD-HHMM>/` (screenshots gitignored, report.md committed)

## Frontmatter

```yaml
---
id: US-012                  # stable, never renumbered or reused
title: Revoke a pending invite
status: draft               # draft | ready | verified | failing
priority: must              # must | should | could
source: spec:2026-11-02-1430-team-invites   # manual | spec:<folder> | prd-m<N> | backfill
tags: [team]
sets: [demo, production]    # demo = happy path set; [production] for edge only stories
verify: [browser, unit]     # which layers apply
tests:
  e2e: [tests/e2e/stories/US-012.spec.ts]
  unit: [src/invites/revoke.test.ts]
verified_level: production  # set by verify-stories: demo or production
last_verified: 2026-11-03   # set by verify-stories
---
```

## Body

```markdown
As a {role}, I want {capability}, so that {outcome}.

## Acceptance criteria

- AC1: Given {context}, when {action}, then {observable result}.
- AC2 (unit): {logic rule}.
- AC3 (edge): Given {unusual context}, when {action}, then {safe result}.

## Test data

- {seed users, fixtures, flags}

## Notes

- {edge cases, out of scope, links}
```

## Rules

- Each AC has a stable label (AC1, AC2, ...). Tests reference them, so do not renumber; append new ACs at the end and mark removed ones `~~AC3~~ removed`.
- Browser ACs describe what a user sees or does, never selectors or implementation.
- `(unit)` ACs describe a rule (validation, calculation, permission) that a unit test can prove.
- `(edge)` ACs are production only: invalid input, permissions, errors, empty states. Untagged ACs are the happy path and belong to the demo set too. Tags combine: `(edge, unit)`. See `testing-levels.md`.
- Use real routes and labels from the app when known (e.g. /team, the Revoke button).
- Test data must be reproducible: reference seed or fixture files, never a personal account.
- Only verify-stories changes `status`, `verified_level`, `tests`, and `last_verified`.
- Stories without `sets` are treated as `[demo, production]`.
- Never edit a story to match observed behavior. If behavior differs, the story is failing until a human decides.

## Index entry

```yaml
US-012:
  file: US-012-revoke-pending-invite.md
  title: Revoke a pending invite
  status: draft
  tags: [team]
  sets: [demo, production]
  source: spec:2026-11-02-1430-team-invites
```

Agents read the index first and open only the stories they need.
