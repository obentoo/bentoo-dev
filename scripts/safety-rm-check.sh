#!/usr/bin/env bash
# PreToolUse Bash hook for Gentoo overlays.
#
# Reads canonical hook JSON payload from stdin and emits one of three decisions:
#
#   1. "deny"  — `rm` / `git rm` of an .ebuild that would empty the package
#                directory (no other ebuilds remain).
#   2. "ask"   — `rm` of an ebuild whose Manifest still has a matching DIST
#                entry that would become orphaned (borderline; prompt user).
#   3. (allow, exit 0)  — every other case.
#
# Output: exit 0 + JSON {hookSpecificOutput.permissionDecision} (canonical
# v2.1.x shape; replaces the legacy "exit 2 + stderr" pathway).
#
# Note: `defer` is reserved for headless mode (`-p` flag, v2.1.89+); for
# interactive prompting the canonical value is `ask`.
set -euo pipefail

[[ -t 0 ]] && exit 0

PAYLOAD="$(cat)"
CMD=""

if command -v jq >/dev/null 2>&1; then
    CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty')
else
    CMD=$(printf '%s' "$PAYLOAD" \
        | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | head -1 \
        | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
fi

[[ -z "$CMD" ]] && exit 0

# Only intercept rm / git rm targeting *.ebuild
if ! echo "$CMD" | grep -qE '(^|[[:space:]])(rm|git[[:space:]]+rm)([[:space:]]|$).*\.ebuild'; then
    exit 0
fi

DENY_REASONS=()
ASK_REASONS=()

# Extract paths ending in .ebuild from the command (best-effort tokenization)
for token in $CMD; do
    [[ "$token" != *.ebuild ]] && continue
    [[ "$token" == -* ]] && continue
    target="$token"
    [[ ! -f "$target" ]] && continue

    dir=$(dirname -- "$target")

    # 1. Hard deny: removing the only .ebuild in the dir.
    remaining=0
    while IFS= read -r f; do
        [[ "$f" == "$target" ]] && continue
        remaining=$((remaining + 1))
    done < <(find "$dir" -maxdepth 1 -name '*.ebuild' -type f 2>/dev/null)

    if [[ "$remaining" -eq 0 ]]; then
        DENY_REASONS+=("$target is the only .ebuild in $dir — removing it would empty the package directory")
        continue
    fi

    # 2. Ask: Manifest still references a DIST tied to this version (orphan risk).
    manifest="$dir/Manifest"
    base="${target##*/}"; ver="${base%.ebuild}"
    if [[ -f "$manifest" ]] && grep -qE "^DIST .*${ver}\b" "$manifest" 2>/dev/null; then
        ASK_REASONS+=("$target removal would orphan DIST entries in $manifest — confirm rm + manifest regenerate")
    fi
done

emit_decision() {
    local decision="$1" reason="$2"
    if command -v jq >/dev/null 2>&1; then
        jq -Rn --arg d "$decision" --arg r "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: $d,
                permissionDecisionReason: $r
            }
        }'
    else
        local esc=${reason//\\/\\\\}
        esc=${esc//\"/\\\"}
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$esc"
    fi
}

if (( ${#DENY_REASONS[@]} > 0 )); then
    REASON=$(printf '%s; ' "${DENY_REASONS[@]}")
    emit_decision "deny" "${REASON%; }"
    exit 0
fi

if (( ${#ASK_REASONS[@]} > 0 )); then
    REASON=$(printf '%s; ' "${ASK_REASONS[@]}")
    emit_decision "ask" "${REASON%; }"
    exit 0
fi

exit 0
