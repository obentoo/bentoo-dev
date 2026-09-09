# Bentoo Overlay Conventions

> **Source of truth**: `<overlay>/CLAUDE.md` in the bentoo checkout. This file is
> an example profile — when the two disagree, the overlay's own `CLAUDE.md` and
> `metadata/layout.conf` win. Read them before relying on anything below.

> **Maintainer / KEYWORDS resolution**: prefer plugin `userConfig` values
> (`CLAUDE_PLUGIN_OPTION_MAINTAINER_EMAIL`, `MAINTAINER_NAME`, `MAINTAINER_TYPE`,
> `DEFAULT_KEYWORDS`). Use the values below only if userConfig is unset.

## Guiding principle

**bentoo is a distribution, not a machine.** The maintainer is the person who
packages it, not the target audience. Every packaging decision follows from that:

- Never size a package by the maintainer's hardware.
- Cover third-party hardware by default: NVIDIA (legacy included), AMD
  (ROCm/Vulkan), Intel (SYCL/oneAPI), NPUs, CPU-only, ARM64.
- Cover third-party use cases: desktop, workstation, server, headless,
  container, edge.
- Acceleration backends ship as **optional USE flags**, never hardcoded. Nobody
  should be forced to pull CUDA to run a package on CPU.
- "It is not useful to me" is **not** an exclusion criterion. "Upstream
  abandoned", "does not build", "no clear license" are.

## Repository

- Name: `bentoo` · Masters: `gentoo` · ~330 packages
- `thin-manifests = true` — a `Manifest` records only `DIST` entries. Ebuilds,
  patches and metadata are covered by git, not by the Manifest.
- `sign-manifests = false`
- `profile-formats = portage-2 profile-repo-deps` · `profiles/eapi` = `5`

### Mask/unmask atoms cut in opposite directions

`profile-repo-deps` allows `::repo` in profile files, and Portage stamps **every**
repo-level atom with the repo being processed (`<atom>::bentoo`):

- To mask something in a **master**, qualify it: `net-libs/nodejs:0::gentoo`.
  A bare atom only ever reaches bentoo's own ebuilds — masks flow *down* the
  masters chain, never up.
- To unmask a bentoo ebuild against a mask inherited from a master, use a
  **bare** atom. The inherited mask lands twice (`::gentoo` and `::bentoo`);
  only the `::bentoo` copy masks our ebuild, and only a bare atom cancels it.

Both existing entries carry that reasoning in their comment. Read it before
editing `profiles/package.mask` or `profiles/package.unmask`.

## KEYWORDS

- `~arm64` is included **whenever upstream supports it**. Restricting to
  `~amd64` is a decision that needs a written justification — not a default.
- Primary: `~amd64` · Binary-only packages: `-* ~amd64 ~arm64`

## Every daemon must be startable without systemd

Any package installing a systemd unit also installs an OpenRC init script of the
**same scope** — system in `/etc/init.d`, user in `/etc/user/init.d`.

The asymmetry is deliberate: the unit is gated behind `USE=systemd`, the init
script **never** is. It costs a systemd user nothing and is the only way to run
the daemon for someone who does not use systemd.

## Versioning

- Snapshots use `_p<YYYYMMDD>` with a `GIT_COMMIT=` or `COMMIT=` variable
- `SRC_URI` renamed with `-> ${P}.tar.gz` when the upstream tarball name is not
  informative
- Live ebuilds are dual-mode: `if [[ ${PV} == *9999* ]]` with git-r3, else a
  pinned commit

## Naming

- `MY_PN` when upstream's name differs (e.g. `MY_PN=Vulkan-Headers`)
- `MY_P="${P/_/-}"` for upstream versions using hyphens instead of underscores
- `S="${WORKDIR}/${MY_PN}-${EGIT_COMMIT}"` for pinned commits

## Binary packages

- Install to `/opt/<package-name>/` · `QA_PREBUILT="*"` ·
  `RESTRICT="bindist mirror strip"`
- `.deb`: `inherit unpacker` · Chromium-based: `inherit chromium-2`, use
  `chromium_remove_language_paks`
