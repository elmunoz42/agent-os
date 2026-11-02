---
name: verify-stories
description: Verify user stories in agent-os/user-stories/ at demo or production level by walking their acceptance criteria in a real browser, running unit tests, and hardening passing checks into committed Playwright tests. Use when the user runs /verify-stories, before declaring a feature, spec, or PRD milestone done, or when asked to test the app like a user.
---

# Verify Stories

Prove that user stories work, two ways:

1. **Acceptance:** you walk each browser AC in a real browser, like a user, and capture evidence.
2. **Regression:** every passing AC is covered by a committed automated test (Playwright e2e or unit) that runs without you.

A story is `verified` only when both hold.

How deep you go depends on the project's **testing level**: `demo` (happy path, fast, moderate checks) or `production` (edge cases, full regression tests). The levels are defined in `../write-user-stories/references/testing-levels.md`. Read it before Step 1.

## Important Guidelines

- **Ask with your structured question tool** (AskUserQuestion in Claude Code; the ask or question tool in Cursor and Codex), or in chat if none is available. Keep questions to blockers only.
- **Never change a story to match the app.** If behavior differs from an AC, the story is failing. Report it.
- **Never weaken a test to make it pass** (no deleted assertions, no blanket timeouts, no skipped tests) unless the user agrees and the story is marked failing.
- **Use test data, not personal accounts.** Follow the story's Test data section and project seed files.
- **Match the level.** At demo level, do not test edge ACs or write edge tests, and keep moving. At production level, do not skip edge ACs.
- Read `references/browser-tools.md` before the browser pass and `references/hardening-e2e.md` before writing tests.

## Usage

```
/verify-stories                    # all stories with status ready or failing
/verify-stories US-012             # one story
/verify-stories US-011 US-012
/verify-stories tag:team           # by tag
/verify-stories spec:<folder>      # stories listed in that spec's stories.md
/verify-stories prd-m2             # stories from PRD milestone 2
/verify-stories all                # everything except draft
/verify-stories --no-harden        # browser and unit checks only, write no tests
/verify-stories --level demo       # this run only: happy path stories and ACs
/verify-stories --level production # this run only: everything, including edge ACs
```

In Codex, invoke as `$verify-stories US-012` or via `/skills`.

## Process

### Step 0: Resolve the testing level

Follow "Which level applies" in `../write-user-stories/references/testing-levels.md`: an explicit `--level` or clear wording in the request wins, then `level:` in `agent-os/testing.yml`, otherwise ask once and save the answer there. State the level in your first progress message, for example: Verifying at demo level (happy path only).

### Step 1: Select stories

Read `agent-os/user-stories/index.yml`, resolve the scope above, and open only the selected story files. Skip `draft` stories unless named explicitly (then ask whether the feature exists yet).

Then apply the level:

- **demo:** keep only stories whose `sets` include `demo`, and within them only ACs without `(edge)`. Stories without `sets` count as `[demo, production]`.
- **production:** keep every selected story and every AC.

A story named explicitly that is out of scope for the level (e.g. a `[production]` story at demo level) is still verified, and you say so.

### Step 2: Load testing config

Read `agent-os/testing.yml`. If it is missing or still has template defaults that do not match the project (e.g. no `dev` script in package.json), detect the real values:

- Start command: package.json scripts (dev, start), Procfile, `bin/dev`, `manage.py runserver`, `docker compose up`.
- Base URL and port: framework defaults or the start script.
- Unit test command: package.json test, pytest, `bin/rails test`, go test.
- E2E: existing `playwright.config.*`. If none, plan to add one (see hardening reference).

Propose the values once, then save them to `agent-os/testing.yml`.

### Step 3: Start the app

- If `reuse_running` and the health URL returns 200, use the running app.
- Otherwise start it in the background with your tool's background process support, log to `agent-os/user-stories/_runs/<run>/app.log`, and poll the health URL for up to 90 seconds.
- If it will not start, stop and report the log tail. Do not mark stories failing for an app that never started.

