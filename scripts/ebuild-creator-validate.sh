#!/usr/bin/env bash
# SubagentStop hook (matcher: ebuild-creator): verifies the subagent produced
# the three artifacts an ebuild creation must yield — the .ebuild itself,
# metadata.xml, and Manifest. Missing artifacts emit decision:block so the
# subagent keeps running and finishes the job.
#
# Two things this must get right, and previously did not:
#
#  1. `ebuild-creator` declares `isolation: worktree`, so its files land in a
#     git worktree, not in the cached overlay root. Searching only the cached
#     root can never see them. Both roots are searched now.
#  2. "Examined nothing" is not "everything is fine". The old version fell
#     through to a success message when the candidate list was empty, which
#     reports a green for zero packages and ends the verification.
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

ROOTS=()
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "${CLAUDE_PLUGIN_DATA}/overlay.json" && $HAVE_JQ -eq 1 ]]; then
    cached=$(jq -r '.root // empty' "${CLAUDE_PLUGIN_DATA}/overlay.json")
    [[ -n "$cached" && -d "$cached" ]] && ROOTS+=("$cached")
fi

# The subagent's cwd — its git worktree under `isolation: worktree`.
if [[ -n "$PAYLOAD" && $HAVE_JQ -eq 1 ]]; then
    wt=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty')
    if [[ -n "$wt" && -d "$wt" ]]; then
        dup=0
        for r in ${ROOTS[@]+"${ROOTS[@]}"}; do [[ "$r" == "$wt" ]] && dup=1; done
        (( dup )) || ROOTS+=("$wt")
    fi
fi

if (( ${#ROOTS[@]} == 0 )); then
    emit_context "[bentoo-dev] ebuild-creator validation SKIPPED: no overlay root cached and no subagent cwd in the payload — nothing was verified."
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
done < <(find "${ROOTS[@]}" -name .git -prune -o -name '*.ebuild' -type f -print0 2>/dev/null)

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
    # ${ROOTS[*]}. Say so, so an empty result is never read as a green.
    emit_context "[bentoo-dev] ebuild-creator validation INCONCLUSIVE: no package modified in the last 5 minutes under ${ROOTS[*]} — 0 packages examined, nothing was verified."
    exit 0
fi

emit_context "[bentoo-dev] ebuild-creator validation passed: ${EXAMINED} recently created package(s) each have metadata.xml and Manifest."
exit 0
