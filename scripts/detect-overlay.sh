#!/usr/bin/env bash
set -euo pipefail

# Walk up to find overlay root (has metadata/layout.conf)
DIR="${1:-.}"
DIR="$(cd "$DIR" && pwd)"

while [[ "$DIR" != "/" ]]; do
    if [[ -f "$DIR/metadata/layout.conf" && -f "$DIR/profiles/repo_name" ]]; then
        REPO_NAME=$(cat "$DIR/profiles/repo_name" | tr -d '[:space:]')
        echo "=== Gentoo Overlay Detected ==="
        echo "Path: $DIR"
        echo "Name: $REPO_NAME"
        echo ""
        echo "=== layout.conf ==="
        cat "$DIR/metadata/layout.conf"
        echo ""
        if [[ -f "$DIR/profiles/package.mask" ]]; then
            echo "=== package.mask ==="
            cat "$DIR/profiles/package.mask"
            echo ""
        fi
        echo "=== Profile ==="
        echo "Recommended: $REPO_NAME"
        echo "=== Categories ==="
        ls -d "$DIR"/*/ 2>/dev/null | grep -v -E '(metadata|profiles|eclass)' \
            | xargs -I{} basename {} | sort | tr '\n' ' '
        echo ""
        if [[ -d "$DIR/eclass" ]]; then
            echo "=== Custom Eclasses ==="
            ls "$DIR/eclass/"*.eclass 2>/dev/null | xargs -I{} basename {} | sort
        fi
        exit 0
    fi
    DIR="$(dirname "$DIR")"
done

echo "No Gentoo overlay detected in current directory tree."
