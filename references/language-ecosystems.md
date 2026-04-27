# Language Ecosystem Patterns for Gentoo Ebuilds

Per-language patterns, gotchas, and working examples from the bentoo overlay.

---

## Go

### Eclass: go-module

**Pattern**:
```bash
EAPI=8
inherit go-module

DESCRIPTION="My Go tool"
HOMEPAGE="https://github.com/author/tool"
SRC_URI="https://github.com/author/tool/archive/v${PV}.tar.gz -> ${P}.tar.gz"

# S= if upstream tarball directory differs from ${P}
# e.g., if upstream tarballs extract to "tool-X.Y.Z" not "author-tool-X.Y.Z":
S="${WORKDIR}/tool-${PV}"

LICENSE="Apache-2.0"
# All transitive dependency licenses MUST be listed:
LICENSE+=" BSD BSD-2 ISC MIT MPL-2.0"
SLOT="0"
KEYWORDS="amd64 ~arm arm64"
RESTRICT="test"  # Go tests often need network/docker; restrict by default
```

### Version Injection with ldflags

Most Go programs have a `version.Version` or similar variable. Inject it at build time:

```bash
# Real example from docker-buildx in this overlay:
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
```

**Common ldflags patterns**:
```bash
# Version string:
-X 'main.version=${PV}'
# Build date:
-X 'main.buildDate=$(date -u +%FT%T%z)'
# Disable version check / mark as release:
-X 'main.isDev=false'
```

### Vendor Tarballs

