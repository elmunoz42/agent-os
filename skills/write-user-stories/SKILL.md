---
name: write-user-stories
description: Write or update user stories with testable acceptance criteria in agent-os/user-stories/. Use when the user runs /write-user-stories, asks for user stories or acceptance criteria, or wants to backfill stories from existing code, specs, or a PRD.
---

# Write User Stories

Capture what users must be able to do as small, testable story files. Stories are long lived: they outlive specs and PRDs and are the contract that verify-stories checks in a browser and in tests.

## Important Guidelines

- **Ask with your structured question tool** (AskUserQuestion in Claude Code; the ask or question tool in Cursor and Codex). If none is available, ask in chat and wait.
- **Propose, don't interrogate.** Draft stories and acceptance criteria, then let the user confirm or edit.
- **Observable acceptance criteria only.** Every AC must be checkable by a person in the browser, or tagged `(unit)` when it is logic not visible in the UI.
- **Small stories.** One user goal per story, 1 to 5 ACs. Split anything larger.
- Follow `references/story-format.md` exactly. Use `references/user-story-template.md` as the file skeleton.

## Inputs (pick from what the user gave)

1. **A feature description** in chat.
2. **A spec folder** in `agent-os/specs/` (plan.md, shape.md).
3. **A PRD**: prefer the prd-to-stories skill, which calls this format.
4. **Backfill** (`/write-user-stories backfill [area]`): read routes, pages, and existing tests to infer what users can already do. Also read old v2 specs (`agent-os/specs/*/spec.md`, `tasks.md`) if present.

If nothing was given, ask what to write stories for, offering these four options.

## Process

### Step 1: Load context

- Read `agent-os/user-stories/index.yml` (create the folder and index from the template in `references/story-format.md` if missing).
- Read `agent-os/product/mission.md` if it exists, for roles and vocabulary.
- Note the highest existing ID. New IDs continue from it. Never renumber or reuse IDs.

### Step 2: Propose stories

Present a compact list, then confirm:

```
Proposed stories for team invites:

1. US-011 Invite a teammate by email
   AC1 Given I am an owner on /team, when I submit an email, then the invite appears as Pending
   AC2 Given an invite email, when the invitee opens the link, then signup shows their email prefilled
2. US-012 Revoke a pending invite
   AC1 Given a pending invite, when I click Revoke, then it disappears from the list
   AC2 (unit) A revoked invite token is rejected

Write these? (yes / edit 2: ... / drop 1 / add: ...)
```

Check for duplicates against the index. If an existing story covers the same goal, propose an update to it instead of a new story.

### Step 3: Write files

For each confirmed story:

1. Write `agent-os/user-stories/US-###-short-slug.md` using the template.
2. Set `status: draft` unless the user said the behavior already exists and works (then `ready`).
3. Set `source:` to `manual`, `spec:<spec-folder>`, `prd-m<N>`, or `backfill`.
4. Set `verify:` to `[browser]`, `[unit]`, or `[browser, unit]` based on the AC tags.
5. Leave `tests:` empty. verify-stories fills it in.

### Step 4: Update the index

Add or update one entry per story in `agent-os/user-stories/index.yml`, sorted by ID:

```yaml
US-011:
  file: US-011-invite-teammate.md
  title: Invite a teammate by email
  status: draft
  tags: [team]
  source: spec:2026-11-02-1430-team-invites
```

### Step 5: Link and hand off

- If working from a spec, add the IDs to the spec's `stories.md`.
- Tell the user which files were written and suggest: run verify-stories once the feature is built (or now, for backfilled stories).

## Status values

| status | meaning | who sets it |
|---|---|---|
| draft | written, behavior may not exist yet | write-user-stories |
| ready | behavior should exist, not yet verified | user or agent after building |
| verified | ACs passed in browser and are covered by committed tests | verify-stories only |
| failing | last verification failed | verify-stories only |
