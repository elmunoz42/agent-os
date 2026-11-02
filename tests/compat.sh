#!/bin/bash
# Cross-tool compatibility checks against the real tools.
#
#   Claude Code: asks the claude CLI which skills it loaded (needs a logged in claude CLI)
#   Codex:       renders Codex's model input with `codex debug prompt-input` (no login
#                needed) and checks every skill was discovered from .agents/skills and
#                that the AGENTS.md block is included
#   Cursor:      loads Cursor's official SDK (@cursor/sdk) and checks that its skill
#                discovery folders and validation rules match what we install and enforce,
#                and that it reads AGENTS.md
#
# Usage: tests/compat.sh [--skip-claude] [--skip-codex] [--skip-cursor] [--claude-e2e]
#   --claude-e2e  also runs /verify-stories in Claude Code on a copy of the sample app
#                 (needs playwright-cli and a browser; takes several minutes)
set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export NO_COLOR=1
SKIP_CLAUDE=false; SKIP_CODEX=false; SKIP_CURSOR=false; CLAUDE_E2E=false
for a in "$@"; do
    case $a in
        --skip-claude) SKIP_CLAUDE=true ;;
        --skip-codex) SKIP_CODEX=true ;;
        --skip-cursor) SKIP_CURSOR=true ;;
        --claude-e2e) CLAUDE_E2E=true ;;
    esac
done

PASS=0; FAIL=0; SKIP=0; CURRENT=""
ok()   { PASS=$((PASS+1)); }
fail() { FAIL=$((FAIL+1)); echo "  ✗ [$CURRENT] $1"; }
skip() { SKIP=$((SKIP+1)); echo "  - skipped: $1"; }
check() { if eval "$1"; then ok; else fail "${2:-$1}"; fi; }
section() { CURRENT=$1; echo "• $1"; }

SKILLS="bm-prd-creator discover-standards index-standards inject-standards plan-product prd-to-stories shape-spec verify-stories write-user-stories"

# One installed project shared by all checks (with the PRD dependency)
P="$WORK/project"; mkdir -p "$P"; git -C "$P" init -q
PRD_ARGS=(--with-prd)
[[ -n "${PRD_SOURCE_DIR:-}" ]] && PRD_ARGS=(--prd-source "$PRD_SOURCE_DIR")
( cd "$P" && "$ROOT/scripts/project-install.sh" --yes "${PRD_ARGS[@]}" >/dev/null 2>&1 )
if [[ ! -f "$P/.agents/skills/bm-prd-creator/SKILL.md" ]]; then
    echo "bm-prd-creator did not install (network?). Set PRD_SOURCE_DIR to a bm-skills checkout."
    exit 1
fi

# -----------------------------------------------------------------------------
section "Claude Code loads every skill from .claude/skills"
if $SKIP_CLAUDE; then skip "--skip-claude"
elif ! command -v claude >/dev/null; then skip "claude CLI not installed"
else
    out=$(cd "$P" && timeout 300 claude -p "List the names of every skill available to you in this project, one per line, nothing else." --max-turns 2 2>&1)
    if echo "$out" | grep -qiE 'not logged in|login|authenticate|api key'; then
        skip "claude CLI not logged in"
    else
        for s in $SKILLS; do check "echo \"\$out\" | grep -qE '^[-* ]*${s}[[:space:]]*$'" "Claude Code did not list $s"; done
        out2=$(cd "$P" && timeout 300 claude -p "Quote the first rule listed under 'Rules for agents' in your project instructions, verbatim, nothing else." --max-turns 2 2>&1)
        check "echo \"\$out2\" | grep -q 'user-facing behavior'" "Claude Code did not load AGENTS.md through the CLAUDE.md import"
    fi
fi

# -----------------------------------------------------------------------------
section "Codex discovers every skill from .agents/skills and reads AGENTS.md"
if $SKIP_CODEX; then skip "--skip-codex"
else
    CODEX=""
    if command -v codex >/dev/null; then CODEX=codex
    elif ( cd "$WORK" && npm init -y >/dev/null 2>&1 && npm i @openai/codex@latest >/dev/null 2>&1 ); then CODEX="$WORK/node_modules/.bin/codex"
    fi
    if [[ -z "$CODEX" ]]; then skip "codex CLI not available (npm install @openai/codex)"
    else
        echo "  $("$CODEX" --version 2>/dev/null)"
        prompt="$WORK/codex-prompt.json"
        ( cd "$P" && "$CODEX" debug prompt-input "hello" > "$prompt" 2>"$WORK/codex-err.txt" )
        check "[[ -s '$prompt' ]]" "codex debug prompt-input produced no output: $(tail -2 "$WORK/codex-err.txt" 2>/dev/null)"
        # Codex aliases skill roots (r0, r1, ...). Find the alias for this project's .agents/skills.
        alias=$(python3 - "$prompt" "$P/.agents/skills" <<'PY'
import re, sys
d = open(sys.argv[1]).read().replace('\\"', '"')
for m in re.finditer(r'`(r\d+)` = `([^`]+)`', d):
    if m.group(2).rstrip('/').endswith(sys.argv[2].rstrip('/')) or m.group(2).rstrip('/') == sys.argv[2].rstrip('/'):
        print(m.group(1)); break
PY
)
        check "[[ -n '$alias' ]]" "Codex did not register $P/.agents/skills as a skill root"
        for s in $SKILLS; do
            check "grep -q -- '- $s: .*(file: $alias/$s/SKILL.md)' '$prompt'" "Codex did not load $s from .agents/skills"
        done
        check "grep -q 'agent-os:start' '$prompt'" "Codex prompt is missing the AGENTS.md agent-os block"
        check "! grep -qiE 'skill.*(error|invalid|failed)' '$WORK/codex-err.txt'" "Codex reported skill errors: $(grep -iE 'skill' "$WORK/codex-err.txt" | head -2)"
    fi
