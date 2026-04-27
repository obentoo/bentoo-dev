# Gentoo Ebuild Gotchas

Common mistakes with concrete before/after examples. Each entry explains WHY it matters, not just what to do.

---

## 1. eapply_user in src_prepare

**Rule**: If you override `src_prepare()`, you MUST call `default` or explicitly call `eapply_user`.

**Why it matters**: Without it, user patches from `/etc/portage/patches/` are silently ignored. The user gets no error — their patches just don't apply. This is a QA violation and breaks a core Portage feature.

```bash
# WRONG — user patches in /etc/portage/patches/ are silently dropped
src_prepare() {
    eapply "${FILESDIR}/my-fix.patch"
}

# RIGHT — call default (applies PATCHES array + eapply_user automatically)
src_prepare() {
    default
}

# RIGHT — or call eapply_user explicitly when you need custom ordering
src_prepare() {
    eapply "${FILESDIR}/my-fix.patch"
    eapply_user
}
```

**Note**: `default` in `src_prepare` applies the `PATCHES` array AND calls `eapply_user`. You don't need to iterate `PATCHES` manually. See gotcha #9.

---

## 2. || die After Fallible Commands

**Rule**: In EAPI 8, Portage builtins (`econf`, `emake`, `dobin`, etc.) auto-die on failure. Shell commands (`cp`, `mv`, `sed`, `rm`, `find`, `chmod`, `grep`) do NOT — add `|| die` after them.

**Why it matters**: A failing `cp` or `sed` during `src_install` will silently produce a broken or incomplete installation. Portage will report success while the package is broken.

```bash
# WRONG — cp failure is silently ignored
src_install() {
    cp -ar "${S}/." "${D}/opt/foo/"
    sed -i 's/updateUrl//' resources/product.json
}

# RIGHT
src_install() {
    cp -ar "${S}/." "${D}/opt/foo/" || die
    sed -i 's/updateUrl//' resources/product.json || die
}
```

**Common shell commands that need `|| die`**: `cp`, `mv`, `rm`, `sed`, `awk`, `chmod`, `find` (when used for side effects), `pushd`, `popd`, `mkdir`.

---

## 3. KEYWORDS Empty for Live Ebuilds

**Rule**: Ebuilds with `PV=9999` must have `KEYWORDS=""` or no KEYWORDS line at all. Never keyword a live ebuild.

**Why it matters**: Live ebuilds fetch from HEAD of a VCS repo — they are by definition unstable and untested. Keyworded live ebuilds would appear in stable/testing package selection, causing users to accidentally install unreproducible packages.

```bash
# WRONG — in a 9999 ebuild
KEYWORDS="~amd64"

# RIGHT
KEYWORDS=""

# Also RIGHT — omit KEYWORDS entirely for live ebuilds
# (no KEYWORDS line at all)
```

**Standard dual live/snapshot pattern** (from vulkan-headers in this overlay):
```bash
if [[ ${PV} == *9999* ]]; then
    EGIT_REPO_URI="https://github.com/KhronosGroup/${MY_PN}.git"
    inherit git-r3
    # No KEYWORDS — live ebuild
else
    EGIT_COMMIT="afe9eb980aa928a66d1c9c06f38c55dd59868720"
    SRC_URI="https://github.com/KhronosGroup/${MY_PN}/archive/${EGIT_COMMIT}.tar.gz -> ${P}.tar.gz"
    KEYWORDS="amd64 arm arm64 ~hppa ~loong ppc ppc64 ~riscv x86"
    S="${WORKDIR}/${MY_PN}-${EGIT_COMMIT}"
fi
```

---

## 4. S= Must Match Extracted Directory

**Rule**: When upstream tarball extracts to a non-standard directory name, set `S=` accordingly.

**Why it matters**: If `S` doesn't match the extracted directory, `src_configure` will fail immediately with a confusing "No such file or directory" error, not an obvious "wrong directory name" message.

```bash
MY_PN=Vulkan-Headers   # upstream uses capital letters

# For pinned commit snapshots:
S="${WORKDIR}/${MY_PN}-${EGIT_COMMIT}"

# For tarballs with version format differences:
MY_P="${P/_/-}"         # convert Portage _ to upstream -
S="${WORKDIR}/${MY_P}"

# For .deb packages unpacked with unpacker eclass:
S="${WORKDIR}"          # deb extracts in-place, no subdirectory
```

**Real example** (docker-buildx in this overlay):
```bash
# Upstream tarball extracts to buildx-0.33.0, not docker-buildx-0.33.0
S=${WORKDIR}/${P#docker-}   # strips "docker-" prefix
```

---

## 5. SRC_URI Rename With ->

**Rule**: When upstream tarball has a non-informative name (commit hash, generic "source.tar.gz"), rename it with `->`.

**Why it matters**: Distfiles are stored in `/var/cache/distfiles/` by filename. A file named `afe9eb9.tar.gz` from one project will collide with a completely different project's file of the same name. Renaming to `${P}.tar.gz` ensures uniqueness and human-readability.

```bash
# WRONG — commit hash filename; collides if two packages use same commit prefix
SRC_URI="https://github.com/foo/bar/archive/${COMMIT}.tar.gz"

# RIGHT — rename to package-version.tar.gz
SRC_URI="https://github.com/foo/bar/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"

# RIGHT — per-arch rename (from cursor ebuild in this overlay)
SRC_URI="
    amd64? (
        https://downloads.cursor.com/production/${BUILD_ID}/linux/x64/deb/amd64/deb/cursor_${PV}_amd64.deb
            -> ${P}-amd64.deb
    )
    arm64? (
        https://downloads.cursor.com/production/${BUILD_ID}/linux/arm64/deb/arm64/deb/cursor_${PV}_arm64.deb
            -> ${P}-arm64.deb
    )
"
```

