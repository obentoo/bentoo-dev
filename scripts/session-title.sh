#!/usr/bin/env bash
# UserPromptSubmit hook: auto-renames the session when the user invokes the
# /bentoo-dev:bentoo router (or auto-triggers the `bentoo` skill). Emits
# hookSpecificOutput.sessionTitle so the session list shows what is being
# worked on.
#
# Examples of resulting titles:
#   /bentoo-dev:bentoo create dev-util/foo 1.0   -> "bentoo: create dev-util/foo 1.0"
#   /bentoo-dev:bentoo bump app-editors/cursor   -> "bentoo: bump app-editors/cursor"
#   /bentoo-dev:bentoo run QA on dev-libs/foo     -> "bentoo: run QA on dev-libs/foo"
#
# No-ops on prompts that don't invoke the bentoo skill.
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

# Match the single router skill, optionally namespaced. Accept both the
# slash-command form (/bentoo-dev:bentoo …) and a bare "bentoo …" lead-in.
if [[ "$PROMPT" =~ ^/bentoo-dev:bentoo[[:space:]]*(.*)$ ]]; then
    ARGS="${BASH_REMATCH[1]}"
elif [[ "$PROMPT" =~ ^/bentoo[[:space:]]*(.*)$ ]]; then
    ARGS="${BASH_REMATCH[1]}"
else
    exit 0
fi

# Keep the first 80 chars of the instruction as the descriptive part.
ARGS="${ARGS:0:80}"
if [[ -n "$ARGS" ]]; then
    TITLE="bentoo: ${ARGS}"
else
    TITLE="bentoo"
fi

if command -v jq >/dev/null 2>&1; then
    jq -n --arg t "$TITLE" '{
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
