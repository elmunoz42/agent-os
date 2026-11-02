#!/bin/bash
# Agent OS fork test suite. Plain bash, no dependencies beyond git.
# Usage: tests/run.sh [--e2e]     (--e2e also runs the sample app Playwright suite)
set -u

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
INSTALL="$ROOT/scripts/project-install.sh"
MIGRATE="$ROOT/scripts/migrate.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export NO_COLOR=1

PASS=0; FAIL=0; CURRENT=""
ok()   { PASS=$((PASS+1)); }
fail() { FAIL=$((FAIL+1)); echo "  ✗ [$CURRENT] $1"; }
assert()      { if eval "$1"; then ok; else fail "${2:-$1}"; fi; }
assert_file() { [[ -f "$1" ]] && ok || fail "missing file $1"; }
assert_no()   { [[ ! -e "$1" && ! -L "$1" ]] && ok || fail "should not exist: $1"; }
assert_grep() { grep -q -- "$1" "$2" 2>/dev/null && ok || fail "'$1' not in $2"; }
section() { CURRENT=$1; echo "• $1"; }

git_init() { git -C "$1" init -q; git -C "$1" config user.email t@t.t; git -C "$1" config user.name t; git -C "$1" add -A; git -C "$1" commit -q -m init --allow-empty; }

tree_sum() { ( cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | LC_ALL=C sort | while read -r f; do if [[ -L "$f" ]]; then echo "L $f $(readlink "$f")"; else echo "F $f $(cksum < "$f")"; fi; done ) | cksum; }
protected_sum() { ( cd "$1" && find agent-os/standards agent-os/product agent-os/specs -type f 2>/dev/null | LC_ALL=C sort | xargs cksum ) | cksum; }

SKILLS="discover-standards index-standards inject-standards plan-product shape-spec write-user-stories verify-stories prd-to-stories"

# -----------------------------------------------------------------------------
# Fixtures
# -----------------------------------------------------------------------------

make_v3() {
    local p=$1
    mkdir -p "$p/agent-os/standards/api" "$p/agent-os/product" "$p/agent-os/specs/2026-01-15-1430-comments" "$p/.claude/commands/agent-os"
    printf '# Response envelope\n\nUse { success, data }.\n' > "$p/agent-os/standards/api/response-format.md"
    printf '# Naming\n' > "$p/agent-os/standards/naming.md"
    printf '# Hand tuned index, keep my comments\nroot:\n  naming:\n    description: Naming rules\n\napi:\n  response-format:\n    description: Envelope\n' > "$p/agent-os/standards/index.yml"
    printf '# Mission\n' > "$p/agent-os/product/mission.md"
    printf '# Plan\n' > "$p/agent-os/specs/2026-01-15-1430-comments/plan.md"
    for c in discover-standards index-standards inject-standards plan-product shape-spec; do
        printf '# old %s\n' "$c" > "$p/.claude/commands/agent-os/$c.md"
    done
    printf '# My project\n\nExisting instructions.\n' > "$p/CLAUDE.md"
    printf 'node_modules/\n' > "$p/.gitignore"
    git_init "$p"
}

make_v2() {
    local p=$1
    mkdir -p "$p/agent-os/standards/global" "$p/agent-os/product" "$p/agent-os/specs/2025-10-01-auth/planning" \
             "$p/agent-os/instructions/core" "$p/.claude/agents/agent-os" "$p/.claude/commands/agent-os"
    printf '# Coding style\n' > "$p/agent-os/standards/global/coding-style.md"
    printf '# Roadmap\n' > "$p/agent-os/product/roadmap.md"
    printf '# Spec\n' > "$p/agent-os/specs/2025-10-01-auth/spec.md"
    printf -- '- [ ] task\n' > "$p/agent-os/specs/2025-10-01-auth/tasks.md"
    printf '# instr\n' > "$p/agent-os/instructions/core/create-spec.md"
    printf '# agent\n' > "$p/.claude/agents/agent-os/spec-writer.md"
    printf '# write spec v2\n' > "$p/.claude/commands/agent-os/write-spec.md"
    printf '# shape spec v2\n' > "$p/.claude/commands/agent-os/shape-spec.md"
    git_init "$p"
}

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

section "skill frontmatter is valid for Claude Code, Codex, Cursor"
assert "'$ROOT/scripts/validate-skills.sh' --strict >/dev/null" "validate-skills.sh --strict failed"

