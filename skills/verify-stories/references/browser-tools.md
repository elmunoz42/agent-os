# Browser tools for the acceptance pass

Use the first tool in `agent-os/testing.yml` `browser.order` that is available in this session. Default order:

1. **playwright-cli** (default, all three tools: Claude Code, Codex, Cursor)
2. **Playwright MCP** (if a `playwright` MCP server is configured)
3. **Built-in agent browser** (Claude browser pane or Claude in Chrome, Cursor browser)
4. **Chrome DevTools MCP** (diagnostics only; use alongside another tool to read console, network, performance)

## playwright-cli

Check: `playwright-cli --version` or `npx --no-install playwright-cli --version`.
Install if missing (ask first): `npm install -g @playwright/cli@latest` then `playwright-cli install-browser chromium`.
It runs headless by default and works in terminals for every agent tool.

Use a named session per run so parallel agents do not collide:

```bash
S=-s=aos-verify
playwright-cli $S open http://localhost:3000/login
playwright-cli $S snapshot                      # get element refs (e1, e2, ...)
playwright-cli $S fill e5 "owner@example.test"
playwright-cli $S fill e6 "password123" --submit
playwright-cli $S find "Pending"                # check the Then without a full snapshot
playwright-cli $S screenshot --filename=agent-os/user-stories/_runs/<run>/screenshots/US-011-AC1.png
playwright-cli $S console error                 # console errors since load
playwright-cli $S requests                      # network, when diagnosing
playwright-cli $S close
```

Turning a manual walk into test code:

```bash
playwright-cli $S recording-start
# ... perform the AC steps ...
playwright-cli $S recording-stop                # prints Playwright code
playwright-cli $S generate-locator e7           # role based locator for one element
```

Use the printed code as a starting point for the hardened test, then clean it up per `hardening-e2e.md`.

Auth reuse: after logging in once, `playwright-cli $S state-save agent-os/user-stories/_runs/<run>/auth.json` and `state-load` it in later steps. Never commit auth state files.

Token tips: prefer `find` over full `snapshot` to check a result; use `--mobile` for lighter pages only if the story is not desktop specific.

## Playwright MCP

Same flow with MCP tools: `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_type`, `browser_take_screenshot`, `browser_console_messages`. Prefer isolated mode for reproducible checks.

## Built-in agent browsers

Claude in Chrome, the Claude browser pane, and Cursor's browser act in a real browser profile. Use them only when a story needs something the others cannot provide, and never with the user's personal accounts for test data. Results are less reproducible, so hardening into a committed test matters even more.

## Chrome DevTools MCP

Do not drive flows with it. Use it to explain a failure: console stack traces, failed requests, slow responses, layout shifts. Attach its findings to the failure dossier.

## Troubleshooting

- **Running as root or in a container** (cloud agents, Codex cloud, devcontainers): Chromium refuses to start without a sandbox. Create `.playwright/cli.config.json` (gitignore it if it is environment specific):

  ```json
  { "browser": { "browserName": "chromium", "launchOptions": { "chromiumSandbox": false } } }
  ```

  then `playwright-cli $S open --config .playwright/cli.config.json <url>`. For `@playwright/test`, use `launchOptions: { chromiumSandbox: false }` only in that environment.
- **Browser download blocked** (corporate proxy, sandbox allowlist): use an installed Chrome. Add `"channel": "chrome"` to `launchOptions` for playwright-cli, and set `channel: process.env.PW_CHANNEL` in `playwright.config.ts`, then run with `PW_CHANNEL=chrome`.
- **Console noise:** a `favicon.ico` 404 is not a finding. Report console errors only when they relate to the AC's action.
- **`find` is ambiguous:** fall back to `snapshot` and read the relevant region.

## No browser tool available

Do not fake a pass. Write the hardened Playwright test from the AC and the code, run it headless with `npx playwright test`, and report that the acceptance pass was test only. Mark the AC result as `test-only` in the report.
