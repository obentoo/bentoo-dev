#!/usr/bin/env bash
# Deterministic ebuild linter. Two entry points:
#
#   Hook mode (stdin = hook payload)
#     PostToolUse on Write|Edit  -> target comes from tool_input.file_path
#     PostToolUse on Bash(cp|mv|sed …) -> targets are parsed out of
#       tool_input.command. Without this, the Bash matchers silently no-op and
#       the ebuild-bumper flow (whose Step 2 is `cp old.ebuild new.ebuild`)
#       runs with no lint at all.
#     Output: hookSpecificOutput.additionalContext, exit 0. PostToolUse cannot
#     block — the write already happened — so findings surface as context.
#
#   CLI mode (paths as arguments)
#     quick-lint.sh [--json] <ebuild> [<ebuild> ...]
#     --json emits a machine-readable report (requires jq). Used by the
#     qa-checker agent so the six mechanical checks below cost zero tokens
#     instead of being re-derived by the model on every ebuild.
#
# Always exits 0: findings are the payload, not a failure of the linter.
set -euo pipefail

# shellcheck source=scripts/lib/hook-common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/hook-common.sh"

LINT_ERRORS=()
LINT_WARNINGS=()

# lint_ebuild <path> -> populates LINT_ERRORS / LINT_WARNINGS
lint_ebuild() {
    local eb="$1" base body
    LINT_ERRORS=()
    LINT_WARNINGS=()
    base=$(basename -- "$eb")

    grep -q '^EAPI=' "$eb" || LINT_ERRORS+=("Missing EAPI declaration")

    head -1 "$eb" | grep -q '^# Copyright' \
        || LINT_ERRORS+=("Missing copyright header on line 1")

    # PMS: an overridden src_prepare must run `default` or `eapply_user`,
    # otherwise /etc/portage/patches is silently ignored. The check is scoped to
    # the function body — a file-wide grep for "default" is satisfied by any
    # `--enable-default-foo` elsewhere in the ebuild and reports a false pass.
    if grep -qE '^[[:space:]]*src_prepare\(\)' "$eb"; then
        body=$(awk '/^[[:space:]]*src_prepare\(\)/{f=1} f{print} f&&/^\}/{exit}' "$eb")
        grep -qE '(^|[[:space:];&|])(default|eapply_user)([[:space:]]*(;|$))' <<<"$body" \
            || LINT_ERRORS+=("src_prepare() overridden without eapply_user or default")
    fi

    # Live ebuilds carry no KEYWORDS at all; a keyworded 9999 is installable by
    # accident on a plain ~arch profile.
    if [[ "$base" == *9999* ]] && grep -qE '^KEYWORDS="[^"]+"' "$eb"; then
        LINT_ERRORS+=("Live ebuild (9999) must have empty KEYWORDS")
    fi

    # Copyright year: a stale header is a QA warning, not a build failure.
    if head -1 "$eb" | grep -q '^# Copyright' \
       && ! head -1 "$eb" | grep -q "$(date +%Y)"; then
        LINT_WARNINGS+=("Copyright year does not include $(date +%Y)")
    fi

    # SLOT is mandatory in EAPI 8 — there is no implicit default.
    grep -q '^SLOT=' "$eb" || LINT_ERRORS+=("Missing SLOT declaration")

    # LICENSE is mandatory too, except for package classes that install no
    # files: virtual/*, acct-user/*, acct-group/*. Flagging those would train
    # the reader to ignore the check.
    if ! grep -q '^LICENSE=' "$eb"; then
        category=$(basename -- "$(dirname -- "$(dirname -- "$(readlink -f -- "$eb")")")")
        case "$category" in
            virtual|acct-user|acct-group) : ;;
            *)
                if grep -qE '^inherit .*\b(acct-user|acct-group)\b' "$eb"; then
                    :
                else
                    LINT_ERRORS+=("Missing LICENSE declaration")
                fi ;;
        esac
    fi
}

