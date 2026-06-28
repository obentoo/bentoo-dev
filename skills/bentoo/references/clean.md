# Reference: clean

Detalhes operacionais para a intenção `clean` (manutenção do overlay) da skill `bentoo`.

## Sub-agent

`overlay-maintainer`

## Modes

- `clean`: remoção de versões antigas (preserva live ebuilds e a versão mais recente; nunca esvazia diretório).
- `refresh-manifests`: regenera Manifests stale em batch.
- `full-audit`: detecta problemas (versões obsoletas, Manifests stale, metadata.xml ausente, DIST entries órfãs) e aplica correções.
- `news`: cria/edita um item de news GLEP 42 em `metadata/news/AAAA-MM-DD-slug/` a partir do template `${CLAUDE_PLUGIN_ROOT}/assets/templates/news-item.txt` (cabeçalhos `Title/Author/Posted/Revision/News-Item-Format` + condições `Display-If-*`).
- `updates`: registra renomes/moves de pacotes em `profiles/updates/<Qn-YYYY>` (`move <old> <new>`, `slotmove <atom> <old> <new>`).
- `mask`: adiciona/edita entradas em `profiles/package.mask` (comentário obrigatório com autor, data e motivo acima do átomo).

## Payload to sub-agent

Invoque `overlay-maintainer` via tool `Agent` com:

1. **Task**: `clean` | `refresh-manifests` | `full-audit` | `news` | `updates` | `mask`
2. **Scope**: pacote único `<category/package>` ou `--all` (overlay inteiro)
3. **Profile content**: o markdown do profile carregado pela skill
4. **Safety flags**:
   - **NUNCA** remover live ebuilds (`*-9999.ebuild`)
   - **NUNCA** esvaziar diretório de pacote (sempre preservar a versão mais recente)
   - Pedir confirmação extra se o scope for `--all` E o modo for destrutivo (`clean`)

## Required arguments

Antes de delegar, garanta que tem:
- `<scope>`: `<category/package>` específico ou `--all`
- Modo desejado (se ambíguo, pergunte: "limpar versões antigas, regenerar manifests, ou audit completo?")

Se o scope for `--all` e o modo for `clean`, peça confirmação explícita ao usuário antes de delegar (ação destrutiva em escala).

## Post-action

Reportar ao usuário:
- Pacotes escaneados / removidos / com Manifest regenerado / metadata criada
- Falhas (network errors em manifest fetch, etc.)
- Estado final do overlay
