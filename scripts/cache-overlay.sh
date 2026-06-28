#!/usr/bin/env bash
# SessionStart / CwdChanged hook: detects the active overlay once per session
# (or on cwd change) and caches the result under ${CLAUDE_PLUGIN_DATA}/overlay.json.
#
# Skills can read this cache instead of re-running detect-overlay.sh on every
# turn (which spawns subshells and re-reads metadata/layout.conf).
#
# Output: exit 0 + optional hookSpecificOutput.additionalContext announcing
# the detected overlay name, so Claude is aware without re-reading the file.
set -euo pipefail

PAYLOAD=""
[[ -t 0 ]] || PAYLOAD="$(cat)"

CWD="$(pwd)"
if [[ -n "${PAYLOAD}" ]] && command -v jq >/dev/null 2>&1; then
    payload_cwd=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty')
    [[ -n "$payload_cwd" ]] && CWD="$payload_cwd"
fi

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    # Older Claude Code without persistent data dir: no-op.
    exit 0
fi

mkdir -p "$CLAUDE_PLUGIN_DATA"
CACHE="$CLAUDE_PLUGIN_DATA/overlay.json"

# Walk up to find overlay root.
DIR="$CWD"
OVERLAY_ROOT=""
OVERLAY_NAME=""
THIN_MANIFESTS="false"
MASTERS=""
MANIFEST_HASHES=""

# Extract a single layout.conf value (first match), trimming whitespace.
layout_value() {
    local key="$1" file="$2" line
    line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -1 || true)
    [[ -z "$line" ]] && return 0
    line="${line#*=}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    printf '%s' "$line"
}

while [[ "$DIR" != "/" ]]; do
    if [[ -f "$DIR/metadata/layout.conf" && -f "$DIR/profiles/repo_name" ]]; then
        OVERLAY_ROOT="$DIR"
        OVERLAY_NAME=$(tr -d '[:space:]' < "$DIR/profiles/repo_name")
        if grep -qE '^[[:space:]]*thin-manifests[[:space:]]*=[[:space:]]*true' "$DIR/metadata/layout.conf" 2>/dev/null; then
            THIN_MANIFESTS="true"
        fi
        MASTERS=$(layout_value masters "$DIR/metadata/layout.conf")
        MANIFEST_HASHES=$(layout_value manifest-hashes "$DIR/metadata/layout.conf")
        break
    fi
    DIR=$(dirname -- "$DIR")
done

if [[ -z "$OVERLAY_ROOT" ]]; then
    # Not inside an overlay; clear stale cache so skills don't load wrong profile.
    rm -f -- "$CACHE" 2>/dev/null || true
    exit 0
fi

EVENT="SessionStart"
if [[ -n "${PAYLOAD}" ]] && command -v jq >/dev/null 2>&1; then
    EVENT=$(printf '%s' "$PAYLOAD" | jq -r '.hook_event_name // "SessionStart"')
fi

if command -v jq >/dev/null 2>&1; then
    jq -n \
        --arg root "$OVERLAY_ROOT" \
        --arg name "$OVERLAY_NAME" \
        --arg thin "$THIN_MANIFESTS" \
        --arg masters "$MASTERS" \
        --arg hashes "$MANIFEST_HASHES" \
        --arg cwd "$CWD" \
        '{root:$root, name:$name, thin_manifests:($thin=="true"), masters:$masters, manifest_hashes:$hashes, detected_at:now, cwd:$cwd}' \
        > "$CACHE"

    MSG="[bentoo-dev] Overlay detected: ${OVERLAY_NAME} at ${OVERLAY_ROOT} (thin-manifests=${THIN_MANIFESTS})"
    jq -n --arg e "$EVENT" --arg c "$MSG" '{
        hookSpecificOutput: {
            hookEventName: $e,
            additionalContext: $c
        }
    }'
else
    printf '{"root":"%s","name":"%s","thin_manifests":%s,"cwd":"%s"}\n' \
        "$OVERLAY_ROOT" "$OVERLAY_NAME" "$THIN_MANIFESTS" "$CWD" > "$CACHE"
fi

exit 0