section "shell syntax"
for f in "$ROOT"/scripts/*.sh "$ROOT"/scripts/lib/*.sh; do assert "bash -n '$f'" "syntax error in $f"; done
if command -v shellcheck >/dev/null; then
    assert "shellcheck -S error '$ROOT'/scripts/*.sh '$ROOT'/scripts/lib/*.sh >/dev/null" "shellcheck errors"
fi

section "fresh install"
P="$WORK/fresh"; mkdir -p "$P"; git_init "$P"
( cd "$P" && "$INSTALL" --yes >/dev/null 2>&1 ); assert "[[ $? -eq 0 ]]" "install exited non-zero"
for s in $SKILLS; do
    assert_file "$P/.agents/skills/$s/SKILL.md"
    assert "[[ \"\$(readlink '$P/.claude/skills/$s')\" == '../../.agents/skills/$s' ]]" ".claude/skills/$s not linked"
    assert_file "$P/.claude/skills/$s/SKILL.md"
done
assert_grep "<!-- agent-os:start -->" "$P/AGENTS.md"
assert_grep "^@AGENTS.md" "$P/CLAUDE.md"
assert_file "$P/agent-os/user-stories/index.yml"
assert_file "$P/agent-os/testing.yml"
assert_grep "agent-os/.backups/" "$P/.gitignore"
assert "[[ \"\$(cat '$P/agent-os/.version')\" == '3.1-fork' ]]" "version marker"
assert "'$ROOT/scripts/validate-skills.sh' --strict '$P/.agents/skills' >/dev/null" "installed skills invalid"

section "install is idempotent"
( cd "$P" && "$INSTALL" --yes --commands-only >/dev/null 2>&1 )
assert "[[ \$(grep -c 'agent-os:start' '$P/AGENTS.md') -eq 1 ]]" "duplicate AGENTS.md block"
assert "[[ \$(grep -c '^@AGENTS.md' '$P/CLAUDE.md') -eq 1 ]]" "duplicate CLAUDE.md import"
assert "[[ \$(grep -c '^agent-os/.backups/$' '$P/.gitignore') -eq 1 ]]" "duplicate gitignore line"

section "AGENTS.md block refresh keeps user content"
printf '\n## My rules\nKeep me.\n' >> "$P/AGENTS.md"
sed -i.bak 's/This project uses/OLD TEXT This project uses/' "$P/AGENTS.md" && rm -f "$P/AGENTS.md.bak"
( cd "$P" && "$INSTALL" --yes --commands-only >/dev/null 2>&1 )
assert_grep "Keep me." "$P/AGENTS.md"
assert "! grep -q 'OLD TEXT' '$P/AGENTS.md'" "managed block not refreshed"

section "tool selection: codex and cursor only"
P="$WORK/codex-cursor"; mkdir -p "$P"
( cd "$P" && "$INSTALL" --yes --tools codex,cursor >/dev/null 2>&1 )
assert_file "$P/.agents/skills/verify-stories/SKILL.md"
assert_no "$P/.claude/skills"
assert_no "$P/CLAUDE.md"
assert_grep "agent-os:start" "$P/AGENTS.md"

section "copy mode (Windows friendly)"
P="$WORK/copy"; mkdir -p "$P"
( cd "$P" && "$INSTALL" --yes --copy >/dev/null 2>&1 )
assert "[[ -d '$P/.claude/skills/shape-spec' && ! -L '$P/.claude/skills/shape-spec' ]]" "not copied"
assert_file "$P/.claude/skills/shape-spec/SKILL.md"

section "user skills with the same name are never overwritten"
P="$WORK/user-skill"; mkdir -p "$P/.claude/skills/shape-spec" "$P/.agents/skills/verify-stories"
echo "mine" > "$P/.claude/skills/shape-spec/SKILL.md"
echo "mine" > "$P/.agents/skills/verify-stories/SKILL.md"
( cd "$P" && "$INSTALL" --yes >/dev/null 2>&1 )
assert "[[ \"\$(cat '$P/.claude/skills/shape-spec/SKILL.md')\" == mine ]]" "user claude skill overwritten"
assert "[[ \"\$(cat '$P/.agents/skills/verify-stories/SKILL.md')\" == mine ]]" "user agents skill overwritten"

section "CLAUDE.md symlinked to AGENTS.md is left alone"
P="$WORK/symlinked"; mkdir -p "$P"; printf '# Agents\n' > "$P/AGENTS.md"; ln -s AGENTS.md "$P/CLAUDE.md"
( cd "$P" && "$INSTALL" --yes >/dev/null 2>&1 )
assert "[[ -L '$P/CLAUDE.md' ]]" "CLAUDE.md symlink replaced"
assert "! grep -q '^@AGENTS.md' '$P/AGENTS.md'" "import added into AGENTS.md"
assert_grep "agent-os:start" "$P/AGENTS.md"

section "dry run writes nothing"
P="$WORK/dry"; make_v3 "$P"; before=$(tree_sum "$P")
( cd "$P" && "$INSTALL" --yes --commands-only --dry-run >/dev/null 2>&1 )
assert "[[ \"$before\" == \"\$(tree_sum '$P')\" ]]" "install --dry-run changed files"
( "$MIGRATE" "$P" >/dev/null 2>&1 )
assert "[[ \"$before\" == \"\$(tree_sum '$P')\" ]]" "migrate dry run changed files"

section "v3 project: detect and migrate"
P="$WORK/v3"; make_v3 "$P"; prot=$(protected_sum "$P"); before=$(tree_sum "$P")
assert "\"$MIGRATE\" '$P' 2>&1 | grep -q 'Detected: v3'" "v3 not detected"
( "$MIGRATE" --apply "$P" >/dev/null 2>&1 ); assert "[[ $? -eq 0 ]]" "migrate failed"
assert "[[ \"$prot\" == \"\$(protected_sum '$P')\" ]]" "standards/product/specs changed"
assert_grep "keep my comments" "$P/agent-os/standards/index.yml"
assert_no "$P/.claude/commands/agent-os/shape-spec.md"
assert_no "$P/.claude/commands/agent-os"
assert_file "$P/.claude/skills/shape-spec/SKILL.md"
assert_grep "Existing instructions." "$P/CLAUDE.md"
assert_grep "^@AGENTS.md" "$P/CLAUDE.md"
assert_grep "node_modules/" "$P/.gitignore"
assert "[[ \"\$(cat '$P/agent-os/.version')\" == '3.1-fork' ]]" "version marker"
assert "ls '$P'/agent-os/.backups/migrate-*/moved/.claude/commands/agent-os/shape-spec.md >/dev/null 2>&1" "legacy command not backed up"