# ---------------------------------------------------------------- CLI mode --
if [[ $# -gt 0 || -t 0 ]]; then
    JSON=0
    TARGETS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) JSON=1; shift ;;
            -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) TARGETS+=("$1"); shift ;;
        esac
    done

    if (( JSON )) && ! command -v jq >/dev/null 2>&1; then
        echo "quick-lint: --json requires jq" >&2
        exit 0
    fi

    TOTAL_E=0
    TOTAL_W=0
    RESULTS="[]"
    for eb in "${TARGETS[@]}"; do
        [[ -f "$eb" && "$eb" == *.ebuild ]] || continue
        lint_ebuild "$eb"
        TOTAL_E=$(( TOTAL_E + ${#LINT_ERRORS[@]} ))
        TOTAL_W=$(( TOTAL_W + ${#LINT_WARNINGS[@]} ))
        if (( JSON )); then
            RESULTS=$(jq -c \
                --arg f "$eb" \
                --argjson e "$(printf '%s\n' "${LINT_ERRORS[@]+"${LINT_ERRORS[@]}"}" | jq -Rsc 'split("\n")|map(select(length>0))')" \
                --argjson w "$(printf '%s\n' "${LINT_WARNINGS[@]+"${LINT_WARNINGS[@]}"}" | jq -Rsc 'split("\n")|map(select(length>0))')" \
                '. + [{file:$f, errors:$e, warnings:$w}]' <<<"$RESULTS")
        else
            b=$(basename -- "$eb")
            for e in ${LINT_ERRORS[@]+"${LINT_ERRORS[@]}"};   do echo "[ERROR] $b: $e"; done
            for w in ${LINT_WARNINGS[@]+"${LINT_WARNINGS[@]}"}; do echo "[WARNING] $b: $w"; done
        fi
    done

    STATUS=PASS
    (( TOTAL_E > 0 )) && STATUS=FAIL
    if (( JSON )); then
        jq -n --argjson r "$RESULTS" --argjson e "$TOTAL_E" --argjson w "$TOTAL_W" --arg s "$STATUS" \
            '{results:$r, summary:{files:($r|length), errors:$e, warnings:$w, status:$s}}'
    else
        echo "Summary: ${TOTAL_E} error(s), ${TOTAL_W} warning(s) — ${STATUS}"
    fi
    exit 0
fi

# --------------------------------------------------------------- hook mode --
PAYLOAD="$(cat)"
EVENT=$(hook_event_name "$PAYLOAD" "PostToolUse")

mapfile -t TARGETS < <(hook_ebuild_targets "$PAYLOAD")
(( ${#TARGETS[@]} == 0 )) && exit 0

PARTS=()
TOTAL_E=0
TOTAL_W=0
for eb in "${TARGETS[@]}"; do
    lint_ebuild "$eb"
    (( ${#LINT_ERRORS[@]} == 0 && ${#LINT_WARNINGS[@]} == 0 )) && continue
    TOTAL_E=$(( TOTAL_E + ${#LINT_ERRORS[@]} ))
    TOTAL_W=$(( TOTAL_W + ${#LINT_WARNINGS[@]} ))
    part="$(basename -- "$eb"): ${#LINT_ERRORS[@]} error(s), ${#LINT_WARNINGS[@]} warning(s)"
    for e in ${LINT_ERRORS[@]+"${LINT_ERRORS[@]}"};    do part+="; ERROR ${e}"; done
    for w in ${LINT_WARNINGS[@]+"${LINT_WARNINGS[@]}"}; do part+="; WARNING ${w}"; done
    PARTS+=("$part")
done

(( ${#PARTS[@]} == 0 )) && exit 0

CTX="[bentoo-dev quick-lint] $(printf '%s | ' "${PARTS[@]}")"
CTX="${CTX% | }"

hook_emit_context "$EVENT" "$CTX"
(( TOTAL_E > 0 )) && echo "$CTX" >&2

exit 0
