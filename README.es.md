# bentoo-dev

[English](README.md) · [Português (Brasil)](README.pt-BR.md) · **Español** · [Русский](README.ru.md) · [简体中文](README.zh-CN.md)

> Traducción del [`README.md`](README.md) en inglés, que es la referencia: si ambos difieren, prevalece el inglés.

Un plugin de Claude Code para desarrollar y mantener **ebuilds y overlays de Gentoo**. Ofrece skills especializadas, subagentes, hooks, monitores y material de referencia para todo el ciclo de vida de un ebuild: crear, editar, actualizar de versión, limpiar y validar con QA.

> **Estado:** v0.4.0 — README y prompts de permiso traducidos al español, portugués de Brasil, ruso y chino simplificado (consulte `CHANGELOG.md`).
> **Versión objetivo de la especificación:** Claude Code v2.1.259+ (funciona en versiones posteriores).

> **Independiente del overlay.** Aunque lo mantiene el proyecto Bentoo, este plugin
> está pensado para **cualquier** overlay de Gentoo activo. Las convenciones se derivan
> del `metadata/layout.conf` del overlay detectado (`masters`, `thin-manifests`,
> `manifest-hashes`), no de su nombre. Los ejemplos que mencionan el overlay
> bentoo son solo ilustrativos.

### Versiones mínimas de Claude Code

| Funcionalidad que usa el plugin                             | Versión mínima  |
|-------------------------------------------------------------|:---------------:|
| Opción `--bare` (incompatible con los comandos `/bentoo-dev:*`) | v2.1.81     |
| Hooks `SessionStart` / `CwdChanged`                         | v2.1.83         |
| Forma JSON de `PreToolUse` `permissionDecision: "ask"`      | v2.1.83         |
| `permissionDecision: "defer"` (solo headless con `-p`)      | v2.1.89         |
| PATH automático de `bin/`                                   | v2.1.91         |
| `hookSpecificOutput.sessionTitle` (UserPromptSubmit)        | v2.1.94         |
| Monitores en segundo plano de `monitors/monitors.json`      | v2.1.105        |
| `claude plugin tag` (publicación de versiones)              | v2.1.118        |
| Hooks en forma exec (`"args": []`)                          | v2.1.139        |
| Campo `displayName` del manifiesto                          | v2.1.143        |
| `additionalContext` desde `Stop`/`SubagentStop`             | v2.1.163        |
| Condiciones `if:` limitadas correctamente al comando coincidente | v2.1.259   |
| Versión objetivo global                                      | **v2.1.259+**   |

Cada fila de arriba se comprobó contra el
[CHANGELOG upstream](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md),
salvo tres que no tienen entrada en el changelog y se mantienen sin verificar:
PATH automático de `bin/` (v2.1.91), `displayName` (v2.1.143) y la introducción de
`permissionDecision: "ask"` (v2.1.83 — una entrada posterior, en v2.1.101, la menciona
como ya existente, así que la funcionalidad es real; solo la versión que la introdujo
está sin confirmar). `statusMessage` tampoco tiene entrada en el changelog, por lo que
aparece sin versión en lugar de con una supuesta.

La versión objetivo global es la entrada más alta, no una inferior: el plugin usa todas
las funcionalidades de la lista. En concreto, v2.1.259 corrigió *"hook `if` conditions like
`Bash(cat *)` firing on unrelated Bash commands"* (condiciones `if` de hooks que se disparaban con comandos Bash no relacionados): este plugin encamina seis hooks
mediante `if: Bash(cp *)` / `(mv *)` / `(sed *)`, así que en versiones anteriores esos hooks
se disparan con comandos no relacionados. Los scripts salen con 0 cuando no encuentran ningún `.ebuild`,
por lo que el comportamiento es correcto en ambos casos; solo cambian los procesos lanzados en vano.

---

## Funcionalidades

- **Un único punto de entrada en lenguaje natural** — `/bentoo-dev:bentoo "<instruction>"`.
  La skill recibe una petición libre, clasifica la intención
  (`create` / `bump` / `edit` / `qa` / `clean` / `bootstrap`), pregunta al usuario si hay ambigüedad,
  carga la referencia correspondiente (`skills/bentoo/references/<intent>.md`)
  y delega en el subagente especializado en esa operación. Ejemplos:
  - `/bentoo-dev:bentoo "create dev-libs/foo 1.2.3 from <upstream>"` → `ebuild-creator`
  - `/bentoo-dev:bentoo "bump app-misc/bar to 2.1"` → `ebuild-bumper`
  - `/bentoo-dev:bentoo "add USE flag wayland to games-util/baz"` → `ebuild-editor`
  - `/bentoo-dev:bentoo "run QA on dev-libs/foo"` → `qa-checker`
  - `/bentoo-dev:bentoo "clean the whole overlay"` → `overlay-maintainer`
  - `/bentoo-dev:bentoo "bootstrap a new overlay at ~/myoverlay"` → `overlay-maintainer`

  La activación automática por coincidencia con la descripción sigue funcionando: *"bump mesa to 26.0.5"*
  o *"package XYZ from .deb"* invoca la skill automáticamente sin escribir `/bentoo-dev:bentoo`.
