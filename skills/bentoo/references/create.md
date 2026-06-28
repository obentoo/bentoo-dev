# Reference: create

Detalhes operacionais para a intenção `create` (criar ebuild novo) da skill `bentoo`.

## Sub-agent

`ebuild-creator`

## Template selection

Determine o tipo de pacote a partir da fonte upstream e selecione o template em `${CLAUDE_PLUGIN_ROOT}/assets/templates/`:

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

Para EAPI 9 (overlays que o permitem), exporte `EAPI=9` antes de chamar
`render-template.sh` — ver `references/eapi9-migration.md`.

## Payload to sub-agent

Invoque `ebuild-creator` via tool `Agent` com:

1. **Task**: criar ebuild para `<category/package>` versão `<version>`
2. **Profile content**: o markdown do profile carregado pela skill
3. **Template path**: caminho absoluto do template escolhido (o sub-agent usa este; não reescolhe)
4. **User context**: o pedido original (`$ARGUMENTS`), URLs upstream, branch/tag, etc.

> Os 10 gotchas já são preloaded no `ebuild-creator` via `skills: [bentoo-dev:gotchas]` — não passe `gotchas.md` no payload.

## Required arguments

Antes de delegar, garanta que tem:
- `<category/package>` (ex.: `dev-libs/foo`)
- `<version>` (ex.: `1.2.3` ou `0_p20260427`)
- Fonte upstream (URL, git repo, .deb path, AppImage path)

Se faltar qualquer um, pergunte ao usuário antes de delegar.

## Post-action

1. Confirme que `ebuild + metadata.xml + Manifest` foram criados.
2. Apresente paths absolutos ao usuário para revisão final.
3. Se `pkgcheck` estiver disponível, sugira rodar a intenção `qa` em seguida.