fi

# -----------------------------------------------------------------------------
section "Cursor runtime (official @cursor/sdk) loads AGENTS.md and every skill"
if $SKIP_CURSOR; then skip "--skip-cursor"
else
    C="$WORK/cursor"; mkdir -p "$C"
    if ! ( cd "$C" && npm init -y >/dev/null 2>&1 && npm i @cursor/sdk@latest >/dev/null 2>&1 ); then
        skip "@cursor/sdk not installable"
    else
        SDK="$C/node_modules/@cursor/sdk"
        echo "  @cursor/sdk $(node -p "require('$SDK/package.json').version")"
        # Prepare a copy of the SDK: export its module loader and observe the two
        # "load completed" points. Discovery and parsing code is left untouched.
        PSDK="$C/sdk-probe"; cp -R "$SDK" "$PSDK"; ln -s "$C/node_modules" "$PSDK/node_modules"
        chunks=$(python3 - "$PSDK/dist/cjs" <<'PY2'
import re, sys, os, glob
d = sys.argv[1]
idx = open(os.path.join(d, 'index.js')).read()
m = re.search(r'Promise\.all\(\[((?:\w\.e\(\d+\),?)+)\]\)\.then\((\w)\.bind\(\2,"\./src/agent/local-executor\.ts"\)\)', idx)
if not m: sys.exit("no local-executor chunk group found")
loader = m.group(2); ids = re.findall(r'\.e\((\d+)\)', m.group(1))
e = re.search(r'module\.exports=(\w+)\}\)\(\);\s*$', idx)
if not e: sys.exit("no module.exports tail found")
idx = idx[:e.start()] + 'module.exports=%s;module.exports.__aosLoader=%s})();' % (e.group(1), loader)
open(os.path.join(d, 'index.js'), 'w').write(idx)
hooks = {
  '"AgentSkillsCursorRulesService load completed"': '__aosSkills',
  '"LocalCursorRulesService load completed"': '__aosRules',
}
done = set()
for f in glob.glob(os.path.join(d, '*.js')):
    s = open(f).read(); changed = False
    for marker, var in hooks.items():
        pat = re.compile(r'\.then\(\((\w)=>\{try\{(\w+)\.info\((\w),' + re.escape(marker))
        mm = pat.search(s)
        if mm:
            s = s[:mm.start()] + '.then((%s=>{try{(globalThis.%s=globalThis.%s||[]).push(%s);%s.info(%s,%s' % (mm.group(1), var, var, mm.group(1), mm.group(2), mm.group(3), marker) + s[mm.end():]
            changed = True; done.add(var)
    if changed: open(f, 'w').write(s)
if done != set(hooks.values()): sys.exit("observer points not found: %s" % (set(hooks.values()) - done))
print(','.join(ids))
PY2
)
        if [[ $? -ne 0 || -z "$chunks" ]]; then
            fail "could not prepare @cursor/sdk for probing ($chunks); the SDK layout changed, update tests/compat.sh"
        else
            probe() { AOS_CURSOR_CHUNKS="$chunks" node "$ROOT/tests/cursor-probe.cjs" "$PSDK" "$1" 2>/dev/null | sed -n 's/^AOS_JSON://p'; }
            # Default install (symlinks), --tools codex,cursor, and --copy
            P2="$WORK/project-codex-cursor"; mkdir -p "$P2"
            ( cd "$P2" && "$ROOT/scripts/project-install.sh" --yes --tools codex,cursor "${PRD_ARGS[@]}" >/dev/null 2>&1 )
            for spec in "$P|.claude/skills|CLAUDE.md AGENTS.md" "$P2|.agents/skills|AGENTS.md"; do
                IFS='|' read -r proj dir want_rules <<< "$spec"
                label=$(basename "$proj")
                json=$(probe "$proj")
                echo "$json" > "$WORK/cursor-$label.json"
                problems=$(python3 - "$WORK/cursor-$label.json" "$dir" "$want_rules" "$SKILLS" <<'PY3'
import json, sys
path, want_dir, want_rules, skills = sys.argv[1], sys.argv[2], sys.argv[3].split(), sys.argv[4].split()
try:
    d = json.load(open(path))
except Exception as e:
    print("probe produced no JSON (%s)" % e); sys.exit()
if "error" in d:
    print("probe error: " + d["error"]); sys.exit()
loaded = d["projectSkills"]
names = [s["path"].split("/")[-2] for s in loaded]
for s in skills:
    if s not in names: print("Cursor did not load skill " + s)
if len(names) != len(set(names)): print("Cursor loaded duplicate skills: %d entries, %d unique" % (len(names), len(set(names))))
for s in loaded:
    if not s["path"].startswith(want_dir + "/"): print("skill loaded from unexpected folder: " + s["path"])
    if s["parseError"]: print("Cursor parse error in %s: %s" % (s["path"], s["parseError"]))
    for w in s["warnings"]: print("Cursor warning in %s: %s" % (s["path"], w))
    if s["type"] != "agentFetched": print("%s loaded as %s, expected agentFetched" % (s["path"], s["type"]))
rules = {r["path"]: r for r in d["projectRules"]}
for r in want_rules:
    if r not in rules or not rules[r]["hasContent"] or rules[r]["type"] != "global":
        print("Cursor did not load %s as a project rule" % r)
PY3
)
                if [[ -z "$problems" ]]; then
                    ok; echo "  ✓ $label: $(echo "$SKILLS" | wc -w | tr -d ' ') skills from $dir, rules: $want_rules"
                else
                    while IFS= read -r line; do fail "$label: $line"; done <<< "$problems"
                fi
            done
        fi
    fi
