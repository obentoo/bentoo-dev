#!/usr/bin/env bash
# Prints the overlay context block the `bentoo` skill injects at load time.
#
# Prefers ${CLAUDE_PLUGIN_DATA}/overlay.json (written once per session by
# cache-overlay.sh) and only falls back to a live detect-overlay.sh run when the
# cache is missing or points somewhere else than the current directory. That is
# the reuse the cache was written for; before this script, the skill re-ran the
# full detection — including a verbatim package.mask dump — on every invocation.
#
# Usage: overlay-context.sh [--full]
#   --full  always bypass the cache and dump layout.conf + package.mask verbatim
#           (needed only by the `clean` / `mask` intents).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--full" ]]; then
    exec bash "$HERE/detect-overlay.sh" --full
fi

CACHE="${CLAUDE_PLUGIN_DATA:-}/overlay.json"

if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -r "$CACHE" ]] && command -v jq >/dev/null 2>&1; then
    ROOT=$(jq -r '.root // empty' "$CACHE" 2>/dev/null || true)
    SUMMARY=$(jq -r '.summary // empty' "$CACHE" 2>/dev/null || true)
    PWD_ABS="$(pwd)"
    # Trust the cache only while the cwd is still inside the overlay it describes.
    if [[ -n "$ROOT" && -n "$SUMMARY" && ( "$PWD_ABS" == "$ROOT" || "$PWD_ABS" == "$ROOT"/* ) ]]; then
        printf '%s\n' "$SUMMARY"
        echo "(source: session cache — run overlay-context.sh --full for layout.conf + package.mask)"
        exit 0
    fi
fi

bash "$HERE/detect-overlay.sh" --summary
