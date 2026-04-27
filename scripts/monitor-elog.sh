#!/usr/bin/env bash
# Background monitor: tails Portage ELOG summary file and emits one line per
# entry. Each stdout line becomes a notification to Claude (per Claude Code
# v2.1.105+ monitor semantics).
#
# Locations checked (first existing wins):
#   - /var/log/portage/elog/summary.log
#   - $PORTAGE_LOGDIR/elog/summary.log
#
# Exits cleanly when the file is unavailable so the monitor doesn't spam
# noise on systems without Portage installed (CI, Docker, non-Gentoo dev).
set -euo pipefail

CANDIDATES=(
    "/var/log/portage/elog/summary.log"
    "${PORTAGE_LOGDIR:-}/elog/summary.log"
)

LOG=""
for c in "${CANDIDATES[@]}"; do
    [[ -n "$c" && -f "$c" ]] && { LOG="$c"; break; }
done

if [[ -z "$LOG" ]]; then
    echo "[bentoo-dev:monitor-elog] no Portage ELOG summary at the expected paths; monitor idle"
    exit 0
fi

# Each line on stdout becomes a notification. Tail in line-buffered mode so
# Claude sees entries promptly.
exec tail -F -n 0 "$LOG"
