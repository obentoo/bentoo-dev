# EAPI 8 → 9 migration

> **Canonical references**
> - PMS (normative): https://projects.gentoo.org/pms/9/pms.html
> - EAPI 9 cheat sheet: https://projects.gentoo.org/pms/9/eapi-cheatsheet.pdf
> - devmanual EAPI index: https://devmanual.gentoo.org/ebuild-writing/eapi/
> - Tentative features tracker: https://wiki.gentoo.org/wiki/Future_EAPI/EAPI_9_tentative_features

EAPI 9 was approved by the Gentoo Council on 2025-12-14. EAPI 8 is **not**
deprecated, so this plugin renders `EAPI=8` by default. Emit `EAPI=9` only when:

1. the target overlay does not list `9` in `eapis-banned` / `eapis-deprecated`
   (`metadata/layout.conf`), and
2. the consuming Portage is recent enough to support it.

To render an EAPI 9 ebuild from a template, export `EAPI=9` before calling
`render-template.sh --env` (the `@@EAPI@@` placeholder picks it up).

## What changes (the parts that touch ebuilds)

### Banned commands
| Removed in EAPI 9 | Replacement |
|-------------------|-------------|
| `assert`          | `pipestatus` (checks the exit status of every command in the pipeline) |
| `domo`            | `insinto /usr/share/locale … ; newins` (or the relevant install path) |

`assert` example:
```bash
# EAPI 8
foo | bar
assert "foo | bar failed"

# EAPI 9
foo | bar || die "foo | bar failed"      # if only the last status matters
pipestatus || die "foo | bar failed"     # if any stage failing must die
```

### New builtins
- `pipestatus` — succeeds only if **every** command in the most recent pipeline
  exited 0. Use it where `|| die` after a pipeline would only catch the last
  command. Directly supersedes the `|| die` pipeline caveat in `gotchas.md` #2.
- `edo` — prints a command, then runs it, dying on failure (`edo make install`).
- `ver_replacing` — version of the package being replaced, for use in
  `pkg_*` phases (cleaner than parsing `REPLACING_VERSIONS`).

### Variables no longer exported to the environment
These remain available **inside the ebuild** but are no longer exported to
helper subprocesses (scripts/Makefiles invoked from a phase):
`P PF PN PV PVR PR CATEGORY A FILESDIR DISTDIR WORKDIR S USE REPLACING_VERSIONS`.

Still exported: `BROOT SYSROOT ESYSROOT TMPDIR HOME` (and `ED`/`EROOT`/`D`/`ROOT`).

Fix: if a `Makefile`/helper relied on `$S` or `$PV` from the environment, pass
them explicitly, e.g. `emake VERSION="${PV}"`.

### Other behavioural changes
- **Absolute symlinks** pointing into `D`/`ROOT` are merged as-is (no longer
  rewritten). Audit `dosym` targets that were relative-by-necessity.
- **Bash 5.3** is the guaranteed interpreter (was 5.0): `${ command; }` value
  substitution, `local -I`, and `&`-substitution are available.
- **Profiles**: EAPI 9 introduces a profile default-EAPI mechanism plus
  `use.stable` / `package.use.stable` (only relevant when editing `profiles/`).

## Quick checklist when bumping an ebuild to EAPI 9
- [ ] Overlay `layout.conf` does not ban/deprecate EAPI 9.
- [ ] No `assert` / `domo` left (replace per table above).
- [ ] Pipelines that must not silently pass use `pipestatus` (not just `|| die`).
- [ ] No helper/Makefile depends on a now-unexported variable.
- [ ] `dosym` absolute targets reviewed.
- [ ] `pkgcheck scan` is clean against the new ebuild.
