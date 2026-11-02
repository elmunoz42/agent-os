# Testing levels: demo and production

Every project has a testing level. It decides how many stories and acceptance criteria (ACs) agents write and verify, and how much test code they leave behind.

| | demo | production |
|---|---|---|
| Purpose | Customer demos and prototypes: the happy path works, built fast | Code that ships: edge cases covered, regressions caught |
| Stories in scope | Stories whose `sets` include `demo` | All stories |
| ACs in scope | Happy path ACs only (no `(edge)` tag) | All ACs, including `(edge)` |
| Writing stories | Happy path only; do not propose edge ACs | Propose edge ACs from the checklist below |
| Browser pass | Walk each in-scope AC, one screenshot each | Same, plus console and failed network requests per AC |
| Unit ACs | Run existing tests; write new ones only for logic the demo depends on | Required: every `(unit)` AC has a test |
| Hardened e2e tests | One happy path test per story, tagged `@demo` | One test per browser AC; happy path tagged `@demo`, edge tagged `@prod` |
| Failure on an in-scope AC | Report it and offer a quick fix; demo stays usable | Blocks done until fixed or the user accepts it as a known bug |
| Time budget | Minutes per story: keep moving | As long as it takes to be thorough |

A story verified at `production` level also counts as verified for `demo`. The reverse is not true.

## Which level applies (agents: resolve this before writing or verifying stories)

1. **Explicit in the request:** `--level demo`, `--level production`, or clear wording such as for the demo, demo quality, going to prod, production ready.
2. **Project setting:** `level:` in `agent-os/testing.yml`.
3. **Otherwise ask once** with your structured question tool, then save the answer as `level:` in `agent-os/testing.yml` so you never ask again:

   ```
   What testing level should I use for this project?

   1. Demo: happy path only, fast, moderate checks (customer demos, prototypes)
   2. Production: edge cases and full regression tests (code that ships)
   ```

   If no one is available to answer (scheduled or unattended run), use `demo`, say so at the top of your report, and do not save it.

A one-off request (for example a production check on a demo project) applies to that run only. Do not change the saved level unless the user asks.

## Marking stories and ACs

- Story frontmatter `sets:` lists the sets a story belongs to: `[demo, production]` for happy path stories (the usual case), `[production]` for stories that are entirely edge cases.
- ACs without a tag are happy path and belong to both sets.
- `(edge)` marks an AC as production only. `(unit)` marks logic proven by a unit test. They combine: `(edge, unit)`.
- Changing a project from demo to production never invalidates stories; it adds edge ACs and `[production]` stories alongside them.

## Edge case checklist (production level)

Propose edge ACs where they apply. Skip anything that doesn't fit the feature.

- Empty, invalid, too long, or duplicate input; leading and trailing spaces
- Permissions: signed out, wrong role, another user's data
- Empty states and very large lists (pagination)
- Server errors and failed or slow network: a clear message, no lost input
- Double submit, refresh, back button, and deep links
- Concurrent edits, where users share data
- Keyboard only use and accessible names for controls
- Narrow (mobile) width, when the app is used on phones
