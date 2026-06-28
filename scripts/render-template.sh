#!/usr/bin/env bash
# Renders a bentoo-dev template by substituting @@VAR@@ placeholders.
#
# Usage:
#   render-template.sh <template> [--out <path>] [VAR=value ...]
#   render-template.sh <template> --env [--out <path>]
#
# Modes:
#   - Explicit:  pass VAR=value pairs on the command line.
#   - --env:     resolve every @@VAR@@ from the current environment, including
#                CLAUDE_PLUGIN_OPTION_* (auto-mapped: MAINTAINER_EMAIL,
#                MAINTAINER_NAME, MAINTAINER_TYPE, DEFAULT_KEYWORDS). EAPI
#                defaults to 8 (override by exporting EAPI=9).
#
# Output:
#   --out <path> writes to <path>; otherwise prints to stdout.
#
# Flags:
#   --strict  treat leftover @@VAR@@ placeholders as an error (exit 2). Without
#             it, unresolved placeholders are only warned about (exit 0) since
#             the creator agent fills the remaining ones in a later step.
#
# Exit codes:
#   0  rendered successfully (or unresolved placeholders without --strict)
#   1  template not found / bad usage
#   2  unresolved placeholders remain and --strict was given
set -euo pipefail

usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

[[ $# -lt 1 ]] && usage

TEMPLATE="$1"
shift
[[ ! -f "$TEMPLATE" ]] && { echo "render-template: not found: $TEMPLATE" >&2; exit 1; }

OUT=""
USE_ENV=0
STRICT=0
declare -A VARS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out)    OUT="$2"; shift 2 ;;
        --env)    USE_ENV=1; shift ;;
        --strict) STRICT=1; shift ;;
        -h|--help) usage ;;
        *=*)      VARS["${1%%=*}"]="${1#*=}"; shift ;;
        *)        echo "render-template: unknown arg: $1" >&2; exit 1 ;;
    esac
done

# Auto-map plugin userConfig env vars (CLAUDE_PLUGIN_OPTION_<KEY>) to canonical
# placeholder names. This is the documented spec-current prefix per Claude Code
# v2.1.x plugins-reference / env-vars.
if (( USE_ENV )); then
    : "${YEAR:=$(date +%Y)}"
    : "${EAPI:=8}"
    : "${MAINTAINER_EMAIL:=${CLAUDE_PLUGIN_OPTION_MAINTAINER_EMAIL:-}}"
    : "${MAINTAINER_NAME:=${CLAUDE_PLUGIN_OPTION_MAINTAINER_NAME:-}}"
    : "${MAINTAINER_TYPE:=${CLAUDE_PLUGIN_OPTION_MAINTAINER_TYPE:-person}}"
    : "${KEYWORDS:=${CLAUDE_PLUGIN_OPTION_DEFAULT_KEYWORDS:-~amd64}}"
fi

CONTENT="$(cat -- "$TEMPLATE")"

# Substitute explicit VAR=value pairs first (they win over --env).
for k in "${!VARS[@]}"; do
    v="${VARS[$k]}"
    CONTENT="${CONTENT//@@${k}@@/${v}}"
done

# Then env-derived placeholders.
if (( USE_ENV )); then
    while IFS= read -r ph; do
        name="${ph#@@}"; name="${name%@@}"
        # Skip if already covered explicitly
        [[ -n "${VARS[$name]+x}" ]] && continue
        val="${!name-}"
        [[ -z "${val}" ]] && continue
        CONTENT="${CONTENT//@@${name}@@/${val}}"
    done < <(printf '%s\n' "$CONTENT" | grep -ohE '@@[A-Z_]+@@' | sort -u || true)
fi

# metadata.xml: <name> is optional (GLEP 68). If MAINTAINER_NAME was not
# provided, drop the whole <name>…</name> line rather than leaving a literal
# placeholder (which would be invalid against the DTD).
if [[ -z "${MAINTAINER_NAME:-}" ]]; then
    CONTENT=$(printf '%s\n' "$CONTENT" | grep -v '<name>@@MAINTAINER_NAME@@</name>' || true)
fi

# Detect unresolved placeholders (informational, non-fatal unless strict).
UNRESOLVED=$(printf '%s\n' "$CONTENT" | grep -ohE '@@[A-Z_]+@@' | sort -u || true)

if [[ -n "$OUT" ]]; then
    mkdir -p "$(dirname -- "$OUT")"
    printf '%s' "$CONTENT" > "$OUT"
else
    printf '%s' "$CONTENT"
fi

if [[ -n "$UNRESOLVED" ]]; then
    {
        echo "render-template: unresolved placeholders:"
        mapfile -t _unres <<< "$UNRESOLVED"
        printf '  %s\n' "${_unres[@]}"
    } >&2
    (( STRICT )) && exit 2
fi

exit 0
