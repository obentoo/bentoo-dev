#!/usr/bin/env bash
set -euo pipefail

# Walks up to find the overlay root (has metadata/layout.conf + profiles/repo_name)
# and prints a generic, overlay-agnostic summary derived from the repository's
# own metadata — never assuming a particular overlay name.
#
# Usage: detect-overlay.sh [--summary|--full] [dir]
#
#   --summary (default)  Key/value summary only. Bounded output (~500 B), which
#                        is what the `bentoo` router needs to pick a profile.
#   --full               Adds the verbatim metadata/layout.conf and
#                        profiles/package.mask dumps. Only the `clean` / `mask`
#                        intents need those; on a real overlay package.mask
#                        alone is ~15 KB (~4k tokens) of context per invocation.

MODE="summary"
DIR="."
while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary) MODE="summary"; shift ;;
        --full)    MODE="full";    shift ;;
        -h|--help)
            sed -n '4,17p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) DIR="$1"; shift ;;
    esac
done
DIR="$(cd "$DIR" && pwd)"

# Extract a single layout.conf value (first match), trimming whitespace.
layout_value() {
    local key="$1" file="$2" line
    line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -1 || true)
    [[ -z "$line" ]] && return 0
    line="${line#*=}"
    # trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    printf '%s' "$line"
}

while [[ "$DIR" != "/" ]]; do
    if [[ -f "$DIR/metadata/layout.conf" && -f "$DIR/profiles/repo_name" ]]; then
        REPO_NAME=$(tr -d '[:space:]' < "$DIR/profiles/repo_name")
        LAYOUT="$DIR/metadata/layout.conf"

        MASTERS=$(layout_value masters "$LAYOUT")
        THIN=$(layout_value thin-manifests "$LAYOUT")
        SIGN=$(layout_value sign-manifests "$LAYOUT")
        HASHES=$(layout_value manifest-hashes "$LAYOUT")
        FORMATS=$(layout_value profile-formats "$LAYOUT")
        BANNED=$(layout_value eapis-banned "$LAYOUT")
        DEPRECATED=$(layout_value eapis-deprecated "$LAYOUT")
        PROFILE_EAPI=$(layout_value profile-eapi-when-unspecified "$LAYOUT")
        # profiles/eapi is the authoritative default EAPI for profile
        # directories and takes precedence over the layout.conf key above.
        # bentoo, for one, sets it to 5 and sets no layout.conf key at all.
        if [[ -f "$DIR/profiles/eapi" ]]; then
            PROFILE_EAPI=$(tr -d '[:space:]' < "$DIR/profiles/eapi")
        fi

        echo "=== Gentoo Overlay Detected ==="
        echo "Path: $DIR"
        echo "Name: $REPO_NAME"
        echo "Masters: ${MASTERS:-<none>}"
        echo "thin-manifests: ${THIN:-false}"
        echo "sign-manifests: ${SIGN:-<unset>}"
        echo "manifest-hashes: ${HASHES:-<default: BLAKE2B SHA512>}"
        echo "profile-formats: ${FORMATS:-<default: portage-1-compat>}"
        echo "profiles/eapi: ${PROFILE_EAPI:-<unset>}"
        echo "eapis-banned: ${BANNED:-<none>}"
        echo "eapis-deprecated: ${DEPRECATED:-<none>}"
        if [[ -f "$DIR/profiles/package.mask" ]]; then
            echo "package.mask: present ($(grep -cE '^[^#[:space:]]' "$DIR/profiles/package.mask" || true) atom line(s)) — read with: detect-overlay.sh --full"
        else
            echo "package.mask: absent"
        fi
        echo ""

        echo "=== Profile ==="
        echo "Overlay name (for example-profile lookup): $REPO_NAME"
        echo ""

        echo "=== Categories ==="
        if [[ -f "$DIR/profiles/categories" ]]; then
            # Authoritative source per GLEP, when present. Optional for an
            # overlay that only reuses categories defined by its masters.
            tr '\n' ' ' < "$DIR/profiles/categories"
            echo ""
        else
            # Fall back to category-shaped top-level dirs (those holding a '-').
            cats=""
            for d in "$DIR"/*-*/; do
                [[ -d "$d" ]] || continue
                name=$(basename -- "$d")
                case "$name" in
                    metadata|profiles|eclass|licenses|files) continue ;;
                esac
                cats+="$name "
            done
            printf '%s\n' "$cats"
        fi

        if [[ -d "$DIR/eclass" ]]; then
            echo "=== Custom Eclasses ==="
            for e in "$DIR"/eclass/*.eclass; do
                [[ -e "$e" ]] || continue
                basename -- "$e"
            done | sort
        fi

        # Overlay-owned verification scripts (bentoo ships nine). They catch
        # failures that pkgcheck passes, so the qa intent should run them.
        if [[ -d "$DIR/scripts" ]]; then
            checks=$(find "$DIR/scripts" -maxdepth 1 -name 'check-*.sh' -o -maxdepth 1 -name '*-parity.sh' 2>/dev/null | sort || true)
            if [[ -n "$checks" ]]; then
                echo ""
                echo "=== Overlay verification scripts ==="
                printf '%s\n' "$checks" | while IFS= read -r c; do basename -- "$c"; done
            fi
        fi

        if [[ "$MODE" == "full" ]]; then
            echo ""
            echo "=== layout.conf ==="
            cat "$LAYOUT"
            if [[ -f "$DIR/profiles/package.mask" ]]; then
                echo ""
                echo "=== package.mask ==="
                cat "$DIR/profiles/package.mask"
            fi
            echo ""
        fi
        exit 0
    fi
    DIR="$(dirname -- "$DIR")"
done

echo "No Gentoo overlay detected in current directory tree."
