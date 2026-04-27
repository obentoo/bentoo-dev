#!/usr/bin/env bash
# PreCompact hook: re-injects the cached overlay context before the conversation
# is compacted, so post-compaction the session still knows which overlay is
# active without re-running detect-overlay.sh.
#
# Reads ${CLAUDE_PLUGIN_DATA}/overlay.json (written by cache-overlay.sh) and
# emits hookSpecificOutput.additionalContext summarising the overlay name,
# root, and thin-manifests flag. No-op when the cache is missing.
#
# Output: exit 0 always; emits JSON only when cache is readable and jq is
# available.
set -euo pipefail

PAYLOAD=""
[[ -t 0 ]] || PAYLOAD="$(cat)"

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    exit 0
fi

CACHE="$CLAUDE_PLUGIN_DATA/overlay.json"
[[ -r "$CACHE" ]] || exit 0

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

EVENT="PreCompact"
if [[ -n "$PAYLOAD" ]]; then
    EVENT=$(printf '%s' "$PAYLOAD" | jq -r '.hook_event_name // "PreCompact"')
fi

NAME=$(jq -r '.name // empty' "$CACHE" 2>/dev/null || true)
ROOT=$(jq -r '.root // empty' "$CACHE" 2>/dev/null || true)
THIN=$(jq -r '.thin_manifests // false' "$CACHE" 2>/dev/null || true)

[[ -n "$NAME" && -n "$ROOT" ]] || exit 0

MSG="[bentoo-dev] Active overlay (preserved across compaction): ${NAME} at ${ROOT} (thin-manifests=${THIN})"

jq -Rn --arg e "$EVENT" --arg c "$MSG" '{
    hookSpecificOutput: {
        hookEventName: $e,
        additionalContext: $c
    }
}'

exit 0
