# Agent OS Fork: Implementation Plan

Fork: `elmunoz42/agent-os` (based on upstream v3.0 + unreleased fixes, commit e892e61)
Date: 2026-11-01

## 1. Goals

1. Modernize Agent OS to current agent standards (Agent Skills, AGENTS.md, plugin marketplace, harness neutral).
2. Integrate the Builder Methods PRD Creator skill.
3. Add `agent-os/user-stories/` with stories verified two ways: agent driven browser checks and durable automated tests (e2e + unit).
4. Stay simple and complementary to upstream.
5. Full backward compatibility with existing v3 projects, plus a migration path for v2 projects and a batch upgrade for many repos.

## 2. Current state (analysis)

Upstream v3 is small: 5 commands, 1 profile, 3 bash scripts.

| Area | Today | Gap |
|---|---|---|
| Commands | `commands/agent-os/*.md`: discover, index, inject standards; plan-product; shape-spec | Claude Code only format, no frontmatter, not Agent Skills |
| Install | `scripts/project-install.sh` copies standards to `agent-os/standards/` and commands to `.claude/commands/agent-os/` | Only targets Claude Code; no `.agents/skills`, no AGENTS.md |
| Planning | `/plan-product` writes mission, roadmap, tech-stack; `/shape-spec` requires plan mode and saves `agent-os/specs/{timestamp}-{slug}/` | Hard stop outside plan mode; no acceptance criteria artifact |
| Testing | Only standards guidance for unit tests | No end user tests, no browser verification |
| Versioning | `config.yml version: 3.0` in base only | Projects carry no version marker, so migrations must guess |
| Tooling | No CI beyond stale/PR bots | No install tests, no shellcheck |

PRD Creator (`buildermethods/bm-skills`, MIT, `skills/bm-prd-creator`):

- 11 step interview, outputs `_build_plan/prd.html` and/or `prd.md` plus `_build_plan/milestones/N-slug/prompt.md`.
- Each milestone has a Done when section framed as what the user can do in the browser. This is the natural seed for user stories.
- `_build_plan/` is explicitly temporary and should be deleted after the build. So stories derived from it must live somewhere permanent: `agent-os/user-stories/`.
- bm-skills already follows the modern layout we want to copy: flat `skills/<name>/SKILL.md`, single plugin `.claude-plugin/` with `source: ./`, AGENTS.md canonical with CLAUDE.md symlink.

Browser tooling landscape (Nov 2026):

- playwright-cli: built for coding agents, ships its own skill, lighter on context than MCP, can record actions and emit Playwright test code. Best default.
- Playwright MCP: clean isolated sessions, good for long stateful exploration.
- Chrome DevTools MCP: diagnostics (console, network, perf), not for driving flows.
- Claude in Chrome / desktop browser pane: real sessions, not reproducible. Use only when a story needs a live login.
- Playwright Test Agents (planner, generator, healer): planner can take a PRD and writes markdown specs to `specs/`. Optional integration, not a dependency.

## 3. Design principles

- Additive. Every new capability is a new file or folder. Existing paths and command names do not change.
- Agent Skills first, harness neutral. Use AskUserQuestion when available, otherwise ask in chat. Use plan mode when available, otherwise plan inline.
- Two layers of verification: the agent walks the story in a real browser (acceptance), then hardens it into a committed test (regression). The committed test is the source of truth in CI.
- Tool agnostic browser use with a configured preference order.
- Keep the fork rebasable on upstream: small hunks in upstream files, new work in new files.

## 4. Target layout

Fork repo:

