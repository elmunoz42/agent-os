# Agent Instructions

Single source of truth for agents working on this repo. `CLAUDE.md` is a symlink to this file; edit only `AGENTS.md`.

## About this repo

Fork of [buildermethods/agent-os](https://github.com/buildermethods/agent-os) v3 (version `3.1-fork`). It installs Agent OS skills into projects for Claude Code, Codex, and Cursor, and adds user stories verified in a real browser and by Playwright tests.

## Layout

- `commands/agent-os/*.md`: upstream commands. Each has Agent Skills frontmatter and installs as `<name>/SKILL.md`. Keep edits to these files small so the fork rebases cleanly on upstream.
- `skills/<name>/SKILL.md`: fork skills (write-user-stories, verify-stories, prd-to-stories), flat Agent Skills layout.
- `scripts/project-install.sh`: installer (upstream flags preserved). `scripts/migrate.sh`: upgrades, batch scan, rollback. `scripts/lib/install-lib.sh`: shared logic.
- `templates/`: files the installer writes into projects (AGENTS.md block, testing.yml, story template, stories index).
- `examples/sample-app/`: tiny app with stories, a real verification run, and story tagged Playwright tests.
- `tests/run.sh`: test suite. `tests/run.sh --e2e` also runs the sample app's Playwright tests. `tests/compat.sh` checks Claude Code, Codex, and Cursor with their own tooling.

## Rules

- Backward compatibility is a hard requirement: never change paths or names under `agent-os/standards`, `agent-os/product`, `agent-os/specs`, or existing command names. Migrations must never modify those folders (migrate.sh checksums them).
- Skill names: lowercase, digits, single hyphens; folder name matches frontmatter `name`; frontmatter keys limited to those `scripts/validate-skills.sh` allows, so skills load in all three tools.
- Scripts must run on bash 3.2 (macOS): no associative arrays, no `mapfile`, no `${var,,}`. Under `set -e`, never end a function or loop body with `[[ cond ]] && cmd`; use `if`.
- Every installer write is tracked for rollback (`track_create`, `track_modify`, `backup_move`) and skipped when content is unchanged.
- External skills (PRD Creator from `buildermethods/bm-skills`, security-audit from `cloudflare/security-audit-skill`, both MIT) are dependencies listed in `EXTERNAL_SKILLS` in `scripts/lib/install-lib.sh`, pinned to tested commits. Never vendor or edit them. Bump a pin only after `tests/run.sh` and `tests/compat.sh` pass against the new commit.
- Before committing: `tests/run.sh` must pass. Add a CHANGELOG entry for user visible changes.
