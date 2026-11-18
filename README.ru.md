# bentoo-dev

[English](README.md) · [Português (Brasil)](README.pt-BR.md) · [Español](README.es.md) · **Русский** · [简体中文](README.zh-CN.md)

> Перевод английского [`README.md`](README.md), который является эталоном: при расхождении верен английский текст.

Плагин Claude Code для разработки и сопровождения **ebuild-файлов и оверлеев Gentoo**. Содержит специализированные скиллы, субагенты, хуки, мониторы и справочные материалы для всего жизненного цикла ebuild — создание, редактирование, обновление версии (bump), очистка, QA-проверка.

> **Статус:** v0.4.0 — README и запросы разрешений переведены на испанский, бразильский португальский, русский и упрощённый китайский (см. `CHANGELOG.md`).
> **Целевая спецификация:** Claude Code v2.1.259+ (работает и в более поздних версиях).

> **Не привязан к конкретному оверлею.** Хотя плагин сопровождается проектом Bentoo,
> он рассчитан на **любой** активный оверлей Gentoo. Соглашения берутся из
> `metadata/layout.conf` обнаруженного оверлея (`masters`, `thin-manifests`,
> `manifest-hashes`), а не из его имени. Примеры с оверлеем bentoo
> приведены лишь для иллюстрации.

### Минимальные версии Claude Code

| Возможность, используемая плагином                          | Мин. версия     |
|-------------------------------------------------------------|:---------------:|
| Флаг `--bare` (несовместим с командами `/bentoo-dev:*`)     | v2.1.81         |
| Хуки `SessionStart` / `CwdChanged`                          | v2.1.83         |
| JSON-структура `PreToolUse` `permissionDecision: "ask"`     | v2.1.83         |
| `permissionDecision: "defer"` (только headless-режим `-p`)  | v2.1.89         |
| Автодобавление `bin/` в PATH                                | v2.1.91         |
| `hookSpecificOutput.sessionTitle` (UserPromptSubmit)        | v2.1.94         |
| Фоновые мониторы `monitors/monitors.json`                   | v2.1.105        |
| `claude plugin tag` (публикация релизов)                    | v2.1.118        |
| Хуки в exec-форме (`"args": []`)                            | v2.1.139        |
| Поле манифеста `displayName`                                | v2.1.143        |
| `additionalContext` из `Stop`/`SubagentStop`                | v2.1.163        |
| Условия `if:`, корректно привязанные к совпавшей команде    | v2.1.259        |
| Целевая спецификация в целом                                 | **v2.1.259+**   |

Каждая строка выше сверена с
[CHANGELOG upstream](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md),
кроме трёх, у которых нет записи в changelog и которые перенесены без проверки:
автодобавление `bin/` в PATH (v2.1.91), `displayName` (v2.1.143) и появление
`permissionDecision: "ask"` (v2.1.83 — более поздняя запись в v2.1.101 упоминает его
как уже существующий, так что возможность реальна; не подтверждена лишь версия,
в которой он появился). У `statusMessage` тоже нет записи в changelog, поэтому он
указан вовсе без версии, а не с угаданной.

Общая целевая версия — максимальная из таблицы, а не меньшая: плагин использует все
перечисленные возможности. В частности, v2.1.259 исправила проблему *«условия хуков `if`
вроде `Bash(cat *)` срабатывали на посторонних командах Bash»* — этот плагин пропускает
шесть хуков через `if: Bash(cp *)` / `(mv *)` / `(sed *)`, поэтому в более ранних версиях
они срабатывают на посторонних командах. Скрипты завершаются с кодом 0, если не находят
`.ebuild`, так что поведение корректно в любом случае; различаются лишь лишние запуски.

---

## Возможности

- **Единая точка входа на естественном языке** — `/bentoo-dev:bentoo "<instruction>"`.
  Скилл получает запрос в свободной форме, определяет намерение
  (`create` / `bump` / `edit` / `qa` / `clean` / `bootstrap`), при неоднозначности переспрашивает пользователя,
  загружает соответствующий справочник (`skills/bentoo/references/<intent>.md`)
  и передаёт работу специализированному субагенту этой операции. Примеры:
  - `/bentoo-dev:bentoo "create dev-libs/foo 1.2.3 from <upstream>"` → `ebuild-creator`
  - `/bentoo-dev:bentoo "bump app-misc/bar to 2.1"` → `ebuild-bumper`
  - `/bentoo-dev:bentoo "add USE flag wayland to games-util/baz"` → `ebuild-editor`
  - `/bentoo-dev:bentoo "run QA on dev-libs/foo"` → `qa-checker`
  - `/bentoo-dev:bentoo "clean the whole overlay"` → `overlay-maintainer`
  - `/bentoo-dev:bentoo "bootstrap a new overlay at ~/myoverlay"` → `overlay-maintainer`

  Автозапуск по совпадению с описанием по-прежнему работает — фраза *«bump mesa to 26.0.5»*
  или *«package XYZ from .deb»* вызывает скилл автоматически, без ввода `/bentoo-dev:bentoo`.