```
agent-os/ (repo)
  AGENTS.md                      # canonical agent instructions; CLAUDE.md symlink
  .claude-plugin/
    plugin.json                  # single plugin, source ./
    marketplace.json
  commands/agent-os/             # upstream command files, now with name/description frontmatter
    discover-standards.md
    index-standards.md
    inject-standards.md
    plan-product.md
    shape-spec.md                # small hunk: stories step + verify task
  skills/                        # new fork skills (Agent Skills layout)
    write-user-stories/SKILL.md
    verify-stories/SKILL.md
      references/browser-tools.md
      references/hardening-e2e.md
    prd-to-stories/SKILL.md
  profiles/default/
    global/tech-stack.md
    testing/user-stories.md      # new standard: story format rules
    testing/e2e-browser.md       # new standard: selectors, data, tagging
  templates/
    user-story.md
    testing.yml
  scripts/
    common-functions.sh
    project-install.sh           # extended, still backward compatible
    sync-to-profile.sh
    migrate.sh                   # new: detect, upgrade, batch scan
    validate-skills.sh           # new: frontmatter lint for CI
  tests/                         # bats tests + fixture projects (v2, v3, fresh)
  config.yml                     # version 3.1-fork, new optional keys
```

Installed into a project:

```
agent-os/
  .version                       # new marker, e.g. 3.1-fork
  standards/ index.yml           # unchanged
  product/                       # unchanged
  specs/                         # unchanged; new specs gain stories.md
  user-stories/                  # new
    index.yml
    US-001-sign-up-with-email.md
    _runs/2026-11-02-1430/report.md + screenshots/   (gitignored by default)
  testing.yml                    # new: app start command, base URL, browser tool order
.agents/skills/<skill>/SKILL.md  # portable skills (Codex, Cursor, Copilot, Gemini)
.claude/skills -> symlinked or copied skills for Claude Code
AGENTS.md                        # managed agent-os block appended between markers
tests/e2e/stories/US-001.spec.ts # hardened tests (path configurable)
```

## 5. User stories design

Story file (`agent-os/user-stories/US-012-reset-password.md`):

```markdown
---
id: US-012
title: Reset password via email link
status: draft | ready | verified | failing
priority: must | should | could
source: prd milestone 2 | spec 2026-11-02-1430-auth | manual
verify: [browser, unit]
tests:
  e2e: tests/e2e/stories/US-012.spec.ts
  unit: [src/auth/reset.test.ts]
---

As a registered user, I want to reset my password from the login page, so I can regain access.

## Acceptance criteria
- AC1: Given I am on /login, when I click Forgot password and submit my email, then I see a confirmation message.
- AC2: Given a valid reset link, when I set a new password, then I can log in with it.
- AC3 (unit): Reset tokens expire after the configured TTL.

## Test data
- Seed user: test@example.com (from project seed files)

## Notes
- Email delivery is stubbed in test env.
```

Rules (in `testing/user-stories.md` standard):

- One story per file, stable IDs, never renumber.
- Each AC is observable. Tag AC with (unit) when it is logic not visible in UI.
- Frontmatter `status` is only changed by verify-stories; per run detail goes to `_runs/` to avoid noisy diffs.
- `index.yml` mirrors the standards index: id, title, status, tags. Lets agents load only relevant stories.

## 6. New and changed skills

### write-user-stories (new)
- Inputs: a feature description, a spec folder, a PRD, or `--backfill` from existing code/specs.
- Proposes stories with AC, confirms one at a time (same interaction style as discover-standards), writes files, updates index.

### prd-to-stories (new, bridge to PRD Creator)
- Reads `_build_plan/prd.md` (or prd.html), turns each milestone Done when plus per-feature in-scope bullets into stories tagged `source: prd milestone N`.
- Appends to the project AGENTS.md block: before writing a milestone-log.md, run verify-stories for that milestone's stories. This hooks into the PRD flow without editing the upstream PRD skill.
- Optionally maps PRD tech stack and data model into `agent-os/product/` so the long lived docs survive after `_build_plan/` is deleted.

