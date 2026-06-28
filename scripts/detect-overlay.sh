#!/usr/bin/env bash
set -euo pipefail

# Walk up to find the overlay root (has metadata/layout.conf + profiles/repo_name)
# and print a generic, overlay-agnostic summary derived from the repository's
# own metadata — never assuming a particular overlay name.
DIR="${1:-.}"
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
        PROFILE_EAPI=$(layout_value profile-eapi-when-unspecified "$LAYOUT")

        echo "=== Gentoo Overlay Detected ==="
        echo "Path: $DIR"
        echo "Name: $REPO_NAME"
        echo "Masters: ${MASTERS:-<none>}"
        echo "thin-manifests: ${THIN:-false}"
        echo "sign-manifests: ${SIGN:-<unset>}"
        echo "manifest-hashes: ${HASHES:-<default: BLAKE2B SHA512>}"
        echo "profile-eapi-when-unspecified: ${PROFILE_EAPI:-<unset>}"
        echo ""
        echo "=== layout.conf ==="
        cat "$LAYOUT"
        echo ""

        if [[ -f "$DIR/profiles/package.mask" ]]; then
            echo "=== package.mask ==="
            cat "$DIR/profiles/package.mask"
            echo ""
        fi

        # Profile recommendation: this plugin ships a named example profile per
        # overlay plus a generic `default` fallback. Convention should be derived
        # from the metadata above, not from the overlay name.
        echo "=== Profile ==="
        echo "Overlay name (for example-profile lookup): $REPO_NAME"
        echo ""

        echo "=== Categories ==="
        if [[ -f "$DIR/profiles/categories" ]]; then
            # Authoritative source per GLEP, when present.
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
        exit 0
    fi
    DIR="$(dirname -- "$DIR")"
done

echo "No Gentoo overlay detected in current directory tree."
