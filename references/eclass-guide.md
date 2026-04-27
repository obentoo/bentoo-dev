# Gentoo Eclass Guide

Organized by category. For each eclass: when to use, key variables/functions, and working examples from the bentoo overlay.

---

## Build Systems

### cmake

**When to use**: Package uses CMake as its build system.

**Key variables/functions**:
- `mycmakeargs` — array of `-DKEY=value` options passed to cmake
- `cmake_src_configure` — runs cmake configuration
- `cmake_src_compile` / `cmake_src_install` — build and install phases

```bash
# Real example: vulkan-headers in this overlay
inherit cmake

src_configure() {
    local mycmakeargs=(
        -DVULKAN_HEADERS_ENABLE_MODULE=OFF
        -DVULKAN_HEADERS_ENABLE_TESTS=$(usex test)
    )
    cmake_src_configure
}

src_install() {
    cmake_src_install
    find "${ED}" -name "*.cppm" -type f -delete || die
}
```

**Notes**:
- `usex flag yes no` returns "yes" or "no"; `usex flag ON OFF` returns "ON" or "OFF"
- Default phases work for most packages — only override what you need
- Use `cmake-multilib` instead when building for multiple ABIs

---

### meson

**When to use**: Package uses Meson as its build system.

**Key variables/functions**:
- `emesonargs` — array of `-Dkey=value` options
- `meson_src_configure` / `meson_src_compile` / `meson_src_install`
- `meson_feature use_flag` — returns `enabled`/`disabled` based on USE flag
- `meson_use use_flag` — returns `true`/`false` based on USE flag

```bash
# Typical meson ebuild pattern (as used in mesa)
inherit meson

src_configure() {
    local emesonargs=(
        -Dplatforms=$(usex X "x11" "")
        -Dvulkan-drivers=$(usex vulkan "amd,intel" "")
        -Dllvm=$(meson_feature llvm)
        -Dvaapi=$(meson_feature vaapi)
        -Dgallium-opencl=$(usex opencl "icd" "disabled")
        -Dbuildtype=$(usex debug "debug" "plain")
    )
    meson_src_configure
}
```

**Notes**:
- `meson_feature` maps to meson's `enabled`/`disabled`/`auto` feature options
- `meson_use` maps to boolean `true`/`false`
- Use `meson-multilib` instead for multilib builds

---

### autotools

**When to use**: Package uses GNU autotools (configure/make).

**Key variables/functions**:
- `econf` — runs `./configure` with sane Gentoo defaults; auto-dies on failure
- `emake` — runs `make` with parallel jobs; auto-dies on failure
- `eautoreconf` (from autotools eclass) — regenerates autotools files

```bash
inherit autotools

src_prepare() {
    default
    eautoreconf  # needed if patches modify configure.ac or Makefile.am
}

src_configure() {
    econf \
        --disable-static \
        $(use_enable nls) \
        $(use_with ssl openssl)
}

src_compile() {
    emake
}
```

**Notes**:
- `use_enable flag` generates `--enable-flag` or `--disable-flag`
- `use_with flag pkg` generates `--with-pkg` or `--without-pkg`
- Most packages don't need to override `src_compile` or `src_install` — the defaults call `emake` and `emake install`

---

## VCS

### git-r3

**When to use**: Live (9999) ebuild that fetches from a git repository, or snapshot ebuild that needs a specific commit.

**Key variables/functions**:
- `EGIT_REPO_URI` — the git repository URL
- `EGIT_COMMIT` — specific commit, tag, or branch to fetch
- `git-r3_src_unpack` — fetches and unpacks the repo (called automatically)

**Standard dual live/snapshot pattern** (from vulkan-headers in this overlay):
```bash
MY_PN=Vulkan-Headers
inherit cmake

if [[ ${PV} == *9999* ]]; then
    EGIT_REPO_URI="https://github.com/KhronosGroup/${MY_PN}.git"
    inherit git-r3
    # No KEYWORDS for live ebuilds
else
    EGIT_COMMIT="afe9eb980aa928a66d1c9c06f38c55dd59868720"
    SRC_URI="https://github.com/KhronosGroup/${MY_PN}/archive/${EGIT_COMMIT}.tar.gz -> ${P}.tar.gz"
    KEYWORDS="amd64 arm arm64 ~hppa ~loong ppc ppc64 ~riscv x86"
    S="${WORKDIR}/${MY_PN}-${EGIT_COMMIT}"
fi
```

