#!/bin/bash

# =============================================================================
# Agent OS Migration Script (fork 3.1)
# Upgrades existing Agent OS projects (v2 or v3) without touching standards,
# product docs, or specs. Dry run by default.
# =============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/common-functions.sh"
source "$SCRIPT_DIR/lib/install-lib.sh"

VERBOSE="false"
DRY_RUN="true"
FORCE="false"
TOOLS="claude,codex,cursor"
LINK_MODE="symlink"
WITH_PRD="false"
PRD_REF="main"
PRD_SOURCE=""
TEST_LEVEL=""
BRANCH=""
SCAN_DIR=""
SCAN_DEPTH=4
ROLLBACK="false"
TARGET=""

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [PROJECT_DIR]

Upgrade an existing Agent OS project to $AOS_VERSION. Dry run unless --apply.
Never modifies agent-os/standards, agent-os/product, or agent-os/specs.

Options:
    --apply              Perform the upgrade (default is dry run)
    --scan <dir>         Find every project under <dir> that has agent-os/ and
                         report its version. With --apply, upgrade each one.
    --depth <n>          Max folder depth for --scan (default: 4)
    --branch <name>      In git repos: create <name>, upgrade, and commit there
                         (never pushes). Recommended for batch upgrades.
    --rollback           Undo the most recent migration in PROJECT_DIR
    --force              Allow running on a git repo with uncommitted changes
    --tools <list>       claude,codex,cursor (default: all)
    --copy               Copy skills into .claude/skills instead of symlinking
    --with-prd           Also install the Builder Methods PRD Creator skill
    --level <level>      Set the testing level: demo or production
    --prd-ref <ref>      bm-skills branch or tag (default: main)
    --prd-source <dir>   Local bm-skills checkout to install from
    --verbose            Show detailed output
    -h, --help           Show this help

Examples:
    $0                                  # dry run in current project
    $0 --apply                          # upgrade current project
    $0 --scan ~/code                    # list projects and versions
    $0 --scan ~/code --apply --branch agent-os-3.1
    $0 --rollback
EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --apply) DRY_RUN="false"; shift ;;
            --scan) SCAN_DIR="$2"; shift 2 ;;
            --depth) SCAN_DEPTH="$2"; shift 2 ;;
            --branch) BRANCH="$2"; shift 2 ;;
            --rollback) ROLLBACK="true"; shift ;;
            --force) FORCE="true"; shift ;;
            --tools) TOOLS="$2"; shift 2 ;;
            --copy) LINK_MODE="copy"; shift ;;
            --with-prd) WITH_PRD="true"; shift ;;
            --level) TEST_LEVEL="$2"; shift 2 ;;
            --prd-ref) PRD_REF="$2"; shift 2 ;;
            --prd-source) PRD_SOURCE="$2"; WITH_PRD="true"; shift 2 ;;
            --verbose) VERBOSE="true"; shift ;;
            -h|--help) show_help ;;
            -*) print_error "Unknown option: $1"; exit 1 ;;
            *) TARGET="$1"; shift ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Detection
# -----------------------------------------------------------------------------

# Prints: none | v2 | v3 | <marker version> | unknown
detect_version() {
    local dir=$1
    if [[ ! -d "$dir/agent-os" ]]; then
        echo "none"; return
    fi
    if [[ -f "$dir/agent-os/.version" ]]; then
        head -1 "$dir/agent-os/.version" | tr -d '[:space:]'; return
    fi
    if [[ -d "$dir/agent-os/instructions" || -d "$dir/agent-os/workflows" || -d "$dir/.claude/agents/agent-os" ]] \
       || ls "$dir"/agent-os/specs/*/tasks.md >/dev/null 2>&1 \
       || ls "$dir"/agent-os/specs/*/spec.md >/dev/null 2>&1; then
        if [[ ! -f "$dir/agent-os/standards/index.yml" ]]; then
            echo "v2"; return
        fi
    fi
    if [[ -f "$dir/agent-os/standards/index.yml" || -f "$dir/.claude/commands/agent-os/inject-standards.md" ]]; then
        echo "v3"; return
    fi
    if [[ -d "$dir/agent-os/standards" || -d "$dir/agent-os/product" || -d "$dir/agent-os/specs" ]]; then
        echo "v2"; return
    fi
    echo "unknown"
}

