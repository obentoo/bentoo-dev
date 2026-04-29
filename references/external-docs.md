# Canonical Gentoo Documentation Index

Curated index of upstream Gentoo documentation. Lazy-loaded — read this file only when the embedded plugin knowledge (`gotchas.md`, `eclass-guide.md`, `dependency-syntax.md`, `language-ecosystems.md`, `skills/bentoo/references/*.md`, `assets/templates/*`) is insufficient and you need the canonical source.

> **Rule of thumb**: prefer the **devmanual** (normative) over the **wiki** (descriptive) when both exist. Cite **PMS** (Package Manager Specification) for any behaviour question that affects multiple package managers.

---

## 1. Foundational reading

| URL | What it is |
|---|---|
| https://wiki.gentoo.org/wiki/Ebuild | Wiki overview of the `.ebuild` format. |
| https://wiki.gentoo.org/wiki/Basic_guide_to_write_Gentoo_Ebuilds | Wiki: tutorial for first-time ebuild authors. |
| https://devmanual.gentoo.org/quickstart/index.html | Devmanual quickstart — minimal walkthrough. |
| https://devmanual.gentoo.org/ebuild-writing/index.html | Devmanual canonical ebuild-writing manual. |
| https://devmanual.gentoo.org/eclass-reference/ebuild/index.html | Devmanual: variables and atom syntax (normative). |

## 2. Variables, dependencies, USE flags

| URL | Topic |
|---|---|
| https://devmanual.gentoo.org/ebuild-writing/variables/index.html | Special variables (DESCRIPTION, SRC_URI, LICENSE, SLOT, IUSE, REQUIRED_USE, PROPERTIES, RESTRICT, S, DOCS). |
| https://devmanual.gentoo.org/general-concepts/dependencies/index.html | DEPEND/RDEPEND/BDEPEND/IDEPEND/PDEPEND, SLOT deps, USE deps, blockers. |
| https://devmanual.gentoo.org/general-concepts/use-flags/index.html | USE-flag policy and best practice. |
| https://devmanual.gentoo.org/ebuild-writing/use-conditional-code/index.html | `use foo`, `usev`, `use_enable`; subshell pitfalls. |
| https://wiki.gentoo.org/wiki/Keywording | KEYWORDS policy: `~arch` vs `arch` vs `-arch`. |

## 3. Phase functions, EAPI, PMS

| URL | Topic |
|---|---|
| https://devmanual.gentoo.org/ebuild-writing/functions/index.html | `src_unpack/prepare/configure/compile/test/install`, `pkg_setup/postinst/postrm`. |
| https://devmanual.gentoo.org/ebuild-writing/eapi/index.html | EAPI comparison (1 → 8). |
| https://dev.gentoo.org/~ulm/pms/head/pms.html | **Package Manager Specification (PMS)** — normative. |
| https://gitweb.gentoo.org/proj/pms.git/ | PMS git repo. |

## 4. Common mistakes and maintenance

| URL | Topic |
|---|---|
| https://devmanual.gentoo.org/ebuild-writing/common-mistakes/index.html | Common mistakes: `\|\| die`, `static` vs `static-libs`, `-Werror`, KEYWORDS hygiene, pkg-config. |
| https://devmanual.gentoo.org/ebuild-maintenance/new-ebuild/index.html | Adding a new ebuild (KEYWORDS bootstrap, bugzilla flow). |
| https://devmanual.gentoo.org/ebuild-maintenance/removal/index.html | Removal: last-rite, deprecation, treecleaner. |

## 5. Eclasses

| URL | Topic |
|---|---|
| https://devmanual.gentoo.org/eclass-reference/index.html | Devmanual eclass-reference index. |
| https://devmanual.gentoo.org/eclass-writing/index.html | How to write an eclass. |
| https://api.gentoo.org/eclass-reference/all-eclasses.html | Auto-generated reference for **every** eclass (cmake, meson, distutils-r1, cargo, go-module, autotools, multilib-minimal, git-r3, etc.). |
| https://wiki.gentoo.org/wiki/Eclass | Wiki: eclass concept. |

## 6. Manifest, SRC_URI, FILESDIR

| URL | Topic |
|---|---|
| https://wiki.gentoo.org/wiki/Repository_format/package/Manifest | Manifest2 format. |
| https://devmanual.gentoo.org/general-concepts/manifest/index.html | How Manifest works (devmanual). |
| https://wiki.gentoo.org/wiki/SRC_URI | SRC_URI syntax, `mirror://`, `->` rename. |
| https://wiki.gentoo.org/wiki/Project:Mirrors | Official mirrors and protocols. |

## 7. Overlay / Portage repository

