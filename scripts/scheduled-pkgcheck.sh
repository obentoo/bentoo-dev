#!/usr/bin/env bash
# Scheduled task target: runs `pkgcheck scan --keywords=warning` against the
# cached overlay (resolved via ${CLAUDE_PLUGIN_DATA}/overlay.json) and writes
# the report to ${CLAUDE_PLUGIN_DATA}/pkgcheck-daily.log.
#
# Designed to be wired into a cron-based scheduled task via Claude Code's
# /schedule skill, e.g.:
#
#   /schedule daily 09:00 bash ${CLAUDE_PLUGIN_ROOT}/scripts/scheduled-pkgcheck.sh
#
# No-ops gracefully when pkgcheck is missing or no overlay is cached so the
# scheduled run never fails on non-Gentoo machines.
set -euo pipefail

if ! command -v pkgcheck >/dev/null 2>&1; then
    echo "[bentoo-dev:scheduled-pkgcheck] pkgcheck not installed; skipping"
    exit 0
fi

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" || ! -f "${CLAUDE_PLUGIN_DATA}/overlay.json" ]]; then
    echo "[bentoo-dev:scheduled-pkgcheck] no overlay cache; skipping"
    exit 0
fi

OVERLAY=""
if command -v jq >/dev/null 2>&1; then
    OVERLAY=$(jq -r '.root // empty' "${CLAUDE_PLUGIN_DATA}/overlay.json")
fi

if [[ -z "$OVERLAY" || ! -d "$OVERLAY" ]]; then
    echo "[bentoo-dev:scheduled-pkgcheck] no valid overlay root; skipping"
    exit 0
fi

mkdir -p "$CLAUDE_PLUGIN_DATA"
LOG="$CLAUDE_PLUGIN_DATA/pkgcheck-daily.log"

{
    printf '=== %s — pkgcheck scan (%s) ===\n' "$(date -Iseconds)" "$OVERLAY"
    (cd "$OVERLAY" && pkgcheck scan --keywords=warning 2>&1) || true
    printf '\n'
} >> "$LOG"

# Trim log to last 5000 lines so it doesn't grow unbounded.
if [[ $(wc -l < "$LOG") -gt 5000 ]]; then
    tail -n 5000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

echo "[bentoo-dev:scheduled-pkgcheck] report appended to $LOG"
exit 0
