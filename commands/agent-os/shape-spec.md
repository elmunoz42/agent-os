---
name: shape-spec
description: Shape a significant feature into a spec saved in agent-os/specs/, including related user stories and a verification task. Use when the user runs /shape-spec or wants to plan a feature before building it.
---

# Shape Spec

Gather context and structure planning for significant work. **Best run in plan mode.**

## Important Guidelines

- **Ask with your structured question tool** when asking the user anything (AskUserQuestion in Claude Code; the ask or question tool in Cursor and Codex). If none is available, ask in chat and wait for the answer. In this file, AskUserQuestion means whichever applies.
- **Offer suggestions** — Present options the user can confirm, adjust, or correct
- **Keep it lightweight** — This is shaping, not exhaustive documentation

## Prerequisites

Plan mode is preferred (Claude Code plan mode, Cursor plan mode, or Codex plan or read-only mode).

If you are not in plan mode, do not stop. Tell the user once:

```
Tip: shape-spec works best in plan mode. Continuing with inline planning; I won't edit code until you approve the plan.
```

Then continue, and do not change any code until the user approves the plan in Step 9.

## Process

### Step 1: Clarify What We're Building

Use AskUserQuestion to understand the scope:

```
What are we building? Please describe the feature or change.

(Be as specific as you like — I'll ask follow-up questions if needed)
```

Based on their response, ask 1-2 clarifying questions if the scope is unclear. Examples:
- "Is this a new feature or a change to existing functionality?"
- "What's the expected outcome when this is done?"
- "Are there any constraints or requirements I should know about?"

### Step 2: Gather Visuals

Use AskUserQuestion:

```
Do you have any visuals to reference?

- Mockups or wireframes
- Screenshots of similar features
- Examples from other apps

(Paste images, share file paths, or say "none")
```

If visuals are provided, note them for inclusion in the spec folder.

### Step 3: Identify Reference Implementations

Use AskUserQuestion:

```
Is there similar code in this codebase I should reference?

Examples:
- "The comments feature is similar to what we're building"
- "Look at how src/features/notifications/ handles real-time updates"
- "No existing references"

(Point me to files, folders, or features to study)
```

If references are provided, read and analyze them to inform the plan.

### Step 4: Check Product Context

Check if `agent-os/product/` exists and contains files.

If it exists, read key files (like `mission.md`, `roadmap.md`, `tech-stack.md`) and use AskUserQuestion:

```
I found product context in agent-os/product/. Should this feature align with any specific product goals or constraints?

Key points from your product docs:
- [summarize relevant points]

(Confirm alignment or note any adjustments)
```

If no product folder exists, skip this step.

### Step 5: Surface Relevant Standards

Read `agent-os/standards/index.yml` to identify relevant standards based on the feature being built.

Use AskUserQuestion to confirm:

```
Based on what we're building, these standards may apply:

1. **api/response-format** — API response envelope structure
2. **api/error-handling** — Error codes and exception handling
3. **database/migrations** — Migration patterns

Should I include these in the spec? (yes / adjust: remove 3, add frontend/forms)
```

Read the confirmed standards files to include their content in the plan context.

### Step 6: Link User Stories

Read `agent-os/user-stories/index.yml` if it exists. Find stories this work creates or changes.

