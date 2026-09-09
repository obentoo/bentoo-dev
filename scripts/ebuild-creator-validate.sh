#!/usr/bin/env bash
# SubagentStop hook (matcher: ebuild-creator): verifies the subagent produced
# the three artifacts an ebuild creation must yield — the .ebuild itself,
# metadata.xml, and Manifest. Missing artifacts emit decision:block so the
# subagent keeps running and finishes the job.
#
# "Examined nothing" is not "everything is fine". An earlier version fell
# through to a success message when the candidate list was empty, reporting a
# green for zero packages examined and ending the verification there. The three
# outcomes are now distinct: blocked, passed, inconclusive.
#
# The search root is the cached overlay, falling back to the subagent's cwd.
# `ebuild-creator` does not run under `isolation: worktree` -- it writes into
# the overlay the caller named -- so one root is enough.
#
# Loop guard: respects stop_hook_active (canonical for Stop/SubagentStop).
set -euo pipefail

PAYLOAD=""
[[ -t 0 ]] || PAYLOAD="$(cat)"

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# Loop guard: don't re-block if we already blocked once this turn.
if [[ -n "$PAYLOAD" && $HAVE_JQ -eq 1 ]]; then
    [[ "$(printf '%s' "$PAYLOAD" | jq -r '.stop_hook_active // false')" = "true" ]] && exit 0
fi

emit_context() {
    (( HAVE_JQ )) || return 0
    jq -n --arg c "$1" '{
        hookSpecificOutput: {
            hookEventName: "SubagentStop",
            additionalContext: $c
        }
    }'
}

ROOT=""
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "${CLAUDE_PLUGIN_DATA}/overlay.json" && $HAVE_JQ -eq 1 ]]; then
    cached=$(jq -r '.root // empty' "${CLAUDE_PLUGIN_DATA}/overlay.json")
    [[ -n "$cached" && -d "$cached" ]] && ROOT="$cached"
fi

if [[ -z "$ROOT" && -n "$PAYLOAD" && $HAVE_JQ -eq 1 ]]; then
    cwd=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty')
    [[ -n "$cwd" && -d "$cwd" ]] && ROOT="$cwd"
fi

if [[ -z "$ROOT" ]]; then
    emit_context "[bentoo-dev] ebuild-creator validation SKIPPED: no overlay root cached and no cwd in the payload — nothing was verified."
    exit 0
fi

NOW=$(date +%s)
EXAMINED=0
INCOMPLETE=()
SEEN_DIRS=""

while IFS= read -r -d '' ebuild; do
    [[ -f "$ebuild" ]] || continue
    mtime=$(stat -c %Y "$ebuild" 2>/dev/null || echo 0)
    (( NOW - mtime > 300 )) && continue

    dir=$(dirname -- "$ebuild")
    case "$SEEN_DIRS" in *"|$dir|"*) continue ;; esac
    SEEN_DIRS+="|$dir|"

    EXAMINED=$(( EXAMINED + 1 ))
    pkg=$(basename -- "$dir")
    missing=()
    [[ -f "$dir/metadata.xml" ]] || missing+=("metadata.xml")
    [[ -f "$dir/Manifest"     ]] || missing+=("Manifest")

    if (( ${#missing[@]} > 0 )); then
        INCOMPLETE+=("$pkg (missing: $(IFS=,; echo "${missing[*]}"))")
    fi
done < <(find "$ROOT" -name .git -prune -o -name '*.ebuild' -type f -print0 2>/dev/null)

if (( ${#INCOMPLETE[@]} > 0 )); then
    REASON="ebuild-creator left package(s) incomplete: $(IFS=';'; echo "${INCOMPLETE[*]}") — generate the missing files before stopping"
    if (( HAVE_JQ )); then
        jq -n --arg r "$REASON" '{decision:"block", reason:$r}'
    else
        ESC=${REASON//\\/\\\\}
        ESC=${ESC//\"/\\\"}
        printf '{"decision":"block","reason":"%s"}\n' "$ESC"
    fi
    exit 0
fi

if (( EXAMINED == 0 )); then
    # Not a pass: the heuristic (ebuild mtime < 5 min) matched nothing under
    # $ROOT. Say so, so an empty result is never read as a green.
    emit_context "[bentoo-dev] ebuild-creator validation INCONCLUSIVE: no package modified in the last 5 minutes under ${ROOT} — 0 packages examined, nothing was verified."
    exit 0
fi

emit_context "[bentoo-dev] ebuild-creator validation passed: ${EXAMINED} recently created package(s) each have metadata.xml and Manifest."
exit 0
