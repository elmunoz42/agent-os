#!/bin/bash
# =============================================================================
# Agent OS install library (fork 3.1)
# Shared by project-install.sh and migrate.sh. Bash 3.2 compatible (macOS).
#
# Expects these globals from the caller:
#   BASE_DIR      agent-os base install (this repo)
#   PROJECT_DIR   target project
#   DRY_RUN       true|false
#   TOOLS         comma list: claude,codex,cursor
#   LINK_MODE     symlink|copy
# =============================================================================

AOS_VERSION="3.1-fork"
AOS_MARKER=".agent-os-managed"
AOS_BLOCK_START="<!-- agent-os:start -->"
AOS_BLOCK_END="<!-- agent-os:end -->"

MANIFEST=""
BACKUP_DIR=""

# -----------------------------------------------------------------------------
# Change tracking (enables rollback)
# -----------------------------------------------------------------------------

# Start a backup session. Creates agent-os/.backups/<ts>/manifest.txt
begin_change_session() {
    local label=$1
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="$PROJECT_DIR/agent-os/.backups/${label}-${ts}"
    local n=1
    while [[ -e "$BACKUP_DIR" || -e "${BACKUP_DIR}.rolled-back" ]]; do
        BACKUP_DIR="$PROJECT_DIR/agent-os/.backups/${label}-${ts}-$n"
        (( n++ )) || true
    done
    if [[ "$DRY_RUN" == "true" ]]; then
        MANIFEST=""
        return
    fi
    mkdir -p "$BACKUP_DIR"
    MANIFEST="$BACKUP_DIR/manifest.txt"
    : > "$MANIFEST"
}

# Remove the session folder if nothing was changed
end_change_session() {
    if [[ -n "$MANIFEST" && -f "$MANIFEST" && ! -s "$MANIFEST" ]]; then
        rm -rf "$BACKUP_DIR"
        rmdir "$PROJECT_DIR/agent-os/.backups" 2>/dev/null || true
        BACKUP_DIR=""
    fi
    MANIFEST=""
    return 0
}

_rel() {
    local p=$1
    echo "${p#$PROJECT_DIR/}"
}

track() {
    [[ -n "$MANIFEST" ]] && echo "$*" >> "$MANIFEST"
    return 0
}

# Record that a path did not exist and is being created
track_create() {
    local path=$1
    if [[ ! -e "$path" && ! -L "$path" ]]; then
        track "created $(_rel "$path")"
    fi
}

# Back up a file before modifying it (or record creation if new)
track_modify() {
    local path=$1
    if [[ -n "$MANIFEST" ]]; then
        if [[ -e "$path" ]]; then
            local rel
            rel=$(_rel "$path")
            if ! grep -q "^modified $rel$" "$MANIFEST" && ! grep -q "^created $rel$" "$MANIFEST"; then
                mkdir -p "$BACKUP_DIR/files/$(dirname "$rel")"
                cp -p "$path" "$BACKUP_DIR/files/$rel"
                track "modified $rel"
            fi
        else
            track_create "$path"
        fi
    fi
}

# Move a path into the backup folder (never delete user content)
backup_move() {
    local path=$1
    local rel
    rel=$(_rel "$path")
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would move to backup: $rel"
        return
    fi
    mkdir -p "$BACKUP_DIR/moved/$(dirname "$rel")"
    mv "$path" "$BACKUP_DIR/moved/$rel"
    track "moved $rel"
    print_verbose "Moved to backup: $rel"
}

# -----------------------------------------------------------------------------
# Tool selection
# -----------------------------------------------------------------------------

tool_enabled() {
    local tool=$1
    case ",$TOOLS," in
        *",$tool,"*) return 0 ;;
    esac
    return 1
}

# -----------------------------------------------------------------------------
# Skill discovery in the base install
# -----------------------------------------------------------------------------

# Prints one line per skill: name|source_path|kind
#   kind=command  source is commands/agent-os/<name>.md (becomes SKILL.md)
#   kind=folder   source is skills/<name>/ (copied as is)
list_base_skills() {
    local f
    for f in "$BASE_DIR"/commands/agent-os/*.md; do
        [[ -f "$f" ]] || continue
        echo "$(basename "$f" .md)|$f|command"
    done
    for f in "$BASE_DIR"/skills/*/; do
        [[ -f "$f/SKILL.md" ]] || continue
        f=${f%/}
        echo "$(basename "$f")|$f|folder"
    done
}

