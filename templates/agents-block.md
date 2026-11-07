<!-- agent-os:start -->
## Agent OS

This project uses [Agent OS](https://github.com/elmunoz42/agent-os) (fork 3.1). This block is managed by the installer; edit outside the markers.

- `agent-os/standards/`: coding standards. Use the inject-standards skill to pull relevant ones into context (index in `agent-os/standards/index.yml`).
- `agent-os/product/`: mission, roadmap, tech stack.
- `agent-os/specs/`: shaped specs, one folder per feature.
- `agent-os/user-stories/`: long lived user stories with acceptance criteria (index in `agent-os/user-stories/index.yml`). Status page: `python3 .agents/skills/verify-stories/scripts/stories_report.py` writes `agent-os/user-stories/report.html`.
- `agent-os/testing.yml`: testing level (demo or production), how to start the app, and how to run unit and e2e tests.

Skills (in `.agents/skills/`, linked into `.claude/skills/`): plan-product, shape-spec, discover-standards, inject-standards, index-standards, write-user-stories, verify-stories, prd-to-stories, plus bm-prd-creator and security-audit if installed.

Rules for agents:
- When a change affects user-facing behavior, find the related stories in `agent-os/user-stories/index.yml` and keep them accurate.
- Before declaring a feature, spec, or milestone done, run the verify-stories skill for its stories. A story counts as verified only when its acceptance criteria passed in a real browser and are covered by committed tests.
- When building from a PRD milestone (`_build_plan/milestones/*/prompt.md`), run verify-stories for that milestone before writing `milestone-log.md`, and include the verification result in the log.
- Security: if the security-audit skill is installed and the level is production, run a focused security review (its guidance mode) of the changed code before declaring work done, and turn each fixed finding into an `(edge)` acceptance criterion. Run its full audit only when the user asks. At any level, never commit secrets or keys. Details: `.agents/skills/write-user-stories/references/testing-levels.md`.
- Testing level: read `level:` in `agent-os/testing.yml`. Demo means happy path stories and tests, fast, moderate checks. Production means edge cases and full regression tests. If it is empty, ask the user once which applies and save the answer there before writing stories or tests.
- Never edit a story to match a bug. Report the failure instead.
<!-- agent-os:end -->
