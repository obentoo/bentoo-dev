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
| Binary `.deb`                  | `binary-deb.ebuild`            |
| Binary direct download         | `binary-direct.ebuild`         |
| AppImage                       | `binary-appimage.ebuild`       |
| Live + snapshot dual-mode      | `live-snapshot.ebuild`         |
| GStreamer plugin               | `gstreamer-plugin.ebuild`      |

## Payload to sub-agent

Invoque `ebuild-creator` via tool `Agent` com:

1. **Task**: criar ebuild para `<category/package>` versão `<version>`
2. **Profile content**: o markdown do profile carregado pela skill
3. **Template path**: caminho absoluto do template escolhido
4. **Gotchas**: `${CLAUDE_PLUGIN_ROOT}/references/gotchas.md` se houver dúvida sobre regras críticas
5. **User context**: o pedido original (`$ARGUMENTS`), URLs upstream, branch/tag, etc.

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
