# bentoo-dev

[English](README.md) · **Português (Brasil)** · [Español](README.es.md) · [Русский](README.ru.md) · [简体中文](README.zh-CN.md)

> Tradução do [`README.md`](README.md) em inglês, que é a referência: se os dois divergirem, vale o inglês.

Um plugin do Claude Code para desenvolver e manter **ebuilds e overlays do Gentoo**. Fornece skills, subagentes, hooks, monitores e material de referência especializados para todo o ciclo de vida de um ebuild — criar, editar, fazer bump, limpar, validar o QA.

> **Status:** v0.4.0 — README e prompts de permissão traduzidos para espanhol, português do Brasil, russo e chinês simplificado (veja `CHANGELOG.md`).
> **Versão-alvo da especificação:** Claude Code v2.1.259+ (funciona em versões posteriores).

> **Independente de overlay.** Embora seja mantido pelo projeto Bentoo, este plugin
> atende **qualquer** overlay ativo do Gentoo. As convenções vêm do
> `metadata/layout.conf` do overlay detectado (`masters`, `thin-manifests`,
> `manifest-hashes`), não do nome dele. Exemplos que citam o overlay bentoo
> são apenas ilustrativos.

### Versões mínimas do Claude Code

| Recurso usado pelo plugin                                   | Versão mínima   |
|-------------------------------------------------------------|:---------------:|
| Flag `--bare` (incompatível com os comandos `/bentoo-dev:*`) | v2.1.81         |
| Hooks `SessionStart` / `CwdChanged`                         | v2.1.83         |
| Formato JSON `PreToolUse` `permissionDecision: "ask"`       | v2.1.83         |
| `permissionDecision: "defer"` (somente headless `-p`)       | v2.1.89         |
| `bin/` auto-PATH                                            | v2.1.91         |
| `hookSpecificOutput.sessionTitle` (UserPromptSubmit)        | v2.1.94         |
| Monitores em segundo plano `monitors/monitors.json`         | v2.1.105        |
| `claude plugin tag` (publicação de releases)                | v2.1.118        |
| Hooks em formato exec (`"args": []`)                        | v2.1.139        |
| Campo `displayName` do manifesto                            | v2.1.143        |
| `additionalContext` a partir de `Stop`/`SubagentStop`       | v2.1.163        |
| Condições `if:` com escopo correto no comando correspondido | v2.1.259        |
| Versão-alvo geral da especificação                           | **v2.1.259+**   |

Cada linha acima foi conferida no
[CHANGELOG upstream](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md),
exceto três que não têm entrada no changelog e foram mantidas sem verificação:
`bin/` auto-PATH (v2.1.91), `displayName` (v2.1.143) e a introdução de
`permissionDecision: "ask"` (v2.1.83 — uma entrada posterior, na v2.1.101, se refere a ele
como já existente, então o recurso é real; só a versão que o introduziu não está
confirmada). `statusMessage` também não tem entrada no changelog e, por isso,
aparece sem versão alguma, em vez de uma versão chutada.

O alvo geral é a entrada mais alta, não uma menor: o plugin usa todos os
recursos listados. A v2.1.259, em particular, corrigiu *"condições `if` de hooks como
`Bash(cat *)` disparando em comandos Bash não relacionados"* — este plugin encaminha seis hooks
por `if: Bash(cp *)` / `(mv *)` / `(sed *)`, então, em versões anteriores, eles
disparam em comandos não relacionados. Os scripts saem com 0 quando não encontram nenhum `.ebuild`, então
o comportamento é correto de qualquer forma; só os processos disparados à toa mudam.

---

## Recursos

