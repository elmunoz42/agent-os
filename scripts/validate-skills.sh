#!/bin/bash
# Validate Agent Skills frontmatter for every skill this repo ships.
# Checks the rules shared by Claude Code, Codex, and Cursor (agentskills.io):
#   - starts with YAML frontmatter
#   - name: lowercase letters, digits, single hyphens, <= 64 chars, matches folder
#   - description: present, <= 1024 chars
#   - only known top-level keys
# Usage: validate-skills.sh [dir ...]   (default: commands/agent-os and skills)
set -u
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ALLOWED="name description license compatibility metadata allowed-tools"
errors=0

err() { echo "  ✗ $1: $2"; errors=$((errors+1)); }

check() {
    local file=$1 expected=$2
    local first
    first=$(head -1 "$file")
    if [[ "$first" != "---" ]]; then err "$file" "missing frontmatter"; return; fi
    local fm
    fm=$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")
    local name desc
    name=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
    desc=$(echo "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)
    [[ -z "$name" ]] && err "$file" "missing name"
    [[ -z "$desc" ]] && err "$file" "missing description"
    if [[ -n "$name" ]]; then
        [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || err "$file" "invalid name '$name'"
        [[ ${#name} -le 64 ]] || err "$file" "name longer than 64"
        [[ "$name" == "$expected" ]] || err "$file" "name '$name' does not match '$expected'"
    fi
    [[ ${#desc} -le 1024 ]] || err "$file" "description longer than 1024"
    local key
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        case " $ALLOWED " in *" $key "*) ;; *) err "$file" "unknown key '$key'";; esac
    done < <(echo "$fm" | grep -E '^[A-Za-z_-]+:' | cut -d: -f1)
}

dirs=("$@")
[[ ${#dirs[@]} -eq 0 ]] && dirs=("$BASE_DIR/commands/agent-os" "$BASE_DIR/skills")
count=0
for d in "${dirs[@]}"; do
    for f in "$d"/*.md; do
        [[ -f "$f" ]] || continue
        check "$f" "$(basename "$f" .md)"; count=$((count+1))
    done
    for f in "$d"/*/SKILL.md; do
        [[ -f "$f" ]] || continue
        check "$f" "$(basename "$(dirname "$f")")"; count=$((count+1))
    done
done
if [[ $errors -gt 0 ]]; then
    echo "Skill validation failed: $errors error(s) in $count skill(s)"
    exit 1
fi
echo "✓ $count skills valid"