list_base_skill_names() {
    list_base_skills | cut -d'|' -f1
}

# -----------------------------------------------------------------------------
# Skill installation
# -----------------------------------------------------------------------------

# Copy one skill into a destination folder
_write_skill() {
    local src=$1 kind=$2 dest=$3
    mkdir -p "$dest"
    if [[ "$kind" == "command" ]]; then
        cp "$src" "$dest/SKILL.md"
    else
        cp -R "$src"/. "$dest"/
    fi
    echo "$AOS_VERSION" > "$dest/$AOS_MARKER"
}

# True if an installed managed skill already matches its source
_skill_unchanged() {
    local src=$1 kind=$2 dest=$3
    [[ -d "$dest" && ! -L "$dest" ]] || return 1
    if [[ "$kind" == "command" ]]; then
        cmp -s "$src" "$dest/SKILL.md" || return 1
        [[ "$(ls -A "$dest" | grep -vx "$AOS_MARKER" | grep -vx SKILL.md)" == "" ]] || return 1
    else
        diff -rq -x "$AOS_MARKER" "$src" "$dest" >/dev/null 2>&1 || return 1
    fi
    [[ "$(cat "$dest/$AOS_MARKER" 2>/dev/null)" == "$AOS_VERSION" ]]
}

# Install a skill dir that is managed by agent-os, without touching user skills
# Returns 0 if written, 1 if skipped
_install_skill_to() {
    local name=$1 src=$2 kind=$3 dest=$4
    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -L "$dest" ]]; then
            # A link we created earlier, or a user link. Only replace our own.
            if [[ -f "$dest/$AOS_MARKER" ]]; then
                return 0
            fi
            print_warning "Skipping $(_rel "$dest"): existing link not managed by agent-os"
            return 1
        fi
        if [[ ! -f "$dest/$AOS_MARKER" ]]; then
            print_warning "Skipping $(_rel "$dest"): a skill with this name already exists and is not managed by agent-os"
            return 1
        fi
        if _skill_unchanged "$src" "$kind" "$dest"; then
            return 0
        fi
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  would update: $(_rel "$dest")"
            return 0
        fi
        # Back up the previous managed copy, then replace
        if [[ -n "$MANIFEST" ]]; then
            local rel
            rel=$(_rel "$dest")
            mkdir -p "$BACKUP_DIR/files/$(dirname "$rel")"
            cp -R "$dest" "$BACKUP_DIR/files/$rel"
            track "replaced $rel"
        fi
        rm -rf "$dest"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  would create: $(_rel "$dest")"
            return 0
        fi
        track_create "$dest"
    fi
    _write_skill "$src" "$kind" "$dest"
    return 0
}

# Link .claude/skills/<name> -> ../../.agents/skills/<name> (or copy)
_link_claude_skill() {
    local name=$1 src=$2 kind=$3
    local dest="$PROJECT_DIR/.claude/skills/$name"
    if [[ "$LINK_MODE" == "copy" ]]; then
        _install_skill_to "$name" "$src" "$kind" "$dest"
        return $?
    fi
    if [[ -L "$dest" ]]; then
        local target
        target=$(readlink "$dest")
        if [[ "$target" == "../../.agents/skills/$name" ]]; then
            return 0
        fi
        print_warning "Skipping $(_rel "$dest"): existing link points elsewhere"
        return 1
    fi
    if [[ -e "$dest" ]]; then
        if [[ -f "$dest/$AOS_MARKER" ]]; then
            # Previously copied by agent-os; convert to link
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "  would relink: $(_rel "$dest")"
                return 0
            fi
            backup_move "$dest"
        else
            print_warning "Skipping $(_rel "$dest"): a skill with this name already exists and is not managed by agent-os"
            return 1
        fi
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would link: $(_rel "$dest")"
        return 0
    fi
    mkdir -p "$PROJECT_DIR/.claude/skills"
    track_create "$dest"
    ln -s "../../.agents/skills/$name" "$dest"
}

