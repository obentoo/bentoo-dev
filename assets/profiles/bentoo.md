# Bentoo Overlay Conventions

> **Maintainer / KEYWORDS resolution**: prefer plugin `userConfig` values
> (`CLAUDE_PLUGIN_OPTION_MAINTAINER_EMAIL`, `MAINTAINER_NAME`, `MAINTAINER_TYPE`,
> `DEFAULT_KEYWORDS`). Use the values below only if userConfig is unset.

## Repository
- Name: `bentoo`
- Masters: `gentoo`
- thin-manifests: true
- sign-manifests: false

## Versioning
- Snapshots use `_p<YYYYMMDD>` suffix with `GIT_COMMIT=` or `COMMIT=` variable
- SRC_URI always renamed with `-> ${P}.tar.gz` when upstream tarball is not informative
- Live ebuilds use dual-mode: `if [[ ${PV} == *9999* ]]` block with git-r3, else pinned commit

## Keywords
- Primary: `~amd64`
- Secondary: `~arm64` when applicable
- Binary-only packages: `-* ~amd64 ~arm64`

## Naming
- `MY_PN` used when upstream name differs (e.g., `MY_PN=Vulkan-Headers`)
- `MY_P="${P/_/-}"` for upstream versions with hyphens instead of underscores
- `S="${WORKDIR}/${MY_PN}-${EGIT_COMMIT}"` for pinned commits

## Copyright
- `# Copyright 1999-<current_year> Gentoo Authors`

## Binary Packages
- Install to `/opt/<package-name>/`
- `QA_PREBUILT="*"`
- `RESTRICT="bindist mirror strip"`
- .deb packages: `inherit unpacker`
- Chromium-based apps: `inherit chromium-2`, use `chromium_remove_language_paks`
- Set SUID on chrome-sandbox: `fperms 4711 /opt/<name>/chrome-sandbox`
- PaX mark executables: `pax-mark m /opt/<name>/<binary>`
- Create symlink: `dosym ../<name>/bin/<binary> /opt/bin/<binary>`

## Desktop Apps
- Install icons at multiple sizes with `newicon -s ${size}`
- Generate .desktop files with corrected Exec and Icon paths
- Install bash completions with `newbashcomp`
- Install zsh completions with `newzshcomp`

## GStreamer
- Use custom eclass `gstreamer-meson` (supports meson.options for GStreamer 1.28.0+)

## Build Defaults
- EAPI=8 always
- Prefer `default` in src_prepare (applies PATCHES + eapply_user)
- Use `|| die` after every fallible command
