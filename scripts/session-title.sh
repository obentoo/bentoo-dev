#!/usr/bin/env bash
# UserPromptSubmit hook: auto-renames the session when the user invokes a
# /bentoo-dev:* slash command. Emits hookSpecificOutput.sessionTitle
# (v2.1.94+ canonical field) so the session list shows what is being worked on.
#
# Examples of resulting titles:
#   /bentoo-dev:ebuild-create dev-util/foo 1.0   -> "bentoo: ebuild-create dev-util/foo 1.0"
#   /bentoo-dev:ebuild-bump app-editors/cursor   -> "bentoo: ebuild-bump app-editors/cursor"
#   /bentoo-dev:overlay-clean --all              -> "bentoo: overlay-clean"
#
# No-ops on prompts that don't start with /bentoo-dev:.
set -euo pipefail

[[ -t 0 ]] && exit 0

PAYLOAD="$(cat)"
PROMPT=""

if command -v jq >/dev/null 2>&1; then
    PROMPT=$(printf '%s' "$PAYLOAD" | jq -r '.prompt // empty')
else
    PROMPT=$(printf '%s' "$PAYLOAD" \
        | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | head -1 \
        | sed -E 's/.*"prompt"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
fi

[[ -z "$PROMPT" ]] && exit 0

if [[ ! "$PROMPT" =~ ^/bentoo-dev: ]]; then
    exit 0
fi

# Strip "/bentoo-dev:" prefix; keep skill name + first 60 chars of args.
TITLE="${PROMPT#/bentoo-dev:}"
TITLE="${TITLE:0:80}"
TITLE="bentoo: ${TITLE}"

if command -v jq >/dev/null 2>&1; then
    jq -Rn --arg t "$TITLE" '{
        hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            sessionTitle: $t
        }
    }'
else
    ESC=${TITLE//\\/\\\\}
    ESC=${ESC//\"/\\\"}
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$ESC"
fi

exit 0