**Notes**:
- `inherit git-r3` AFTER setting `EGIT_REPO_URI` in the conditional block
- For snapshot ebuilds, the `EGIT_COMMIT` is baked in — no actual git fetch happens
- Live ebuilds always fetch the latest; snapshot ebuilds are reproducible

---

## Rust

### cargo

**When to use**: Package is a Rust project built with Cargo.

**Key variables/functions**:
- `CRATES` — list of `crate@version` dependencies (one per line)
- `CARGO_CRATE_URIS` — auto-generated SRC_URI entries from CRATES
- `cargo_src_compile` — builds the package
- `cargo_src_install` — installs the built binary

```bash
# From mesa ebuild — Rust crates as meson subproject wraps
CRATES="
    paste@1.0.14
    proc-macro2@1.0.86
    quote@1.0.35
    rustc-hash@2.1.1
    syn@2.0.87
    unicode-ident@1.0.12
"

RUST_MIN_VER="1.82.0"
RUST_OPTIONAL=1

inherit cargo

SRC_URI+=" ${CARGO_CRATE_URIS}"
```

**Standalone Rust binary**:
```bash
CRATES="
    clap@4.5.0
    serde@1.0.195
    tokio@1.36.0
"

inherit cargo

SRC_URI="${CARGO_CRATE_URIS}"

src_compile() {
    cargo_src_compile
}

src_install() {
    cargo_src_install
    # cargo_src_install installs to /usr/bin by default
}
```

**Notes**:
- Generate `CRATES` list with `pycargoebuild` tool
- `CARGO_OPTIONAL=1` + `RUST_OPTIONAL=1` used when Rust is only needed for some USE combinations (like in mesa for LLVM Rust bindings)
- `QA_FLAGS_IGNORED` may be needed for Rust binaries that don't honor CFLAGS

---

### rust-toolchain

**When to use**: Package requires a minimum Rust version.

```bash
RUST_MIN_VER="1.82.0"
inherit rust-toolchain
```

---

## Go

### go-module

**When to use**: Package is a Go module.

**Key variables/functions**:
- `ego` — wrapper for `go` that respects Gentoo env settings
- `EGO_PN` — Go import path (e.g., `github.com/docker/buildx`)
- `go_ldflags` — convention for passing ldflags

```bash
# Real example: docker-buildx in this overlay
inherit go-module

SRC_URI="https://github.com/docker/buildx/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S=${WORKDIR}/${P#docker-}   # upstream extracts as buildx-X.Y.Z

LICENSE="Apache-2.0"
LICENSE+=" Apache-2.0 BSD BSD-2 ISC MIT MPL-2.0"  # dependency licenses

src_compile() {
    local _buildx_r='github.com/docker/buildx'
    local version=${PV}
    local go_ldflags=(
        "-linkmode=external"
        -X "${_buildx_r}/version.Version=${version}"
        -X "${_buildx_r}/version.Revision=$(date -u +%FT%T%z)"
        -X "${_buildx_r}/version.Package=${_buildx_r}"
    )
    ego build -o docker-buildx -ldflags "${go_ldflags[*]}" ./cmd/buildx
}

src_install() {
    exeinto /usr/libexec/docker/cli-plugins
    doexe docker-buildx
    einstalldocs
}
```

**Vendor tarballs** (for offline builds):
```bash
# Generate vendor tarball: go mod vendor && tar czf ${P}-vendor.tar.gz vendor/
SRC_URI="
    https://github.com/foo/bar/archive/v${PV}.tar.gz -> ${P}.tar.gz
    https://dev.gentoo.org/~maintainer/distfiles/${P}-vendor.tar.gz
"
```

**Notes**:
- Go tests often need network or docker — add `RESTRICT="test"` if they fail in sandbox
- License must include all transitive dependency licenses (`LICENSE+=" ..."`)
- `ego` sets `GOPATH`, `GOMODCACHE`, etc. correctly for Portage

---

## Python

### python-any-r1

**When to use**: Python is needed only at BUILD time (e.g., for code generation, documentation build). Not needed at runtime.

```bash
PYTHON_COMPAT=( python3_{11..14} )
inherit python-any-r1

BDEPEND="${PYTHON_DEPS}
    $(python_gen_any_dep 'dev-python/mako[${PYTHON_USEDEP}]')
"

python_check_deps() {
    python_has_version "dev-python/mako[${PYTHON_USEDEP}]"
}
```

---

### python-single-r1

**When to use**: Package installs Python scripts/modules that require exactly ONE Python version at runtime.

