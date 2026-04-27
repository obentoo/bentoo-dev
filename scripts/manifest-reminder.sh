#!/usr/bin/env bash
# PostToolUse / FileChanged hook: reminds Claude (via additionalContext) to
# regenerate Manifest when an ebuild with SRC_URI is written or edited.
#
# Reads canonical hook payload (JSON) from stdin. Falls back to $1 for manual
# invocation. Emits hookSpecificOutput.additionalContext + exit 0 (canonical
# for non-blocking informational hooks).
set -euo pipefail

EBUILD=""

if [[ -t 0 ]]; then
    EBUILD="${1:-}"
else
    PAYLOAD="$(cat)"
    if command -v jq >/dev/null 2>&1; then
        EBUILD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // .path // empty')
    else
        EBUILD=$(printf '%s' "$PAYLOAD" \
            | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"[^"]+"' \
            | head -1 \
            | sed -E 's/.*"(file_path|path)"[[:space:]]*:[[:space:]]*"([^"]+)".*/\2/')
    fi
fi

[[ -z "$EBUILD" ]] && exit 0
[[ "$EBUILD" != *.ebuild ]] && exit 0
[[ ! -f "$EBUILD" ]] && exit 0

grep -q '^[[:space:]]*SRC_URI' "$EBUILD" 2>/dev/null || exit 0

DIR=$(dirname -- "$EBUILD")
PKG=$(basename -- "$DIR")
MSG="[bentoo-dev] Reminder: regenerate Manifest for ${PKG} — run: ebuild ${EBUILD} manifest"

# Determine the hook event from stdin payload (PostToolUse vs FileChanged).
EVENT="PostToolUse"
if [[ -n "${PAYLOAD:-}" ]] && command -v jq >/dev/null 2>&1; then
    EVENT=$(printf '%s' "$PAYLOAD" | jq -r '.hook_event_name // "PostToolUse"')
fi

if command -v jq >/dev/null 2>&1; then
    jq -Rn --arg e "$EVENT" --arg c "$MSG" '{
        hookSpecificOutput: {
            hookEventName: $e,
            additionalContext: $c
        }
    }'
else
    ESC=${MSG//\\/\\\\}
    ESC=${ESC//\"/\\\"}
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$EVENT" "$ESC"
fi

exit 0