---

## 6. QA_PREBUILT and RESTRICT for Binaries

**Rule**: Pre-compiled packages need `QA_PREBUILT` to suppress soname/stripping QA warnings, and `RESTRICT` to prevent stripping and mirroring.

**Why it matters**: Without `QA_PREBUILT`, Portage will fail QA checks on pre-built binaries (missing soname, wrong RPATH, etc.). Without `RESTRICT="strip"`, Portage will strip debug symbols from the binary, potentially breaking it. Without `RESTRICT="mirror"`, the binary may be mirrored to Gentoo mirrors (which is not allowed for proprietary binaries).

```bash
# For a package installing everything as prebuilt (e.g., cursor, kiro):
QA_PREBUILT="*"
RESTRICT="bindist mirror strip"

# For a package with only specific prebuilt files (e.g., kiro ebuild in this overlay):
QA_PREBUILT="
    opt/kiro/kiro
    opt/kiro/chrome_crashpad_handler
    opt/kiro/chrome-sandbox
    opt/kiro/lib*.so*
"
RESTRICT="mirror strip bindist"
```

**Note**: `bindist` means the package cannot be distributed in binary form (e.g., it has a proprietary license). `mirror` means Portage won't mirror the distfile. `strip` means Portage won't strip debug symbols.

---

## 7. Copyright + EAPI Ordering

**Rule**: Copyright header MUST be line 1. EAPI MUST be the first non-comment, non-blank line.

**Why it matters**: Portage parses EAPI before fully evaluating the ebuild. If EAPI is not first (after comments/blanks), Portage may assume EAPI 0 or fail to parse the ebuild correctly. This is a hard QA requirement.

```bash
# CORRECT ordering — always exactly this:
# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit some-eclass

DESCRIPTION="..."
```

```bash
# WRONG — EAPI after inherit or other assignments
inherit cmake
EAPI=8

# WRONG — missing copyright header
EAPI=8
```

**Copyright year**: Use the current year when creating a new ebuild. When modifying existing ebuilds, update the year range if needed (e.g., `1999-2025` -> `1999-2026`).

---

## 8. thin-manifests

**Rule**: In git-based overlays with `thin-manifests = true`, Manifests only contain DIST entries (checksums for remote distfiles). No EBUILD/AUX/MISC entries.

**Why it matters**: With `thin-manifests`, git itself tracks local file integrity. Adding EBUILD/AUX entries is redundant, bloats the Manifest, and causes `pkgcheck` warnings.

```
# CORRECT thin Manifest — only DIST entries:
DIST cursor-3.0.9-amd64.deb 123456789 BLAKE2B abc123... SHA512 def456...
DIST cursor-3.0.9-arm64.deb 98765432 BLAKE2B 789abc... SHA512 012def...

# WRONG — full Manifest with EBUILD entries:
EBUILD cursor-3.0.9.ebuild 4567 BLAKE2B ...
DIST cursor-3.0.9-amd64.deb 123456789 BLAKE2B ...
AUX fix.patch 890 BLAKE2B ...
```

Update Manifest with: `ebuild foo.ebuild manifest` or `pkgdev manifest`.

**Check overlay config**: `metadata/layout.conf` should contain `thin-manifests = true` for git overlays.

---

## 9. default in src_prepare

**Rule**: Calling `default` in `src_prepare` automatically applies the `PATCHES` array AND calls `eapply_user`. Do not iterate `PATCHES` manually.

**Why it matters**: Manually calling `eapply` in a loop on `PATCHES` skips `eapply_user`. Using `default` is the correct, idiomatic, and complete way to apply patches.

```bash
# WRONG — manual loop skips eapply_user
PATCHES=( "${FILESDIR}/${PN}-fix.patch" )
src_prepare() {
    for p in "${PATCHES[@]}"; do
        eapply "${p}"
    done
}

# WRONG — eapply on the array, still skips eapply_user
src_prepare() {
    eapply "${PATCHES[@]}"
}

# RIGHT — default handles PATCHES array + eapply_user
PATCHES=(
    "${FILESDIR}/${PN}-fix-build.patch"
    "${FILESDIR}/${PN}-gcc15.patch"
)

src_prepare() {
    default
    # Additional modifications after patches...
    sed -i 's/hardcoded-path/correct-path/' src/config.h || die
}
```

---

## 10. MY_P/MY_PN When Upstream Naming Differs

**Rule**: When upstream uses a different package name or version format than Portage's `${PN}/${PV}`, use `MY_PN`/`MY_P` variables to bridge the gap.

**Why it matters**: Portage normalizes package names to lowercase with hyphens. Upstream may use CamelCase, underscores, or different version separators. Without `MY_PN`/`MY_P`, `S=` and `SRC_URI` will point to non-existent paths.

```bash
# Upstream uses CamelCase name:
MY_PN=Vulkan-Headers   # upstream: Vulkan-Headers, Portage: vulkan-headers

# Upstream uses underscores where Portage uses hyphens (or vice versa):
MY_P="${P/_/-}"        # convert portage _ to upstream -
# e.g., foo-bar_1.2.3 -> foo-bar-1.2.3

# Upstream version has rc/pre notation differently:
MY_PV="${PV/_rc/rc}"  # convert portage _rc1 to upstream rc1

# Combined:
MY_PN=Vulkan-Headers
MY_P="${MY_PN}-${PV}"
SRC_URI="https://github.com/KhronosGroup/${MY_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${MY_P}"

# For pinned commit (snapshot ebuilds):
EGIT_COMMIT="afe9eb980aa928a66d1c9c06f38c55dd59868720"
S="${WORKDIR}/${MY_PN}-${EGIT_COMMIT}"
```
