# Gentoo Dependency Syntax Reference

Compact reference for dependency atom syntax in DEPEND/RDEPEND/BDEPEND/IDEPEND and REQUIRED_USE.

**Canonical references**:
- https://devmanual.gentoo.org/general-concepts/dependencies/index.html — full dependency semantics (normative).
- https://devmanual.gentoo.org/eclass-reference/ebuild/index.html — atom syntax (SLOT/USE deps, defaults, blockers).
- https://devmanual.gentoo.org/general-concepts/use-flags/index.html — USE-flag policy.
- https://devmanual.gentoo.org/ebuild-writing/use-conditional-code/index.html — USE-conditional code patterns.
- See `references/external-docs.md` for the full index.

---

## Version Operators

```
>=dev-libs/foo-1.0        # greater than or equal to 1.0
>dev-libs/foo-1.0         # strictly greater than 1.0
=dev-libs/foo-1.0         # exactly version 1.0
=dev-libs/foo-1.0*        # any version matching 1.0.* (glob prefix match)
~dev-libs/foo-1.0         # version 1.0, any revision (-r0, -r1, etc.)
<=dev-libs/foo-2.0        # less than or equal to 2.0
<dev-libs/foo-2.0         # strictly less than 2.0
dev-libs/foo              # any version (no operator)
```

**Revision note**: `~pkg-1.0` matches `pkg-1.0`, `pkg-1.0-r1`, `pkg-1.0-r2`, etc. Use this when you want any revision of a specific version. `=pkg-1.0` matches only `pkg-1.0-r0`.

---

## USE Dependencies

```
dev-libs/foo[ssl]           # foo must have ssl USE flag enabled
dev-libs/foo[-ssl]          # foo must have ssl USE flag disabled
dev-libs/foo[ssl,-debug]    # ssl enabled AND debug disabled
dev-libs/foo[ssl(+)]        # ssl enabled; if foo doesn't have this flag,
                             # treat it as if enabled (default on)
dev-libs/foo[ssl(-)]        # ssl enabled; if foo doesn't have this flag,
                             # treat it as if disabled (default off)
```

**`(+)` and `(-)` modifiers**: Used for flags added in newer versions of a package. `(+)` says "if this flag doesn't exist in the dep, assume it's ON" — useful for flags that were implicit before being made explicit.

```bash
# Real example from mesa in this overlay:
>=media-libs/mesa-17.1.0[gbm(+)]
# gbm(+) means: if mesa doesn't have gbm USE flag (older version), assume gbm is available
```

---

## Slot Dependencies

```
dev-libs/foo:2              # require slot 2 specifically
dev-libs/foo:=              # any slot, but rebuild this package when foo's
                             # subslot changes (most common for libraries)
dev-libs/foo:2=             # slot 2, rebuild on subslot change
dev-libs/foo:*              # any slot, no rebuild tracking
```

**When to use `:=`**: Any library that your package links against should use `:=` in RDEPEND. This ensures your package is rebuilt when the library's ABI changes.

```bash
RDEPEND="
    >=dev-libs/openssl-1.1:=    # rebuild when openssl ABI changes
    virtual/zlib-1.2.9:=[${MULTILIB_USEDEP}]   # zlib with multilib + rebuild tracking
"
```

---

## Subslots

```
SLOT="0"          # slot 0, subslot 0 (no subslot change triggers)
SLOT="0/16.1"     # slot 0, subslot 16.1 (e.g., library SONAME version)
SLOT="2"          # slot 2 (for parallel-installable packages like Python, Ruby)
```

**Subslot convention for libraries**: Set `SLOT="0/${SONAME_VER}"` where SONAME_VER matches the library's SONAME (e.g., `libfoo.so.16.1`). When you bump the SONAME, change the subslot, triggering rebuilds of all `:=` consumers.

---

## Blockers

```
!dev-libs/foo        # soft blocker: foo cannot be installed AT THE SAME TIME;
                      # Portage will unmerge it before merging your package
!!dev-libs/foo       # hard blocker: foo MUST be manually unmerged first;
                      # Portage will refuse to proceed
```

```bash
# Soft blocker — Portage handles it automatically:
RDEPEND="!<dev-libs/foo-2.0"   # blocks old versions (upgrade scenario)

# Hard blocker — user must intervene:
RDEPEND="!!dev-libs/conflicting-package"
```

---

## Conditionals

```bash
# USE flag conditional:
RDEPEND="
    ssl? ( dev-libs/openssl:= )
    !ssl? ( dev-libs/gnutls:= )
"

# Any-of (OR): at least one must be satisfied
RDEPEND="
    || (
        sys-apps/systemd
        sys-apps/systemd-utils
    )
"

# Real example from cursor in this overlay:
RDEPEND="
    || (
        sys-apps/systemd
        sys-apps/systemd-utils
    )
    >=app-accessibility/at-spi2-core-2.46.0:2
"

# Negated USE flag:
RDEPEND="
    !kerberos? ( )   # nothing extra needed
    kerberos? ( app-crypt/mit-krb5 )
"
```

---

## DEPEND vs RDEPEND vs BDEPEND vs IDEPEND

