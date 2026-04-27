#!/usr/bin/env bash
# Stop hook: blocks turn end if any package directory has an ebuild whose
# mtime is newer than its Manifest. Deterministic alternative to a prompt-type
# hook (no LLM call, no token cost).
#
# Walks the cwd looking for `*.ebuild` files; for each, compares the mtime of
# the newest .ebuild in the directory with the Manifest mtime. Skips packages
# without SRC_URI (no fetch -> Manifest not required). For overlays declaring
# `thin-manifests = true` in metadata/layout.conf the Manifest only needs to
# carry DIST entries, so a mtime drift after an EBUILD-only edit is benign and
# is not flagged.
#
# Returns:
#   exit 0                                                                      -> allow turn end
#   exit 0 + JSON {decision:block,reason:...} on stdout (canonical for Stop)    -> block turn end
set -euo pipefail

PAYLOAD=""
[[ -t 0 ]] || PAYLOAD="$(cat)"

# Stop-hook loop guard (canonical per docs/en/hooks): exit 0 if the previous
# turn was already blocked by this hook, to avoid Claude pingponging.
if [[ -n "$PAYLOAD" ]] && command -v jq >/dev/null 2>&1; then
    [[ "$(printf '%s' "$PAYLOAD" | jq -r '.stop_hook_active // false')" = "true" ]] && exit 0
fi

# Cache thin-manifests detection per overlay root (walk up from each ebuild to
# the directory containing metadata/layout.conf).
declare -A THIN_CACHE=()

is_thin_manifest_overlay() {
    local start="$1"
    local d
    d=$(cd "$start" && pwd)
    while [[ "$d" != "/" ]]; do
        if [[ -f "$d/metadata/layout.conf" ]]; then
            if [[ -n "${THIN_CACHE[$d]+x}" ]]; then
                [[ "${THIN_CACHE[$d]}" = "1" ]] && return 0 || return 1
            fi
            if grep -qE '^[[:space:]]*thin-manifests[[:space:]]*=[[:space:]]*true' "$d/metadata/layout.conf" 2>/dev/null; then
                THIN_CACHE[$d]=1
                return 0
            fi
            THIN_CACHE[$d]=0
            return 1
        fi
        d=$(dirname -- "$d")
    done
    return 1
}

STALE=()

while IFS= read -r -d '' ebuild; do
    [[ -f "$ebuild" ]] || continue
    grep -q '^[[:space:]]*SRC_URI' "$ebuild" 2>/dev/null || continue

    dir=$(dirname -- "$ebuild")
    manifest="$dir/Manifest"

    if [[ ! -f "$manifest" ]]; then
        STALE+=("$dir (no Manifest)")
        continue
    fi

    eb_mtime=$(stat -c %Y "$ebuild" 2>/dev/null || echo 0)
    mf_mtime=$(stat -c %Y "$manifest" 2>/dev/null || echo 0)

    if (( eb_mtime > mf_mtime )); then
        # Under thin-manifests, ebuild edits that don't touch SRC_URI lines
        # don't require a Manifest regen — git tracks integrity.
        if is_thin_manifest_overlay "$dir"; then
            continue
        fi
        STALE+=("$dir (ebuild newer than Manifest)")
    fi
done < <(find . -name '*.ebuild' -type f -print0 2>/dev/null)

if (( ${#STALE[@]} > 0 )); then
    REASON="Manifest stale or missing for: $(printf '%s; ' "${STALE[@]}")"
    REASON="${REASON%; }"
    if command -v jq >/dev/null 2>&1; then
        jq -Rn --arg r "$REASON" '{decision:"block", reason:$r}'
    else
        ESCAPED=${REASON//\\/\\\\}
        ESCAPED=${ESCAPED//\"/\\\"}
        printf '{"decision":"block","reason":"%s"}\n' "$ESCAPED"
    fi
fi

exit 0
