#!/usr/bin/env bash
# PostToolUse Write|Edit / FileChanged hook for ebuilds.
# Reads hook payload (JSON) from stdin and lints only .ebuild files.
# Falls back to $1 when invoked manually (e.g., from a wrapper in bin/).
#
# Output:
#   Clean ebuild       -> exit 0, no output.
#   Warnings / errors  -> hookSpecificOutput.additionalContext JSON, exit 0.
#                         (PostToolUse cannot block — the write already
#                         happened — so findings surface as context to Claude.)
set -euo pipefail

EBUILD=""
EVENT="PostToolUse"

if [[ -t 0 ]]; then
    EBUILD="${1:-}"
else
    PAYLOAD="$(cat)"
    if command -v jq >/dev/null 2>&1; then
        EBUILD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // .path // empty')
        EVENT=$(printf '%s' "$PAYLOAD" | jq -r '.hook_event_name // "PostToolUse"')
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

ERRORS=()
WARNINGS=()
BASENAME=$(basename "$EBUILD")

if ! grep -q '^EAPI=' "$EBUILD"; then
    ERRORS+=("Missing EAPI declaration")
fi

if ! head -1 "$EBUILD" | grep -q '^# Copyright'; then
    ERRORS+=("Missing copyright header on line 1")
fi

if grep -q 'src_prepare()' "$EBUILD"; then
    if ! grep -q 'eapply_user\|default' "$EBUILD"; then
        ERRORS+=("src_prepare() overridden without eapply_user or default")
    fi
fi

if echo "$BASENAME" | grep -q '9999'; then
    if grep -q '^KEYWORDS="..*"' "$EBUILD"; then
        ERRORS+=("Live ebuild (9999) must have empty KEYWORDS")
    fi
fi

if ! grep -q '^SLOT=' "$EBUILD"; then
    WARNINGS+=("Missing SLOT declaration")
fi

if ! grep -q '^LICENSE=' "$EBUILD"; then
    WARNINGS+=("Missing LICENSE declaration")
fi

E_COUNT=${#ERRORS[@]}
W_COUNT=${#WARNINGS[@]}

if (( E_COUNT == 0 && W_COUNT == 0 )); then
    exit 0
fi

CTX="[bentoo-dev quick-lint] ${BASENAME}: ${E_COUNT} error(s), ${W_COUNT} warning(s)"
for e in "${ERRORS[@]}"; do CTX+="; ERROR ${e}"; done
for w in "${WARNINGS[@]}"; do CTX+="; WARNING ${w}"; done

if command -v jq >/dev/null 2>&1; then
    jq -Rn --arg e "$EVENT" --arg c "$CTX" '{
        hookSpecificOutput: {
            hookEventName: $e,
            additionalContext: $c
        }
    }'
else
    ESC=${CTX//\\/\\\\}
    ESC=${ESC//\"/\\\"}
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$EVENT" "$ESC"
fi

if (( E_COUNT > 0 )); then
    echo "$CTX" >&2
fi

exit 0