| Variable | When it's needed | Example |
|----------|-----------------|---------|
| `DEPEND` | At compile time on the BUILD host (for cross-compilation) | C headers, static libs |
| `RDEPEND` | At runtime on the TARGET host | Shared libraries, tools used by the package |
| `BDEPEND` | At build time on the BUILD host | build tools (cmake, autoconf, pkg-config) |
| `IDEPEND` | At install time on the BUILD host (pkg_preinst/postinst) | xdg-utils for cache updates |

**Practical rules**:
- Libraries your package links against: `RDEPEND` (with `:=`)
- `cmake`, `meson`, `autoconf`: `BDEPEND`
- Headers/static libs only used at compile time: `DEPEND`
- `xdg-utils`, `gtk-update-icon-cache`: `IDEPEND`
- Most runtime dependencies: `RDEPEND`
- Set `DEPEND="${RDEPEND}"` when compile deps == runtime deps (common for C libraries)

```bash
BDEPEND="
    virtual/pkgconfig
    >=dev-build/cmake-3.20
"

DEPEND="
    >=dev-libs/openssl-1.1:=
"

RDEPEND="
    ${DEPEND}
    sys-libs/zlib:=
"
```

---

## REQUIRED_USE

Controls which USE flag combinations are valid. Checked before building.

```bash
# Any-of: at least one of a, b must be enabled
REQUIRED_USE="|| ( a b )"

# At-most-one: zero or one of a, b (not both)
REQUIRED_USE="?? ( a b )"

# Exactly-one: exactly one of a, b must be enabled (exclusive-or)
REQUIRED_USE="^^ ( a b )"

# Implication: if a is enabled, b must also be enabled
REQUIRED_USE="a? ( b )"

# Negation: if a is enabled, b must NOT be enabled
REQUIRED_USE="a? ( !b )"

# Combined example from mesa in this overlay:
REQUIRED_USE="
    llvm? ( ${LLVM_REQUIRED_USE} )
    video_cards_i915? ( llvm )
    video_cards_lavapipe? ( llvm vulkan )
    video_cards_radeon? ( x86? ( llvm ) amd64? ( llvm ) )
    video_cards_zink? ( vulkan opengl )
    video_cards_nvk? ( vulkan video_cards_nouveau )
"
```

---

## Multilib: MULTILIB_USEDEP

When a library is built with `multilib-minimal`, packages depending on it for both 32-bit and 64-bit must use `${MULTILIB_USEDEP}`:

```bash
# In a multilib package's RDEPEND:
RDEPEND="
    >=x11-libs/libdrm-2.4.121[${MULTILIB_USEDEP}]
    >=dev-libs/expat-2.1.0[${MULTILIB_USEDEP}]
    >=virtual/zlib-1.2.9:=[${MULTILIB_USEDEP}]
"

# ${MULTILIB_USEDEP} expands to something like: abi_x86_32(-)?,abi_x86_64(-)?
# It ensures the dep is also built for each needed ABI
```

---

## Python: PYTHON_USEDEP and PYTHON_DEPS

```bash
PYTHON_COMPAT=( python3_{11..14} )
inherit python-single-r1   # or python-r1, distutils-r1

# For python-single-r1 packages:
RDEPEND="
    ${PYTHON_DEPS}
    $(python_gen_cond_dep '
        dev-python/requests[${PYTHON_USEDEP}]
        dev-python/urllib3[${PYTHON_USEDEP}]
    ')
"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# For python-any-r1 (build-time only):
BDEPEND="
    ${PYTHON_DEPS}
    $(python_gen_any_dep '
        dev-python/mako[${PYTHON_USEDEP}]
    ')
"
python_check_deps() {
    python_has_version "dev-python/mako[${PYTHON_USEDEP}]"
}
```

---

## LLVM: llvm_gen_dep

```bash
LLVM_COMPAT=( {18..21} )
inherit llvm-r1

# llvm_gen_dep generates one dep entry per supported LLVM slot,
# with LLVM_SLOT substituted appropriately:
RDEPEND="
    $(llvm_gen_dep "
        llvm-core/llvm:\${LLVM_SLOT}[llvm_targets_AMDGPU(+)]
        opencl? (
            llvm-core/clang:\${LLVM_SLOT}
            dev-util/spirv-llvm-translator:\${LLVM_SLOT}
        )
    ")
"
```

**Note**: `${LLVM_SLOT}` inside `llvm_gen_dep` is a literal string (single quotes or escaped) that gets substituted by the eclass. It must NOT be expanded by bash at parse time.

---

## Common Patterns

### Virtual packages
```bash
RDEPEND="
    virtual/jdk:17        # Java JDK slot 17
    virtual/jre:17        # Java JRE slot 17
    virtual/pkgconfig     # any pkg-config implementation
    virtual/libelf:=      # any libelf implementation, with rebuild
    virtual/opencl-3      # OpenCL 3.x
"
```

### Optional runtime features
```bash
RDEPEND="
    wayland? ( >=dev-libs/wayland-1.18.0 )
    kerberos? ( app-crypt/mit-krb5 )
    !kerberos? ( )
"
```

### Test dependencies
```bash
RESTRICT="!test? ( test )"

BDEPEND="
    test? (
        dev-python/pytest
        dev-libs/gtest
    )
"
```