```bash
PYTHON_COMPAT=( python3_{11..14} )
inherit python-single-r1

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="${PYTHON_DEPS}
    $(python_gen_cond_dep 'dev-python/requests[${PYTHON_USEDEP}]')
"

src_install() {
    dobin scripts/mytool
    python_fix_shebang "${D}/usr/bin/mytool"
    python_optimize
}
```

---

### python-r1

**When to use**: Package supports multiple Python versions simultaneously (e.g., a library that installs to multiple python3.X directories).

```bash
PYTHON_COMPAT=( python3_{11..14} )
inherit python-r1

REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RDEPEND="${PYTHON_DEPS}"

src_install() {
    python_foreach_impl python_install
}

python_install() {
    insinto "$(python_get_sitedir)"
    doins mymodule.py
}
```

---

### distutils-r1

**When to use**: Python package with a setup.py / pyproject.toml build system.

**Key variables**:
- `DISTUTILS_USE_PEP517` — set to `setuptools`, `flit`, `hatchling`, `poetry`, or `no`
- `distutils_enable_tests pytest` — sets up test phase

```bash
PYTHON_COMPAT=( python3_{11..14} )
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1

distutils_enable_tests pytest

RDEPEND="
    dev-python/requests[${PYTHON_USEDEP}]
"

python_test() {
    epytest  # called automatically by distutils_enable_tests pytest
}
```

---

## Binary

### unpacker

**When to use**: Extracting non-standard archives (.deb, .rpm, .7z, etc.).

```bash
inherit unpacker

src_unpack() {
    unpack_deb ${A}   # for .deb files
    # or:
    unpack ${A}       # handles many formats including .7z, .deb, .rpm
}
```

**Typical .deb ebuild structure** (from kiro in this overlay):
```bash
inherit unpacker xdg desktop

S="${WORKDIR}"  # deb extracts in place, no subdirectory

src_unpack() {
    unpack_deb ${A}
}

src_prepare() {
    default
    rm -rf DEBIAN/ || die
}
```

---

### chromium-2

**When to use**: Electron or Chromium-based applications that bundle locale .pak files.

```bash
CHROMIUM_LANGS="af am ar bg bn ca cs da de el en-GB es es-419 et fa fi fil fr gu he
    hi hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr
    sv sw ta te th tr uk ur vi zh-CN zh-TW"

inherit chromium-2

src_prepare() {
    default
    pushd "${INSTALL_DIR}/locales" >/dev/null || die
    chromium_remove_language_paks
    popd >/dev/null || die
}
```

**Notes**: `chromium_remove_language_paks` removes locale .pak files not listed in `CHROMIUM_LANGS`, respecting the user's `L10N` USE flags.

---

### verify-sig

**When to use**: Package provides GPG signatures for distfiles.

```bash
inherit verify-sig

VERIFY_SIG_OPENPGP_KEY_PATH="${BROOT}/usr/share/openpgp-keys/maintainer.gpg"

SRC_URI="
    https://example.com/foo-${PV}.tar.gz
    verify-sig? ( https://example.com/foo-${PV}.tar.gz.asc )
"

IUSE="verify-sig"
BDEPEND="verify-sig? ( sec-keys/openpgp-keys-maintainer )"
```

---

## Desktop

### desktop

**When to use**: Installing .desktop files and icons.

```bash
inherit desktop

src_install() {
    domenu "${T}/app.desktop"           # install .desktop file
    doicon icon.png                      # install icon (default size)
    newicon -s 256 big-icon.png app.png  # install sized icon to hicolor theme
    newicon icon.svg app.svg             # install SVG icon
}
```

---

### xdg

**When to use**: Any package installing desktop files, icons, or MIME types. Handles cache updates.

```bash
inherit xdg

pkg_postinst() {
    xdg_pkg_postinst  # updates icon/desktop/mime caches
}

pkg_postrm() {
    xdg_pkg_postrm
}
```

---

### pax-utils

**When to use**: Packages with executables that need PaX memory protection exemptions (Electron/Chromium apps, JVM-based apps).

```bash
inherit pax-utils

src_install() {
    # ...
    pax-mark m "${ED}/opt/cursor/cursor"  # mark as needing PaX mprotect exemption
}
```

---

### shell-completion

**When to use**: Installing shell completion scripts.

```bash
inherit shell-completion

src_install() {
    newbashcomp completions/app.bash app    # install bash completion
    newzshcomp completions/_app _app        # install zsh completion
    newfishcomp completions/app.fish app    # install fish completion
}
```

