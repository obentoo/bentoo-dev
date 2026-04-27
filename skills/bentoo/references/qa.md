# Reference: qa

Detalhes operacionais para a intenção `qa` (validação read-only de ebuilds) da skill `bentoo`.

## Sub-agent

`qa-checker`

## Payload to sub-agent

Invoque `qa-checker` via tool `Agent` com:

1. **Targets**: paths de ebuilds ou diretório de pacote (`<category/package>`)
2. **Run pkgcheck?**: `yes` por padrão se `pkgcheck` estiver no `PATH`
3. **Output format**: estruturado `[ERROR|WARNING|INFO]` + summary final

## Required arguments

Antes de delegar, garanta que tem:
- `<target>`: ebuild path, diretório de pacote, ou `--all` para o overlay inteiro

Se o usuário não especificar, pergunte se é um pacote único ou o overlay inteiro.

## Notas

- **Read-only**: nunca modifique arquivos durante esta intenção.
- O sub-agent `qa-checker` é configurado em `agents/qa-checker.md` e pode rodar em modelo mais leve (haiku) se desejado.

## Post-action

Apresentar ao usuário:
- Lista estruturada de findings (categorizados por severidade)
- Summary count: `N error(s), N warning(s), N info — PASS|FAIL`
- Se `pkgcheck` indisponível, sugerir `emerge dev-util/pkgcheck`
