#!/usr/bin/env bash
# StopFailure hook (v2.1.78+): fires when a turn ends due to an API error
# (rate_limit, authentication_failed, billing_error, invalid_request,
# server_error, max_output_tokens, unknown). Logs a structured entry to
# ${CLAUDE_PLUGIN_DATA}/stop-failures.log so headless/CI runs surface the
# real cause of premature termination instead of a silent hang.
#
# Output and exit code are ignored by Claude Code for StopFailure (per
# /en/hooks-reference), so this script is observability-only.
set -euo pipefail

PAYLOAD=""
[[ -t 0 ]] || PAYLOAD="$(cat)"

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]] || [[ -z "$PAYLOAD" ]]; then
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

mkdir -p "$CLAUDE_PLUGIN_DATA"
LOG="$CLAUDE_PLUGIN_DATA/stop-failures.log"

ERROR_TYPE=$(printf '%s' "$PAYLOAD" | jq -r '.error_type // "unknown"')
ERROR_MSG=$(printf '%s' "$PAYLOAD" | jq -r '.error_message // ""')
SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // ""')
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

printf '%s\t%s\t%s\t%s\n' "$TS" "$SESSION_ID" "$ERROR_TYPE" "$ERROR_MSG" >> "$LOG"

# Trim to last 1000 lines to bound the log.
if [[ -f "$LOG" ]]; then
    LINES=$(wc -l < "$LOG" 2>/dev/null || echo 0)
    if [[ "$LINES" -gt 1000 ]]; then
        tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
fi

exit 0
