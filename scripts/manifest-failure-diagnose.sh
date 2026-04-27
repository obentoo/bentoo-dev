#!/usr/bin/env bash
# PostToolUseFailure hook: detects failures of `ebuild <path> manifest`
# (the most common Gentoo workflow failure mode) and emits diagnostic
# additionalContext so Claude can suggest next steps without re-reading
# the full error stream.
#
# Detected patterns (heuristic, on stderr/error fields):
#   - "Network is unreachable" / "Connection refused" / "could not connect"
#       -> SRC_URI fetch network failure
#   - "checksum failed" / "manifest mismatch"
#       -> upstream tarball changed; suggest re-fetch
#   - "404" / "Not Found"
#       -> SRC_URI dead URL
#   - other: generic guidance
#
# Output: hookSpecificOutput.additionalContext + exit 0.
set -euo pipefail

[[ -t 0 ]] && exit 0

PAYLOAD="$(cat)"
CMD=""
ERR=""

if command -v jq >/dev/null 2>&1; then
    CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty')
    ERR=$(printf '%s' "$PAYLOAD" | jq -r '.error // empty')
else
    CMD=$(printf '%s' "$PAYLOAD" \
        | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | head -1 \
        | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
fi

# Only react to `ebuild ... manifest` failures.
if ! echo "$CMD" | grep -qE '\bebuild[[:space:]]+.*[[:space:]]+manifest\b'; then
    exit 0
fi

DIAG="generic ebuild manifest failure"
if echo "$ERR" | grep -qiE 'network is unreachable|connection refused|could not connect|name or service not known'; then
    DIAG="network unreachable — verify connectivity, then re-run; check SRC_URI hostname"
elif echo "$ERR" | grep -qiE 'checksum failed|manifest mismatch|digest.*differ'; then
    DIAG="distfile checksum mismatch — upstream tarball likely changed; remove old DIST entry from Manifest and re-run"
elif echo "$ERR" | grep -qiE '404|not found|http error 4'; then
    DIAG="SRC_URI returned 4xx — URL likely dead; check upstream release page for new tarball location"
elif echo "$ERR" | grep -qiE 'permission denied'; then
    DIAG="permission denied — ensure overlay dir is writable and \$DISTDIR is accessible"
fi

MSG="[bentoo-dev:manifest-failure] ${DIAG}"

if command -v jq >/dev/null 2>&1; then
    jq -Rn --arg c "$MSG" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUseFailure",
            additionalContext: $c
        }
    }'
else
    ESC=${MSG//\\/\\\\}
    ESC=${ESC//\"/\\\"}
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUseFailure","additionalContext":"%s"}}\n' "$ESC"
fi

exit 0
