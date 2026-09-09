#!/usr/bin/env bash
# Stop hook: blocks turn end if a package directory has an ebuild whose mtime
# is newer than its Manifest. Deterministic — no LLM call, no token cost.
#
# Cost matters here: this runs at the end of EVERY turn. The previous version
# walked the whole cwd with `find`, then spawned a `cd` subshell plus two
# `stat` calls per ebuild — ~750 processes and ~1.0 s on a 375-ebuild overlay,
# growing linearly. This version:
#   * scopes the walk to the overlay root (from the session cache when usable),
#   * finds SRC_URI ebuilds with a single recursive grep,
#   * batches every mtime lookup into one `stat` call,
#   * resolves thin-manifests once per overlay instead of once per ebuild.
#
# Packages without SRC_URI are skipped (no fetch -> no Manifest required). For
# overlays declaring `thin-manifests = true` the Manifest carries only DIST
# entries, so mtime drift after an ebuild-only edit is benign and not flagged.
#
# Returns:
#   exit 0                                                       -> allow turn end
#   exit 0 + JSON {decision:block,reason:...} (canonical for Stop) -> block
set -euo pipefail

PAYLOAD=""
[[ -t 0 ]] || PAYLOAD="$(cat)"

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# Stop-hook loop guard (canonical per docs/en/hooks): exit 0 if the previous
# turn was already blocked by this hook, to avoid Claude pingponging.
if [[ -n "$PAYLOAD" && $HAVE_JQ -eq 1 ]]; then
    [[ "$(printf '%s' "$PAYLOAD" | jq -r '.stop_hook_active // false')" = "true" ]] && exit 0
fi

PWD_ABS="$(pwd)"

# --- Resolve which overlay root(s) to scan -----------------------------------
ROOTS=()

if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "${CLAUDE_PLUGIN_DATA}/overlay.json" && $HAVE_JQ -eq 1 ]]; then
    cached=$(jq -r '.root // empty' "${CLAUDE_PLUGIN_DATA}/overlay.json")
    if [[ -n "$cached" && -d "$cached" && ( "$PWD_ABS" == "$cached" || "$PWD_ABS" == "$cached"/* ) ]]; then
        ROOTS=("$cached")
    fi
fi

if (( ${#ROOTS[@]} == 0 )); then
    d="$PWD_ABS"
    while [[ "$d" != "/" ]]; do
        if [[ -f "$d/metadata/layout.conf" ]]; then ROOTS=("$d"); break; fi
        d=$(dirname -- "$d")
    done
fi

if (( ${#ROOTS[@]} == 0 )); then
    # cwd is not inside an overlay; it may still contain some. Bounded depth so
    # a home directory never turns this into a filesystem sweep.
    while IFS= read -r lc; do
        ROOTS+=("$(dirname -- "$(dirname -- "$lc")")")
    done < <(find "$PWD_ABS" -maxdepth 4 -path '*/metadata/layout.conf' -type f 2>/dev/null)
fi

# No overlay anywhere -> loose .ebuild files (templates, examples) are not ours
# to police. Same intent as the old is_inside_overlay guard.
(( ${#ROOTS[@]} == 0 )) && exit 0

STALE=()

for ROOT in "${ROOTS[@]}"; do
    THIN=0
    if grep -qE '^[[:space:]]*thin-manifests[[:space:]]*=[[:space:]]*true' \
        "$ROOT/metadata/layout.conf" 2>/dev/null; then
        THIN=1
    fi

    # One process for the whole tree instead of one grep per ebuild.
    mapfile -t EBUILDS < <(grep -rlE --include='*.ebuild' --exclude-dir=.git \
        '^[[:space:]]*SRC_URI' "$ROOT" 2>/dev/null || true)
    (( ${#EBUILDS[@]} == 0 )) && continue

    # Candidate Manifests, deduplicated by package directory.
    declare -A DIRS=()
    for eb in "${EBUILDS[@]}"; do DIRS["$(dirname -- "$eb")"]=1; done

    STAT_TARGETS=("${EBUILDS[@]}")
    for d in "${!DIRS[@]}"; do
        if [[ -f "$d/Manifest" ]]; then
            STAT_TARGETS+=("$d/Manifest")
        else
            STALE+=("$d (no Manifest)")
            unset 'DIRS[$d]'
        fi
    done

    (( ${#DIRS[@]} == 0 )) && { unset DIRS; continue; }

    # One batched stat for every ebuild and Manifest in the overlay.
    declare -A MTIME=()
    while read -r ts path; do
        [[ -n "$path" ]] && MTIME["$path"]="$ts"
    done < <(printf '%s\0' "${STAT_TARGETS[@]}" | xargs -0 stat -c '%Y %n' 2>/dev/null || true)

    # Newest ebuild per package directory.
    declare -A NEWEST=()
    for eb in "${EBUILDS[@]}"; do
        d=$(dirname -- "$eb")
        [[ -n "${DIRS[$d]+x}" ]] || continue
        t="${MTIME[$eb]:-0}"
        (( t > ${NEWEST[$d]:-0} )) && NEWEST["$d"]="$t"
    done

    for d in "${!NEWEST[@]}"; do
        mf="${MTIME["$d/Manifest"]:-0}"
        (( ${NEWEST[$d]} > mf )) || continue
        # Under thin-manifests, an ebuild edit that leaves SRC_URI alone needs
        # no regen — git covers ebuild integrity, the Manifest covers DIST only.
        (( THIN )) && continue
        STALE+=("$d (ebuild newer than Manifest)")
    done

    unset DIRS MTIME NEWEST
done

if (( ${#STALE[@]} > 0 )); then
    REASON="Manifest stale or missing for: $(printf '%s; ' "${STALE[@]}")"
    REASON="${REASON%; }"
    if (( HAVE_JQ )); then
        jq -Rn --arg r "$REASON" '{decision:"block", reason:$r}'
    else
        ESCAPED=${REASON//\\/\\\\}
        ESCAPED=${ESCAPED//\"/\\\"}
        printf '{"decision":"block","reason":"%s"}\n' "$ESCAPED"
    fi
fi

exit 0
