---
name: bentoo
description: >
  Manutenção completa de ebuilds e overlays Gentoo num único entry point.
  Recebe instrução em linguagem natural e roteia para a operação correta
  (criar / bump / editar / QA / limpar overlay), perguntando se ambígua.
when_to_use: >
  Use para QUALQUER operação em ebuilds ou overlay Gentoo. Triggers PT/EN:
  "criar ebuild", "novo pacote", "package from source/deb/AppImage/git",
  "bump version", "atualizar pacote", "atualizar mesa para 26.0.5",
  "snapshot bump", "nova versão", "update ebuild", "editar ebuild",
  "add USE flag", "fix dependencies", "adicionar patch", "modificar
  src_install", "fix build with gcc-15", "verificar QA", "validar ebuild",
  "lint ebuild", "pkgcheck", "audit ebuild", "limpar overlay", "remover
  versões antigas", "regenerar manifests", "fix overlay health".
allowed-tools: Read Write Edit Bash Glob Grep Agent
argument-hint: "<instrução em linguagem natural>"
effort: high
paths:
  - "**/*.ebuild"
  - "**/metadata.xml"
  - "**/Manifest"
  - "**/files/**"
  - "**/profiles/**"
  - "**/eclass/**"
  - "**/metadata/layout.conf"
---

# bentoo

Entry point único para operações em ebuilds e overlays Gentoo. Recebe instrução em linguagem natural via `$ARGUMENTS`, classifica a intenção, pergunta ao usuário se ambígua, carrega o reference detalhado da intenção e delega ao sub-agent especializado.

## Overlay context (preprocessed)

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh 2>/dev/null || echo "No overlay detected"`

Use o nome detectado para escolher o profile que será passado ao sub-agent:
- Se `bentoo`: `${CLAUDE_PLUGIN_ROOT}/assets/profiles/bentoo.md`
- Caso contrário: `${CLAUDE_PLUGIN_ROOT}/assets/profiles/default.md`

## User input

```
$ARGUMENTS
```

## Step 1 — Classifique a intenção

Analise `$ARGUMENTS` e o contexto da conversa, e determine UMA das 5 intenções abaixo. **Se o input for vazio**, peça ao usuário o que deseja fazer e liste as 5 opções.

| Intenção | Quando aplicar | Sub-agent | Reference |
|----------|----------------|-----------|-----------|
| `create` | Criar pacote novo do zero (não existe ainda no overlay). Ex: "criar ebuild para X", "novo pacote", "package XYZ from source/deb/AppImage/git" | `ebuild-creator` | `references/create.md` |
| `bump`   | Subir versão de um ebuild existente (cópia da versão anterior, atualiza versão/commit/SRC_URI). Ex: "bump mesa to 26.0.5", "snapshot bump", "atualizar para nova versão" | `ebuild-bumper` | `references/bump.md` |
| `edit`   | Modificação cirúrgica em ebuild que já existe, mantendo a mesma versão. Ex: "add USE flag", "fix dependencies", "adicionar patch", "fix build with gcc-15", "modificar src_install" | `ebuild-editor` | `references/edit.md` |
| `qa`     | Validação read-only de ebuilds. Ex: "validar QA", "lint", "pkgcheck", "audit ebuild" | `qa-checker` | `references/qa.md` |
| `clean`  | Manutenção do overlay como um todo: remover versões antigas, regenerar Manifests em batch, criar metadata.xml ausentes. Ex: "limpar overlay", "remover versões antigas", "fix overlay health" | `overlay-maintainer` | `references/clean.md` |

### Regras de desambiguação

Quando duas intenções podem se aplicar, **pergunte ao usuário antes de prosseguir**. Casos comuns:

- **"atualizar foo"** ou **"update foo"** → pode ser `bump` (subir versão) OU `edit` (corrigir um build na mesma versão). Pergunte: *"Atualizar para uma nova versão (bump) ou aplicar uma correção mantendo a versão atual (edit)?"*
- **"criar nova versão"** → pode ser `create` (pacote inédito) OU `bump` (próxima versão de pacote existente). Verifique se o pacote já existe no overlay; se sim, é `bump`. Se ambíguo após checagem, pergunte.
- **"fix overlay"** → pode ser `clean` (manutenção em batch) OU `qa` (audit read-only). Pergunte se o usuário quer apenas relatório (`qa`) ou aplicar correções (`clean`).
- **Input vazio ou genérico** ("ajuda com ebuild", "trabalhar no overlay") → pergunte qual das 5 operações.

Não invente argumentos faltando: se a intenção é clara mas faltam parâmetros (`<category/package>`, `<version>`, descrição da mudança), peça-os explicitamente.

## Step 2 — Carregue o reference

Após classificar a intenção (e desambiguar se necessário), leia o arquivo correspondente com a tool `Read`:

- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/create.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/bump.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/edit.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/qa.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/clean.md`

O reference contém: detalhes operacionais, payload exato a passar ao sub-agent, e checks de pós-execução específicos da intenção.

## Step 3 — Delegue ao sub-agent

Invoque o sub-agent listado no reference via tool `Agent` (subagent_type correspondente). Sempre passe:

1. A instrução original do usuário (`$ARGUMENTS`)
2. Profile content (carregado via overlay context acima)
3. Itens adicionais especificados no reference

## Step 4 — Pós-execução

Após o sub-agent retornar, siga os checks listados no reference da intenção e apresente o resultado final ao usuário (paths absolutos, diff, contagens, status PASS/FAIL conforme aplicável).

## Notas

- Esta skill **roda inline** (não use `context: fork`) para poder pedir clarificação ao usuário quando a intenção for ambígua.
- Os 5 sub-agents (`ebuild-creator`, `ebuild-bumper`, `ebuild-editor`, `qa-checker`, `overlay-maintainer`) já existem em `agents/` e fazem o trabalho real — esta skill apenas orquestra.
- Para detalhes de gotchas críticos do Gentoo, os sub-agents preloadam a skill interna `gotchas` automaticamente; você não precisa carregá-la aqui.
- Canonical Gentoo docs (PMS, devmanual, wiki, GLEPs) estão indexados em `${CLAUDE_PLUGIN_ROOT}/references/external-docs.md` — consulte sob demanda quando o conhecimento embarcado não bastar.
