# bentoo-dev

A Claude Code plugin for developing and maintaining **Gentoo ebuilds and overlays**. Provides specialised skills, sub-agents, hooks, monitors, and reference material for the full lifecycle of an ebuild — create, edit, bump, clean, QA-validate.

> **Status:** v0.1.0 — initial public release (see `CHANGELOG.md`).
> **Spec target:** Claude Code v2.1.119.

### Minimum Claude Code versions

| Feature used by the plugin                                  | Minimum version |
|-------------------------------------------------------------|:---------------:|
| `--bare` flag (incompatible with `/bentoo-dev:*` commands)  | v2.1.81         |
| `SessionStart` / `CwdChanged` / `FileChanged` hooks         | v2.1.83         |
| `PreToolUse` `permissionDecision: "ask"` JSON shape         | v2.1.83         |
| `permissionDecision: "defer"` (headless `-p` only)          | v2.1.89         |
| `bin/` auto-PATH                                            | v2.1.91         |
| `hookSpecificOutput.sessionTitle` (UserPromptSubmit)        | v2.1.94         |
| `monitors/monitors.json` background monitors                | v2.1.105        |
| `claude plugin tag` (release publishing)                    | v2.1.118        |
| Spec target overall                                          | **v2.1.119**    |

---

## Features

- **Single natural-language entry point** — `/bentoo-dev:bentoo "<instruction>"`.
  The skill receives a free-form request, classifies the intent
  (`create` / `bump` / `edit` / `qa` / `clean`), asks the user when ambiguous,
  loads the matching reference (`skills/bentoo/references/<intent>.md`),
  and delegates to the specialised sub-agent for that operation. Examples:
  - `/bentoo-dev:bentoo "create dev-libs/foo 1.2.3 from <upstream>"` → `ebuild-creator`
  - `/bentoo-dev:bentoo "bump app-misc/bar to 2.1"` → `ebuild-bumper`
  - `/bentoo-dev:bentoo "add USE flag wayland to games-util/baz"` → `ebuild-editor`
  - `/bentoo-dev:bentoo "run QA on dev-libs/foo"` → `qa-checker`
  - `/bentoo-dev:bentoo "clean the whole overlay"` → `overlay-maintainer`

  Auto-trigger by description-matching still works — *"bump mesa to 26.0.5"*
  or *"package XYZ from .deb"* invokes the skill automatically without typing `/bentoo-dev:bentoo`.
- **5 specialised sub-agents** at `agents/` — invoked via the `Agent` tool by the `bentoo` skill; each declares `effort`, `maxTurns`, `tools`, `disallowedTools`, `color`, and preloads the gotchas reference via `skills:` frontmatter.
- **Deterministic hooks** covering 5 lifecycle events:
  - `SessionStart` / `CwdChanged` (overlay auto-detect + cache).
  - `PreToolUse` Bash (rm safety, with `deny`/`ask` decisions).
  - `PostToolUse` Write|Edit (lint, Manifest reminder).
  - `FileChanged` (catches edits via Bash that bypass Write|Edit).
  - `Stop` (Manifest staleness gate, `thin-manifests`-aware).
- **Background monitors** (v2.1.105) for portage ELOG and `pkgcheck` findings, scoped to the relevant skill invocations.
- **Output style** `qa-report` for deterministic, parseable QA reports.
- **Bilingual triggers (PT/EN)** consolidated in the `bentoo` skill `description` and `when_to_use` for high auto-trigger fidelity across all five operations.
- **11 ebuild templates** in `assets/templates/` + canonical placeholder substitution via `render-template.sh --env`.
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
├── hooks/hooks.json                # SessionStart / CwdChanged / PreToolUse / PostToolUse / FileChanged / Stop
├── monitors/monitors.json          # portage-elog + pkgcheck-watch (v2.1.105+)
├── output-styles/qa-report.md      # deterministic QA report format
├── scripts/                        # shell helpers used by hooks / agents / monitors
│   ├── detect-overlay.sh
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
│   └── templates/  (11 *.ebuild + metadata.xml)
└── evals/  (evals.json, trigger-queries.json)
```

---

## Hooks

| Event              | Matcher / Filter                              | Script                                | Purpose                                                                                       |
|--------------------|-----------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------------|
| SessionStart       | _(none)_                                      | `cache-overlay.sh`                    | Detect active overlay once and cache as `${CLAUDE_PLUGIN_DATA}/overlay.json`.                 |
| SessionEnd         | _(none)_                                      | `cleanup-cache.sh`                    | Drop the per-session overlay cache so the next session re-detects from scratch.               |
| CwdChanged         | _(none)_                                      | `cache-overlay.sh`                    | Refresh cache when the user navigates between overlays.                                       |
| UserPromptSubmit   | _(none)_                                      | `session-title.sh`                    | Auto-rename the session via `hookSpecificOutput.sessionTitle` for `/bentoo-dev:*` invocations. |
| PreToolUse         | `Bash` + `if: Bash(rm *)`                     | `safety-rm-check.sh`                  | `deny` rm of the only `.ebuild` in a dir; `ask` rm with orphan DIST risk.                     |
| PreToolUse         | `Bash` + `if: Bash(git rm *)`                 | `safety-rm-check.sh`                  | Same gate for `git rm` (split entry — pipe-OR is not documented for `if:`).                   |
| PostToolUse        | `Write\|Edit`                                 | `quick-lint.sh` + `manifest-reminder.sh` | Lint EAPI, copyright, `eapply_user`, KEYWORDS, SLOT, LICENSE; remind on SRC_URI changes.   |
| PostToolUseFailure | `Bash`                                        | `manifest-failure-diagnose.sh`        | Classify `ebuild ... manifest` failures (network/checksum/404/perm) and suggest next steps.   |
| FileChanged        | `*.ebuild`                                    | `quick-lint.sh` + `manifest-reminder.sh` | Catch edits made via Bash (`cp`/`mv`/`sed`) that bypass `Write\|Edit`.                     |
| SubagentStop       | `ebuild-creator`                              | `ebuild-creator-validate.sh`          | Block stop if any newly-created package is missing `metadata.xml` or `Manifest`.              |
| Stop               | _(any)_                                       | `manifest-stale-check.sh`             | Block turn end if a modified ebuild has a stale Manifest (skips `thin-manifests` overlays).   |

All scripts read the canonical hook JSON payload from stdin, emit
`hookSpecificOutput` JSON shapes (`permissionDecision` / `additionalContext` /
`sessionTitle` / `{decision: "block", reason}`) on stdout, and exit 0.
The `Stop` and `SubagentStop` hooks honour the `stop_hook_active` loop guard.

### `permissionDecision`: `ask` vs `defer`

The PreToolUse `safety-rm-check.sh` emits `permissionDecision: "ask"` for the
orphan-DIST case (interactive prompt) and `"deny"` when removing the only
`.ebuild` in a package directory. `defer` is reserved for headless mode
(`-p` flag, v2.1.89+) and is **not** the right value for interactive
"please confirm" prompts.

---

## Critical gotchas (reference)

The 10 must-know rules are centralised in `references/gotchas.md` and exposed
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