section "migrate is idempotent"
after1=$(tree_sum "$P")
( "$MIGRATE" --apply --force "$P" >/dev/null 2>&1 )
assert "[[ \"$after1\" == \"\$(tree_sum '$P')\" ]]" "second migrate changed files"
assert "\"$MIGRATE\" '$P' 2>&1 | grep -q 'Detected: 3.1-fork'" "marker version not detected"

section "rollback restores the exact pre-migration tree"
( "$MIGRATE" --rollback "$P" >/dev/null 2>&1 ); assert "[[ $? -eq 0 ]]" "rollback failed"
mv "$P/agent-os/.backups" "$WORK/v3-backups"; rmdir "$P/agent-os/.backups" 2>/dev/null
assert "[[ \"$before\" == \"\$(tree_sum '$P')\" ]]" "tree differs after rollback"

section "rollback keeps stories added after migration"
P="$WORK/v3b"; make_v3 "$P"
( "$MIGRATE" --apply "$P" >/dev/null 2>&1 )
printf -- '---\nid: US-001\n---\n' > "$P/agent-os/user-stories/US-001-x.md"
( "$MIGRATE" --rollback "$P" >/dev/null 2>&1 )
assert_file "$P/agent-os/user-stories/US-001-x.md"

section "v2 project: migrate without deleting v2 content"
P="$WORK/v2"; make_v2 "$P"; prot=$(protected_sum "$P")
assert "\"$MIGRATE\" '$P' 2>&1 | grep -q 'Detected: v2'" "v2 not detected"
( "$MIGRATE" --apply "$P" >/dev/null 2>&1 ); assert "[[ $? -eq 0 ]]" "v2 migrate failed"
assert "[[ \"$prot\" == \"\$(protected_sum '$P')\" ]]" "v2 standards/product/specs changed"
assert_file "$P/agent-os/instructions/core/create-spec.md"
assert_file "$P/.claude/agents/agent-os/spec-writer.md"
assert_file "$P/.claude/commands/agent-os/write-spec.md"
assert_no "$P/.claude/commands/agent-os/shape-spec.md"
assert_file "$P/agent-os/specs/2025-10-01-auth/tasks.md"