When the package requires modules not easily fetched during build (all Go modules must be vendored for Portage's network-less sandbox):

```bash
# go-module eclass fetches modules automatically if you provide EGO_SUM
# For large projects, create a vendor tarball instead:
# 1. go mod download
# 2. tar czf ${P}-vendor.tar.gz vendor/
# 3. Upload to your distfiles server

SRC_URI="
    https://github.com/foo/bar/archive/v${PV}.tar.gz -> ${P}.tar.gz
    https://dev.gentoo.org/~maintainer/distfiles/${P}-vendor.tar.gz
"

# go-module eclass with EGO_SUM (auto-generates the vendor tarball entries):
# Populate EGO_SUM with output of: go mod download -json | jq -r '"\(.Path) \(.Version) \(.Hash)"'
```

### S= Pattern

```bash
# Most common patterns:
S="${WORKDIR}/${P}"                # default, works when tarball extracts to package-version/
S="${WORKDIR}/tool-${PV}"         # when binary name differs from package name
S=${WORKDIR}/${P#prefix-}         # strip package prefix (as in docker-buildx)
```

### Gotchas
- Always add `LICENSE+=" ..."` for all transitive Go module licenses — `go mod` does not track them automatically; use `go-licenses` or check each dep
- `RESTRICT="test"` is common because `go test ./...` often needs network or running daemons
- `ego` (not `go`) must be used to respect `GOPATH`, `GOFLAGS`, and Portage's sandbox

---

## Rust

### Eclass: cargo + rust-toolchain

**Pattern**:
```bash
EAPI=8

CRATES="
    clap@4.5.0
    serde@1.0.195
    serde_json@1.0.113
    tokio@1.36.0
    tokio-util@0.7.10
"

RUST_MIN_VER="1.80.0"

inherit cargo rust-toolchain

SRC_URI="
    https://github.com/author/tool/archive/v${PV}.tar.gz -> ${P}.tar.gz
    ${CARGO_CRATE_URIS}
"

LICENSE="MIT"
LICENSE+=" Apache-2.0 MIT BSD"  # transitive dependency licenses
SLOT="0"
KEYWORDS="amd64 ~arm64"
```

### CRATES Generation

Use `pycargoebuild` to generate the `CRATES` list from `Cargo.lock`:
```bash
# Install: pip install pycargoebuild
# Run from the package source directory:
pycargoebuild /path/to/package/
```

The output includes both the `CRATES` variable and `LICENSE` contributions.

### Building

```bash
src_compile() {
    cargo_src_compile
    # or for specific binary:
    cargo_src_compile --bin mytool
}

src_install() {
    cargo_src_install
    # cargo_src_install installs all [[bin]] targets to /usr/bin
    # For docs:
    einstalldocs
}
```

### QA Flags for Rust Binaries

Rust binaries compiled with `cargo_src_compile` don't use `CFLAGS`/`LDFLAGS` in the same way:
```bash
QA_FLAGS_IGNORED="usr/bin/mytool"
# or for all binaries:
QA_FLAGS_IGNORED=".*"
```

### Workspace Builds

For Cargo workspaces (multiple crates in one repo):
```bash
src_compile() {
    # Build specific workspace member:
    cargo_src_compile --package mytool

    # Build all binaries:
    cargo_src_compile --workspace --bins
}
```

### Rust + Meson (mesa pattern)

Some packages use Rust as a Meson subproject (like mesa for its LLVM Rust bindings):
```bash
CARGO_OPTIONAL=1
RUST_MIN_VER="1.82.0"
RUST_OPTIONAL=1   # only needed with llvm USE flag

inherit cargo rust-toolchain

CRATES="
    paste@1.0.14
    proc-macro2@1.0.86
    ...
"

SRC_URI+=" ${CARGO_CRATE_URIS}"

# In src_configure, Meson handles the Rust compilation via wraps
```

### Gotchas
- `CRATES` must exactly match `Cargo.lock` versions — regenerate with `pycargoebuild` on each version bump
- Transitive Rust crate licenses must be listed in `LICENSE`
- `RUST_MIN_VER` is the minimum rustc version; check `rust-edition` in `Cargo.toml`

---

## Java

### Eclass: java-pkg-2

**Pattern**:
```bash
EAPI=8
inherit java-pkg-2

JAVA_SRC_DIR="src/main/java"

RDEPEND="
    >=virtual/jre-17:*
    dev-java/commons-lang:3.6
"

DEPEND="
    >=virtual/jdk-17:*
    ${RDEPEND}
"
```

### JDK/JRE Slot Dependencies

```bash
# Virtual slots for Java:
virtual/jdk:17      # JDK 17 specifically
virtual/jre:17      # JRE 17 specifically
virtual/jdk:*       # any JDK version
>=virtual/jdk-17:*  # JDK 17 or newer

# Specific implementations:
dev-java/openjdk:17
dev-java/openjdk-bin:21
```

### Build Systems

```bash
# Ant:
inherit java-pkg-2 java-ant-2
EANT_BUILD_TARGET="jar"

# Maven (avoid if possible — network-dependent):
# Use java-pkg-simple or java-pkg-2 with pre-built jar from upstream

# Gradle (avoid if possible):
# Same issue; prefer fetching pre-built jars
```

### Gotchas
- Maven/Gradle both want network access during builds — use pre-built jars from upstream releases when possible
- Always pin JDK slot in `DEPEND` and JRE slot in `RDEPEND`
- `java-pkg-2` eclass handles `JAVA_HOME` and `javac` wrapper

---

## Python

### PYTHON_COMPAT Array

```bash
PYTHON_COMPAT=( python3_{11..14} )  # supports python 3.11-3.14
PYTHON_COMPAT=( python3_12 python3_13 )  # specific versions only
```

### DISTUTILS_USE_PEP517 Values

| Value | Backend | When to use |
|-------|---------|-------------|
| `setuptools` | setuptools/setup.py | Most common |
| `flit` | flit-core | Scientific/simple packages |
| `hatchling` | hatch | Modern packages with pyproject.toml |
| `poetry` | poetry-core | Poetry-managed packages |
| `no` | none | Package uses custom build |

### Full distutils-r1 Pattern

```bash
EAPI=8
PYTHON_COMPAT=( python3_{11..14} )
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1

RDEPEND="
    dev-python/requests[${PYTHON_USEDEP}]
    dev-python/click[${PYTHON_USEDEP}]
"
BDEPEND="
    dev-python/setuptools[${PYTHON_USEDEP}]
"

distutils_enable_tests pytest

# Optional: if tests need extra setup
python_test() {
    epytest -x tests/  # -x stops on first failure
}
```

### python_foreach_impl

For `python-r1` (multi-version) packages:
```bash
inherit python-r1

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

src_install() {
    python_foreach_impl python_install
}

python_install() {
    insinto "$(python_get_sitedir)"
    doins mymodule.py
    python_optimize  # byte-compile .py files
}
```

### PYTHON_USEDEP in RDEPEND

```bash
RDEPEND="
    # Single dep with PYTHON_USEDEP:
    dev-python/requests[${PYTHON_USEDEP}]

    # For python-any-r1 (any of several python versions):
    $(python_gen_any_dep '
        dev-python/mako[${PYTHON_USEDEP}]
        dev-python/markupsafe[${PYTHON_USEDEP}]
    ')
"

# For python-any-r1, also define:
python_check_deps() {
    python_has_version "dev-python/mako[${PYTHON_USEDEP}]" &&
    python_has_version "dev-python/markupsafe[${PYTHON_USEDEP}]"
}
```

### Gotchas
- `${PYTHON_USEDEP}` is only valid inside dep strings that correspond to the eclass's compatible interpreters
- Always include `REQUIRED_USE="${PYTHON_REQUIRED_USE}"` for `python-single-r1` and `python-r1`
- `distutils_enable_tests pytest` automatically sets up `BDEPEND` and `python_test()` — don't define `python_test` separately unless you need custom behavior

---

## Ruby

### Eclass: ruby-fakegem

**Pattern** (from erb ebuild in this overlay):
```bash
EAPI=8

USE_RUBY="ruby32 ruby33 ruby34 ruby40"

RUBY_FAKEGEM_BINWRAP=""              # set to "" to skip wrapper generation
RUBY_FAKEGEM_EXTENSIONS=(ext/erb/escape/extconf.rb)  # native extensions
RUBY_FAKEGEM_EXTENSION_LIBDIR="lib/erb"
RUBY_FAKEGEM_EXTRADOC="README.md"
RUBY_FAKEGEM_EXTRAINSTALL="libexec"
RUBY_FAKEGEM_GEMSPEC="erb.gemspec"

inherit ruby-fakegem

SRC_URI="https://github.com/ruby/erb/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="|| ( Ruby-BSD BSD-2 )"
SLOT="$(ver_cut 1)"  # major version as slot for parallel installation
KEYWORDS="~amd64 ~arm64"
```

### Test Phase

```bash
# ruby-fakegem test:
RUBY_FAKEGEM_RECIPE_TEST="rake"      # use rake test
RUBY_FAKEGEM_RECIPE_TEST="rspec"     # use rspec
RUBY_FAKEGEM_RECIPE_TEST="none"      # no tests

# Custom test:
each_ruby_test() {
    ${RUBY} -Ilib:test -rtest/helper -e "Dir['test/**/test_*.rb'].each { require _1 }" || die
}
```

### Gotchas
- `USE_RUBY` must list all actually tested/supported Ruby implementations
- `SLOT="$(ver_cut 1)"` enables parallel installation of major versions (like Python)
- Native extensions need `RUBY_FAKEGEM_EXTENSIONS` pointing to the extconf.rb

---

## Perl

### Eclass: perl-module

**Pattern**:
```bash
EAPI=8
inherit perl-module

DESCRIPTION="Some Perl module"
HOMEPAGE="https://metacpan.org/pod/Module::Name"

MODULE_AUTHOR="AUTHOR"   # CPAN author ID (uppercase)
SRC_URI="mirror://cpan/authors/id/${MODULE_AUTHOR:0:1}/${MODULE_AUTHOR:0:2}/${MODULE_AUTHOR}/${P}.tar.gz"

LICENSE="|| ( Artistic GPL-1+ )"
SLOT="0"
KEYWORDS="~amd64"
```

### CPAN Integration

```bash
# Standard CPAN mirror URI for modules:
SRC_URI="mirror://cpan/authors/id/A/AU/AUTHOR/${MY_P}.tar.gz"

# Modules with non-standard dist names:
MY_P="Module-Name-${PV}"
SRC_URI="mirror://cpan/authors/id/A/AU/AUTHOR/${MY_P}.tar.gz"
S="${WORKDIR}/${MY_P}"
```

### Build Systems

```bash
# ExtUtils::MakeMaker (most common):
# perl-module eclass handles it automatically

# Module::Build:
PERL_MB_OPT="--installdirs vendor"

# Module::Install:
# handled by perl-module eclass
```

---

## Electron/Node (Binary Repack Pattern)

**Critical rule**: Never compile Electron/Node.js packages from source in Gentoo. Electron requires a specific Chromium version and its own Node.js — compiling it is practically impossible. Always use binary repack from official .deb releases.

### Full Binary .deb Pattern (from cursor in this overlay)

```bash
EAPI=8

CHROMIUM_LANGS="af am ar bg bn ca cs da de el en-GB es es-419 ..."

inherit chromium-2 desktop pax-utils unpacker xdg optfeature shell-completion

BUILD_ID="93e276db8a03af947eafb2d10241e2de17806c29"
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
S="${WORKDIR}"

LICENSE="cursor"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"   # -* means "not stable on any arch by default"
RESTRICT="bindist mirror strip"

QA_PREBUILT="*"
```

### Required eclasses for Electron apps

| Eclass | Purpose |
|--------|---------|
| `unpacker` | Extract .deb files with `unpack_deb` |
| `chromium-2` | Remove unused locale .pak files |
| `pax-utils` | Mark Electron executable for PaX |
| `desktop` | Install .desktop files and icons |
| `xdg` | Handle XDG cache updates in postinst |
| `shell-completion` | Install bash/zsh completion scripts |
| `optfeature` | Suggest optional packages in postinst |

### chrome-sandbox SUID

Electron's chrome-sandbox binary MUST be installed with SUID 4711 permissions:
```bash
src_install() {
    dodir /opt/myapp
    cp -ar "${INSTALL_DIR}/." "${D}/opt/myapp/" || die

    # chrome-sandbox MUST be SUID root:
    fperms 4711 /opt/myapp/chrome-sandbox

    # Main executable needs PaX marking:
    pax-mark m /opt/myapp/myapp
}
```

### Removing Foreign Architecture Binaries

Electron bundles arm64 and x64 binaries even for amd64 packages. Remove them to avoid QA soname warnings:
```bash
src_prepare() {
    default

    # Remove foreign arch binaries (from cursor ebuild):
    if use amd64; then
        rm -r "${CURSOR_HOME}/resources/app/extensions/cursor-agent/dist/vendor/ripgrep/arm64-linux" || die
    elif use arm64; then
        rm -r "${CURSOR_HOME}/resources/app/extensions/cursor-agent/dist/vendor/ripgrep/x64-linux" || die
    fi
}
```

### Locale PAK Removal with chromium-2

```bash
# CHROMIUM_LANGS controls which locales to keep (based on user's L10N flags):
CHROMIUM_LANGS="af am ar bg bn ca cs da de el en-GB ..."

inherit chromium-2

src_prepare() {
    default
    pushd "${APP_HOME}/locales" >/dev/null || die
    chromium_remove_language_paks  # removes all .pak files not in CHROMIUM_LANGS
    popd >/dev/null || die
}
```

### Desktop File and Icon Installation

```bash
src_install() {
    # Rewrite desktop file (upstream Exec= path is wrong for Gentoo):
    sed -e "s|^Exec=/.*/cursor|Exec=cursor ${EXEC_EXTRA_FLAGS[*]}|" \
        -e "s|^Icon=.*|Icon=cursor|" \
        usr/share/applications/cursor.desktop > "${T}/cursor.desktop" || die
    domenu "${T}/cursor.desktop"

    # Install icon at multiple sizes for hicolor theme compatibility:
    local size
    for size in 16 24 32 48 64 128 256 512; do
        newicon -s "${size}" usr/share/pixmaps/app.png appname.png
    done
}
```

### pkg_postinst with optfeature

```bash
pkg_postinst() {
    xdg_pkg_postinst

    # Suggest optional packages:
    optfeature "desktop notifications" x11-libs/libnotify
    optfeature "keyring/secret storage support" "virtual/secret-service"
    optfeature "Wayland GPU acceleration" "gui-libs/xdg-desktop-portal-wlr"
}
```

### Gotchas for Electron/Node

1. **Never use `KEYWORDS="amd64"`** — use `KEYWORDS="-* ~amd64"` to indicate this is a binary-only package not stable on any arch
2. **RESTRICT must include strip** — Portage stripping breaks Electron binaries
3. **QA_PREBUILT="*"** — suppresses soname QA checks on all prebuilt files
4. **chrome-sandbox must be SUID 4711** — without this, Electron's sandbox fails and the app may not start or will show warnings
5. **pax-mark m on the main executable** — required on PaX-enabled kernels; harmless on non-PaX kernels
6. **BUILD_ID** — Electron apps often have a commit/build ID separate from the version; it appears in the download URL and must be updated with each version bump
7. **Locale PAK files** — always use `chromium-2` + `chromium_remove_language_paks` to reduce installed size by ~50MB
