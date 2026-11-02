<img width="1200" height="675" alt="Agent OS" src="https://github.com/user-attachments/assets/97ad4491-d199-4b9b-9482-ae710291dfb4" />

## This fork: Agent OS 3.1-fork

Fork of Agent OS v3 by Builder Methods, modernized for Claude Code, Codex, and Cursor, with user stories that agents verify in a real browser and harden into Playwright tests. Fully backward compatible with existing v3 projects, with a migration path for v2.

**What's added**

- **Agent Skills for three tools.** Every command is a valid Agent Skill. Skills install once to `.agents/skills/` (Codex, Cursor) and are linked into `.claude/skills/` (Claude Code). `AGENTS.md` gets a managed agent-os block; `CLAUDE.md` imports it.
- **User stories.** `agent-os/user-stories/` holds long lived stories with Given/When/Then acceptance criteria and an `index.yml`.
- **Browser verified stories.** `/verify-stories` starts your app, walks each acceptance criterion in a real browser (playwright-cli by default), runs unit tests, then hardens passing checks into committed Playwright tests tagged `@US-###`.
- **PRD Creator integration.** Installs the Builder Methods [PRD Creator](https://github.com/buildermethods/bm-skills) as a dependency; `/prd-to-stories` turns its milestones into stories and wires milestone verification.
- **Safe upgrades.** `migrate.sh` upgrades one project or a whole folder of repos, on a branch, with dry run and rollback. Standards, product docs, and specs are never modified.

### Install

```bash
git clone https://github.com/elmunoz42/agent-os.git ~/agent-os
cd /path/to/your/project
~/agent-os/scripts/project-install.sh --with-prd
```

Useful flags: `--tools claude,codex,cursor` (default all), `--copy` (no symlinks, for Windows), `--commands-only` (keep standards), `--dry-run`, `--yes`.

### Upgrade existing projects

```bash
~/agent-os/scripts/migrate.sh                       # dry run in the current project
~/agent-os/scripts/migrate.sh --apply
~/agent-os/scripts/migrate.sh --scan ~/code         # list every Agent OS project and its version
~/agent-os/scripts/migrate.sh --scan ~/code --apply --branch agent-os-3.1
~/agent-os/scripts/migrate.sh --rollback
```

See [UPGRADING.md](UPGRADING.md) for details.

### Using it in each tool

| | Claude Code | Codex | Cursor |
|---|---|---|---|
| Skills read from | `.claude/skills/` (linked) | `.agents/skills/` | `.agents/skills/` (also reads `.claude/skills/`) |
| Instructions | `CLAUDE.md` imports `AGENTS.md` | `AGENTS.md` | `AGENTS.md` |
| Invoke | `/verify-stories US-012` | `$verify-stories US-012` or `/skills` | `/verify-stories US-012` |
| Plan mode for /shape-spec | Plan mode | Plan mode if available, else read only approvals | Plan mode |

Cursor reads both skill folders and resolves the symlinks, so with the default install each skill appears once (verified with Cursor's own runtime, see Tests). With `--copy`, the copies are separate files and Cursor lists each skill twice; prefer symlinks (on Windows, enable Developer Mode and `git config core.symlinks true`), or use `--tools codex,cursor` where you don't need Claude Code.

Claude Code users can also install the skills globally as a plugin: `/plugin marketplace add elmunoz42/agent-os`, then `/plugin install agent-os`. You still run `project-install.sh` once per project to scaffold `agent-os/`.

### Workflow

1. `/plan-product` (or `/bm-prd-creator` for a new app, then `/prd-to-stories`)
2. `/discover-standards`, `/inject-standards`
3. `/shape-spec` links or writes stories and ends every plan with a verification task
4. Build
5. `/verify-stories spec:<folder>` (or `prd-m1`, a story ID, a tag)

See `examples/sample-app/` for stories, a real verification report with screenshots, and story tagged Playwright tests, including a known failing story.

### Tests

```bash
tests/run.sh               # installer, migration, rollback, batch, skill validation
tests/run.sh --e2e         # plus the sample app's Playwright story tests
tests/compat.sh            # checks against the real tools (see below)
tests/compat.sh --claude-e2e   # plus Claude Code running /verify-stories on the sample app
```

`tests/compat.sh` checks each tool with its own code (CI runs the Codex and Cursor checks on every push):

- Claude Code: the claude CLI lists all installed skills and loads AGENTS.md through the CLAUDE.md import.
- Codex: `codex debug prompt-input` (no login needed) shows every skill discovered from `.agents/skills` and the AGENTS.md block in the model input.
- Cursor: runs Cursor's own local runtime from the official `@cursor/sdk` package (no API key needed) on an installed project and checks that it loads AGENTS.md and CLAUDE.md as project rules and every skill exactly once, with no parse errors or warnings, for both the default install and `--tools codex,cursor`.

---

## Agents that build the way you would

[Agent OS](https://buildermethods.com/agent-os) helps you shape better specs, keeps agents aligned in a lightweight system that fits how you already build.

Works alongside Claude Code, Cursor, Antigravity, and other AI tools. Any language, any framework.

**Core capabilities:**

- **Discover Standards** — Extract patterns and conventions from your codebase into documented standards
- **Deploy Standards** — Intelligently inject relevant standards based on what you're building
- **Shape Spec** — Create better plans that lead to better builds
- **Index Standards** — Keep your standards organized and discoverable

---

### Documentation & Installation

Docs, installation, usage, & best practices 👉 [It's all here](https://buildermethods.com/agent-os)

---

### Follow updates & releases

Read the [changelog](CHANGELOG.md)

[Subscribe to be notified of major new releases of Agent OS](https://buildermethods.com/agent-os)

---

### Created by Brian Casel @ Builder Methods

Created by Brian Casel, the creator of [Builder Methods](https://buildermethods.com), where Brian helps professional software developers and teams build with AI.

Get Brian's free resources on building with AI:
- [Builder Briefing newsletter](https://buildermethods.com)
- [YouTube](https://youtube.com/@briancasel)

Join [Builder Methods Pro](https://buildermethods.com/pro) for official support and connect with our community of AI-first builders:

