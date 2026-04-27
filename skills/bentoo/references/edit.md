# Reference: edit

Detalhes operacionais para a intenção `edit` (modificação cirúrgica em ebuild existente) da skill `bentoo`.

## Sub-agent

`ebuild-editor`

## Payload to sub-agent

Invoque `ebuild-editor` via tool `Agent` com:

1. **Task**: descrição precisa da mudança (`add USE flag X`, `add patch Y`, `fix dep Z`, `bump dep min version`, `add src_install hook`, etc.)
2. **Target ebuild**: path absoluto do ebuild a modificar
3. **Profile content**: o markdown do profile carregado pela skill
4. **Gotchas**: `${CLAUDE_PLUGIN_ROOT}/references/gotchas.md` quando relevante
5. **Reference loading hints**: aponte qual reference do plugin o sub-agent deve consultar:
   - `${CLAUDE_PLUGIN_ROOT}/references/eclass-guide.md` → escolha/troca de eclass
   - `${CLAUDE_PLUGIN_ROOT}/references/dependency-syntax.md` → blocos USE-conditional, REQUIRED_USE, slot deps
   - `${CLAUDE_PLUGIN_ROOT}/references/language-ecosystems.md` → Go/Rust/Java/Python/Ruby/Perl/Electron

## Required arguments

Antes de delegar, garanta que tem:
- `<target ebuild>` (path ou `<category/package>`)
- Descrição clara da mudança

Se a mudança envolve um arquivo de patch, confirme path/conteúdo do patch antes de delegar.

## Post-action

1. Verificar consistência cross-file: IUSE ↔ deps ↔ metadata.xml ↔ phase functions.
2. Se `SRC_URI` mudou → confirmar Manifest regenerado.
3. Apresentar diff resumido ao usuário.
4. Se `pkgcheck` estiver disponível, sugira rodar a intenção `qa` em seguida.