- `fperms 4711 /opt/<name>/chrome-sandbox` · `pax-mark m` executables ·
  `dosym ../<name>/bin/<binary> /opt/bin/<binary>`

## Desktop apps

- Icons at multiple sizes with `newicon -s ${size}`; `.desktop` with corrected
  Exec/Icon paths; completions via `newbashcomp` / `newzshcomp`

## Custom eclasses

`brave.eclass` · `gstreamer-meson.eclass` (meson.options, GStreamer 1.28.0+) ·
`rpm.eclass`

## Build defaults

- `EAPI=8` · `default` in `src_prepare` (applies PATCHES + eapply_user) ·
  `|| die` after every fallible command
- Copyright: `# Copyright 1999-<current_year> Gentoo Authors`

## Autoupdate bookkeeping

- Configured in `.autoupdate/packages.toml`. Every record is a promise that some
  endpoint answers: `url` plus a working `parser`.
- A package removed from the overlay becomes `enabled = false`; the entry is
  never deleted, which preserves the already-verified probe.
- An upstream that cannot be probed gets **no** record — it is listed in
  `.autoupdate/dead-upstreams.md`, so unverifiable never reads as verified.
- An upstream assessed and rejected goes in `.autoupdate/not-packageable.md`
  with the evidence and the condition that would reopen the decision.

## Working rules — these bite

- **The checkout is not what Portage reads.** Portage reads
  `/var/db/repos/bentoo`. A fix takes effect only after commit + push +
  `emaint sync -r bentoo`. Say which tree you touched.
- **Always pass an explicit target to `pkgdev manifest`.** With no target it
  rewrites the Manifest of the **entire overlay**.
- **`md5-cache` must be regenerated per package after a bump**, otherwise the
  previous entry is left behind:
  `egencache --repositories-configuration ... --update --repo bentoo <cat/pkg>`.
  `PORTAGE_CONFIGROOT` / `PORTAGE_REPOSITORIES` are ignored by `egencache`, and
  without `--repositories-configuration` it tries to delete the cache under
  `/var/db/repos/bentoo`.
- **This host has no `sudo`.** Validate with `emerge -pv`, or run build phases
  with your own `PORTAGE_TMPDIR`. A "PASS" that never merged anything is a false
  pass — say so explicitly.
- **One git worktree per concurrent session.** `bentoo overlay add` with no
  paths is `git add .`: anything sitting in the tree when it runs gets committed
  and pushed, including another session's work in progress.

## Overlay verification scripts (`<overlay>/scripts/`)

Each exits `1` on a gap and names what diverged. They exist because the failure
they catch is silent — it passes `pkgcheck`, merges cleanly, and only surfaces
on a user's machine. Run the relevant ones during the `qa` intent.

| Script | Asserts |
|---|---|
| `check-openrc-coverage.sh [cat[/pkg]]` | every systemd unit has an OpenRC counterpart at the same scope |
| `gentoo-parity.sh [cat[/pkg]]` | every axis on which a package diverges from `::gentoo`; read-only |
| `check-slot-naming-contract.sh` | `net-libs/nodejs` and `app-eselect/eselect-nodejs` agree on where a slot lives |
| `check-foldingathome-image.sh <ebuild>` | properties of the installed *image*, not of the ebuild text |
| `check-edk2-dbx-freshness.sh` | `sys-firmware/edk2`'s `SBO_VER` names the newest revocation list (needs network; exits `2`, not `1`, when the network is at fault) |
| `check-autoupdate-damage.sh` / `check-tlottie-pin.sh` | autoupdate regressions and a pinned dependency |
| `test-eselect-nodejs.sh` | slot ordering and directory replacement in the eselect module |

`check-openrc-coverage.sh`, `gentoo-parity.sh` and `check-edk2-dbx-freshness.sh`
also take `--self-test`, which runs their assertions without touching the tree.

**`${FILESDIR}` references matching no file** (the `[missing]` line in
`gentoo-parity.sh`) are not litter: they die at install under EAPI 8, so the
package cannot merge at all. That count must stay at 0.
