---
description: >
  Bump (atualização de versão) de ebuilds Gentoo — cópia da versão anterior
  como base, atualização de versão/commit/SRC_URI e regeneração do Manifest.
  Use ao pedir "bump version", "atualizar pacote", "nova versão",
  "update ebuild", "bump <pkg> to <ver>", "atualizar mesa para 26.0.5",
  "snapshot bump", ou qualquer pedido de incremento de versão.
allowed-tools: Read Write Edit Bash(cp *) Bash(ebuild *) Glob Grep Agent
argument-hint: "[category/package] [new-version]"
effort: high
paths:
  - "**/*.ebuild"
  - "**/Manifest"
---

# ebuild-bump

Realiza version bumps (standard ou snapshot `_p<YYYYMMDD>`) com mudanças mínimas no ebuild copiado. Delega ao sub-agent `ebuild-bumper`.

## Overlay context

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh 2>/dev/null || echo "No overlay detected"`

- `bentoo`: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/bentoo.md`
- demais: leia `${CLAUDE_PLUGIN_ROOT}/assets/profiles/default.md`

## Bump mode detection

- **Standard bump**: `<pkg>-<old>` → `<pkg>-<new>` (versão semver normal)
- **Snapshot bump**: `<pkg>-<base>_p<YYYYMMDD>` (atualiza `GIT_COMMIT` + data)
- **Live ebuild**: `9999.ebuild` — geralmente não precisa de bump explícito

## Delegate

Invoque o sub-agent `ebuild-bumper` (via tool `Agent`) passando:

1. **Task**: bump `$pkg` para a versão `$version`
2. **Mode**: standard | snapshot (detectar pelo formato `_p<YYYYMMDD>` em `$version`)
3. **New commit hash** (snapshot apenas)
4. **Profile content**
5. **Old ebuild path** (para usar como base)
6. **Remove old version?**: yes/no (default: no)

## Post-action

1. Confirmar novo ebuild válido + Manifest regenerado
2. Reportar: old → new, files created/removed, mudanças não-óbvias (S=, GIT_COMMIT, MY_P)
