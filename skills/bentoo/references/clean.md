# Reference: clean

Detalhes operacionais para a intenção `clean` (manutenção do overlay) da skill `bentoo`.

## Sub-agent

`overlay-maintainer`

## Modes

- `clean`: remoção de versões antigas (preserva live ebuilds e a versão mais recente; nunca esvazia diretório).
- `refresh-manifests`: regenera Manifests stale em batch.
- `full-audit`: detecta problemas (versões obsoletas, Manifests stale, metadata.xml ausente, DIST entries órfãs) e aplica correções.

## Payload to sub-agent

Invoque `overlay-maintainer` via tool `Agent` com:

1. **Task**: `clean` | `refresh-manifests` | `full-audit`
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