section "dirty git tree is refused"
P="$WORK/dirty"; make_v3 "$P"; echo change >> "$P/agent-os/product/mission.md"
( "$MIGRATE" --apply "$P" >/dev/null 2>&1 ); rc=$?
assert "[[ $rc -ne 0 ]]" "dirty tree was not refused"
assert_no "$P/.agents"

section "scan and batch upgrade on branches"
B="$WORK/batch"; mkdir -p "$B/client-a" "$B/nested/client-b" "$B/plain"
make_v3 "$B/client-a"; make_v2 "$B/nested/client-b"; git_init "$B/plain"
out=$("$MIGRATE" --scan "$B" 2>&1)
assert "echo \"\$out\" | grep -q 'client-a'" "scan missed client-a"
assert "echo \"\$out\" | grep -q 'client-b'" "scan missed nested client-b"
assert "! echo \"\$out\" | grep -q '/plain'" "scan listed non agent-os repo"
mkdir -p "$B/tools"; cp -R "$ROOT" "$B/tools/agent-os"; rm -rf "$B/tools/agent-os/.git"
out2=$("$MIGRATE" --scan "$B" 2>&1)
assert "! echo \"\$out2\" | grep -q 'tools/agent-os'" "scan listed the Agent OS base repo or its examples"
rm -rf "$B/tools"
( "$MIGRATE" --scan "$B" --apply --branch agent-os-3.1 >/dev/null 2>&1 ); assert "[[ $? -eq 0 ]]" "batch failed"
for p in "$B/client-a" "$B/nested/client-b"; do
    assert "[[ \"\$(git -C '$p' branch --show-current)\" == agent-os-3.1 ]]" "branch not created in $p"
    assert "git -C '$p' log -1 --format=%s | grep -q 'Upgrade Agent OS'" "no commit in $p"
    assert "[[ -z \"\$(git -C '$p' status --porcelain)\" ]]" "uncommitted leftovers in $p"
    assert "! git -C '$p' ls-files | grep -q '.backups'" "backups committed in $p"
    assert "git -C '$p' ls-files | grep -q '.claude/skills/verify-stories'" "skill link not committed in $p"
done

section "PRD Creator dependency (--with-prd)"
PRD_SRC="${PRD_SOURCE_DIR:-}"
if [[ -z "$PRD_SRC" ]]; then
    PRD_SRC="$WORK/bm-skills"
    git clone -q --depth 1 https://github.com/buildermethods/bm-skills.git "$PRD_SRC" 2>/dev/null || PRD_SRC=""
fi
if [[ -n "$PRD_SRC" ]]; then
    P="$WORK/prd"; mkdir -p "$P"
    ( cd "$P" && "$INSTALL" --yes --prd-source "$PRD_SRC" >/dev/null 2>&1 )
    assert_file "$P/.agents/skills/bm-prd-creator/SKILL.md"
    assert_file "$P/.agents/skills/bm-prd-creator/steps/write-files.md"
    assert_file "$P/.claude/skills/bm-prd-creator/SKILL.md"
    P="$WORK/v3"; ( cd "$P" && git add -A >/dev/null 2>&1; git commit -qm wip >/dev/null 2>&1; "$MIGRATE" --apply --prd-source "$PRD_SRC" "$P" >/dev/null 2>&1 )
    assert_file "$P/.agents/skills/bm-prd-creator/SKILL.md"
else
    echo "  (skipped: bm-skills not reachable; set PRD_SOURCE_DIR)"
fi

