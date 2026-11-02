// Load a project with Cursor's own runtime and report what Cursor loaded.
//
// Uses the official @cursor/sdk local executor (the same code the Cursor SDK runs for
// local agents). No API key or network is needed: the executor builds the workspace,
// and Cursor's LocalCursorRulesService and AgentSkillsCursorRulesService load the
// project's rules (AGENTS.md, CLAUDE.md, .cursor/rules) and Agent Skills.
//
// tests/compat.sh prepares a copy of the SDK with two read-only observers added at the
// points where Cursor logs "... load completed", plus an export of the bundle's module
// loader. Nothing about how Cursor discovers or parses skills is changed.
//
// Usage: node cursor-probe.cjs <patched-sdk-dir> <project-dir>
// Prints one line: AOS_JSON:{"projectRules":[...],"projectSkills":[...]}
const path = require('path');
const sdkDir = path.resolve(process.argv[2]);
const project = path.resolve(process.argv[3]);

(async () => {
  const sdk = require(path.join(sdkDir, 'dist/cjs/index.js'));
  const load = sdk.__aosLoader;
  if (typeof load !== 'function') throw new Error('SDK copy is not prepared (no module loader export)');
  // Same chunk group the SDK loads before creating a local executor
  const chunks = (process.env.AOS_CURSOR_CHUNKS || '587,336').split(',').map(Number);
  await Promise.all(chunks.map((c) => load.e(c)));
  const { createLocalExecutor } = load('./src/agent/local-executor.ts');
  const ex = await createLocalExecutor({ workingDirectory: project, settingSources: ['project'] });
  for (let i = 0; i < 150 && !(globalThis.__aosSkills && globalThis.__aosRules); i++) {
    await new Promise((r) => setTimeout(r, 100));
  }
  const skills = (globalThis.__aosSkills || []).at(-1);
  const rules = (globalThis.__aosRules || []).at(-1) || [];
  if (!skills) throw new Error('Cursor skills service did not finish loading');
  const rel = (p) => (p && p.startsWith(project + path.sep) ? p.slice(project.length + 1) : null);
  const out = {
    projectRules: rules
      .filter((r) => rel(r.fullPath))
      .map((r) => ({ path: rel(r.fullPath), type: r.type?.type?.case ?? null, hasContent: !!r.content, parseError: r.parseError || null })),
    projectSkills: skills.rules
      .filter((r) => rel(r.fullPath))
      .map((r) => ({ path: rel(r.fullPath), type: r.type?.type?.case ?? null, description: r.type?.type?.value?.description ?? null, parseError: r.parseError || null, warnings: r.warnings || [] })),
  };
  console.log('AOS_JSON:' + JSON.stringify(out));
  try { await ex.dispose?.(); } catch {}
  process.exit(0);
})().catch((e) => {
  console.log('AOS_JSON:' + JSON.stringify({ error: String((e && e.message) || e) }));
  process.exit(1);
});