### verify-stories (new, the core)
1. Select scope: one story, a tag, a milestone, a spec, or all ready/failing.
2. Read `agent-os/testing.yml`: start command, base URL, health check, browser tool order.
3. Start the app (or reuse a running one), wait for health check.
4. Browser pass: for each browser AC, drive the UI with the first available tool from the configured order. Capture a screenshot per AC and console errors. Record pass/fail with evidence.
5. Unit pass: for each (unit) AC, find or write the unit test, run the project test command.
6. Harden: for each passing browser AC without a committed test, generate a Playwright test (playwright-cli recording-stop output or written directly), tagged `@US-012`, using role based locators per the e2e standard. Run it headless to confirm it passes on its own.
7. Report: write `_runs/<timestamp>/report.md`, update story status and `tests:` paths, update index.
8. Failures: produce a short failure dossier (steps, screenshot, console, network) and stop; do not silently edit the story to match the bug.

### shape-spec (small upstream hunk)
- Remove the hard stop when not in plan mode: proceed with inline planning and say so.
- New step after Step 1: list related existing stories and propose new ones.
- Spec folder gains `stories.md` (links to story IDs).
- Final task in every plan: run verify-stories for the linked stories.

### plan-product (small hunk)
- Offer: run the PRD Creator interview instead, if installed.

### Existing commands
- Add `name` and `description` frontmatter so they work as Agent Skills. Body text unchanged except harness neutral wording for AskUserQuestion.

### Browser tool order (`agent-os/testing.yml`)

```yaml
app:
  start: npm run dev
  base_url: http://localhost:3000
  health: /
tests:
  unit: npm test
  e2e: npx playwright test --grep @US
  e2e_dir: tests/e2e/stories
browser:
  order: [playwright-cli, playwright-mcp, claude-browser, chrome-devtools-mcp]
  headed: false
  artifacts: agent-os/user-stories/_runs
```

Non JS stacks: Python projects use pytest-playwright and the same tagging; the e2e standard has a short section per language.

## 7. PRD Creator integration choice

Recommended: depend, do not vendor.
- install.sh offers to install bm-skills (`--with-prd`) by copying `skills/bm-prd-creator` from a pinned tag into `.agents/skills/`, or tells Claude Code users to run the bm-skills plugin install.
- prd-to-stories reads its outputs. No edits to upstream PRD files, so you inherit Brian's updates for free.
- Alternative if you want one command and offline installs: vendor under `vendor/bm-prd-creator/` with a `scripts/sync-prd.sh` and attribution (MIT permits this).

## 8. Backward compatibility and migration

Guarantees for existing projects:

- Paths unchanged: `agent-os/standards/`, `standards/index.yml`, `agent-os/product/`, `agent-os/specs/`.
- Command names unchanged: /discover-standards, /inject-standards, /index-standards, /plan-product, /shape-spec still work in Claude Code (installed as skills with the same names).
- `config.yml` with `version: 3.0` still parses. All new keys optional with defaults.
- Old specs untouched. New skills read old specs but never rewrite them.
- New folders (`user-stories/`, `testing.yml`) are created only if absent.
- Running the old upstream installer on a migrated project still works (it only touches standards and `.claude/commands/agent-os/`).

Upgrade paths:

| From | Detected by | Action |
|---|---|---|
| v3 (upstream) | `agent-os/standards/index.yml` and `.claude/commands/agent-os/` | Install skills, move old command copies to backup (avoids duplicate slash commands), add AGENTS.md block, add version marker, scaffold user-stories and testing.yml |
| v2 | `agent-os/instructions/`, `.claude/agents/agent-os/`, or specs with `spec.md` + `tasks.md` | Same as v3, plus: leave v2 folders in place, print what can be deleted, offer `write-user-stories --backfill` from v2 specs |
| v1 / unknown | Anything else under `agent-os/` | Report only, no changes |
| Fresh | No `agent-os/` | Normal install |

`scripts/migrate.sh`:

```
migrate.sh                      # current project, dry run (default)
migrate.sh --apply              # perform upgrade
migrate.sh --scan ~/code        # find every repo with agent-os/, print version table
migrate.sh --scan ~/code --apply --branch agent-os-upgrade
                                # batch: per repo, require clean git tree,
                                # create branch, upgrade, commit, never push
migrate.sh --rollback           # restore from agent-os/.backup-<timestamp>
```

Safety: dry run by default, refuses on a dirty git tree unless `--force`, backs up everything it moves, idempotent (second run is a no-op), writes `agent-os/.version`.