- **5 специализированных субагентов** в `agents/` — скилл `bentoo` вызывает их через инструмент `Agent`; каждый объявляет `effort`, `maxTurns`, `tools`, `disallowedTools`, `color` и заранее подгружает справочник типичных ошибок (gotchas) через frontmatter `skills:`.
- **Детерминированные хуки** на 11 событий жизненного цикла — полная таблица в разделе [Хуки](#хуки). Ключевые из них:
  - `SessionStart` / `CwdChanged` (автоопределение оверлея, кэшируется в виде сводки ограниченного размера).
  - `PreToolUse` Bash (защита от опасного rm, с решениями `deny`/`ask`).
  - `PostToolUse` Write|Edit (lint, напоминание о Manifest).
  - `PostToolUse` Bash `if: cp|mv|sed` (ловит правки `.ebuild` через Bash в обход Write|Edit; `FileChanged` намеренно не используется — он сопоставляет буквальные имена файлов, а не glob-шаблоны).
  - `Stop` (проверка устаревшего Manifest с учётом `thin-manifests`).
  - `PreCompact` (повторно внедряет сведения об оверлее, чтобы они пережили сжатие контекста) и
    `StopFailure` (записывает завершения из-за ошибок API в `${CLAUDE_PLUGIN_DATA}/stop-failures.log`).
- **Фоновые мониторы** (v2.1.105) для ELOG Portage и находок `pkgcheck`, привязанные к соответствующим вызовам скиллов.
- **Стиль вывода** `qa-report` для детерминированных, машиночитаемых QA-отчётов.
- **Локализованные запросы разрешений** — запрос `ask` хука защиты rm следует вашей локали (`LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG`, как в gettext) на испанском, бразильском португальском, русском и упрощённом китайском, а в остальных случаях выводится на английском. Всё, что читает Claude, — скиллы, агенты, справочники, контекст хуков, причины `deny` и `block` — намеренно остаётся на английском: переведённый промпт ухудшает работу модели и не помогает ни одному пользователю. См. `scripts/lib/i18n.sh`.
- **Англоязычные триггеры** собраны в `description` и `when_to_use` скилла `bentoo` для точного автозапуска во всех шести операциях. Начиная с 0.3.0 скилл больше не запускается автоматически по инструкции на другом языке; вызывайте его явно: `/bentoo-dev:bentoo "…"`.
- **15 шаблонов ebuild** в `assets/templates/` (включая `source-pypi`, `virtual`, `acct-user`, `acct-group`) + `metadata.xml` + `news-item.txt` по GLEP 42; каноническая подстановка плейсхолдеров через `render-template.sh --env` с параметрами `@@EAPI@@` (по умолчанию 8; `EAPI=9` — по явному выбору) и `@@KEYWORDS@@`.
- **Профили для оверлеев** в `assets/profiles/` — сейчас `bentoo` и `default`.
- **Модульные справочники** в `references/` — `gotchas.md` подгружается заранее как скилл; остальные загружаются по требованию.

---

## Установка

### Локально (разработка / личное использование)

Склонируйте репозиторий в рабочий каталог и подключите плагин через `--plugin-dir`:

```bash
git clone <this-repo> ~/.claude/plugins/bentoo-dev
claude --plugin-dir ~/.claude/plugins/bentoo-dev
```

### Marketplace

После публикации установите так:

```bash
/plugin install bentoo-dev@<marketplace-name>
```

### Пользовательские параметры

Задайте свои данные Gentoo-мейнтейнера один раз через `userConfig` (Claude Code спросит их при установке) или отредактировав конфигурацию плагина:

| Ключ                      | Назначение                                           | По умолчанию             |
|---------------------------|------------------------------------------------------|--------------------------|
| `maintainer_email`        | `<email>` в `metadata.xml`                           | `lucascs@protonmail.com` |
| `maintainer_name`         | `<name>` в `metadata.xml`                            | `lucascouts`             |
| `maintainer_type`         | атрибут `type=` (`person` / `project` / `nobody`)    | `person`                 |
| `default_keywords`        | KEYWORDS для новых ebuild                            | `~amd64`                 |
| `preferred_overlay_path`  | Необязательный путь к оверлею по умолчанию (если пусто — определяется автоматически) | _(не задан)_ |

Эти значения передаются скриптам и субагентам как переменные окружения `CLAUDE_PLUGIN_OPTION_*` (актуальный по спецификации префикс согласно справочнику `env-vars` Claude Code v2.1.x).

---

## Структура

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

## Хуки

| Событие            | Matcher / фильтр                              | Скрипт                                | Назначение                                                                                    |
|--------------------|-----------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------------|
| SessionStart       | _(нет)_                                       | `cache-overlay.sh`                    | Один раз определяет активный оверлей и кэширует сводку и поля в `${CLAUDE_PLUGIN_DATA}/overlay.json`. |
| SessionEnd         | _(нет)_                                       | `cleanup-cache.sh`                    | Удаляет кэш оверлея текущей сессии, чтобы следующая сессия определяла его заново.             |
| CwdChanged         | _(нет)_                                       | `cache-overlay.sh`                    | Обновляет кэш, когда пользователь переходит между оверлеями.                                  |
| UserPromptSubmit   | _(нет)_                                       | `session-title.sh`                    | Автоматически переименовывает сессию через `hookSpecificOutput.sessionTitle` при вызовах `/bentoo-dev:*`. |
| PreToolUse         | `Bash` + `if: Bash(rm *)`                     | `safety-rm-check.sh`                  | `deny` для rm единственного `.ebuild` в каталоге; `ask` для rm с риском осиротить записи DIST. |
| PreToolUse         | `Bash` + `if: Bash(git rm *)`                 | `safety-rm-check.sh`                  | Та же проверка для `git rm` (отдельная запись — pipe-OR для `if:` не документирован).         |
| PostToolUse        | `Write\|Edit`                                 | `quick-lint.sh` + `manifest-reminder.sh` | Lint EAPI, заголовка copyright и года, `eapply_user` (в пределах `src_prepare`), KEYWORDS, SLOT, LICENSE; напоминание при изменении SRC_URI. |
| PostToolUseFailure | `Bash`                                        | `manifest-failure-diagnose.sh`        | Классифицирует сбои `ebuild ... manifest` (сеть/контрольная сумма/404/права) и предлагает следующие шаги. |
| PostToolUse        | `Bash` + `if: cp\|mv\|sed`                     | `quick-lint.sh` + `manifest-reminder.sh` | Ловит правки `.ebuild` через Bash (`cp`/`mv`/`sed`) в обход `Write\|Edit`.                  |
| SubagentStop       | `ebuild-creator`                              | `ebuild-creator-validate.sh`          | Блокирует остановку, если у нового пакета нет `metadata.xml` или `Manifest`.                  |
| Stop               | _(любое)_                                     | `manifest-stale-check.sh`             | Блокирует завершение хода, если у изменённого ebuild устарел Manifest (пропускает оверлеи с `thin-manifests`). |
| StopFailure        | _(любое)_                                     | `stopfailure-log.sh`                  | Записывает завершения из-за ошибок API (rate limit, оплата, max tokens) в `stop-failures.log`. |
| PreCompact         | _(любое)_                                     | `precompact-reinject-overlay.sh`      | Повторно внедряет закэшированные сведения об оверлее, чтобы они пережили сжатие беседы.       |

Все скрипты читают канонический JSON-payload хука из stdin, выводят в stdout
JSON-структуры `hookSpecificOutput` (`permissionDecision` / `additionalContext` /
`sessionTitle` / `{decision: "block", reason}`) и завершаются с кодом 0. Если stdout
хука разбирается и проходит валидацию, исход определяет он, независимо от кода завершения.

Все хуки используют **exec-форму** (`"args": []`): Claude Code запускает скрипт
напрямую, без оболочки, поэтому нет экранирования, которое можно сломать на пути
к плагину с пробелом. `${CLAUDE_PLUGIN_ROOT}` подставляется в обеих формах, и обе
экспортируют его в запущенный процесс. Каждый хук также объявляет
`statusMessage`, чтобы индикатор ожидания показывал, что именно выполняется.

Хуки `Stop` и `SubagentStop` соблюдают защиту от зацикливания `stop_hook_active`.
Claude Code отменяет хук `Stop` после **восьми** блокировок подряд; увеличьте этот
предел через `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`, если для сходимости действительно
нужно больше.

### Бюджет контекста: сводка об оверлее намеренно ограничена

`scripts/overlay-context.sh` — это то, что скилл `bentoo` внедряет при загрузке. Он
отдаёт **ограниченную сводку** (~1,3 КБ) из кэша сессии, записанного
`cache-overlay.sh`, и повторяет определение, только если кэш не покрывает
текущий каталог.

Дословный дамп `metadata/layout.conf` + `profiles/package.mask` в эту сводку
**не входит**. В реальном оверлее один только `package.mask` занимает ~15 КБ — около
4 тыс. токенов на каждый вызов ради того, что читают лишь намерения `clean` / `mask`.
Загружайте его явно, когда он нужен:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh" --full   # layout.conf + package.mask
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh" --summary  # same summary, no cache
```

### Пакетный lint без модели

`scripts/quick-lint.sh` работает и как CLI. Агент `qa-checker` вызывает его один раз
за прогон, так что семь механических проверок ничего не стоят:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/quick-lint.sh" --json <ebuild> [<ebuild> ...]
# -> {"results":[{"file","errors","warnings"}],"summary":{"files","errors","warnings","status"}}
```

Серьёзность определяется по PMS: отсутствие `SLOT` или `LICENSE` — **ошибка** (в EAPI 8
у SLOT нет неявного значения по умолчанию); устаревший год copyright — **предупреждение**.
`LICENSE` намеренно не требуется для `virtual/*`, `acct-user/*` и `acct-group/*`,
которые не устанавливают файлов. Скрипт всегда завершается с кодом 0 — результат передаётся в выводе.

### `permissionDecision`: `ask` или `defer`

Хук PreToolUse `safety-rm-check.sh` выдаёт `permissionDecision: "ask"` в случае
осиротевших DIST (интерактивный запрос) и `"deny"` при удалении единственного
`.ebuild` в каталоге пакета. `defer` предназначен для headless-режима
(флаг `-p`, v2.1.89+) и **не подходит** для интерактивных запросов
«подтвердите, пожалуйста».

### Усиление защиты `rm` (fail-open хук + правило разрешений)

`safety-rm-check.sh` — это **страховочное ограждение по мере сил, а не граница безопасности**:
фильтр `if: "Bash(rm *)"` работает по принципу fail-open, а скрипт разбивает команду на токены
по пробелам, так что кавычки, `$()` и цепочки `&&` могут его обойти. Для жёсткой
блокировки дополните его правилом разрешений `deny`/`ask` в настройках, например:

```json
{ "permissions": { "ask": ["Bash(rm *.ebuild)", "Bash(rm -r *)"] } }
```

Хук по-прежнему переводит рекурсивный или glob-`rm` рядом с файлами `.ebuild` в
запрос `ask` в качестве последнего рубежа.

### Оговорка о контрольных точках

Здесь складываются два ограничения, и вместе они означают, что **ничего из созданного
этим плагином нельзя восстановить через `/rewind`**:

1. Контрольные точки **не отслеживают** файлы, изменённые командами Bash (`rm`, `mv`,
   `cp`, `sed`), — только `Write`/`Edit`/`NotebookEdit`. `Manifest`, пересозданный
   через `ebuild … manifest`, или `.ebuild`, скопированный через `cp`, не откатываются.
2. Контрольные точки **не восстанавливают и правки субагентов**. Согласно
   [документации по контрольным точкам](https://code.claude.com/docs/en/checkpointing), правки
   восстанавливаются только у форкнутого скилла, работающего на переднем плане; для любого другого
   субагента *«перемотка не восстанавливает правки. Откатывайте их с помощью git»*.
   Все записи в этом плагине выполняются внутри одного из пяти субагентов.

Поэтому `/rewind` — не страховка для работы с оверлеем. **Используйте git.** Именно поэтому
плагин поставляет детерминированные хуки проверки устаревшего Manifest и защиты rm вместо того,
чтобы полагаться на контрольные точки, и поэтому `safety-rm-check.sh` запрещает, а не предупреждает.

### Регулярный `pkgcheck`

Путь для pkgcheck один: **монитор `pkgcheck-watch`**, запускаемый при
вызове скилла `bentoo`. Он сканирует закэшированный оверлей, уведомляет о новых
находках уровня ERROR и дописывает каждый новый результат в
`${CLAUDE_PLUGIN_DATA}/pkgcheck.log`.

Монитор — штатный механизм для этого.
[Документация по запланированным задачам](https://code.claude.com/docs/en/scheduled-tasks) говорит
прямо: монитор *«полностью избавляет от опроса и часто экономнее по токенам
и отзывчивее, чем повторный запуск промпта по интервалу»*. Второй скрипт, запускаемый по cron,
раньше дублировал то же сканирование; его удалили, а не оставили расходиться с основным.

Интервал настраивается через `BENTOO_DEV_PKGCHECK_INTERVAL` (в секундах, по умолчанию 300).

Если нужно расписание, переживающее сессию, учтите, что облачные
[Routines](https://code.claude.com/docs/en/routines) для этого **не подходят**: они
работают в свежем клоне без доступа к вашему локальному оверлею. Используйте
**запланированную задачу Desktop** или `/loop` — оба работают на вашей машине.

---

## Критические подводные камни (справочник)

11 обязательных к знанию правил собраны в `references/gotchas.md` и доступны
субагентам через скилл `bentoo-dev:gotchas` (подгружается заранее через frontmatter
`skills:`, с `user-invocable: false`):

1. `eapply_user` обязателен в переопределённом `src_prepare`
2. `|| die` после shell-команд, которые могут завершиться ошибкой
3. Пустые KEYWORDS для live-ebuild `9999`
4. `S=` должен совпадать с распакованным каталогом
5. Переименование в SRC_URI через `->` для неинформативных tarball
6. `QA_PREBUILT` + `RESTRICT` для бинарных пакетов
7. Copyright в строке 1, `EAPI=` — первая строка, не являющаяся комментарием
8. `thin-manifests` содержит только записи DIST
9. `default` в `src_prepare` применяет `PATCHES` + `eapply_user`
10. `MY_P` / `MY_PN` при расхождении с именованием upstream
11. `<stabilize-allarches/>` ищется через grep, а не разбирается парсером — никогда не пишите этот токен буквально в `metadata.xml`, даже в комментарии

### Учёт в оверлее, который соблюдают агенты

Два правила, которые не относятся к синтаксису ebuild, но незаметно портят оверлей; они встроены в
`ebuild-bumper` и `overlay-maintainer`:

- **`pkgdev manifest` всегда получает явную цель.** Без цели он
  перезаписывает Manifest всего оверлея.
- **`metadata/md5-cache` пересоздаётся для пакета после bump**, если
  оверлей его хранит, — иначе запись предыдущей версии остаётся осиротевшей, и
  мусор растёт с каждым bump:
  `egencache --repositories-configuration "$(portageq repos_config /)" --update --repo <repo> <cat>/<pkg>`.
  `--repositories-configuration` обязателен в checkout, путь которого не
  зарегистрирован в Portage; `PORTAGE_CONFIGROOT` / `PORTAGE_REPOSITORIES`
  `egencache` игнорирует.

---

## CI / headless-использование

Плагин полностью совместим с неинтерактивным режимом `claude -p`. Все хуки
читают JSON-payload из stdin и корректно деградируют при ручном вызове.

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

> **Примечание о `--bare`**: этот флаг (Claude Code v2.1.81+) полностью пропускает
> загрузку плагинов (вместе с хуками, скиллами, MCP, CLAUDE.md). Поэтому он
> несовместим с `--plugin-dir` для вызова команд `/bentoo-dev:*`. Для
> закрытого CI используйте `--permission-mode dontAsk` вместе с явным
> белым списком `--allowedTools`, как показано выше. Аутентификация должна идти через
> `ANTHROPIC_API_KEY`.

### Релизы

Отправьте тег `vX.Y.Z`, чтобы запустить `.github/workflows/release.yml`: он проверяет
плагин и выполняет `claude plugin tag .` (v2.1.118+) для публикации в
marketplace.

---

## Участие в разработке

1. Добавляйте новые профили оверлеев в `assets/profiles/<name>.md`.
2. Добавляйте новые шаблоны в `assets/templates/`.
3. Обновляйте `evals/evals.json` и `evals/trigger-queries.json` при добавлении нового скилла или изменении триггеров.
4. Повышайте `version` в `.claude-plugin/plugin.json` и обновляйте `CHANGELOG.md`.
5. Новое сообщение, которое читает **человек** (запрос разрешения, а не контекст хука), получает ID в **каждом** каталоге в `scripts/lib/i18n.sh`; иначе `bats tests/i18n.bats` завершится с ошибкой. Изменяя `README.md`, обновите переводы (`README.<lang>.md`) или укажите в PR, что они отстают.

---

## Лицензия

MIT — см. `LICENSE`.
