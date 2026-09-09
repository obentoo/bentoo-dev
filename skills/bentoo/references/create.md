# Reference: create

Operational detail for the `create` intent (author a new ebuild) of the `bentoo` skill.

## Sub-agent

`ebuild-creator`

## Template selection

Determine the package type from the upstream source and pick the template under `${CLAUDE_PLUGIN_ROOT}/assets/templates/`:

| Upstream                       | Template                       |
|--------------------------------|--------------------------------|
| CMake project                  | `source-cmake.ebuild`          |
| Meson project                  | `source-meson.ebuild`          |
| Autotools (configure.ac)       | `source-autotools.ebuild`      |
| Rust / Cargo.toml              | `source-cargo.ebuild`          |
| Go module / go.mod             | `source-go.ebuild`             |
| Python (PEP 517 / pyproject)   | `source-python.ebuild`         |
| Python from PyPI (pypi eclass) | `source-pypi.ebuild`           |
| Binary `.deb`                  | `binary-deb.ebuild`            |
| Binary direct download         | `binary-direct.ebuild`         |
| AppImage                       | `binary-appimage.ebuild`       |
| Live + snapshot dual-mode      | `live-snapshot.ebuild`         |
| GStreamer plugin               | `gstreamer-plugin.ebuild`      |
| `virtual/` package             | `virtual.ebuild`               |
| System user (acct-user)        | `acct-user.ebuild`             |
| System group (acct-group)      | `acct-group.ebuild`            |

For EAPI 9 (on overlays that allow it), export `EAPI=9` before calling
`render-template.sh` — see `references/eapi9-migration.md`.

## Payload to sub-agent

Invoke `ebuild-creator` through the `Agent` tool with:

1. **Task**: create an ebuild for `<category/package>` version `<version>`
2. **Profile content**: the profile markdown loaded by the skill
3. **Template path**: absolute path of the chosen template (the sub-agent uses this one; it does not re-pick)
4. **User context**: the original request (`$ARGUMENTS`), upstream URLs, branch/tag, and so on

> The 11 gotchas are already preloaded into `ebuild-creator` via
> `skills: [bentoo-dev:gotchas]` — do not pass `gotchas.md` in the payload.

## Required arguments

Before delegating, make sure you have:
- `<category/package>` (e.g. `dev-libs/foo`)
- `<version>` (e.g. `1.2.3` or `0_p20260427`)
- The upstream source (URL, git repo, .deb path, AppImage path)

If any is missing, ask the user before delegating.

## Post-action

1. Confirm that `ebuild + metadata.xml + Manifest` were all created.
2. Present the absolute paths to the user for a final review.
3. If `pkgcheck` is available, suggest running the `qa` intent next.
