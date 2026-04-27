# Reference: bump

Detalhes operacionais para a intenção `bump` (atualização de versão de ebuild existente) da skill `bentoo`.

## Sub-agent

`ebuild-bumper`

## Bump mode detection

- **Standard bump**: `<pkg>-<old>` → `<pkg>-<new>` (versão semver normal)
- **Snapshot bump**: `<pkg>-<base>_p<YYYYMMDD>` (atualiza `GIT_COMMIT` + data)
- **Live ebuild**: `9999.ebuild` — geralmente não precisa de bump explícito; sinalize ao usuário se for este o caso.

## Payload to sub-agent

Invoque `ebuild-bumper` via tool `Agent` com:

1. **Task**: bump `<category/package>` para a versão `<new-version>`
2. **Mode**: `standard` | `snapshot` (detectar pelo formato `_p<YYYYMMDD>` em `<new-version>`)
3. **New commit hash** (snapshot apenas — peça ao usuário se não foi fornecido)
4. **Profile content**: o markdown do profile carregado pela skill
5. **Old ebuild path**: caminho absoluto do ebuild da versão anterior (a versão mais alta encontrada via `Glob` no diretório do pacote)
6. **Remove old version?**: `yes` / `no` (default: `no`)

## Required arguments

Antes de delegar, garanta que tem:
- `<category/package>` (existente no overlay)
- `<new-version>`
- Para snapshot bumps: `<commit-hash>` + data `YYYYMMDD`

Se o pacote não existe, confirme com o usuário se é caso de `create` em vez de `bump`.

## Post-action

1. Confirmar novo ebuild válido + Manifest regenerado.
2. Reportar: `old → new`, files created/removed, mudanças não-óbvias (`S=`, `GIT_COMMIT`, `MY_P`, `MY_PV`).
3. Se `pkgcheck` estiver disponível, sugira rodar a intenção `qa` em seguida.
