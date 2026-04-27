---
description: >
  Validação QA de ebuilds Gentoo — checks de EAPI, copyright, || die,
  eapply_user, KEYWORDS, IUSE consistency, metadata.xml, Manifest, SLOT,
  LICENSE; roda pkgcheck quando disponível. Use ao pedir "run QA",
  "verificar QA", "check ebuild", "validar ebuild", "lint ebuild",
  "pkgcheck", "verificar pacote", "audit ebuild" — read-only, não modifica.
allowed-tools: Read Bash(pkgcheck *) Bash(ebuild *) Glob Grep Agent
argument-hint: "[category/package | path-to-ebuild]"
effort: medium
model: haiku
context: fork
agent: qa-checker
paths:
  - "**/*.ebuild"
  - "**/metadata.xml"
  - "**/Manifest"
---

# ebuild-qa

Valida ebuilds sem modificar arquivos. Roda 10 checks manuais + pkgcheck (se disponível). Output apenas em stdout. Delega ao sub-agent `qa-checker`.

## Overlay context

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh 2>/dev/null || echo "No overlay detected"`

## Delegate

Invoque o sub-agent `qa-checker` (via tool `Agent`) passando:

1. **Targets**: paths de ebuilds ou diretório de pacote
2. **Run pkgcheck?**: sim por padrão se `pkgcheck` no PATH
3. **Output format**: estruturado `[ERROR|WARNING|INFO]` + summary final

## Post-action

Apresentar ao usuário:
- Lista estruturada de findings
- Summary count: `N error(s), N warning(s), N info — PASS|FAIL`
- Se `pkgcheck` indisponível, sugerir `emerge dev-util/pkgcheck`