| URL | Topic |
|---|---|
| https://wiki.gentoo.org/wiki/Creating_an_ebuild_repository | Creating an overlay (basic structure). |
| https://wiki.gentoo.org/wiki/Project:Overlays/Overlays_guide | Official overlay guide. |
| https://wiki.gentoo.org/wiki/Eselect/Repository | `eselect-repository` (replaces layman). |
| https://wiki.gentoo.org/wiki/Custom_repository | Custom/local repository. |
| https://wiki.gentoo.org/wiki/Repository_format/profiles | `profiles/`, `repo_name`, `categories`. |
| https://wiki.gentoo.org/wiki/Repository_format/metadata | `metadata/layout.conf` (`masters`, `thin-manifests`, `eclass-overrides`). |
| https://wiki.gentoo.org/wiki/Project:Portage/Sync | Sync engines (rsync, git, svn). |
| https://wiki.gentoo.org/wiki/Project:Portage | Portage project hub. |

## 8. QA tools

| URL | Topic |
|---|---|
| https://wiki.gentoo.org/wiki/Pkgcheck | `pkgcheck scan` — static QA analysis. |
| https://wiki.gentoo.org/wiki/Pkgdev | `pkgdev manifest`, `pkgdev commit`, `pkgdev push`, `pkgdev mask`. |
| https://wiki.gentoo.org/wiki/Repoman | Repoman (deprecated in favour of pkgdev). |
| https://devmanual.gentoo.org/tools-reference/ebuild/index.html | `ebuild(1)` command reference. |
| https://wiki.gentoo.org/wiki/Eshowkw | `eshowkw` — visualise KEYWORDS. |
| https://wiki.gentoo.org/wiki/Equery | `equery` — query installed packages. |

## 9. Live ebuilds, VCS, patches

| URL | Topic |
|---|---|
| https://wiki.gentoo.org/wiki/Project:Quality_Assurance/Backwards_Compatibility#Live_ebuilds | Policy for `9999` live ebuilds. |
| https://wiki.gentoo.org/wiki/Eclass/git-r3 | `git-r3.eclass` — git source fetching. |
| https://devmanual.gentoo.org/ebuild-writing/installation-files/patching/index.html | `PATCHES` array, `eapply`, `eapply_user`. |
| https://wiki.gentoo.org/wiki//etc/portage/patches | User patches in `/etc/portage/patches`. |

## 10. Cross-compile, multilib

| URL | Topic |
|---|---|
| https://wiki.gentoo.org/wiki/Cross_build_environment | Cross-compile environment. |
| https://wiki.gentoo.org/wiki/Project:Multilib | Multilib project (`multilib.eclass`, `multilib-build.eclass`, `multilib-minimal.eclass`). |
| https://wiki.gentoo.org/wiki/Crossdev | `crossdev`. |

## 11. Binary packages, binhost

| URL | Topic |
|---|---|
| https://wiki.gentoo.org/wiki/Binary_package_guide | Binary package guide. |
| https://wiki.gentoo.org/wiki/Binary_package_format | GPKG format. |
| https://wiki.gentoo.org/wiki/Binhost | Hosting a binhost. |

## 12. GLEPs (Gentoo Linux Enhancement Proposals)

| URL | Topic |
|---|---|
| https://www.gentoo.org/glep/ | Official GLEP index. |
| https://www.gentoo.org/glep/glep-0042.html | GLEP 42 — News mechanism. |
| https://www.gentoo.org/glep/glep-0074.html | GLEP 74 — Full-tree verification (Manifest). |
| https://www.gentoo.org/glep/glep-0075.html | GLEP 75 — Split distfile mirror structure. |

## 13. Policy and project governance

| URL | Topic |
|---|---|
| https://devmanual.gentoo.org/general-concepts/index.html | General concepts (atom syntax, slotting, profile). |
| https://devmanual.gentoo.org/policies/index.html | Official Gentoo policies. |
| https://wiki.gentoo.org/wiki/Project:Council | Council (project decisions). |
| https://wiki.gentoo.org/wiki/Project:Quality_Assurance | QA team. |
| https://wiki.gentoo.org/wiki/Project:Quality_Assurance/Policies | QA policies. |

---

## How to use this index from a sub-agent

1. Try the embedded reference first (`gotchas.md` for the 10 critical rules; topical references for deeper material).
2. Fall back to this index when you need normative wording, less common eclass behaviour, or a policy citation.
3. Prefer the **devmanual URL** when both wiki and devmanual cover the topic — devmanual is normative.
4. Do not paste large excerpts back into ebuilds — link the URL in a code comment only when the rationale is genuinely non-obvious.