`project-install.sh --commands-only` keeps working and now means: refresh skills and commands, preserve standards and stories.

Upstream sync: add `upstream` remote, rebase monthly. Upstream file changes are limited to frontmatter and two small hunks in shape-spec and plan-product, so conflicts stay small.

## 9. Milestones

### M0. Baseline (half day)
- Add upstream remote, branch `fork/v3.1`.
- CI: shellcheck, bats, skill frontmatter lint.
- Fixture projects in `tests/fixtures/`: fresh, v2, v3 with custom standards.
- Done when: CI green, installer smoke test into each fixture passes on Linux and macOS runners.

### M1. Modernize packaging (1 day)
- Frontmatter on commands; harness neutral wording; shape-spec plan mode softening.
- Installer targets `.agents/skills/` and `.claude/skills/`, AGENTS.md managed block (marker comments, update in place).
- `.claude-plugin/` manifest; AGENTS.md + CLAUDE.md symlink in the fork itself.
- Done when: fresh fixture works in Claude Code and Codex; v3 fixture upgrades with zero changes to standards.

### M2. Migration tooling (1 day)
- `migrate.sh` with detect, dry run, apply, scan, batch branch, rollback, version marker.
- Done when: bats tests pass for v2, v3, fresh, dirty tree refusal, idempotency, rollback.

### M3. User stories (1 day)
- Template, `testing/user-stories.md` standard, index format, write-user-stories skill, shape-spec stories step.
- Done when: running shape-spec on a sample app yields stories.md and story files that pass lint.

### M4. Verify stories (2 days)
- testing.yml, verify-stories skill with references, `testing/e2e-browser.md` standard, hardening via playwright-cli, run reports, failure dossiers.
- Sample app in `tests/sample-app/` (tiny Vite or Express app) with 3 stories, one intentionally failing.
- Done when: verify-stories marks 2 verified and 1 failing with a dossier, and generated Playwright tests pass headless in CI.

### M5. PRD integration (half day)
- `--with-prd` install option, prd-to-stories skill, AGENTS.md milestone hook.
- Done when: PRD run on the sample app produces stories per milestone and the milestone prompt flow triggers verification before milestone-log.md.

### M6. Docs and dogfood (1 day)
- README section for the fork, CHANGELOG 3.1-fork, upgrade guide.
- Run `migrate.sh --scan` across your projects; batch upgrade 2 real repos first, then the rest.
- Done when: 2 real projects upgraded, verify-stories run on each, no regressions in existing commands.

## 10. Decisions and build status (2026-11-01)

Resolved:
1. Name and version: agent-os, `3.1-fork`.
2. PRD: dependency on bm-skills (installed with `--with-prd`), not vendored.
3. Browser tool: playwright-cli for agent checks, `@playwright/test` for hardened tests.
4. E2E test location default: `tests/e2e/stories/`.
5. `_runs/`: report.md committed, screenshots, logs, and auth state gitignored.
6. Tools: Claude Code, Codex, and Cursor are first class.

Built on branch `fork/v3.1`. Differences from the plan above:
- Story and e2e conventions live inside the skills (`write-user-stories/references/story-format.md`, `verify-stories/references/`) instead of profile standards, so upgrades never touch a project's `agent-os/standards/`.
- Sample app lives in `examples/sample-app/`; tests are plain bash in `tests/run.sh` (no bats dependency) with fixtures generated on the fly.
- Upstream bug noted, not changed: the installer reads `profiles/<name>/standards/`, but the default profile ships `profiles/default/global/tech-stack.md`, so fresh installs get no standards.

## Sources

- https://github.com/buildermethods/bm-skills (PRD Creator, MIT)
- https://agentskills.io/
- https://playwright.dev/docs/test-agents
- https://github.com/microsoft/playwright-cli
- https://stevekinney.com/courses/self-testing-ai-agents/runtime-tools-compared
- https://browser-use.com/posts/best-mcp-servers-to-control-a-browser