section "testing level: demo or production"
P="$WORK/level"; mkdir -p "$P"
( cd "$P" && "$INSTALL" --yes >/dev/null 2>&1 )
assert "grep -qx 'level:' '$P/agent-os/testing.yml'" "fresh testing.yml should leave level empty so agents ask"
assert_grep "Testing level: read" "$P/AGENTS.md"
assert_file "$P/.agents/skills/write-user-stories/references/testing-levels.md"
assert_grep "Resolve the testing level" "$P/.agents/skills/verify-stories/SKILL.md"
( cd "$P" && "$INSTALL" --yes --commands-only --level demo >/dev/null 2>&1 )
assert "grep -qx 'level: demo' '$P/agent-os/testing.yml'" "--level demo not saved"
assert "[[ \$(grep -c '^level:' '$P/agent-os/testing.yml') -eq 1 ]]" "duplicate level lines"
before=$(tree_sum "$P")
( cd "$P" && "$INSTALL" --yes --commands-only --level demo >/dev/null 2>&1 )
assert "[[ \"$before\" == \"\$(tree_sum '$P')\" ]]" "re-setting the same level changed files"
( cd "$P" && "$INSTALL" --yes --commands-only --level staging >/dev/null 2>&1 ); rc=$?
assert "[[ $rc -ne 0 ]]" "invalid level accepted"
assert "grep -qx 'level: demo' '$P/agent-os/testing.yml'" "invalid level changed the file"
P="$WORK/level-v3"; make_v3 "$P"
( "$MIGRATE" --apply --level production "$P" >/dev/null 2>&1 )
assert "grep -qx 'level: production' '$P/agent-os/testing.yml'" "migrate --level not saved"
printf 'app:\n  start: npm start\n' > "$WORK/custom-testing.yml"
P="$WORK/level-custom"; mkdir -p "$P/agent-os"; cp "$WORK/custom-testing.yml" "$P/agent-os/testing.yml"
( cd "$P" && "$INSTALL" --yes --level production >/dev/null 2>&1 )
assert_grep "start: npm start" "$P/agent-os/testing.yml"
assert "grep -qx 'level: production' '$P/agent-os/testing.yml'" "level not appended to an existing testing.yml"

section "sample app fixtures are valid"
assert_file "$ROOT/examples/sample-app/agent-os/user-stories/index.yml"
for s in "$ROOT"/examples/sample-app/agent-os/user-stories/US-*.md; do
    id=$(sed -n 's/^id: //p' "$s")
    assert "grep -q '^$id:' '$ROOT/examples/sample-app/agent-os/user-stories/index.yml'" "$id missing from index"
    assert "grep -rq '@$id' '$ROOT/examples/sample-app/tests/e2e/stories/'" "$id has no tagged e2e test"
    assert "grep -qE '^sets: \\[' '$s'" "$id has no sets"
    # a story whose ACs are all (edge) belongs to the production set only
    if ! grep -E '^- AC[0-9]+' "$s" | grep -vq '(edge'; then
        assert "grep -qx 'sets: \\[production\\]' '$s'" "$id has only edge ACs but is in the demo set"
    fi
done
SA="$ROOT/examples/sample-app"
assert "grep -q '^level: ' '$SA/agent-os/testing.yml'" "sample testing.yml has no level"
assert "! grep -rE \"@prod'\" '$SA/tests/e2e/stories/' | grep -q '@demo'" "a test is tagged both @demo and @prod"
assert "! grep -rh 'test(' '$SA/tests/e2e/stories/' | grep '@US' | grep -vqE '@(demo|prod)'" "a story test has no @demo or @prod tag"

if [[ "${1:-}" == "--e2e" ]]; then
    section "sample app: story tests pass headless in Playwright"
    ( cd "$ROOT/examples/sample-app" && npm test --silent >/dev/null 2>&1 ); assert "[[ $? -eq 0 ]]" "unit tests failed"
    ( cd "$ROOT/examples/sample-app" && set -o pipefail && npx playwright test --grep @US --reporter=line 2>&1 | tail -5 ); rc=$?
    assert "[[ $rc -eq 0 ]]" "playwright story tests failed"
    demo_n=$(cd "$SA" && npx playwright test --list --grep @demo 2>/dev/null | sed -n 's/^Total: \([0-9]*\) test.*/\1/p')
    prod_n=$(cd "$SA" && npx playwright test --list --grep @prod 2>/dev/null | sed -n 's/^Total: \([0-9]*\) test.*/\1/p')
    all_n=$(cd "$SA" && npx playwright test --list --grep @US 2>/dev/null | sed -n 's/^Total: \([0-9]*\) test.*/\1/p')
    assert "[[ -n '$demo_n' && -n '$prod_n' && \$(( $demo_n + $prod_n )) -eq $all_n ]]" "demo ($demo_n) + prod ($prod_n) tests should equal all story tests ($all_n)"
    ( cd "$SA" && set -o pipefail && npx playwright test --grep @demo --reporter=line 2>&1 | tail -1 ); rc=$?
    assert "[[ $rc -eq 0 ]]" "demo set failed on its own"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