Resolve the testing level first (`level:` in `agent-os/testing.yml`; if empty, ask demo or production once and save it; see the write-user-stories skill's `references/testing-levels.md`). Demo specs get happy path stories only. Production specs also get `(edge)` ACs.

Use AskUserQuestion:

```
These existing user stories relate to this work:
- US-004 Reset password via email link (verified)

I'd also add these new stories:
- Invite a teammate by email: AC1 invite form sends email, AC2 invitee lands on signup with email prefilled
- Revoke a pending invite: AC1 owner sees pending invites, AC2 revoke removes the link

Include them? (yes / adjust / skip stories for this spec)
```

Follow the story format in the write-user-stories skill (`references/story-format.md`). New stories are written to `agent-os/user-stories/` as part of Task 1. If `agent-os/user-stories/` does not exist, offer to create it.

### Step 7: Generate Spec Folder Name

Create a folder name using this format:
```
YYYY-MM-DD-HHMM-{feature-slug}/
```

Where:
- Date/time is current timestamp
- Feature slug is derived from the feature description (lowercase, hyphens, max 40 chars)

Example: `2026-01-15-1430-user-comment-system/`

**Note:** If `agent-os/specs/` doesn't exist, create it when saving the spec folder.

### Step 8: Structure the Plan

Now build the plan with **Task 1 always being "Save spec documentation"**.

Present this structure to the user:

```
Here's the plan structure. Task 1 saves all our shaping work before implementation begins.

---

## Task 1: Save Spec Documentation

Create `agent-os/specs/{folder-name}/` with:

- **plan.md** — This full plan
- **shape.md** — Shaping notes (scope, decisions, context from our conversation)
- **standards.md** — Relevant standards that apply to this work
- **references.md** — Pointers to reference implementations studied
- **stories.md** — Linked user story IDs (and write any new story files to `agent-os/user-stories/`)
- **visuals/** — Any mockups or screenshots provided

## Task 2: [First implementation task]

[Description based on the feature]

## Task 3: [Next task]

...

## Security Review (production level, if the security-audit skill is installed)

Run a focused security review of the code this spec changed (security-audit guidance mode). Fix confirmed findings and add an `(edge)` AC for each fix to the linked stories. See the write-user-stories skill's `references/testing-levels.md`.

## Final Task: Verify Stories

Run the verify-stories skill, at the project's testing level, for the stories in stories.md: check each acceptance criterion in a real browser, harden passing checks into committed tests, and report failures.

---

Does this plan structure look right? I'll fill in the implementation tasks next.
```

### Step 9: Complete the Plan

After Task 1 is confirmed, continue building out the remaining implementation tasks based on:
- The feature scope from Step 1
- Patterns from reference implementations (Step 3)
- Constraints from standards (Step 5)
- Acceptance criteria from linked stories (Step 6)

Each task should be specific and actionable.

### Step 10: Ready for Execution

When the full plan is ready:

```
Plan complete. When you approve and execute:

1. Task 1 will save all spec documentation (and new user stories) first
2. Then implementation tasks will proceed
3. The final task verifies the linked stories in a browser and with tests

Ready to start? (approve / adjust)
```

## Output Structure

The spec folder will contain:

```
agent-os/specs/{YYYY-MM-DD-HHMM-feature-slug}/
├── plan.md           # The full plan
├── shape.md          # Shaping decisions and context
├── standards.md      # Which standards apply and key points
├── references.md     # Pointers to similar code
├── stories.md        # Linked user story IDs
└── visuals/          # Mockups, screenshots (if any)
```

## shape.md Content

The shape.md file should capture:

```markdown
# {Feature Name} — Shaping Notes

## Scope

[What we're building, from Step 1]

## Decisions

- [Key decisions made during shaping]
- [Constraints or requirements noted]

## Context

- **Visuals:** [List of visuals provided, or "None"]
- **References:** [Code references studied]
- **Product alignment:** [Notes from product context, or "N/A"]

## Standards Applied

- api/response-format — [why it applies]
- api/error-handling — [why it applies]
```

## standards.md Content

Include the full content of each relevant standard:

```markdown
# Standards for {Feature Name}

The following standards apply to this work.

---

## api/response-format

[Full content of the standard file]

---

## api/error-handling

[Full content of the standard file]
```

## stories.md Content

```markdown
# Stories for {Feature Name}

- US-004 Reset password via email link (existing)
- US-011 Invite a teammate by email (new)
- US-012 Revoke a pending invite (new)
```

## references.md Content

```markdown
# References for {Feature Name}

## Similar Implementations

### {Reference 1 name}

- **Location:** `src/features/comments/`
- **Relevance:** [Why this is relevant]
- **Key patterns:** [What to borrow from this]

### {Reference 2 name}

...
```

## Tips

- **Keep shaping fast** — Don't over-document. Capture enough to start, refine as you build.
- **Visuals are optional** — Not every feature needs mockups.
- **Standards guide, not dictate** — They inform the plan but aren't always mandatory.
- **Specs are discoverable** — Months later, someone can find this spec and understand what was built and why.
