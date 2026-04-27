---
description: >
  Limpeza e manutenção de overlay Gentoo — remoção de versões antigas,
  regeneração de Manifests em batch, criação de metadata.xml ausentes,
  detecção de DIST entries órfãs. Use ao pedir "clean overlay",
  "limpar overlay", "remover versões antigas", "remove old versions",
  "maintain overlay", "regenerar manifests", "fix overlay health".
allowed-tools: Read Write Edit Bash(ebuild *) Bash(rm *) Bash(ls *) Glob Grep Agent
argument-hint: "[category/package | --all]"
effort: high
paths:
  - "**/*.ebuild"
  - "**/Manifest"
  - "**/metadata.xml"
  - "**/metadata/layout.conf"
---

# overlay-clean

Mantém saúde geral do overlay. Itera por `category/package/`, identifica problemas (versões obsoletas, Manifests stale, metadata.xml ausente, DIST entries órfãs) e aplica correções em batch. Delega ao sub-agent `overlay-maintainer`.

## Overlay context

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh 2>/dev/null || echo "No overlay detected"`

- `bentoo`: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/bentoo.md`
- demais: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/default.md`

## Delegate

Invoque o sub-agent `overlay-maintainer` (via tool `Agent`) passando:

1. **Task**: clean (remoção de antigos) | refresh-manifests | full-audit
2. **Scope**: pacote único `<cat/pkg>` ou `--all` (overlay inteiro)
3. **Profile content**
4. **Safety flags**: nunca remover live ebuilds (9999); nunca esvaziar diretório de pacote

## Post-action

Reportar ao usuário:
- Pacotes escaneados / removidos / com Manifest regenerado / metadata criada
- Falhas (network errors em manifest fetch, etc.)
- Estado final do overlay