**Real example** (from cursor ebuild in this overlay):
```bash
inherit shell-completion

src_install() {
    newbashcomp usr/share/bash-completion/completions/cursor cursor
    newzshcomp usr/share/zsh/vendor-completions/_cursor _cursor
}
```

---

### optfeature

**When to use**: Package works better with optional, separate packages.

```bash
inherit optfeature

pkg_postinst() {
    xdg_pkg_postinst
    optfeature "desktop notifications" x11-libs/libnotify
    optfeature "keyring support inside cursor" "virtual/secret-service"
    optfeature "Wayland support" "gui-libs/xdg-desktop-portal-wlr"
}
```

---

## Multilib

### multilib-minimal

**When to use**: Library needs to be built for both 64-bit and 32-bit ABIs (e.g., graphics libraries).

```bash
inherit multilib-minimal

# In RDEPEND/DEPEND, use MULTILIB_USEDEP for deps that must also be multilib:
RDEPEND="
    >=x11-libs/libX11-1.8[${MULTILIB_USEDEP}]
    >=dev-libs/expat-2.1.0[${MULTILIB_USEDEP}]
"

multilib_src_configure() {
    local myconf=(
        --enable-feature
    )
    ECONF_SOURCE="${S}" econf "${myconf[@]}"
}
```

### cmake-multilib / meson-multilib

**When to use**: CMake or Meson packages needing multilib builds (like mesa).

```bash
# From mesa in this overlay:
inherit meson-multilib

multilib_src_configure() {
    local emesonargs=(
        -Dvulkan-drivers=$(usex vulkan "amd" "")
    )
    meson_src_configure
}
```

---

## LLVM

### llvm-r1

**When to use**: Package requires LLVM/Clang (compilers, graphics drivers, etc.).

**Key variables/functions**:
- `LLVM_COMPAT` — array of supported LLVM major versions
- `LLVM_OPTIONAL=1` — LLVM is optional (controlled by USE flag)
- `llvm_gen_dep` — generates correct LLVM slot dependencies
- `get_llvm_prefix` — returns path to the active LLVM installation
- `LLVM_REQUIRED_USE` — must be included in REQUIRED_USE when LLVM is optional

```bash
# From mesa in this overlay:
LLVM_COMPAT=( {18..21} )
LLVM_OPTIONAL=1

inherit llvm-r1

REQUIRED_USE="
    llvm? ( ${LLVM_REQUIRED_USE} )
"

RDEPEND="
    llvm? (
        $(llvm_gen_dep "
            llvm-core/llvm:\${LLVM_SLOT}[llvm_targets_AMDGPU(+),${MULTILIB_USEDEP}]
            opencl? (
                dev-util/spirv-llvm-translator:\${LLVM_SLOT}
                llvm-core/clang:\${LLVM_SLOT}[llvm_targets_AMDGPU(+),${MULTILIB_USEDEP}]
            )
        ")
    )
"

src_configure() {
    local llvm_prefix=$(get_llvm_prefix)
    local emesonargs=(
        -Dllvm-prefix="${llvm_prefix}"
    )
    meson_src_configure
}
```

---

## Utility

### flag-o-matic

**When to use**: Manipulating compiler flags.

```bash
inherit flag-o-matic

src_configure() {
    filter-lto                      # remove LTO flags (breaks some packages)
    append-flags -fno-strict-aliasing
    replace-flags -O3 -O2           # downgrade optimization
    strip-unsupported-flags         # remove flags not supported by this compiler
}
```

---

### toolchain-funcs

**When to use**: Querying compiler information in ebuilds.

```bash
inherit toolchain-funcs

src_configure() {
    local cc=$(tc-getCC)    # get the C compiler
    local cxx=$(tc-getCXX)  # get the C++ compiler

    if tc-is-clang; then
        # clang-specific flags
        append-flags -Wno-error=unused-private-field
    fi
}
```

---

### linux-info

**When to use**: Checking kernel configuration options.

```bash
inherit linux-info

CONFIG_CHECK="~INOTIFY_USER ~FANOTIFY"
ERROR_INOTIFY_USER="Kernel must have CONFIG_INOTIFY_USER enabled"

pkg_pretend() {
    check_extra_config
}

pkg_setup() {
    check_extra_config
}
```

---

### savedconfig

**When to use**: Packages where users save and restore their build configuration (busybox, dropbear, etc.).

```bash
inherit savedconfig

src_prepare() {
    default
    restore_config .config
}

src_install() {
    save_config .config
    # ...
}
```
