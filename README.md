# bentoo-dev

A Claude Code plugin for developing and maintaining **Gentoo ebuilds and overlays**. Provides specialised skills, sub-agents, hooks, monitors, and reference material for the full lifecycle of an ebuild — create, edit, bump, clean, QA-validate.

> **Status:** v0.3.0 — bounded skill context, hook-correctness fixes, and component-reference conformance (see `CHANGELOG.md`).
> **Spec target:** Claude Code v2.1.259+ (works on later releases).

> **Overlay-agnostic.** Although maintained by the Bentoo project, this plugin
> targets **any** active Gentoo overlay. Conventions are derived from the
> detected overlay's `metadata/layout.conf` (`masters`, `thin-manifests`,
> `manifest-hashes`), not from its name. Examples that mention the bentoo
> overlay are illustrative only.

### Minimum Claude Code versions

| Feature used by the plugin                                  | Minimum version |
|-------------------------------------------------------------|:---------------:|
| `--bare` flag (incompatible with `/bentoo-dev:*` commands)  | v2.1.81         |
| `SessionStart` / `CwdChanged` hooks                         | v2.1.83         |
| `PreToolUse` `permissionDecision: "ask"` JSON shape         | v2.1.83         |
| `permissionDecision: "defer"` (headless `-p` only)          | v2.1.89         |
| `bin/` auto-PATH                                            | v2.1.91         |
| `hookSpecificOutput.sessionTitle` (UserPromptSubmit)        | v2.1.94         |
| `monitors/monitors.json` background monitors                | v2.1.105        |
| `claude plugin tag` (release publishing)                    | v2.1.118        |
| Exec-form hooks (`"args": []`)                              | v2.1.139        |
| `displayName` manifest field                                | v2.1.143        |
| `additionalContext` from `Stop`/`SubagentStop`              | v2.1.163        |
| `if:` conditions scoped correctly to the matched command    | v2.1.259        |
| Spec target overall                                          | **v2.1.259+**   |

Every row above was checked against the
[upstream CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md),
except three that have no changelog entry and are carried over unverified:
`bin/` auto-PATH (v2.1.91), `displayName` (v2.1.143), and the introduction of
`permissionDecision: "ask"` (v2.1.83 — a later entry at v2.1.101 refers to it as
already existing, so the feature is real; only the introducing version is
unconfirmed). `statusMessage` has no changelog entry either and is therefore
listed with no version at all rather than a guessed one.

The overall target is the highest entry, not a lower one: the plugin uses every
feature listed. v2.1.259 in particular fixed *"hook `if` conditions like
`Bash(cat *)` firing on unrelated Bash commands"* — this plugin routes six hooks
through `if: Bash(cp *)` / `(mv *)` / `(sed *)`, so on earlier versions those
fire on unrelated commands. The scripts exit 0 when they find no `.ebuild`, so
the behaviour is correct either way; only the wasted spawns differ.

---

## Features

- **Single natural-language entry point** — `/bentoo-dev:bentoo "<instruction>"`.
  The skill receives a free-form request, classifies the intent
  (`create` / `bump` / `edit` / `qa` / `clean` / `bootstrap`), asks the user when ambiguous,
  loads the matching reference (`skills/bentoo/references/<intent>.md`),
  and delegates to the specialised sub-agent for that operation. Examples:
  - `/bentoo-dev:bentoo "create dev-libs/foo 1.2.3 from <upstream>"` → `ebuild-creator`
  - `/bentoo-dev:bentoo "bump app-misc/bar to 2.1"` → `ebuild-bumper`
  - `/bentoo-dev:bentoo "add USE flag wayland to games-util/baz"` → `ebuild-editor`
  - `/bentoo-dev:bentoo "run QA on dev-libs/foo"` → `qa-checker`
  - `/bentoo-dev:bentoo "clean the whole overlay"` → `overlay-maintainer`
  - `/bentoo-dev:bentoo "bootstrap a new overlay at ~/myoverlay"` → `overlay-maintainer`

  Auto-trigger by description-matching still works — *"bump mesa to 26.0.5"*
  or *"package XYZ from .deb"* invokes the skill automatically without typing `/bentoo-dev:bentoo`.
