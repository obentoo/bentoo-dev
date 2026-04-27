#!/usr/bin/env bash
# Resolves the persistent plugin-data directory (${CLAUDE_PLUGIN_DATA}) and
# ensures it exists. Use this for any cache or persistent state — files written
# inside ${CLAUDE_PLUGIN_ROOT} are wiped on every plugin update.
#
# Usage:
#   DATA_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/plugin-data-dir.sh")
#   echo "..." > "${DATA_DIR}/cache.txt"
#
# Exit codes:
#   0  prints absolute path of the data dir on stdout
#   1  ${CLAUDE_PLUGIN_DATA} not set (Claude Code older than v2.1.x)
set -euo pipefail

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    echo "plugin-data-dir: \${CLAUDE_PLUGIN_DATA} not set; require Claude Code v2.1.x" >&2
    exit 1
fi

mkdir -p "$CLAUDE_PLUGIN_DATA"
printf '%s\n' "$CLAUDE_PLUGIN_DATA"
