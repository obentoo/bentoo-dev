# Generic Gentoo Overlay Conventions

## Repository
- Detect configuration via `metadata/layout.conf`
- Follow Gentoo devmanual strictly

## Versioning
- Standard Gentoo version scheme
- EAPI=8

## Keywords
- Default: `~amd64`
- Use `~arch` for new ebuilds (never commit straight to stable)

## Copyright
- `# Copyright 1999-<current_year> Gentoo Authors`
- `# Distributed under the terms of the GNU General Public License v2`

## Build Defaults
- Prefer `default` in src_prepare over explicit eapply_user
- SRC_URI with rename `->` only when necessary
- Test with `ebuild <path> manifest clean unpack compile install`

## Style
- Tabs for indentation (each tab = 4 spaces equivalent)
- No spaces around `=` in variable assignments
- Variable values must be ASCII only (GLEP 31)
- Only override phase functions when needed