# Install all base skills for the enabled tools
install_skills() {
    print_status "Installing skills (tools: $TOOLS)..."
    if [[ "$LINK_MODE" == "copy" ]] && tool_enabled claude && tool_enabled cursor; then
        print_warning "--copy with Claude Code and Cursor: Cursor reads both .agents/skills and .claude/skills, so real copies appear twice in Cursor. Symlinks (the default) avoid this; on Windows enable Developer Mode and git core.symlinks, or install with --tools codex,cursor on Cursor-only machines."
    fi
    local count=0 line name src kind
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        name=${line%%|*}
        src=${line#*|}; src=${src%|*}
        kind=${line##*|}
        # Canonical copy: .agents/skills (read by Codex and Cursor)
        if _install_skill_to "$name" "$src" "$kind" "$PROJECT_DIR/.agents/skills/$name"; then
            if tool_enabled claude; then
                _link_claude_skill "$name" "$src" "$kind" || true
            fi
            (( count++ )) || true
        fi
    done < <(list_base_skills)
    print_success "Installed $count skills to .agents/skills/$(tool_enabled claude && echo ' (linked into .claude/skills/)')"
}

# Install an external skill folder (used for the PRD dependency)
install_external_skill() {
    local name=$1 src=$2
    if _install_skill_to "$name" "$src" folder "$PROJECT_DIR/.agents/skills/$name"; then
        tool_enabled claude && { _link_claude_skill "$name" "$src" folder || true; }
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# Legacy command cleanup
# -----------------------------------------------------------------------------

# Move .claude/commands/agent-os/<name>.md files whose names collide with
# skills we install. Other legacy commands (e.g. v2 write-spec) stay put.
retire_colliding_commands() {
    local legacy="$PROJECT_DIR/.claude/commands/agent-os"
    [[ -d "$legacy" ]] || return 0
    local moved=0 name
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if [[ -f "$legacy/$name.md" ]]; then
            backup_move "$legacy/$name.md"
            (( moved++ )) || true
        fi
    done < <(list_base_skill_names)
    if [[ "$moved" -gt 0 ]]; then
        print_success "Retired $moved legacy commands (now skills with the same /names; backups in agent-os/.backups/)"
    fi
    if [[ "$DRY_RUN" != "true" ]] && [[ -d "$legacy" ]] && [[ -z "$(ls -A "$legacy")" ]]; then
        rmdir "$legacy"
        track "removed-empty-dir .claude/commands/agent-os"
    fi
}

# -----------------------------------------------------------------------------
# Agent instruction files
# -----------------------------------------------------------------------------

agents_block() {
    cat "$BASE_DIR/templates/agents-block.md"
}

# Insert or replace the managed block in AGENTS.md
update_agents_md() {
    local file="$PROJECT_DIR/AGENTS.md"
    local block
    block=$(agents_block)
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -f "$file" ]] && grep -qF "$AOS_BLOCK_START" "$file"; then
            echo "  would refresh agent-os block in AGENTS.md"
        else
            echo "  would add agent-os block to AGENTS.md"
        fi
        return
    fi
    local tmp
    tmp=$(mktemp)
    if [[ -f "$file" ]] && grep -qF "$AOS_BLOCK_START" "$file"; then
        awk -v start="$AOS_BLOCK_START" -v end="$AOS_BLOCK_END" -v blockfile="$BASE_DIR/templates/agents-block.md" '
            $0 == start { while ((getline line < blockfile) > 0) print line; skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$file" > "$tmp"
    else
        if [[ -f "$file" ]]; then
            cat "$file" > "$tmp"
            # Ensure a blank line separates existing content from the block
            [[ -n "$(tail -c1 "$file")" ]] && echo "" >> "$tmp"
            echo "" >> "$tmp"
        else
            printf '# Agent Instructions\n\n' > "$tmp"
        fi
        printf '%s\n' "$block" >> "$tmp"
    fi
    if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
        rm -f "$tmp"
        return 0
    fi
    track_modify "$file"
    if [[ -L "$file" ]]; then
        # Write through the link to preserve the user's setup
        cat "$tmp" > "$file"
        rm -f "$tmp"
    else
        mv "$tmp" "$file"
    fi
    print_success "AGENTS.md updated (read by Codex and Cursor)"
}

# Make Claude Code load AGENTS.md via an @import in CLAUDE.md
update_claude_md() {
    tool_enabled claude || return 0
    local file="$PROJECT_DIR/CLAUDE.md"
    if [[ -L "$file" ]]; then
        local target
        target=$(readlink "$file")
        if [[ "$target" == "AGENTS.md" || "$target" == "./AGENTS.md" ]]; then
            print_verbose "CLAUDE.md links to AGENTS.md; nothing to do"
            return 0
        fi
    fi
    if [[ -f "$file" ]] && grep -qE '^@\.?/?AGENTS\.md[[:space:]]*$' "$file"; then
        return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would add @AGENTS.md import to CLAUDE.md"
        return
    fi
    track_modify "$file"
    if [[ -f "$file" ]]; then
        [[ -n "$(tail -c1 "$file")" ]] && echo "" >> "$file"
        printf '\n@AGENTS.md\n' >> "$file"
    else
        printf '# Claude Code\n\nShared agent instructions live in AGENTS.md (also read by Codex and Cursor).\n\n@AGENTS.md\n' > "$file"
    fi
    print_success "CLAUDE.md imports AGENTS.md"
}

# -----------------------------------------------------------------------------
# Scaffolding for user stories and testing
# -----------------------------------------------------------------------------

_scaffold_file() {
    local src=$1 dest=$2
    if [[ -e "$dest" ]]; then
        return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would create: $(_rel "$dest")"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    track_create "$dest"
    cp "$src" "$dest"
}

scaffold_stories() {
    print_status "Scaffolding user stories and testing config..."
    if [[ ! -d "$PROJECT_DIR/agent-os/user-stories" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  would create: agent-os/user-stories/"
        else
            track_create "$PROJECT_DIR/agent-os/user-stories"
            mkdir -p "$PROJECT_DIR/agent-os/user-stories"
        fi
    fi
    _scaffold_file "$BASE_DIR/templates/user-stories-index.yml" "$PROJECT_DIR/agent-os/user-stories/index.yml"
    _scaffold_file "$BASE_DIR/templates/testing.yml" "$PROJECT_DIR/agent-os/testing.yml"
    ensure_gitignore_lines "agent-os/.backups/" "agent-os/user-stories/_runs/*/screenshots/" \
        "agent-os/user-stories/_runs/*/*.json" "agent-os/user-stories/_runs/*/*.log" \
        "agent-os/user-stories/report.html" ".playwright/" ".playwright-cli/"
    [[ "$DRY_RUN" == "true" ]] || print_success "agent-os/user-stories/ and agent-os/testing.yml ready (existing files kept)"
}

ensure_gitignore_lines() {
    local file="$PROJECT_DIR/.gitignore" line missing=""
    for line in "$@"; do
        if [[ ! -f "$file" ]] || ! grep -qxF "$line" "$file"; then
            missing="$missing$line"$'\n'
        fi
    done
    [[ -z "$missing" ]] && return 0
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would add to .gitignore: $(echo "$missing" | tr '\n' ' ')"
        return 0
    fi
    track_modify "$file"
    if [[ -f "$file" ]] && [[ -n "$(tail -c1 "$file")" ]]; then
        echo "" >> "$file"
    fi
    if [[ ! -f "$file" ]] || ! grep -qxF "# agent-os" "$file"; then
        echo "# agent-os" >> "$file"
    fi
    printf '%s' "$missing" >> "$file"
}

# Set level: in agent-os/testing.yml (demo or production). Only called with --level.
set_testing_level() {
    local level=$1 file="$PROJECT_DIR/agent-os/testing.yml"
    case "$level" in
        demo|production) ;;
        *) print_error "--level must be demo or production (got: $level)"; return 1 ;;
    esac
    if [[ -f "$file" ]] && grep -qE "^level:[[:space:]]*${level}[[:space:]]*(#.*)?$" "$file"; then
        return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would set level: $level in agent-os/testing.yml"
        return 0
    fi
    track_modify "$file"
    if [[ -f "$file" ]] && grep -qE '^level:' "$file"; then
        local tmp
        tmp=$(mktemp)
        awk -v lvl="$level" '/^level:/ && !done { print "level: " lvl; done=1; next } { print }' "$file" > "$tmp"
        cat "$tmp" > "$file"; rm -f "$tmp"
    elif [[ -f "$file" ]]; then
        printf '\n# Testing level: demo (happy path) or production (edge cases, full regression)\nlevel: %s\n' "$level" >> "$file"
    else
        mkdir -p "$(dirname "$file")"
        printf 'level: %s\n' "$level" > "$file"
    fi
    print_success "Testing level set to $level (agent-os/testing.yml)"
}

write_version_marker() {
    local file="$PROJECT_DIR/agent-os/.version"
    if [[ -f "$file" && "$(cat "$file")" == "$AOS_VERSION" ]]; then
        return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would write agent-os/.version ($AOS_VERSION)"
        return
    fi
    track_modify "$file"
    echo "$AOS_VERSION" > "$file"
}

# -----------------------------------------------------------------------------
# PRD Creator dependency (buildermethods/bm-skills)
# -----------------------------------------------------------------------------

PRD_REPO_DEFAULT="https://github.com/buildermethods/bm-skills.git"

# Install bm-prd-creator from a local checkout or by cloning bm-skills
install_prd_skill() {
    local source=${PRD_SOURCE:-}
    local ref=${PRD_REF:-main}
    local tmp=""
    if [[ -z "$source" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  would clone $PRD_REPO_DEFAULT ($ref) and install bm-prd-creator"
            return 0
        fi
        tmp=$(mktemp -d)
        print_status "Fetching PRD Creator from bm-skills ($ref)..."
        if ! git clone -q --depth 1 --branch "$ref" "$PRD_REPO_DEFAULT" "$tmp/bm-skills" 2>/dev/null; then
            print_warning "Could not clone bm-skills. Install it later with --with-prd, or in Claude Code: /plugin marketplace add buildermethods/bm-skills"
            rm -rf "$tmp"
            return 1
        fi
        source="$tmp/bm-skills"
    fi
    local skill="$source/skills/bm-prd-creator"
    if [[ ! -f "$skill/SKILL.md" ]]; then
        print_warning "bm-prd-creator not found in $source"
        [[ -n "$tmp" ]] && rm -rf "$tmp"
        return 1
    fi
    if install_external_skill "bm-prd-creator" "$skill"; then
        [[ "$DRY_RUN" == "true" ]] || print_success "Installed PRD Creator (bm-prd-creator, MIT, Builder Methods)"
    fi
    [[ -n "$tmp" ]] && rm -rf "$tmp"
    return 0
}

# -----------------------------------------------------------------------------
# Rollback
# -----------------------------------------------------------------------------

# Undo a change session using its manifest. Lines are replayed in reverse.
rollback_session() {
    local session=$1
    local manifest="$session/manifest.txt"
    if [[ ! -f "$manifest" ]]; then
        print_error "No manifest in $session"
        return 1
    fi
    local line action rel
    while IFS= read -r line; do
        action=${line%% *}
        rel=${line#* }
        case "$action" in
            created)
                case "$rel" in
                    .agents/skills/*|.claude/skills/*)
                        rm -rf "${PROJECT_DIR:?}/$rel" ;;
                    *)
                        if [[ -d "$PROJECT_DIR/$rel" && ! -L "$PROJECT_DIR/$rel" ]]; then
                            # Keep folders that now hold user content
                            rmdir "$PROJECT_DIR/$rel" 2>/dev/null || print_warning "Kept $rel (not empty)"
                        else
                            rm -f "${PROJECT_DIR:?}/$rel"
                        fi ;;
                esac
                ;;
            modified)
                mkdir -p "$(dirname "$PROJECT_DIR/$rel")"
                cat "$session/files/$rel" > "$PROJECT_DIR/$rel"
                ;;
            replaced)
                rm -rf "${PROJECT_DIR:?}/$rel"
                cp -R "$session/files/$rel" "$PROJECT_DIR/$rel"
                ;;
            moved)
                mkdir -p "$(dirname "$PROJECT_DIR/$rel")"
                mv "$session/moved/$rel" "$PROJECT_DIR/$rel"
                ;;
            removed-empty-dir)
                mkdir -p "$PROJECT_DIR/$rel"
                ;;
        esac
    done < <(awk '{a[NR]=$0} END{for(i=NR;i>=1;i--)print a[i]}' "$manifest")
    # Clean up empty dirs we may have created
    local d
    for d in .claude/skills .claude .agents/skills .agents agent-os/user-stories; do
        if [[ -d "$PROJECT_DIR/$d" ]]; then rmdir "$PROJECT_DIR/$d" 2>/dev/null || true; fi
    done
    return 0
}
