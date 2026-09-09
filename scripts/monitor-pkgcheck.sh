#!/usr/bin/env bash
# Background monitor: periodically runs `pkgcheck scan` against the cached
# overlay (resolved via ${CLAUDE_PLUGIN_DATA}/overlay.json) and prints one line
# per ERROR-level finding. Each stdout line becomes a Claude notification.
#
# This is the single pkgcheck path in the plugin. A separate scheduled variant
# used to exist and ran the same scan on a cron-style interval; the docs are
# explicit that a monitor "avoids polling altogether and is often more
# token-efficient and responsive than re-running a prompt on an interval", so
# the monitor absorbed its one distinct feature -- a persistent log -- rather
# than the two coexisting and drifting apart.
#
# Findings are appended to ${CLAUDE_PLUGIN_DATA}/pkgcheck.log (trimmed to the
# last 5000 lines) so a scan result outlives the session that observed it.
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

LOG="$CLAUDE_PLUGIN_DATA/pkgcheck.log"

LAST_HASH=""
while :; do
    # OVERLAY was validated as a directory above; pkgcheck exits non-zero when
    # it finds issues, so fall back to empty output instead of aborting.
    OUT=$(cd "$OVERLAY" && pkgcheck scan --keywords=error 2>/dev/null) || OUT=""
    if [[ -n "$OUT" ]]; then
        H=$(printf '%s' "$OUT" | sha256sum | awk '{print $1}')
        if [[ "$H" != "$LAST_HASH" ]]; then
            LAST_HASH="$H"
            {
                printf '=== %s — pkgcheck scan (%s) ===\n' "$(date -Iseconds)" "$OVERLAY"
                printf '%s\n\n' "$OUT"
            } >> "$LOG" 2>/dev/null || true
            if [[ -f "$LOG" ]] && (( $(wc -l < "$LOG") > 5000 )); then
                tail -n 5000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
            fi
            while IFS= read -r line; do
                [[ -n "$line" ]] && echo "[bentoo-dev:pkgcheck] $line"
            done <<< "$OUT"
        fi
    fi
    sleep "$POLL_SECS"
done
