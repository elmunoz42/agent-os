#!/bin/bash
# Validate Agent Skills so they load in Claude Code, Codex, and Cursor.
#
# Errors (the skill would be rejected, renamed, or unusable in at least one tool):
#   - no YAML frontmatter, missing name or description
#   - name not lowercase letters/digits joined by single hyphens, over 64 chars,
#     or different from the folder name (Cursor and Codex key skills by folder)
#   - description over 1024 chars
# Warnings (loads everywhere, but worth knowing):
#   - keys outside the Agent Skills spec that some tools ignore
#     (e.g. user_invocable, disable-model-invocation)
#   - body over ~5000 tokens (Cursor's recommended limit)
#
# Rules mirror agentskills.io and Cursor's own validator (from @cursor/sdk).
# Usage: validate-skills.sh [--strict] [dir ...]
#   default dirs: commands/agent-os and skills; --strict turns warnings into errors
set -u
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SPEC_KEYS="name description license compatibility metadata allowed-tools"
# Tool-specific keys: honored by some tools, ignored by others. Not errors.
TOOL_KEYS="user_invocable user-invocable disable-model-invocation argument-hint paths globs alwaysApply model icon color when_to_use"
STRICT="false"
errors=0
warnings=0

err()  { echo "  ✗ $1: $2"; errors=$((errors+1)); }
warn() { echo "  ! $1: $2"; warnings=$((warnings+1)); }

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
    if [[ -z "$name" ]]; then err "$file" "missing name"; fi
    if [[ -z "$desc" ]]; then err "$file" "missing description"; fi
    if [[ -n "$name" ]]; then
        [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || err "$file" "invalid name '$name'"
        [[ ${#name} -le 64 ]] || err "$file" "name longer than 64"
        [[ "$name" == "$expected" ]] || err "$file" "name '$name' does not match folder '$expected'"
    fi
    [[ ${#desc} -le 1024 ]] || err "$file" "description longer than 1024"
    local key
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        case " $SPEC_KEYS " in
            *" $key "*) ;;
            *)
                case " $TOOL_KEYS " in
                    *" $key "*) warn "$file" "tool-specific key '$key' (ignored by tools that don't support it)" ;;
                    *) warn "$file" "non-standard key '$key'" ;;
                esac ;;
        esac
    done < <(echo "$fm" | grep -E '^[A-Za-z_-]+:' | cut -d: -f1)
    local body_chars
    body_chars=$(awk 'NR==1{next} f{print} /^---$/{f=1}' "$file" | wc -c | tr -d ' ')
    if [[ $((body_chars / 4)) -gt 5000 ]]; then
        warn "$file" "body is about $((body_chars / 4)) tokens; Cursor recommends under 5000"
    fi
}

dirs=()
for a in "$@"; do
    if [[ "$a" == "--strict" ]]; then STRICT="true"; else dirs+=("$a"); fi
done
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
if [[ "$STRICT" == "true" ]]; then errors=$((errors + warnings)); fi
if [[ $errors -gt 0 ]]; then
    echo "Skill validation failed: $errors error(s), $warnings warning(s) in $count skill(s)"
    exit 1
fi
if [[ $warnings -gt 0 ]]; then
    echo "✓ $count skills valid ($warnings warning(s))"
else
    echo "✓ $count skills valid"
fi
