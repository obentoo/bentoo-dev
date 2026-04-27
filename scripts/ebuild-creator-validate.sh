#!/usr/bin/env bash
# SubagentStop hook (matcher: ebuild-creator): verifies the subagent produced
# the three artifacts an ebuild creation must yield — the .ebuild itself,
# metadata.xml, and Manifest. If any are missing under the cached overlay,
# emits decision:block to keep the subagent running so it can finish.
#
# Loop guard: respects stop_hook_active (canonical for Stop/SubagentStop).
set -euo pipefail

PAYLOAD=""
[[ -t 0 ]] || PAYLOAD="$(cat)"

# Loop guard: don't re-block if we already blocked once this turn.
if [[ -n "$PAYLOAD" ]] && command -v jq >/dev/null 2>&1; then
    [[ "$(printf '%s' "$PAYLOAD" | jq -r '.stop_hook_active // false')" = "true" ]] && exit 0
fi

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" || ! -f "${CLAUDE_PLUGIN_DATA}/overlay.json" ]]; then
    exit 0
fi

OVERLAY=""
if command -v jq >/dev/null 2>&1; then
    OVERLAY=$(jq -r '.root // empty' "${CLAUDE_PLUGIN_DATA}/overlay.json")
fi
[[ -z "$OVERLAY" || ! -d "$OVERLAY" ]] && exit 0

# Find any package directory whose newest .ebuild was modified in the last
# 5 minutes (heuristic for "this run created it") and check it has the trio.
INCOMPLETE=()
while IFS= read -r -d '' ebuild; do
    [[ -f "$ebuild" ]] || continue
    age=$(( $(date +%s) - $(stat -c %Y "$ebuild" 2>/dev/null || echo 0) ))
    (( age > 300 )) && continue

    dir=$(dirname -- "$ebuild")
    pkg=$(basename -- "$dir")
    missing=()
    [[ -f "$dir/metadata.xml" ]] || missing+=("metadata.xml")
    [[ -f "$dir/Manifest"     ]] || missing+=("Manifest")

    if (( ${#missing[@]} > 0 )); then
        INCOMPLETE+=("$pkg (missing: $(IFS=,; echo "${missing[*]}"))")
    fi
done < <(find "$OVERLAY" -name '*.ebuild' -type f -print0 2>/dev/null)

if (( ${#INCOMPLETE[@]} > 0 )); then
    REASON="ebuild-creator left package(s) incomplete: $(IFS=';'; echo "${INCOMPLETE[*]}") — generate the missing files before stopping"
    if command -v jq >/dev/null 2>&1; then
        jq -Rn --arg r "$REASON" '{decision:"block", reason:$r}'
    else
        ESC=${REASON//\\/\\\\}
        ESC=${ESC//\"/\\\"}
        printf '{"decision":"block","reason":"%s"}\n' "$ESC"
    fi
fi

exit 0