git_state() {
    local dir=$1
    if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "no-git"; return
    fi
    if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
        echo "dirty"
    else
        echo "clean"
    fi
}

# -----------------------------------------------------------------------------
# Migration of one project
# -----------------------------------------------------------------------------

# Checksums of content that must never change during migration
protected_checksum() {
    local dir=$1
    ( cd "$dir" && find agent-os/standards agent-os/product agent-os/specs -type f 2>/dev/null \
        | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done ) | cksum | awk '{print $1}'
}

migrate_project() {
    PROJECT_DIR=$1
    local version gstate
    version=$(detect_version "$PROJECT_DIR")
    gstate=$(git_state "$PROJECT_DIR")

    print_section "Agent OS migration: $PROJECT_DIR"
    echo "  Detected: $version | git: $gstate | tools: $TOOLS"

    case "$version" in
        none)
            print_warning "No agent-os/ folder. Use project-install.sh for a fresh install."
            return 0 ;;
        unknown)
            print_warning "agent-os/ found but layout not recognized. Report only, no changes."
            return 0 ;;
        "$AOS_VERSION")
            echo "  Already on $AOS_VERSION. Refreshing skills and agent files."
            ;;
    esac

    if [[ "$version" == "v2" ]]; then
        echo ""
        echo "  v2 notes: v2 folders (instructions, workflows, .claude/agents/agent-os) and"
        echo "  v2 commands without a matching skill are left in place. Delete them when"
        echo "  you no longer use them. Old specs stay readable; run /write-user-stories"
        echo "  backfill to turn them into user stories."
    fi

    if [[ "$DRY_RUN" != "true" && "$gstate" == "dirty" && "$FORCE" != "true" ]]; then
        print_error "Uncommitted changes in $PROJECT_DIR. Commit or stash first, or pass --force."
        return 1
    fi

    if [[ "$DRY_RUN" != "true" && -n "$BRANCH" && "$gstate" != "no-git" ]]; then
        if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
            git -C "$PROJECT_DIR" checkout -q "$BRANCH"
        else
            git -C "$PROJECT_DIR" checkout -q -b "$BRANCH"
        fi
        echo "  On branch: $BRANCH"
    fi

    local before=""
    [[ "$DRY_RUN" != "true" ]] && before=$(protected_checksum "$PROJECT_DIR")

    echo ""
    [[ "$DRY_RUN" == "true" ]] && echo "  Planned changes:"
    begin_change_session "migrate"
    install_skills
    retire_colliding_commands
    update_agents_md
    update_claude_md
    scaffold_stories
    if [[ "$WITH_PRD" == "true" ]]; then
        install_prd_skill || true
    fi
    if [[ -n "$TEST_LEVEL" ]]; then set_testing_level "$TEST_LEVEL" || return 1; fi
    write_version_marker
    local session="$BACKUP_DIR"
    end_change_session
    BACKUP_DIR="$session"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        print_success "Dry run only. Re-run with --apply to make these changes."
        return 0
    fi

    local after
    after=$(protected_checksum "$PROJECT_DIR")
    if [[ "$before" != "$after" ]]; then
        print_error "Protected content changed unexpectedly. Rolling back."
        [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]] && rollback_session "$BACKUP_DIR"
        return 1
    fi

    if [[ -n "$BRANCH" && "$gstate" != "no-git" ]]; then
        git -C "$PROJECT_DIR" add -A -- agent-os .agents .claude AGENTS.md CLAUDE.md .gitignore 2>/dev/null || true
        # Backups are gitignored; make sure they never get staged
        git -C "$PROJECT_DIR" reset -q -- agent-os/.backups 2>/dev/null || true
        if ! git -C "$PROJECT_DIR" diff --cached --quiet; then
            git -C "$PROJECT_DIR" commit -q -m "Upgrade Agent OS to $AOS_VERSION

Skills in .agents/skills (Codex, Cursor) linked into .claude/skills (Claude Code),
AGENTS.md agent-os block, CLAUDE.md import, user stories and testing scaffold.
Standards, product docs, and specs unchanged."
            echo "  Committed on $BRANCH (not pushed)"
        fi
    fi

    echo ""
    print_success "Migrated to $AOS_VERSION. Standards, product, and specs unchanged."
    echo "  Undo with: $0 --rollback $PROJECT_DIR"
}

