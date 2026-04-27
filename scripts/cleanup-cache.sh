#!/usr/bin/env bash
# SessionEnd hook: removes stale ${CLAUDE_PLUGIN_DATA}/overlay.json when the
# session ends, so a future session starts with a clean detection cycle.
# Long-lived caches that should survive sessions (pkgcheck snapshots, distfile
# metadata) are left untouched.
#
# SessionEnd has no decision control (observability only) — exit 0 always.
set -euo pipefail

[[ -z "${CLAUDE_PLUGIN_DATA:-}" ]] && exit 0
[[ -d "$CLAUDE_PLUGIN_DATA" ]] || exit 0

CACHE="$CLAUDE_PLUGIN_DATA/overlay.json"
[[ -f "$CACHE" ]] && rm -f -- "$CACHE"

exit 0