fi

# -----------------------------------------------------------------------------
if $CLAUDE_E2E; then
    section "Claude Code runs /verify-stories end to end on the sample app"
    if ! command -v claude >/dev/null || ! command -v playwright-cli >/dev/null; then
        skip "needs claude and playwright-cli on PATH"
    else
        E="$WORK/e2e"; cp -R "$ROOT/examples/sample-app" "$E"; rm -rf "$E/agent-os/user-stories/_runs"
        # Own port, so a concurrent sample app run (tests/run.sh --e2e) cannot interfere
        sed -i.bak -e 's#start: npm run dev#start: PORT=4199 npm run dev#' -e 's#localhost:4173#localhost:4199#' "$E/agent-os/testing.yml" && rm -f "$E/agent-os/testing.yml.bak"
        sed -i.bak -e 's/status: verified/status: ready/' -e '/^verified_level:/d' "$E"/agent-os/user-stories/*.md "$E"/agent-os/user-stories/index.yml && rm -f "$E"/agent-os/user-stories/*.bak "$E"/agent-os/user-stories/index.yml.bak
        ( cd "$E" && git init -q && "$ROOT/scripts/project-install.sh" --yes >/dev/null 2>&1 && [[ -d node_modules ]] || npm install >/dev/null 2>&1 )
        ( cd "$E" && timeout 1200 claude -p "/verify-stories all --no-harden. Use playwright-cli. Run autonomously without questions." \
            --permission-mode bypassPermissions --max-turns 80 > "$WORK/e2e.log" 2>&1 )
        check "grep -q '^status: verified' '$E/agent-os/user-stories/US-001-add-a-task.md'" "US-001 not verified"
        check "grep -q '^status: verified' '$E/agent-os/user-stories/US-002-complete-a-task.md'" "US-002 not verified"
        check "grep -q '^status: failing' '$E/agent-os/user-stories/US-003-filter-active-tasks.md'" "US-003 should stay failing"
        check "grep -q '^status: verified' '$E/agent-os/user-stories/US-004-reject-long-titles.md'" "US-004 (production only) not verified at production level"
        check "grep -qi 'level: *production' '$E'/agent-os/user-stories/_runs/*/report.md" "report does not state the production level"
        check "ls '$E'/agent-os/user-stories/_runs/*/report.md >/dev/null 2>&1" "no run report written"
        check "ls '$E'/agent-os/user-stories/_runs/*/screenshots/US-003-AC1.png >/dev/null 2>&1" "no US-003 screenshot"
        if [[ $FAIL -gt 0 ]]; then
            echo "  --- last lines of the Claude Code run ---"; tail -25 "$WORK/e2e.log" | sed 's/^/  | /'
            echo "  --- story statuses ---"; grep -H '^status' "$E"/agent-os/user-stories/US-*.md | sed 's/^/  | /'
        fi
    fi
fi

echo ""
echo "$PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