- **Ponto de entrada único em linguagem natural** — `/bentoo-dev:bentoo "<instruction>"`.
  A skill recebe um pedido em formato livre, classifica a intenção
  (`create` / `bump` / `edit` / `qa` / `clean` / `bootstrap`), pergunta ao usuário quando há ambiguidade,
  carrega a referência correspondente (`skills/bentoo/references/<intent>.md`)
  e delega ao subagente especializado naquela operação. Exemplos:
  - `/bentoo-dev:bentoo "create dev-libs/foo 1.2.3 from <upstream>"` → `ebuild-creator`
  - `/bentoo-dev:bentoo "bump app-misc/bar to 2.1"` → `ebuild-bumper`
  - `/bentoo-dev:bentoo "add USE flag wayland to games-util/baz"` → `ebuild-editor`
  - `/bentoo-dev:bentoo "run QA on dev-libs/foo"` → `qa-checker`
  - `/bentoo-dev:bentoo "clean the whole overlay"` → `overlay-maintainer`
  - `/bentoo-dev:bentoo "bootstrap a new overlay at ~/myoverlay"` → `overlay-maintainer`

  O acionamento automático por correspondência com a descrição continua funcionando — *"bump mesa to 26.0.5"*
  ou *"package XYZ from .deb"* invoca a skill automaticamente, sem digitar `/bentoo-dev:bentoo`.