- **5 specialised sub-agents** at `agents/` — invoked via the `Agent` tool by the `bentoo` skill; each declares `effort`, `maxTurns`, `tools`, `disallowedTools`, `color`, and preloads the gotchas reference via `skills:` frontmatter.
- **Deterministic hooks** covering 11 lifecycle events — see the full table under [Hooks](#hooks). The load-bearing ones:
  - `SessionStart` / `CwdChanged` (overlay auto-detect, cached as a bounded summary).
  - `PreToolUse` Bash (rm safety, with `deny`/`ask` decisions).
  - `PostToolUse` Write|Edit (lint, Manifest reminder).
  - `PostToolUse` Bash `if: cp|mv|sed` (catches `.ebuild` edits via Bash that bypass Write|Edit; `FileChanged` is intentionally not used — it matches literal filenames, not globs).
  - `Stop` (Manifest staleness gate, `thin-manifests`-aware).
  - `PreCompact` (re-injects the overlay identity so it survives compaction) and
    `StopFailure` (logs API-error terminations to `${CLAUDE_PLUGIN_DATA}/stop-failures.log`).
- **Background monitors** (v2.1.105) for portage ELOG and `pkgcheck` findings, scoped to the relevant skill invocations.
- **Output style** `qa-report` for deterministic, parseable QA reports.
- **Bilingual triggers (PT/EN)** consolidated in the `bentoo` skill `description` and `when_to_use` for high auto-trigger fidelity across all six operations. The Portuguese phrases are match strings, not prose — they are labelled `PT triggers:` in the frontmatter so they are not "translated away" by a later cleanup.
- **15 ebuild templates** in `assets/templates/` (incl. `source-pypi`, `virtual`, `acct-user`, `acct-group`) + `metadata.xml` + a GLEP 42 `news-item.txt`; canonical placeholder substitution via `render-template.sh --env` with parametrized `@@EAPI@@` (renders 8 by default; `EAPI=9` opt-in) and `@@KEYWORDS@@`.
- **Per-overlay profiles** in `assets/profiles/` — currently `bentoo` and `default`.
- **Modular references** in `references/` — `gotchas.md` preloaded as a skill; the others lazy-loaded on demand.

---

## Installation

### Local (development / personal use)

Clone the repo into a working location and load the plugin via `--plugin-dir`:

```bash
git clone <this-repo> ~/.claude/plugins/bentoo-dev
claude --plugin-dir ~/.claude/plugins/bentoo-dev
```

### Marketplace

When published, install via:

```bash
/plugin install bentoo-dev@<marketplace-name>
```

### Configure user values

Set your Gentoo identity once via `userConfig` (Claude Code prompts during install) or by editing the plugin config:

| Key                       | Purpose                                              | Default                  |
|---------------------------|------------------------------------------------------|--------------------------|
| `maintainer_email`        | `<email>` in `metadata.xml`                          | `lucascs@protonmail.com` |
| `maintainer_name`         | `<name>` in `metadata.xml`                           | `lucascouts`             |
| `maintainer_type`         | `type=` attribute (`person` / `project` / `nobody`)  | `person`                 |
| `default_keywords`        | KEYWORDS for new ebuilds                             | `~amd64`                 |
| `preferred_overlay_path`  | Optional default overlay path (auto-detected if empty) | _(unset)_              |

These values are exposed to scripts and sub-agents as `CLAUDE_PLUGIN_OPTION_*` environment variables (the spec-current prefix per Claude Code v2.1.x `env-vars` reference).

---

## Layout

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
│   ├── cache-overlay.sh            # SessionStart / CwdChanged hook target
│   ├── quick-lint.sh
│   ├── manifest-reminder.sh
│   ├── manifest-stale-check.sh
│   ├── safety-rm-check.sh
│   ├── monitor-elog.sh
│   ├── monitor-pkgcheck.sh
│   ├── render-template.sh          # substitutes @@VAR@@ in templates
│   └── plugin-data-dir.sh
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

| Event              | Matcher / Filter                              | Script                                | Purpose                                                                                       |
|--------------------|-----------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------------|
| SessionStart       | _(none)_                                      | `cache-overlay.sh`                    | Detect active overlay once and cache summary + fields as `${CLAUDE_PLUGIN_DATA}/overlay.json`.                 |
| SessionEnd         | _(none)_                                      | `cleanup-cache.sh`                    | Drop the per-session overlay cache so the next session re-detects from scratch.               |
| CwdChanged         | _(none)_                                      | `cache-overlay.sh`                    | Refresh cache when the user navigates between overlays.                                       |
| UserPromptSubmit   | _(none)_                                      | `session-title.sh`                    | Auto-rename the session via `hookSpecificOutput.sessionTitle` for `/bentoo-dev:*` invocations. |
| PreToolUse         | `Bash` + `if: Bash(rm *)`                     | `safety-rm-check.sh`                  | `deny` rm of the only `.ebuild` in a dir; `ask` rm with orphan DIST risk.                     |
| PreToolUse         | `Bash` + `if: Bash(git rm *)`                 | `safety-rm-check.sh`                  | Same gate for `git rm` (split entry — pipe-OR is not documented for `if:`).                   |
| PostToolUse        | `Write\|Edit`                                 | `quick-lint.sh` + `manifest-reminder.sh` | Lint EAPI, copyright header + year, `eapply_user` (scoped to `src_prepare`), KEYWORDS, SLOT, LICENSE; remind on SRC_URI changes. |
| PostToolUseFailure | `Bash`                                        | `manifest-failure-diagnose.sh`        | Classify `ebuild ... manifest` failures (network/checksum/404/perm) and suggest next steps.   |
| PostToolUse        | `Bash` + `if: cp\|mv\|sed`                     | `quick-lint.sh` + `manifest-reminder.sh` | Catch `.ebuild` edits made via Bash (`cp`/`mv`/`sed`) that bypass `Write\|Edit`.            |
| SubagentStop       | `ebuild-creator`                              | `ebuild-creator-validate.sh`          | Block stop if any newly-created package is missing `metadata.xml` or `Manifest`.              |
| Stop               | _(any)_                                       | `manifest-stale-check.sh`             | Block turn end if a modified ebuild has a stale Manifest (skips `thin-manifests` overlays).   |
| StopFailure        | _(any)_                                       | `stopfailure-log.sh`                  | Log API-error terminations (rate limit, billing, max tokens) to `stop-failures.log`.           |
| PreCompact         | _(any)_                                       | `precompact-reinject-overlay.sh`      | Re-inject the cached overlay identity so it survives conversation compaction.                  |

All scripts read the canonical hook JSON payload from stdin, emit
`hookSpecificOutput` JSON shapes (`permissionDecision` / `additionalContext` /
`sessionTitle` / `{decision: "block", reason}`) on stdout, and exit 0. A hook
whose stdout parses and validates decides the outcome regardless of exit code.

Every hook uses **exec form** (`"args": []`): Claude Code spawns the script
directly with no shell, so there is no quoting to get wrong on a plugin path
containing a space. `${CLAUDE_PLUGIN_ROOT}` is substituted in both forms, and
both export it on the spawned process. Each hook also declares a
`statusMessage`, so the spinner names what is running.

The `Stop` and `SubagentStop` hooks honour the `stop_hook_active` loop guard.
Claude Code overrides a `Stop` hook after **eight** consecutive blocks; raise
that with `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` if a convergence legitimately needs
more.

### Context budget: the overlay summary is bounded on purpose

`scripts/overlay-context.sh` is what the `bentoo` skill injects at load time. It
serves the **bounded summary** (~1.3 KB) out of the session cache written by
`cache-overlay.sh`, and only re-runs detection when the cache does not cover the
current directory.

The verbatim `metadata/layout.conf` + `profiles/package.mask` dump is **not** in
that summary. On a real overlay `package.mask` alone is ~15 KB — about 4k tokens
injected on every single invocation, for something only the `clean` / `mask`
intents ever read. Load it explicitly when you need it:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh" --full   # layout.conf + package.mask
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh" --summary  # same summary, no cache
```

### Batch linting without the model

`scripts/quick-lint.sh` doubles as a CLI. The `qa-checker` agent calls it once
per run so the seven mechanical checks cost nothing:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/quick-lint.sh" --json <ebuild> [<ebuild> ...]
# -> {"results":[{"file","errors","warnings"}],"summary":{"files","errors","warnings","status"}}
```

Severity follows PMS: missing `SLOT` or `LICENSE` is an **error** (SLOT has no
implicit default in EAPI 8); a stale copyright year is a **warning**. `LICENSE`
is deliberately not required for `virtual/*`, `acct-user/*` and `acct-group/*`,
which install no files. Always exits 0 — the findings are the output.

### `permissionDecision`: `ask` vs `defer`

The PreToolUse `safety-rm-check.sh` emits `permissionDecision: "ask"` for the
orphan-DIST case (interactive prompt) and `"deny"` when removing the only
`.ebuild` in a package directory. `defer` is reserved for headless mode
(`-p` flag, v2.1.89+) and is **not** the right value for interactive
"please confirm" prompts.

### Hardening `rm` (fail-open hook + permission rule)

`safety-rm-check.sh` is a **best-effort guard rail, not a security boundary**:
the `if: "Bash(rm *)"` filter is fail-open and the script tokenizes on
whitespace, so quoting, `$()`, and `&&` chains can slip past it. For a hard
block, pair it with a permission `deny`/`ask` rule in your settings, e.g.:

```json
{ "permissions": { "ask": ["Bash(rm *.ebuild)", "Bash(rm -r *)"] } }
```

The hook still escalates recursive/globbed `rm` near `.ebuild` files to an
`ask` prompt as a backstop.

### Checkpointing caveat

Two limitations stack here, and together they mean **nothing this plugin
produces is recoverable with `/rewind`**:

1. Checkpoints **do not** track files changed by Bash commands (`rm`, `mv`,
   `cp`, `sed`) — only `Write`/`Edit`/`NotebookEdit`. A `Manifest` regenerated
   via `ebuild … manifest`, or an `.ebuild` copied with `cp`, is not undone.
2. Checkpoints **do not restore subagent edits** either. Per the
   [checkpointing docs](https://code.claude.com/docs/en/checkpointing), only a
   forked skill running in the foreground has its edits restored; for any other
   subagent, *"rewinding doesn't restore the edits. Use git to revert them."*
   Every write in this plugin happens inside one of the five sub-agents.

So `/rewind` is not a safety net for overlay work. **Use git.** This is why the
plugin ships deterministic Manifest-staleness and rm-safety hooks instead of
relying on checkpoints, and why `safety-rm-check.sh` denies rather than warns.

### Recurring `pkgcheck`

There is one pkgcheck path: the **`pkgcheck-watch` monitor**, started on
`bentoo` skill invocation. It scans the cached overlay, notifies on new
ERROR-level findings, and appends each new result to
`${CLAUDE_PLUGIN_DATA}/pkgcheck.log`.

A monitor is the native mechanism for this. The
[scheduled-tasks docs](https://code.claude.com/docs/en/scheduled-tasks) put it
plainly: a monitor *"avoids polling altogether and is often more token-efficient
and responsive than re-running a prompt on an interval."* A second, cron-driven
script used to duplicate the same scan; it was removed rather than left to drift.

Tune the interval with `BENTOO_DEV_PKGCHECK_INTERVAL` (seconds, default 300).

If you do want a schedule that outlives the session, note that cloud
[Routines](https://code.claude.com/docs/en/routines) **cannot** serve this: they
run in a fresh clone with no access to your local overlay. Use a
**Desktop scheduled task** or `/loop`, both of which run on your machine.

---

## Critical gotchas (reference)

The 11 must-know rules are centralised in `references/gotchas.md` and exposed
to sub-agents via the `bentoo-dev:gotchas` skill (preloaded via `skills:`
frontmatter, with `user-invocable: false`):

1. `eapply_user` mandatory in overridden `src_prepare`
2. `|| die` after fallible shell commands
3. KEYWORDS empty for `9999` live ebuilds
4. `S=` must match the extracted directory
5. SRC_URI rename with `->` for non-informative tarballs
6. `QA_PREBUILT` + `RESTRICT` for binary packages
7. Copyright on line 1, `EAPI=` first non-comment line
8. `thin-manifests` only contains DIST entries
9. `default` in `src_prepare` applies `PATCHES` + `eapply_user`
10. `MY_P` / `MY_PN` for upstream naming mismatches
11. `<stabilize-allarches/>` is grepped, not parsed — never write the literal token in `metadata.xml`, not even in a comment

### Overlay bookkeeping the agents enforce

Two rules that are not ebuild syntax but silently rot an overlay, wired into
`ebuild-bumper` and `overlay-maintainer`:

- **`pkgdev manifest` always takes an explicit target.** With no target it
  rewrites the Manifest of the entire overlay.
- **`metadata/md5-cache` is regenerated per package after a bump**, when the
  overlay keeps one — otherwise the previous version's entry is orphaned and the
  litter grows with every bump:
  `egencache --repositories-configuration "$(portageq repos_config /)" --update --repo <repo> <cat>/<pkg>`.
  `--repositories-configuration` is mandatory on a checkout that is not the path
  Portage has registered; `PORTAGE_CONFIGROOT` / `PORTAGE_REPOSITORIES` are
  ignored by `egencache`.

---

## CI / headless usage

The plugin is fully compatible with `claude -p` non-interactive mode. All hooks
read JSON payloads from stdin and degrade gracefully when invoked manually.

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

> **Note on `--bare`**: this flag (Claude Code v2.1.81+) skips plugin loading
> entirely (along with hooks, skills, MCP, CLAUDE.md). It is therefore
> incompatible with `--plugin-dir` for invoking `/bentoo-dev:*` commands. For
> locked-down CI use `--permission-mode dontAsk` plus an explicit
> `--allowedTools` allowlist as above. Authentication must come from
> `ANTHROPIC_API_KEY`.

### Releases

Push a tag `vX.Y.Z` to trigger `.github/workflows/release.yml`, which validates
the plugin and runs `claude plugin tag .` (v2.1.118+) to publish to
marketplaces.

---

## Contributing

1. Add new overlay profiles under `assets/profiles/<name>.md`.
2. Add new templates under `assets/templates/`.
3. Update `evals/evals.json` and `evals/trigger-queries.json` whenever you add a new skill or change triggers.
4. Bump `version` in `.claude-plugin/plugin.json` and update `CHANGELOG.md`.

---

## License

MIT — see `LICENSE`.
