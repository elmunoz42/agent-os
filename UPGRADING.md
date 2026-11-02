# Upgrading to Agent OS 3.1-fork

## What never changes

- `agent-os/standards/` and `standards/index.yml`
- `agent-os/product/`
- `agent-os/specs/` (v2 and v3 specs stay readable as they are)
- Command names: /discover-standards, /inject-standards, /index-standards, /plan-product, /shape-spec

`migrate.sh` checksums these folders before and after, and rolls back automatically if anything differs.

## What gets added

| Path | Purpose |
|---|---|
| `.agents/skills/<name>/` | Skills for Codex and Cursor (canonical copy) |
| `.claude/skills/<name>` | Links to the above for Claude Code (`--copy` for real folders) |
| `AGENTS.md` | Managed block between `<!-- agent-os:start -->` and `<!-- agent-os:end -->`; your content outside it is kept |
| `CLAUDE.md` | One `@AGENTS.md` import line appended (skipped if CLAUDE.md already links to AGENTS.md) |
| `agent-os/user-stories/index.yml` | Story index |
| `agent-os/testing.yml` | App start command, URLs, test commands, browser tool order |
| `agent-os/.version` | `3.1-fork`, for future migrations |
| `.gitignore` | Backups and run screenshots and logs |

Skills that already exist with the same name and were not installed by Agent OS are never overwritten (a warning is printed).

## What moves

`.claude/commands/agent-os/<name>.md` files whose names match a skill are moved to `agent-os/.backups/<session>/moved/`, so Claude Code does not show two `/shape-spec` entries. Other legacy commands (for example v2 `write-spec`) stay where they are. Use `--keep-legacy-commands` with project-install.sh to keep everything.

## From v3

```bash
cd your-project
~/agent-os/scripts/migrate.sh            # dry run: lists every planned change
~/agent-os/scripts/migrate.sh --apply
```

Equivalent: `~/agent-os/scripts/project-install.sh --commands-only --yes`.

## From v2

Same command. v2 is detected by `agent-os/instructions/`, `.claude/agents/agent-os/`, or v2 style specs (`spec.md`, `tasks.md`) without a standards index. v2 folders are left in place; delete them when you no longer use them. To turn old specs into stories: `/write-user-stories backfill`.

## Many projects at once

```bash
~/agent-os/scripts/migrate.sh --scan ~/code                                   # report only
~/agent-os/scripts/migrate.sh --scan ~/code --apply --branch agent-os-3.1     # upgrade all
```

- Finds every folder with `agent-os/` up to depth 4 (`--depth n` to change), skipping node_modules, vendor, and the Agent OS repo itself.
- Refuses repos with uncommitted changes (`--force` to override).
- With `--branch`: checks out or creates the branch, upgrades, and commits. Never pushes. Review and merge per repo.
- Add `--with-prd` to also install the PRD Creator everywhere.

## Rollback

```bash
~/agent-os/scripts/migrate.sh --rollback [project]
```

Undoes the most recent install or migration from its manifest in `agent-os/.backups/`: removes added skills and files, restores modified files, and moves retired commands back. Story files you created after migrating are kept. If you used `--branch`, you can also just delete the branch.

## After upgrading

1. Check `agent-os/testing.yml` (or let `/verify-stories` detect and fill it in).
2. `/write-user-stories backfill` for existing features, or let `/shape-spec` add stories as you go.
3. `/verify-stories` to run the first browser pass and generate story tests.