rollback_project() {
    PROJECT_DIR=$1
    local latest
    latest=$(ls -1d "$PROJECT_DIR"/agent-os/.backups/migrate-* "$PROJECT_DIR"/agent-os/.backups/install-* 2>/dev/null \
        | grep -v '\.rolled-back$' | awk -F/ '{print $NF"|"$0}' | sed 's/^[a-z]*-//' | LC_ALL=C sort | tail -1 | cut -d'|' -f2)
    if [[ -z "$latest" ]]; then
        print_error "No migration backups found in $PROJECT_DIR/agent-os/.backups/"
        return 1
    fi
    print_status "Rolling back $(basename "$latest")..."
    rollback_session "$latest"
    mv "$latest" "${latest}.rolled-back"
    print_success "Rolled back. Backup kept at ${latest#$PROJECT_DIR/}.rolled-back"
}

# -----------------------------------------------------------------------------
# Scan
# -----------------------------------------------------------------------------

is_base_install() {
    [[ -f "$1/scripts/project-install.sh" && -d "$1/profiles" ]]
}

# True if dir or any ancestor (up to the scan root) is an Agent OS base install
inside_base_install() {
    local dir=$1 root=$2
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        is_base_install "$dir" && return 0
        [[ "$dir" == "$root" ]] && break
        dir=$(dirname "$dir")
    done
    return 1
}

# A project agent-os folder has at least one of these
looks_like_project_agent_os() {
    local d=$1
    [[ -d "$d/standards" || -d "$d/product" || -d "$d/specs" || -d "$d/user-stories" \
       || -d "$d/instructions" || -f "$d/.version" ]]
}

scan_projects() {
    local root=$1
    find "$root" -maxdepth "$SCAN_DEPTH" -type d -name agent-os \
        -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' \
        -not -path '*/.agents/*' -not -path '*/.claude/*' 2>/dev/null \
        | while IFS= read -r d; do
            local p
            p=$(dirname "$d")
            looks_like_project_agent_os "$d" || continue
            is_base_install "$d" && continue
            inside_base_install "$p" "$root" && continue
            echo "$p"
        done | LC_ALL=C sort
}

run_scan() {
    local root=$1
    print_section "Agent OS projects under $root"
    local projects
    projects=$(scan_projects "$root")
    if [[ -z "$projects" ]]; then
        echo "  None found."
        return 0
    fi
    printf "  %-10s %-8s %s\n" "VERSION" "GIT" "PROJECT"
    while IFS= read -r p; do
        printf "  %-10s %-8s %s\n" "$(detect_version "$p")" "$(git_state "$p")" "$p"
    done <<< "$projects"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "Dry run. Add --apply (and ideally --branch <name>) to upgrade all of these."
        return 0
    fi

    local ok=0 failed=0 skipped=0 v
    while IFS= read -r p; do
        v=$(detect_version "$p")
        if [[ "$v" == "unknown" || "$v" == "none" ]]; then
            (( skipped++ )) || true
            continue
        fi
        if ( migrate_project "$p" ); then
            (( ok++ )) || true
        else
            (( failed++ )) || true
        fi
    done <<< "$projects"
    echo ""
    print_success "Batch complete: $ok upgraded, $failed failed, $skipped skipped"
    [[ "$failed" -eq 0 ]]
}

main() {
    parse_arguments "$@"
    if [[ -n "$TEST_LEVEL" && "$TEST_LEVEL" != demo && "$TEST_LEVEL" != production ]]; then
        print_error "--level must be demo or production (got: $TEST_LEVEL)"; exit 1
    fi
    if [[ -n "$SCAN_DIR" ]]; then
        run_scan "$(cd "$SCAN_DIR" && pwd)"
        return $?
    fi
    local dir
    dir=$(cd "${TARGET:-$(pwd)}" && pwd)
    if [[ "$dir" == "$BASE_DIR" ]]; then
        print_error "Run this from a project, not the Agent OS base install."
        exit 1
    fi
    if [[ "$ROLLBACK" == "true" ]]; then
        rollback_project "$dir"
        return $?
    fi
    migrate_project "$dir"
}

main "$@"