`<run>` is `YYYY-MM-DD-HHMM`.

### Step 4: Browser pass (acceptance)

Pick the first available tool from `browser.order` (see `references/browser-tools.md`). For each story, for each browser AC:

1. Set up the Given: navigate, log in with test data, create needed records (prefer UI or seed scripts the app already has).
2. Do the When like a user: click visible controls by their labels, fill forms, press keys.
3. Check the Then: confirm the observable result in a snapshot (text, element state, URL).
4. Save a screenshot to `_runs/<run>/screenshots/US-012-AC1.png`.
5. Check the console for errors. A console error tied to the action is a finding even if the AC passed.
6. Record: pass, fail, or blocked (with reason).

Keep a short step log per AC. It becomes the test script in Step 6 and the dossier on failure.

### Step 5: Unit pass

For each in-scope `(unit)` AC (at demo level, only where the demo depends on it; otherwise run the existing tests and move on):

1. Look for an existing test that proves it (search for the story ID, then for the rule).
2. If none exists, write one next to the code under test, following the project's test conventions (`agent-os/standards/testing/` if present). Name or tag it with the story ID and AC, e.g. `it('US-012 AC2: rejects revoked token', ...)`.
3. Run the unit command (scoped to those files when possible). Record pass or fail.

### Step 6: Harden browser ACs (regression)

Skip with `--no-harden`. For each browser AC that passed and has no committed e2e test:

- **demo:** one happy path test per story that walks its main ACs end to end, tagged `@US-012 @demo`.
- **production:** one test per browser AC. Happy path ACs are tagged `@US-012 @demo` and edge ACs `@US-012 @prod`.

1. Write or extend `{tests.e2e_dir}/US-012.spec.ts` (one file per story) following `references/hardening-e2e.md`.
2. Tag tests with the story ID and set so they can be selected: `test('US-012 AC1: ... @US-012 @demo', ...)`.
3. Run only that file headless: `npx playwright test {file}`. It must pass on its own, without your browser session.
4. If it fails while the manual check passed, fix the test (locators, waits on real conditions, test data setup), not the assertion.

### Step 7: Update stories and report

For each story:

- All in-scope ACs passed and covered by committed tests: `status: verified`, `verified_level: demo` or `production`, `last_verified: <date>`, fill `tests.e2e` and `tests.unit` paths. Never lower an existing `verified_level: production` because of a demo run.
- Any in-scope AC failed: `status: failing`, keep `tests` paths, do not touch the AC text. At demo level, offer a quick fix so the demo stays usable; at production level the story blocks done until fixed or accepted as a known bug.
- Blocked ACs only (missing data, external service): leave status as is and say why.

Update the matching index entries. Then write `_runs/<run>/report.md`:

```markdown
# Story verification 2026-11-03 14:30

Level: production | App: http://localhost:3000 (npm run dev) | Browser tool: playwright-cli

| Story | AC | Browser | Unit | Test | Result |
|---|---|---|---|---|---|
| US-011 | AC1 | pass | | tests/e2e/stories/US-011.spec.ts | pass |
| US-012 | AC2 | | fail | src/invites/revoke.test.ts | fail |

## Failures

### US-012 AC2: revoked token rejected
- Expected: request with revoked token returns 410
- Actual: 200, invite accepted
- Evidence: unit test output below; screenshot screenshots/US-012-AC1.png
- Suspected area: src/invites/accept.ts (token status not checked)
```

### Step 8: Tell the user

Summarize in a few lines: the level used; counts of verified, failing, blocked; at demo level, how many edge ACs and `[production]` stories were skipped; new test files; the report path. For failures, ask whether to fix the code now. Stop the app if you started it.

## When called from other workflows

- **shape-spec final task:** scope is `spec:<folder>`.
- **PRD milestone:** scope is `prd-m<N>`. Put the summary table in the milestone's `milestone-log.md` under `## Verification`.
- **Before saying done** on any user facing change: run for the stories the change touched.
