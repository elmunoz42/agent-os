<!-- agent-os:start -->
## Agent OS

This project uses [Agent OS](https://github.com/elmunoz42/agent-os) (fork 3.1). This block is managed by the installer; edit outside the markers.

- `agent-os/standards/`: coding standards. Use the inject-standards skill to pull relevant ones into context (index in `agent-os/standards/index.yml`).
- `agent-os/product/`: mission, roadmap, tech stack.
- `agent-os/specs/`: shaped specs, one folder per feature.
- `agent-os/user-stories/`: long lived user stories with acceptance criteria (index in `agent-os/user-stories/index.yml`).
- `agent-os/testing.yml`: how to start the app and run unit and e2e tests.

Skills (in `.agents/skills/`, linked into `.claude/skills/`): plan-product, shape-spec, discover-standards, inject-standards, index-standards, write-user-stories, verify-stories, prd-to-stories, and bm-prd-creator if installed.

Rules for agents:
- When a change affects user-facing behavior, find the related stories in `agent-os/user-stories/index.yml` and keep them accurate.
- Before declaring a feature, spec, or milestone done, run the verify-stories skill for its stories. A story counts as verified only when its acceptance criteria passed in a real browser and are covered by committed tests.
- When building from a PRD milestone (`_build_plan/milestones/*/prompt.md`), run verify-stories for that milestone before writing `milestone-log.md`, and include the verification result in the log.
- Never edit a story to match a bug. Report the failure instead.
<!-- agent-os:end -->
