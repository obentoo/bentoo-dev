---
description: >
  Edita ebuilds Gentoo existentes preservando consistência entre IUSE,
  dependências, metadata.xml e phase functions. Use ao pedir "edit ebuild",
  "editar ebuild", "alterar ebuild", "add USE flag", "fix dependencies",
  "adicionar patch", "modificar src_install", "fix build with gcc-15",
  ou qualquer modificação cirúrgica em ebuilds já existentes.
allowed-tools: Read Write Edit Bash(ebuild *) Glob Grep Agent
argument-hint: "[category/package] [change-description]"
effort: high
paths:
  - "**/*.ebuild"
  - "**/metadata.xml"
  - "**/files/**"
  - "**/eclass/**"
---

# ebuild-edit

Aplica modificações pontuais em ebuilds existentes mantendo consistência cross-file (IUSE ↔ deps ↔ metadata.xml ↔ phase functions). Delega ao sub-agent `ebuild-editor`.

## Overlay context

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh 2>/dev/null || echo "No overlay detected"`

- `bentoo`: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/bentoo.md`
- demais: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/default.md`

## Delegate

Invoque o sub-agent `ebuild-editor` (via tool `Agent`) passando:

1. **Task**: descrição precisa da mudança (add USE flag X, add patch Y, fix dep Z, etc.)
2. **Target ebuild**: path absoluto do ebuild a modificar
3. **Profile content**: profile carregado
4. **Gotchas**: `${CLAUDE_PLUGIN_ROOT}/references/gotchas.md` quando relevante
5. **Reference loading hints**: aponte qual reference em `${CLAUDE_PLUGIN_ROOT}/references/` o sub-agent deve consultar:
   - `eclass-guide.md` → escolha/troca de eclass
   - `dependency-syntax.md` → blocos USE-conditional, REQUIRED_USE, slot deps
   - `language-ecosystems.md` → Go/Rust/Java/Python/Ruby/Perl/Electron

## Post-action

1. Verificar consistência IUSE/deps/metadata.xml
2. Se SRC_URI mudou → confirmar Manifest regenerado
3. Apresentar diff resumido ao usuário
