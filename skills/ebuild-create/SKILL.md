---
description: >
  Cria novos ebuilds Gentoo do zero. Use sempre que o usuário pedir
  "criar ebuild", "novo pacote", "create ebuild", "new package",
  "package XYZ from source/deb/AppImage", ou ao detectar tarballs/repos
  a empacotar — mesmo que o usuário não diga explicitamente "ebuild".
allowed-tools: Read Write Edit Bash(ebuild *) Bash(mkdir *) Bash(cp *) Glob Grep Agent
argument-hint: "[category/package] [version]"
effort: high
paths:
  - "**/*.ebuild"
  - "**/metadata.xml"
  - "**/Manifest"
  - "**/profiles/**"
  - "**/eclass/**"
  - "**/metadata/layout.conf"
---

# ebuild-create

Cria um novo ebuild Gentoo a partir de upstream (tarball, git repo, .deb, AppImage, binary direct). Detecta o build system, escolhe o template apropriado e delega ao sub-agent `ebuild-creator` via tool `Agent`.

## Overlay context

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh 2>/dev/null || echo "No overlay detected"`

Use o nome detectado para carregar o profile correspondente:
- Se `bentoo`: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/bentoo.md`
- Caso contrário: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/default.md`

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

## Delegate

Invoque o sub-agent `ebuild-creator` (via tool `Agent`) passando:

1. **Task**: criar ebuild para `<category/package>` versão `<version>`
2. **Profile content**: o markdown do profile carregado acima
3. **Template path**: caminho absoluto do template escolhido
4. **Gotchas**: leia `${CLAUDE_PLUGIN_ROOT}/references/gotchas.md` se houver dúvida sobre regras críticas
5. **User context**: o pedido original do usuário, URLs upstream, branch/tag, etc.

## Post-action

Após a conclusão do sub-agent:
1. Confirme que ebuild + metadata.xml + Manifest foram criados
2. Apresente paths absolutos ao usuário para revisão final