- **5 subagentes especializados** en `agents/`, invocados con la herramienta `Agent` desde la skill `bentoo`; cada uno declara `effort`, `maxTurns`, `tools`, `disallowedTools` y `color`, y precarga la referencia de gotchas mediante el frontmatter `skills:`.
- **Hooks deterministas** que cubren 11 eventos del ciclo de vida; consulte la tabla completa en [Hooks](#hooks). Los esenciales:
  - `SessionStart` / `CwdChanged` (detección automática del overlay, guardada en caché como un resumen acotado).
  - `PreToolUse` Bash (seguridad de rm, con decisiones `deny`/`ask`).
  - `PostToolUse` Write|Edit (lint, recordatorio del Manifest).
  - `PostToolUse` Bash `if: cp|mv|sed` (detecta ediciones de `.ebuild` hechas con Bash que esquivan Write|Edit; `FileChanged` no se usa a propósito: coincide con nombres de archivo literales, no con globs).
  - `Stop` (barrera contra Manifest desactualizado, compatible con `thin-manifests`).
  - `PreCompact` (vuelve a inyectar la identidad del overlay para que sobreviva a la compactación) y
    `StopFailure` (registra las terminaciones por error de la API en `${CLAUDE_PLUGIN_DATA}/stop-failures.log`).
- **Monitores en segundo plano** (v2.1.105) para ELOG de portage y hallazgos de `pkgcheck`, limitados a las invocaciones de skill pertinentes.
- **Estilo de salida** `qa-report` para informes de QA deterministas y analizables.
- **Prompts de permiso localizados** — el prompt `ask` del hook de seguridad de rm sigue su locale (`LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG`, como en gettext) en español, portugués de Brasil, ruso y chino simplificado, con inglés como alternativa. Todo lo que lee Claude —skills, agentes, referencias, contexto de hooks, motivos de `deny` y `block`— se mantiene en inglés a propósito: un prompt traducido empeora el modelo y no ayuda a ningún usuario. Consulte `scripts/lib/i18n.sh`.
- **Disparadores bilingües (PT/EN)** consolidados en la `description` y el `when_to_use` de la skill `bentoo` para una activación automática fiable en las seis operaciones. Las frases en portugués son cadenas de coincidencia, no prosa: están etiquetadas como `PT triggers:` en el frontmatter para que una limpieza posterior no las "traduzca" y las elimine.
- **15 plantillas de ebuild** en `assets/templates/` (incl. `source-pypi`, `virtual`, `acct-user`, `acct-group`) + `metadata.xml` + un `news-item.txt` GLEP 42; sustitución canónica de marcadores con `render-template.sh --env`, con `@@EAPI@@` parametrizado (8 por defecto; `EAPI=9` opcional) y `@@KEYWORDS@@`.
- **Perfiles por overlay** en `assets/profiles/`: actualmente `bentoo` y `default`.
- **Referencias modulares** en `references/`: `gotchas.md` precargado como skill; las demás se cargan bajo demanda.

---

## Instalación

### Local (desarrollo / uso personal)

Clone el repositorio en una ubicación de trabajo y cargue el plugin con `--plugin-dir`:

```bash
git clone <this-repo> ~/.claude/plugins/bentoo-dev
claude --plugin-dir ~/.claude/plugins/bentoo-dev
```

### Marketplace

Cuando se publique, instálelo con:

```bash
/plugin install bentoo-dev@<marketplace-name>
```

### Configurar los valores de usuario

Defina su identidad de Gentoo una vez mediante `userConfig` (Claude Code lo pide durante la instalación) o editando la configuración del plugin:

| Clave                     | Finalidad                                            | Valor por defecto        |
|---------------------------|------------------------------------------------------|--------------------------|
| `maintainer_email`        | `<email>` en `metadata.xml`                          | `lucascs@protonmail.com` |
| `maintainer_name`         | `<name>` en `metadata.xml`                           | `lucascouts`             |
| `maintainer_type`         | Atributo `type=` (`person` / `project` / `nobody`)   | `person`                 |
| `default_keywords`        | KEYWORDS para ebuilds nuevos                         | `~amd64`                 |
| `preferred_overlay_path`  | Ruta de overlay por defecto opcional (se detecta automáticamente si está vacía) | _(sin definir)_ |

Estos valores se exponen a los scripts y subagentes como variables de entorno `CLAUDE_PLUGIN_OPTION_*` (el prefijo vigente en la especificación según la referencia `env-vars` de Claude Code v2.1.x).

---

## Estructura

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

| Evento             | Matcher / Filtro                              | Script                                | Finalidad                                                                                     |
|--------------------|-----------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------------|
| SessionStart       | _(ninguno)_                                   | `cache-overlay.sh`                    | Detecta el overlay activo una vez y guarda en caché el resumen + campos como `${CLAUDE_PLUGIN_DATA}/overlay.json`. |
| SessionEnd         | _(ninguno)_                                   | `cleanup-cache.sh`                    | Descarta la caché del overlay de la sesión para que la siguiente sesión lo detecte desde cero. |
| CwdChanged         | _(ninguno)_                                   | `cache-overlay.sh`                    | Actualiza la caché cuando el usuario cambia de overlay.                                       |
| UserPromptSubmit   | _(ninguno)_                                   | `session-title.sh`                    | Renombra la sesión automáticamente con `hookSpecificOutput.sessionTitle` en las invocaciones `/bentoo-dev:*`. |
| PreToolUse         | `Bash` + `if: Bash(rm *)`                     | `safety-rm-check.sh`                  | `deny` para rm del único `.ebuild` de un directorio; `ask` para rm con riesgo de DIST huérfanas. |
| PreToolUse         | `Bash` + `if: Bash(git rm *)`                 | `safety-rm-check.sh`                  | La misma barrera para `git rm` (entrada separada: el OR con barra vertical no está documentado para `if:`). |
| PostToolUse        | `Write\|Edit`                                 | `quick-lint.sh` + `manifest-reminder.sh` | Lint de EAPI, cabecera de copyright + año, `eapply_user` (limitado a `src_prepare`), KEYWORDS, SLOT, LICENSE; recordatorio ante cambios en SRC_URI. |
| PostToolUseFailure | `Bash`                                        | `manifest-failure-diagnose.sh`        | Clasifica los fallos de `ebuild ... manifest` (red/checksum/404/permisos) y sugiere los siguientes pasos. |
| PostToolUse        | `Bash` + `if: cp\|mv\|sed`                     | `quick-lint.sh` + `manifest-reminder.sh` | Detecta ediciones de `.ebuild` hechas con Bash (`cp`/`mv`/`sed`) que esquivan `Write\|Edit`. |
| SubagentStop       | `ebuild-creator`                              | `ebuild-creator-validate.sh`          | Bloquea la parada si a algún paquete recién creado le falta `metadata.xml` o `Manifest`.      |
| Stop               | _(cualquiera)_                                | `manifest-stale-check.sh`             | Bloquea el fin del turno si un ebuild modificado tiene el Manifest desactualizado (omite los overlays `thin-manifests`). |
| StopFailure        | _(cualquiera)_                                | `stopfailure-log.sh`                  | Registra las terminaciones por error de la API (límite de tasa, facturación, máximo de tokens) en `stop-failures.log`. |
| PreCompact         | _(cualquiera)_                                | `precompact-reinject-overlay.sh`      | Vuelve a inyectar la identidad del overlay en caché para que sobreviva a la compactación de la conversación. |

Todos los scripts leen el payload JSON canónico del hook desde stdin, emiten
formas JSON de `hookSpecificOutput` (`permissionDecision` / `additionalContext` /
`sessionTitle` / `{decision: "block", reason}`) en stdout y salen con 0. Un hook
cuyo stdout se analiza y valida correctamente decide el resultado sea cual sea el código de salida.

Todos los hooks usan la **forma exec** (`"args": []`): Claude Code lanza el script
directamente, sin shell, así que no hay comillas que puedan fallar con una ruta de plugin
que contenga un espacio. `${CLAUDE_PLUGIN_ROOT}` se sustituye en ambas formas, y
ambas lo exportan al proceso lanzado. Cada hook declara además un
`statusMessage`, para que el indicador de progreso muestre qué se está ejecutando.

Los hooks `Stop` y `SubagentStop` respetan la protección contra bucles `stop_hook_active`.
Claude Code anula un hook `Stop` tras **ocho** bloqueos consecutivos; aumente
ese límite con `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` si una convergencia realmente necesita
más.

### Presupuesto de contexto: el resumen del overlay está acotado a propósito

`scripts/overlay-context.sh` es lo que la skill `bentoo` inyecta al cargarse. Sirve
el **resumen acotado** (~1,3 KB) desde la caché de sesión escrita por
`cache-overlay.sh`, y solo vuelve a ejecutar la detección cuando la caché no cubre el
directorio actual.

El volcado literal de `metadata/layout.conf` + `profiles/package.mask` **no** está en
ese resumen. En un overlay real, solo `package.mask` ocupa ~15 KB: unos 4k tokens
inyectados en cada invocación, para algo que solo leen las intenciones `clean` / `mask`.
Cárguelo explícitamente cuando lo necesite:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh" --full   # layout.conf + package.mask
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh" --summary  # same summary, no cache
```

### Lint por lotes sin el modelo

`scripts/quick-lint.sh` funciona también como CLI. El agente `qa-checker` lo llama una vez
por ejecución, así que las siete comprobaciones mecánicas no cuestan nada:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/quick-lint.sh" --json <ebuild> [<ebuild> ...]
# -> {"results":[{"file","errors","warnings"}],"summary":{"files","errors","warnings","status"}}
```

La severidad sigue la PMS: la falta de `SLOT` o `LICENSE` es un **error** (SLOT no tiene
valor por defecto implícito en EAPI 8); un año de copyright desactualizado es una **advertencia**. `LICENSE`
no se exige deliberadamente para `virtual/*`, `acct-user/*` y `acct-group/*`,
que no instalan archivos. Siempre sale con 0: los hallazgos son la salida.

### `permissionDecision`: `ask` frente a `defer`

El `safety-rm-check.sh` de PreToolUse emite `permissionDecision: "ask"` en el
caso de DIST huérfanas (prompt interactivo) y `"deny"` al eliminar el único
`.ebuild` de un directorio de paquete. `defer` está reservado para el modo headless
(opción `-p`, v2.1.89+) y **no** es el valor adecuado para prompts interactivos
de "confirme, por favor".

### Reforzar `rm` (hook fail-open + regla de permiso)

`safety-rm-check.sh` es una **barrera de protección de mejor esfuerzo, no un límite de seguridad**:
el filtro `if: "Bash(rm *)"` es fail-open y el script separa los tokens por
espacios en blanco, así que las comillas, `$()` y las cadenas con `&&` pueden esquivarlo. Para un bloqueo
estricto, combínelo con una regla de permiso `deny`/`ask` en su configuración, por ejemplo:

```json
{ "permissions": { "ask": ["Bash(rm *.ebuild)", "Bash(rm -r *)"] } }
```

El hook sigue elevando a un prompt `ask` los `rm` recursivos o con globs cerca de archivos `.ebuild`,
como respaldo.

### Advertencia sobre los checkpoints

Aquí se suman dos limitaciones que, juntas, significan que **nada de lo que produce este plugin
se puede recuperar con `/rewind`**:

1. Los checkpoints **no** registran archivos modificados por comandos Bash (`rm`, `mv`,
   `cp`, `sed`), solo `Write`/`Edit`/`NotebookEdit`. Un `Manifest` regenerado
   con `ebuild … manifest`, o un `.ebuild` copiado con `cp`, no se deshace.
2. Los checkpoints **tampoco restauran las ediciones de subagentes**. Según la
   [documentación de checkpointing](https://code.claude.com/docs/en/checkpointing), solo una
   skill bifurcada que se ejecuta en primer plano recupera sus ediciones; para cualquier otro
   subagente, *"rewinding doesn't restore the edits. Use git to revert them."* (rebobinar no restaura las ediciones; use git para revertirlas).
   Toda escritura de este plugin ocurre dentro de uno de los cinco subagentes.

Así que `/rewind` no es una red de seguridad para el trabajo en overlays. **Use git.** Por eso el
plugin incluye hooks deterministas de Manifest desactualizado y de seguridad de rm en lugar de
depender de los checkpoints, y por eso `safety-rm-check.sh` deniega en lugar de advertir.

### `pkgcheck` recurrente

Hay una sola vía para pkgcheck: el **monitor `pkgcheck-watch`**, que se inicia al
invocar la skill `bentoo`. Analiza el overlay en caché, notifica los nuevos hallazgos
de nivel ERROR y añade cada resultado nuevo a
`${CLAUDE_PLUGIN_DATA}/pkgcheck.log`.

Un monitor es el mecanismo nativo para esto. La
[documentación de tareas programadas](https://code.claude.com/docs/en/scheduled-tasks) lo dice
claramente: un monitor *"avoids polling altogether and is often more token-efficient
and responsive than re-running a prompt on an interval."* (evita el sondeo por completo y suele ser más eficiente en tokens y más ágil que volver a ejecutar un prompt a intervalos). Un segundo script, basado en cron,
duplicaba el mismo análisis; se eliminó en lugar de dejar que divergiera.

Ajuste el intervalo con `BENTOO_DEV_PKGCHECK_INTERVAL` (segundos, por defecto 300).

Si quiere una programación que sobreviva a la sesión, tenga en cuenta que las
[Routines](https://code.claude.com/docs/en/routines) en la nube **no** sirven para esto: se
ejecutan en un clon nuevo sin acceso a su overlay local. Use una
**tarea programada de Desktop** o `/loop`, que se ejecutan ambas en su máquina.

---

## Gotchas críticos (referencia)

Las 11 reglas imprescindibles están centralizadas en `references/gotchas.md` y se exponen
a los subagentes mediante la skill `bentoo-dev:gotchas` (precargada con el frontmatter
`skills:`, con `user-invocable: false`):

1. `eapply_user` obligatorio en un `src_prepare` sobrescrito
2. `|| die` tras comandos de shell que pueden fallar
3. KEYWORDS vacío en ebuilds live `9999`
4. `S=` debe coincidir con el directorio extraído
5. Renombrado de SRC_URI con `->` para tarballs con nombres poco informativos
6. `QA_PREBUILT` + `RESTRICT` para paquetes binarios
7. Copyright en la línea 1, `EAPI=` en la primera línea que no sea comentario
8. `thin-manifests` solo contiene entradas DIST
9. `default` en `src_prepare` aplica `PATCHES` + `eapply_user`
10. `MY_P` / `MY_PN` cuando el nombre upstream no coincide
11. `<stabilize-allarches/>` se busca con grep, no se analiza: nunca escriba el token literal en `metadata.xml`, ni siquiera en un comentario

### Mantenimiento del overlay que imponen los agentes

Dos reglas que no son sintaxis de ebuild pero degradan un overlay en silencio, integradas en
`ebuild-bumper` y `overlay-maintainer`:

- **`pkgdev manifest` siempre recibe un objetivo explícito.** Sin objetivo,
  reescribe el Manifest de todo el overlay.
- **`metadata/md5-cache` se regenera por paquete tras un bump**, cuando el
  overlay lo mantiene; si no, la entrada de la versión anterior queda huérfana y la
  basura crece con cada bump:
  `egencache --repositories-configuration "$(portageq repos_config /)" --update --repo <repo> <cat>/<pkg>`.
  `--repositories-configuration` es obligatorio en un checkout que no sea la ruta
  que Portage tiene registrada; `egencache` ignora `PORTAGE_CONFIGROOT` / `PORTAGE_REPOSITORIES`.

---

## Uso en CI / headless

El plugin es totalmente compatible con el modo no interactivo `claude -p`. Todos los hooks
leen payloads JSON desde stdin y se degradan con elegancia cuando se invocan manualmente.

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

> **Nota sobre `--bare`**: esta opción (Claude Code v2.1.81+) omite por completo la carga
> de plugins (junto con hooks, skills, MCP y CLAUDE.md). Por tanto, es
> incompatible con `--plugin-dir` para invocar comandos `/bentoo-dev:*`. Para una
> CI restringida, use `--permission-mode dontAsk` junto con una lista explícita
> `--allowedTools` como la de arriba. La autenticación debe venir de
> `ANTHROPIC_API_KEY`.

### Versiones publicadas

Envíe (push) una etiqueta `vX.Y.Z` para disparar `.github/workflows/release.yml`, que valida
el plugin y ejecuta `claude plugin tag .` (v2.1.118+) para publicar en los
marketplaces.

---

## Contribuir

1. Añada nuevos perfiles de overlay en `assets/profiles/<name>.md`.
2. Añada nuevas plantillas en `assets/templates/`.
3. Actualice `evals/evals.json` y `evals/trigger-queries.json` siempre que añada una skill nueva o cambie los disparadores.
4. Incremente `version` en `.claude-plugin/plugin.json` y actualice `CHANGELOG.md`.
5. Un mensaje nuevo que lee una **persona** (un prompt de permiso, no contexto de hook) recibe un ID en **todos** los catálogos de `scripts/lib/i18n.sh`; si no, `bats tests/i18n.bats` falla. Cuando cambie `README.md`, actualice las traducciones (`README.<lang>.md`) o indique en el PR que van con retraso.

---

## Licencia

MIT — consulte `LICENSE`.
