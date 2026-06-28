# KEYWORDS and architectures

How the `KEYWORDS` variable controls which architectures an ebuild is visible
on, and which arches Gentoo currently keywords.

**Canonical references**:
- https://wiki.gentoo.org/wiki/Keywording — wiki overview of keywording.
- https://devmanual.gentoo.org/keywording/ — devmanual keywording section (concepts + workflow).
- See `references/external-docs.md` for the full index.

---

## Keyword forms

| Form          | Meaning                                                                                 |
|---------------|-----------------------------------------------------------------------------------------|
| `~arch`       | **Testing**: believed to work, no known serious bugs, but needs more testing before stabilization. |
| `arch`        | **Stable**: widely tested, known to work with no serious issues on that platform.        |
| `-arch`       | **Does not work**: broken/unsupported on that arch (code, hardware, or binary-only reasons). Hides the version there. |
| `-*`          | "Not worth testing on unlisted arches" — typically binary-only packages. Combined with explicit positive keywords, e.g. `-* amd64`. |
| `**`          | Not a value you write in `KEYWORDS`. It is an **`ACCEPT_KEYWORDS`** wildcard a user sets to accept *any* keyword (including empty), used to install live ebuilds. |
| *(empty)*     | Live ebuilds (e.g. `-9999`) **do not set `KEYWORDS` at all**. With no keyword the version is masked everywhere unless the user opts in with `ACCEPT_KEYWORDS="**"` or `package.accept_keywords`. |

```bash
# Standard testing keyword for a single arch the maintainer tests:
KEYWORDS="~amd64"

# Mixed: stable on amd64/x86, testing elsewhere:
KEYWORDS="amd64 ~arm64 ~ppc64 ~riscv x86"

# Binary-only package, only ever amd64:
KEYWORDS="-* amd64"

# Live (9999) ebuild — NO KEYWORDS line at all:
if [[ ${PV} == *9999* ]]; then
    inherit git-r3
    # (no KEYWORDS)
else
    KEYWORDS="~amd64"
fi
```

> Gotcha: a live (`9999`) ebuild with `KEYWORDS="~amd64"` (or any value) is a QA
> error. Leave the variable unset for live ebuilds.

---

## Currently keyworded architectures

From `profiles/arch.list` in the gentoo repository. **Stable** arches accept
both `arch` and `~arch`; **testing-only** arches realistically only ever carry
`~arch` (no stable profiles / stabilization).

**Stable-capable Linux arches:**
`amd64`, `arm`, `arm64`, `hppa`, `loong`, `mips`, `ppc`, `ppc64`, `riscv`,
`sparc`, `x86`

**Testing-only (`~arch`) arches:**
`alpha`, `m68k`, `s390`

> `ia64` was removed from Gentoo and is no longer keyworded. Historical ebuilds
> may still reference it; do not add new `~ia64` keywords.

**Prefix / non-Linux keywords** (only relevant to Gentoo Prefix; rarely touched
in a typical overlay): `amd64-linux`, `arm-linux`, `arm64-linux`,
`ppc64-linux`, `riscv-linux`, `x86-linux`, `arm64-macos`, `ppc-macos`,
`x86-macos`, `x64-macos`, `x64-solaris`.

---

## Overlay policy

- **Only keyword what you actually test.** In an overlay, that almost always
  means `~amd64` alone — or the specific arch(es) the maintainer runs.
- **Never mark `arch` (stable) without stabilization testing.** Stable keywords
  imply the package is widely tested and trustworthy; an untested stable keyword
  is misleading and a QA violation.
- Prefer `~amd64` over `amd64` for new or freshly bumped overlay ebuilds.
- Copy keywords from upstream Gentoo only if you have verified the package
  behaves the same in your overlay; otherwise narrow them to what you test.

```bash
# Typical overlay ebuild — test on amd64 only:
KEYWORDS="~amd64"
```

---

## Tools

### `eshowkw` — inspect keywords
Part of `app-portage/gentoolkit`. Shows the keyword matrix across all versions
and arches for a package.

```bash
eshowkw sys-apps/foo            # keyword table for every version
eshowkw -a amd64,x86 cat/pkg    # restrict to specific arches
```

### `ekeyword` — edit keywords
Part of `app-portage/gentoolkit` (modern) and historically
`app-portage/gentoolkit-dev`; also bundled with `dev-util/pkgdev`. Edits the
`KEYWORDS` line in place.

```bash
ekeyword ~amd64 foo-1.2.3.ebuild        # add/replace ~amd64
ekeyword amd64 foo-1.2.3.ebuild         # promote ~amd64 -> amd64 (stabilize)
ekeyword ~arm64 ~riscv foo-1.2.3.ebuild # add multiple testing keywords
ekeyword -- -hppa foo-1.2.3.ebuild      # mark -hppa (does not work)
ekeyword ^alpha foo-1.2.3.ebuild        # drop the alpha keyword entirely
```

> `pkgdev` (`dev-util/pkgdev`) wraps `ekeyword` and regenerates the Manifest in
> one step; `app-portage/gentoolkit` provides both `eshowkw` and `ekeyword`.
