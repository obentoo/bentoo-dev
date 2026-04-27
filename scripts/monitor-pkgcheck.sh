#!/usr/bin/env bash
# Background monitor: periodically runs `pkgcheck scan` against the cached
# overlay (resolved via ${CLAUDE_PLUGIN_DATA}/overlay.json) and prints one
# line per ERROR-level finding. Each stdout line becomes a Claude notification.
#
# No-ops when pkgcheck is missing or when the overlay cache is absent.
set -euo pipefail

POLL_SECS="${BENTOO_DEV_PKGCHECK_INTERVAL:-300}"

if ! command -v pkgcheck >/dev/null 2>&1; then
    echo "[bentoo-dev:monitor-pkgcheck] pkgcheck not installed; monitor idle"
    exit 0
fi

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" || ! -f "${CLAUDE_PLUGIN_DATA}/overlay.json" ]]; then
    echo "[bentoo-dev:monitor-pkgcheck] overlay cache missing; monitor idle"
    exit 0
fi

OVERLAY=""
if command -v jq >/dev/null 2>&1; then
    OVERLAY=$(jq -r '.root // empty' "${CLAUDE_PLUGIN_DATA}/overlay.json")
fi

if [[ -z "$OVERLAY" || ! -d "$OVERLAY" ]]; then
    echo "[bentoo-dev:monitor-pkgcheck] no valid overlay root cached; monitor idle"
    exit 0
fi

LAST_HASH=""
while :; do
    OUT=$(cd "$OVERLAY" && pkgcheck scan --keywords=error 2>/dev/null || true)
    if [[ -n "$OUT" ]]; then
        H=$(printf '%s' "$OUT" | sha256sum | awk '{print $1}')
        if [[ "$H" != "$LAST_HASH" ]]; then
            LAST_HASH="$H"
            while IFS= read -r line; do
                [[ -n "$line" ]] && echo "[bentoo-dev:pkgcheck] $line"
            done <<< "$OUT"
        fi
    fi
    sleep "$POLL_SECS"
done