- **5 subagentes especializados** em `agents/` — invocados pela ferramenta `Agent` a partir da skill `bentoo`; cada um declara `effort`, `maxTurns`, `tools`, `disallowedTools`, `color` e pré-carrega a referência de gotchas pelo frontmatter `skills:`.
- **Hooks determinísticos** cobrindo 11 eventos do ciclo de vida — veja a tabela completa em [Hooks](#hooks). Os essenciais:
  - `SessionStart` / `CwdChanged` (detecção automática do overlay, em cache como um resumo de tamanho limitado).
  - `PreToolUse` Bash (proteção do rm, com decisões `deny`/`ask`).
  - `PostToolUse` Write|Edit (lint, lembrete do Manifest).
  - `PostToolUse` Bash `if: cp|mv|sed` (captura edições de `.ebuild` feitas via Bash que contornam Write|Edit; `FileChanged` não é usado de propósito — ele casa nomes de arquivo literais, não globs).
  - `Stop` (barreira contra Manifest desatualizado, ciente de `thin-manifests`).
  - `PreCompact` (reinjeta a identidade do overlay para que ela sobreviva à compactação) e
    `StopFailure` (registra encerramentos por erro de API em `${CLAUDE_PLUGIN_DATA}/stop-failures.log`).
- **Monitores em segundo plano** (v2.1.105) para o ELOG do portage e os achados do `pkgcheck`, restritos às invocações de skill relevantes.
- **Estilo de saída** `qa-report` para relatórios de QA determinísticos e fáceis de processar.
- **Prompts de permissão localizados** — o prompt `ask` do hook de proteção do rm segue o seu locale (`LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG`, como no gettext) em espanhol, português do Brasil, russo e chinês simplificado, com inglês como fallback. Tudo o que o Claude lê — skills, agentes, referências, contexto de hooks, motivos de `deny` e `block` — continua em inglês de propósito: um prompt traduzido piora o modelo e não ajuda nenhum usuário. Veja `scripts/lib/i18n.sh`.
- **Gatilhos bilíngues (PT/EN)** consolidados na `description` e no `when_to_use` da skill `bentoo`, para alta fidelidade de acionamento automático nas seis operações. As frases em português são strings de correspondência, não prosa — elas estão marcadas como `PT triggers:` no frontmatter para que uma limpeza futura não as "traduza para fora".
- **15 templates de ebuild** em `assets/templates/` (incl. `source-pypi`, `virtual`, `acct-user`, `acct-group`) + `metadata.xml` + um `news-item.txt` GLEP 42; substituição canônica de placeholders via `render-template.sh --env`, com `@@EAPI@@` parametrizado (gera 8 por padrão; `EAPI=9` opcional) e `@@KEYWORDS@@`.
- **Perfis por overlay** em `assets/profiles/` — atualmente `bentoo` e `default`.
- **Referências modulares** em `references/` — `gotchas.md` pré-carregado como skill; as demais carregadas sob demanda.

---

## Instalação

### Local (desenvolvimento / uso pessoal)

Clone o repositório em um local de trabalho e carregue o plugin via `--plugin-dir`:

```bash
git clone <this-repo> ~/.claude/plugins/bentoo-dev
claude --plugin-dir ~/.claude/plugins/bentoo-dev
```

### Marketplace

Quando publicado, instale com:

```bash
/plugin install bentoo-dev@<marketplace-name>
```

### Configurar os valores do usuário

Defina sua identidade Gentoo uma vez via `userConfig` (o Claude Code pergunta durante a instalação) ou editando a configuração do plugin:

| Chave                     | Finalidade                                           | Padrão                   |
|---------------------------|------------------------------------------------------|--------------------------|
| `maintainer_email`        | `<email>` em `metadata.xml`                          | `lucascs@protonmail.com` |
| `maintainer_name`         | `<name>` em `metadata.xml`                           | `lucascouts`             |
| `maintainer_type`         | Atributo `type=` (`person` / `project` / `nobody`)   | `person`                 |
| `default_keywords`        | KEYWORDS para novos ebuilds                          | `~amd64`                 |
| `preferred_overlay_path`  | Caminho padrão opcional do overlay (detectado automaticamente se vazio) | _(não definido)_ |

Esses valores ficam disponíveis para scripts e subagentes como variáveis de ambiente `CLAUDE_PLUGIN_OPTION_*` (o prefixo atual da especificação, conforme a referência `env-vars` do Claude Code v2.1.x).

---

## Estrutura

```
bentoo-dev/
├── .claude-plugin/plugin.json      # manifest (semver, userConfig)
├── README.md
├── CHANGELOG.md
├── LICENSE
├── skills/                         # 1 user-invocable + 1 internal preload
│   ├── bentoo/
│   │   ├── SKILL.md                # natural-language router
│   │   └── references/             # progressive-disclosure detail per intent
│   │       ├── create.md
│   │       ├── bump.md
│   │       ├── edit.md
│   │       ├── qa.md
│   │       └── clean.md
│   └── gotchas/SKILL.md            # internal: preloaded by sub-agents
├── agents/                         # 5 sub-agents (delegated via Agent tool)
│   ├── ebuild-creator.md
│   ├── ebuild-editor.md
│   ├── ebuild-bumper.md
│   ├── overlay-maintainer.md
│   └── qa-checker.md
├── hooks/hooks.json                # SessionStart / CwdChanged / PreToolUse / PostToolUse / SubagentStop / Stop / PreCompact
├── monitors/monitors.json          # portage-elog + pkgcheck-watch (v2.1.105+)
├── output-styles/qa-report.md      # deterministic QA report format
├── scripts/                        # shell helpers used by hooks / agents / monitors
│   ├── detect-overlay.sh           # --summary (default) | --full
│   ├── overlay-context.sh          # cache-first context for the skill
│   ├── lib/hook-common.sh          # shared payload/target helpers
│   ├── lib/i18n.sh                 # message catalogs for user-facing hook text
│   ├── cache-overlay.sh            # SessionStart / CwdChanged hook target
│   ├── quick-lint.sh
│   ├── manifest-reminder.sh
│   ├── manifest-stale-check.sh
│   ├── safety-rm-check.sh
│   ├── monitor-elog.sh
│   ├── monitor-pkgcheck.sh
│   ├── render-template.sh          # substitutes @@VAR@@ in templates
│   └── plugin-data-dir.sh
├── tests/i18n.bats                 # catalogs, locale selection, localized rm prompt
├── bin/                            # PATH-exposed wrappers
│   ├── gentoo-overlay-detect
│   ├── gentoo-overlay-cache
│   └── gentoo-ebuild-lint
├── references/                     # progressive-disclosure docs
│   ├── gotchas.md                  # preloaded via skills/gotchas
│   ├── eclass-guide.md
│   ├── dependency-syntax.md
│   └── language-ecosystems.md
├── assets/
│   ├── profiles/  (bentoo.md, default.md)
│   └── templates/  (15 *.ebuild + metadata.xml + news-item.txt)
└── evals/  (evals.json, trigger-queries.json)
```

---

## Hooks

| Evento             | Matcher / Filtro                              | Script                                | Finalidade                                                                                    |
|--------------------|-----------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------------|
| SessionStart       | _(nenhum)_                                    | `cache-overlay.sh`                    | Detecta o overlay ativo uma vez e guarda em cache o resumo + campos como `${CLAUDE_PLUGIN_DATA}/overlay.json`. |
| SessionEnd         | _(nenhum)_                                    | `cleanup-cache.sh`                    | Descarta o cache do overlay da sessão para que a próxima sessão detecte tudo do zero.         |
| CwdChanged         | _(nenhum)_                                    | `cache-overlay.sh`                    | Atualiza o cache quando o usuário navega entre overlays.                                      |
| UserPromptSubmit   | _(nenhum)_                                    | `session-title.sh`                    | Renomeia a sessão automaticamente via `hookSpecificOutput.sessionTitle` em invocações `/bentoo-dev:*`. |
| PreToolUse         | `Bash` + `if: Bash(rm *)`                     | `safety-rm-check.sh`                  | `deny` para rm do único `.ebuild` de um diretório; `ask` para rm com risco de DIST órfão.     |
| PreToolUse         | `Bash` + `if: Bash(git rm *)`                 | `safety-rm-check.sh`                  | Mesma barreira para `git rm` (entrada separada — OR com pipe não é documentado para `if:`).   |
| PostToolUse        | `Write\|Edit`                                 | `quick-lint.sh` + `manifest-reminder.sh` | Lint de EAPI, cabeçalho de copyright + ano, `eapply_user` (restrito a `src_prepare`), KEYWORDS, SLOT, LICENSE; lembrete quando o SRC_URI muda. |
| PostToolUseFailure | `Bash`                                        | `manifest-failure-diagnose.sh`        | Classifica falhas de `ebuild ... manifest` (rede/checksum/404/permissão) e sugere os próximos passos. |
| PostToolUse        | `Bash` + `if: cp\|mv\|sed`                     | `quick-lint.sh` + `manifest-reminder.sh` | Captura edições de `.ebuild` feitas via Bash (`cp`/`mv`/`sed`) que contornam `Write\|Edit`. |
| SubagentStop       | `ebuild-creator`                              | `ebuild-creator-validate.sh`          | Bloqueia a parada se algum pacote recém-criado estiver sem `metadata.xml` ou `Manifest`.      |
| Stop               | _(qualquer)_                                  | `manifest-stale-check.sh`             | Bloqueia o fim do turno se um ebuild modificado tiver Manifest desatualizado (pula overlays `thin-manifests`). |
| StopFailure        | _(qualquer)_                                  | `stopfailure-log.sh`                  | Registra encerramentos por erro de API (rate limit, cobrança, máximo de tokens) em `stop-failures.log`. |
| PreCompact         | _(qualquer)_                                  | `precompact-reinject-overlay.sh`      | Reinjeta a identidade do overlay em cache para que ela sobreviva à compactação da conversa.   |

Todos os scripts leem o payload JSON canônico do hook pela stdin, emitem
formatos JSON `hookSpecificOutput` (`permissionDecision` / `additionalContext` /
`sessionTitle` / `{decision: "block", reason}`) na stdout e saem com 0. Um hook
cuja stdout é interpretada e validada decide o resultado, seja qual for o código de saída.

Todo hook usa o **formato exec** (`"args": []`): o Claude Code inicia o script
diretamente, sem shell, então não há aspas para errar em um caminho de plugin
que contenha espaço. `${CLAUDE_PLUGIN_ROOT}` é substituído nos dois formatos, e
ambos o exportam para o processo iniciado. Cada hook também declara um
`statusMessage`, para que o indicador de progresso mostre o que está rodando.

Os hooks `Stop` e `SubagentStop` respeitam a proteção contra loop `stop_hook_active`.
O Claude Code passa por cima de um hook `Stop` após **oito** bloqueios consecutivos; aumente
esse limite com `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` se uma convergência realmente precisar
de mais.

### Orçamento de contexto: o resumo do overlay é limitado de propósito

`scripts/overlay-context.sh` é o que a skill `bentoo` injeta ao ser carregada. Ele
entrega o **resumo limitado** (~1,3 KB) a partir do cache da sessão gravado por
`cache-overlay.sh`, e só refaz a detecção quando o cache não cobre o
diretório atual.

O dump literal de `metadata/layout.conf` + `profiles/package.mask` **não** está
nesse resumo. Em um overlay real, só o `package.mask` tem ~15 KB — cerca de 4 mil tokens
injetados em toda invocação, para algo que só as intenções `clean` / `mask`
chegam a ler. Carregue-o explicitamente quando precisar:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh" --full   # layout.conf + package.mask
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh" --summary  # same summary, no cache
```

### Lint em lote sem o modelo

`scripts/quick-lint.sh` também funciona como CLI. O agente `qa-checker` o chama uma vez
por execução, então as sete verificações mecânicas não custam nada:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/quick-lint.sh" --json <ebuild> [<ebuild> ...]
# -> {"results":[{"file","errors","warnings"}],"summary":{"files","errors","warnings","status"}}
```

A severidade segue a PMS: `SLOT` ou `LICENSE` ausente é **erro** (SLOT não tem
valor padrão implícito no EAPI 8); ano de copyright desatualizado é **aviso**. `LICENSE`
não é exigido de propósito para `virtual/*`, `acct-user/*` e `acct-group/*`,
que não instalam arquivos. Sempre sai com 0 — os achados são a saída.

### `permissionDecision`: `ask` vs `defer`

O `safety-rm-check.sh` do PreToolUse emite `permissionDecision: "ask"` no
caso de DIST órfão (prompt interativo) e `"deny"` ao remover o único
`.ebuild` de um diretório de pacote. `defer` é reservado ao modo headless
(flag `-p`, v2.1.89+) e **não** é o valor certo para prompts interativos
de "confirme, por favor".

### Endurecendo o `rm` (hook fail-open + regra de permissão)

`safety-rm-check.sh` é uma **proteção de melhor esforço, não uma barreira de segurança**:
o filtro `if: "Bash(rm *)"` é fail-open e o script separa tokens por
espaço em branco, então aspas, `$()` e encadeamentos com `&&` podem escapar dele. Para um bloqueio
rígido, combine-o com uma regra de permissão `deny`/`ask` nas suas configurações, por exemplo:

```json
{ "permissions": { "ask": ["Bash(rm *.ebuild)", "Bash(rm -r *)"] } }
```

O hook continua escalando `rm` recursivo/com glob perto de arquivos `.ebuild` para um
prompt `ask`, como última linha de defesa.

### Ressalva sobre checkpoints

Duas limitações se somam aqui e, juntas, significam que **nada que este plugin
produz pode ser recuperado com `/rewind`**:

1. Checkpoints **não** rastreiam arquivos alterados por comandos Bash (`rm`, `mv`,
   `cp`, `sed`) — só `Write`/`Edit`/`NotebookEdit`. Um `Manifest` regenerado
   via `ebuild … manifest`, ou um `.ebuild` copiado com `cp`, não é desfeito.
2. Checkpoints **também não restauram edições de subagentes**. Segundo a
   [documentação de checkpoints](https://code.claude.com/docs/en/checkpointing), só uma
   skill em fork rodando em primeiro plano tem as edições restauradas; para qualquer outro
   subagente, *"voltar atrás não restaura as edições. Use o git para revertê-las."*
   Toda escrita deste plugin acontece dentro de um dos cinco subagentes.

Então `/rewind` não é rede de segurança para trabalho em overlay. **Use git.** É por isso que o
plugin traz hooks determinísticos de Manifest desatualizado e de proteção do rm, em vez de
depender de checkpoints, e por isso o `safety-rm-check.sh` nega em vez de só avisar.

### `pkgcheck` recorrente

Há um único caminho para o pkgcheck: o **monitor `pkgcheck-watch`**, iniciado na
invocação da skill `bentoo`. Ele varre o overlay em cache, notifica sobre novos
achados de nível ERROR e acrescenta cada novo resultado a
`${CLAUDE_PLUGIN_DATA}/pkgcheck.log`.

Um monitor é o mecanismo nativo para isso. A
[documentação de tarefas agendadas](https://code.claude.com/docs/en/scheduled-tasks) diz
claramente: um monitor *"evita totalmente o polling e costuma ser mais eficiente em tokens
e mais responsivo do que rodar um prompt de novo em intervalos."* Um segundo script, disparado por cron,
duplicava a mesma varredura; ele foi removido em vez de ficar divergindo.

Ajuste o intervalo com `BENTOO_DEV_PKGCHECK_INTERVAL` (segundos, padrão 300).

Se você quiser um agendamento que sobreviva à sessão, note que as
[Routines](https://code.claude.com/docs/en/routines) na nuvem **não servem** para isso: elas
rodam em um clone novo, sem acesso ao seu overlay local. Use uma
**tarefa agendada do Desktop** ou `/loop`, que rodam na sua máquina.

---

## Gotchas críticos (referência)

As 11 regras indispensáveis estão centralizadas em `references/gotchas.md` e expostas
aos subagentes pela skill `bentoo-dev:gotchas` (pré-carregada pelo frontmatter
`skills:`, com `user-invocable: false`):

1. `eapply_user` obrigatório em `src_prepare` sobrescrito
2. `|| die` após comandos de shell que podem falhar
3. KEYWORDS vazio em ebuilds live `9999`
4. `S=` deve corresponder ao diretório extraído
5. Renomear no SRC_URI com `->` para tarballs de nome pouco informativo
6. `QA_PREBUILT` + `RESTRICT` para pacotes binários
7. Copyright na linha 1, `EAPI=` na primeira linha que não é comentário
8. `thin-manifests` contém apenas entradas DIST
9. `default` em `src_prepare` aplica `PATCHES` + `eapply_user`
10. `MY_P` / `MY_PN` quando o nome upstream não bate
11. `<stabilize-allarches/>` é buscado com grep, não interpretado — nunca escreva o token literal em `metadata.xml`, nem em comentário

### Manutenção do overlay que os agentes impõem

Duas regras que não são sintaxe de ebuild, mas apodrecem um overlay em silêncio, embutidas no
`ebuild-bumper` e no `overlay-maintainer`:

- **`pkgdev manifest` sempre recebe um alvo explícito.** Sem alvo, ele
  reescreve o Manifest do overlay inteiro.
- **`metadata/md5-cache` é regenerado por pacote após um bump**, quando o
  overlay mantém um — senão a entrada da versão anterior fica órfã e o
  lixo cresce a cada bump:
  `egencache --repositories-configuration "$(portageq repos_config /)" --update --repo <repo> <cat>/<pkg>`.
  `--repositories-configuration` é obrigatório em um checkout que não seja o caminho
  registrado no Portage; `PORTAGE_CONFIGROOT` / `PORTAGE_REPOSITORIES` são
  ignorados pelo `egencache`.

---

## Uso em CI / headless

O plugin é totalmente compatível com o modo não interativo `claude -p`. Todos os hooks
leem payloads JSON da stdin e degradam de forma controlada quando invocados manualmente.

```bash
# Run QA on every modified ebuild in a PR:
claude -p "/bentoo-dev:bentoo run QA on $(git diff --name-only origin/main | grep '\.ebuild$' | xargs)" \
  --plugin-dir ./bentoo-dev \
  --permission-mode dontAsk \
  --allowedTools "Read Bash Glob Grep Agent" \
  --output-format json | jq -r '.result'

# Validate plugin manifest + components on every PR:
claude plugin validate ./bentoo-dev
```

> **Nota sobre `--bare`**: esta flag (Claude Code v2.1.81+) pula por completo o carregamento
> de plugins (junto com hooks, skills, MCP, CLAUDE.md). Por isso ela é
> incompatível com `--plugin-dir` para invocar comandos `/bentoo-dev:*`. Para
> CI restrito, use `--permission-mode dontAsk` mais uma allowlist explícita de
> `--allowedTools`, como acima. A autenticação precisa vir de
> `ANTHROPIC_API_KEY`.

### Releases

Faça push de uma tag `vX.Y.Z` para disparar `.github/workflows/release.yml`, que valida
o plugin e roda `claude plugin tag .` (v2.1.118+) para publicar nos
marketplaces.

---

## Contribuindo

1. Adicione novos perfis de overlay em `assets/profiles/<name>.md`.
2. Adicione novos templates em `assets/templates/`.
3. Atualize `evals/evals.json` e `evals/trigger-queries.json` sempre que adicionar uma skill nova ou mudar gatilhos.
4. Faça bump de `version` em `.claude-plugin/plugin.json` e atualize o `CHANGELOG.md`.
5. Uma mensagem nova que um **humano** lê (um prompt de permissão, não contexto de hook) ganha um ID em **todos** os catálogos de `scripts/lib/i18n.sh`; do contrário, `bats tests/i18n.bats` falha. Ao alterar o `README.md`, atualize as traduções (`README.<lang>.md`) ou diga no PR que elas estão defasadas.

---

## Licença

MIT — veja `LICENSE`.
