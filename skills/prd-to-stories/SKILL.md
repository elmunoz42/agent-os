---
name: prd-to-stories
description: Turn a Builder Methods PRD (_build_plan/prd.md or prd.html from the bm-prd-creator skill) into long lived user stories in agent-os/user-stories/, one set per milestone, and wire milestone verification. Use when the user runs /prd-to-stories or has just finished a PRD and wants testable stories.
---

# PRD to Stories

The PRD Creator (`bm-prd-creator`, Builder Methods) writes a temporary `_build_plan/` folder that is deleted after the initial build. This skill carries its user facing scope into permanent user stories so it can be verified now and regression tested later.

## Important Guidelines

- **Ask with your structured question tool** (AskUserQuestion in Claude Code; the ask or question tool in Cursor and Codex), or in chat if none is available.
- **Do not edit `_build_plan/`** or the bm-prd-creator skill. Read only.
- Stories follow the write-user-stories format: read `../write-user-stories/references/story-format.md` (or the installed copy in `.agents/skills/write-user-stories/references/`).
- The PRD is a what document. Stories stay at that level: user visible behavior, no implementation.

## Process

### Step 1: Find the PRD

Look for `_build_plan/prd.md`, then `_build_plan/prd.html`. If both exist, use prd.md. If neither exists:

```
No PRD found in _build_plan/. Run the bm-prd-creator skill first, or point me to a PRD file.
```

If bm-prd-creator is not installed, mention: install it with `project-install.sh --commands-only --with prd`, or in Claude Code `/plugin marketplace add buildermethods/bm-skills`.

### Step 2: Extract scope per milestone

For each `## Milestone N — Name` section, collect:

- **What gets built** bullets: candidate stories (one user goal each).
- **Done when**: the milestone's acceptance bar. Every Done when sentence must be covered by at least one AC.
- **What milestone N explicitly does NOT include**: copy relevant items to the story Notes as out of scope.

Also read the top level sections for roles (What the app does), test data hints (Data model), and integrations that need stubbing in tests.

### Step 3: Propose stories, milestone by milestone

Present one milestone at a time:

```
Milestone 1 — Core CRUD (5 stories)

US-001 Save a bookmark from a URL
  AC1 Given I am signed in on /bookmarks, when I paste a URL and click Save, then it appears at the top of the list with its page title
  AC2 (unit) URLs without http or https are rejected with a message
US-002 Tag a bookmark
  ...

Done when coverage: "user can save, tag, and filter bookmarks" -> US-001, US-002, US-003

Write these? (yes / edit / skip milestone)
```

Continue IDs from `agent-os/user-stories/index.yml`. Set `source: prd-m<N>`, `status: draft`, tags from the feature name.

Resolve the testing level first (see `../write-user-stories/references/testing-levels.md`). A PRD's Done when criteria are happy path, so they become untagged ACs with `sets: [demo, production]`. At production level, also add `(edge)` ACs from the edge case checklist and from each milestone's explicit exclusions where they imply a guard (for example, a clear message instead of a crash).

### Step 4: Write files and index

Write each story file and index entry exactly as write-user-stories does.

### Step 5: Wire milestone verification

1. Ensure the project `AGENTS.md` contains the agent-os managed block (installed by `project-install.sh`). It already tells agents to run verify-stories for `prd-m<N>` before writing `milestone-log.md`. If the block is missing, add this line under the `_build_plan/` section the PRD Creator added:

   ```markdown
   Before writing a milestone's `milestone-log.md`, run the verify-stories skill with scope `prd-m<N>` and include its summary table under `## Verification` in the log.
   ```

2. Do not modify `_build_plan/milestones/*/prompt.md`. AGENTS.md is read by Claude Code (via the CLAUDE.md import), Codex, and Cursor, so the instruction reaches every agent.

### Step 6: Carry durable product context

If `agent-os/product/` is missing or empty, offer to run plan-product pre-filled from the PRD (mission from What we're building, roadmap from the milestones, tech stack from the stack section), since `_build_plan/` will be deleted later.

### Step 7: Hand off

Tell the user how many stories were written per milestone and the next step:

```
Start milestone 1 with _build_plan/milestones/1-core-crud/prompt.md.
When it is built, the agent runs /verify-stories prd-m1 before writing its milestone log.
```
