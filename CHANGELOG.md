# Changelog

All notable changes to the `bentoo-dev` plugin are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_No changes yet._

## [0.1.1] — 2026-04-27

### Fixed

- `scripts/manifest-stale-check.sh` (Stop hook) no longer flags loose `.ebuild`
  files that live outside an overlay tree. The check now requires
  `metadata/layout.conf` in some ancestor directory before validating Manifest
  freshness. Eliminates false positives against the plugin's own
  `assets/templates/*.ebuild` files (and any other repo that keeps example
  ebuilds outside an overlay).

## [0.1.0] — 2026-04-27

Initial public release. Plugin claims conformance against Claude Code v2.1.119
spec (plugins-reference, sub-agents, skills, hooks, env-vars, tools-reference,
monitors, output-styles).

### Added

- `.claude-plugin/plugin.json` manifest with `userConfig` (5 fields, all carrying
  the required `type` / `title` / `description`):
  - `maintainer_email`, `maintainer_name`, `maintainer_type`, `default_keywords`,
    `preferred_overlay_path`.
  - `output-styles/` and `monitors/monitors.json` are loaded from their
    documented default locations — no explicit manifest keys needed.
- 5 namespaced skills under `skills/` with bilingual (PT/EN) triggers and
  `paths:` glob filters scoped to ebuild / metadata / Manifest / profiles /
  eclass files:
  - `/bentoo-dev:ebuild-create` — new ebuilds from upstream
    (source / `.deb` / AppImage / git).
  - `/bentoo-dev:ebuild-edit` — surgical changes with cross-file consistency.
  - `/bentoo-dev:ebuild-bump` — version bumps (standard or `_p<YYYYMMDD>`
    snapshot).
  - `/bentoo-dev:overlay-clean` — overlay-wide health.
  - `/bentoo-dev:ebuild-qa` — read-only validation
    (`agent: qa-checker`, `model: haiku`, `context: fork`).
- One internal preload skill `bentoo-dev:gotchas`
  (`user-invocable: false`) that exposes the 10 critical Gentoo gotchas via
  Bash injection so sub-agents preload them via `skills:` frontmatter
  instead of re-reading the file every turn.
- `Bash(...)` pre-approvals declared in every skill's `allowed-tools` to reduce
  permission prompts during common Gentoo workflows
  (`Bash(ebuild *)`, `Bash(pkgcheck *)`, `Bash(rm *)`, `Bash(cp *)`, etc.),
  using the canonical `Bash(<cmd> *)` prefix-match form documented under
  `/en/skills` and `/en/sub-agents`. Bare `Bash` is intentionally omitted to
  preserve least-privilege (a bare entry would silently approve any command).
- 5 sub-agents under `agents/` with `effort`, `maxTurns`, `color`, and
  `skills: [bentoo-dev:gotchas]` declared:
  - `qa-checker` — model `haiku`, low effort, 10 turns, color `green`,
    `disallowedTools: Write, Edit` for defence-in-depth.
  - `ebuild-bumper` — model `sonnet`, medium, 15 turns, color `yellow`.
  - `ebuild-editor` — high, 20 turns, color `cyan`.
  - `ebuild-creator` — high, 25 turns, color `blue`,
    `isolation: worktree` (cancelled runs leave the overlay untouched),
    `disallowedTools: WebFetch`.
  - `overlay-maintainer` — model `sonnet`, medium, 30 turns, color `orange`,
    `background: true`, `memory: project` (accumulates package-level knowledge
    across sessions).
- Canonical hooks at `hooks/hooks.json` covering all relevant lifecycle events:
  - `SessionStart` and `CwdChanged` → `cache-overlay.sh` writes
    `${CLAUDE_PLUGIN_DATA}/overlay.json` so skills don't re-detect on every
    turn (hook events introduced in v2.1.83).
  - `SessionEnd` → `cleanup-cache.sh` drops
    `${CLAUDE_PLUGIN_DATA}/overlay.json` when the session terminates so the
    next session redetects the overlay from scratch (long-lived caches like
    `pkgcheck-daily.log` are preserved).
  - `UserPromptSubmit` (v2.1.94+) → `session-title.sh` emits
    `hookSpecificOutput.sessionTitle` so any session that starts with
    `/bentoo-dev:*` is auto-renamed to `bentoo: <skill> <args>` in the
    session list.
  - `PreToolUse` `Bash` with two `if:` entries (`Bash(rm *)` and
    `Bash(git rm *)`) → `safety-rm-check.sh` emitting
    `hookSpecificOutput.permissionDecision: "deny"` (hard block when an rm
    would empty a package directory) or `"ask"` (orphan-DIST risk; prompt
    user). `permissionDecision` JSON shape introduced in v2.1.83. Split into
    two entries because pipe-OR is not a documented form for `if:`.
    Interactive value is `"ask"`; `"defer"` is reserved for headless `-p`
    mode (v2.1.89+).
  - `PostToolUse` `Write|Edit` → `quick-lint.sh` and `manifest-reminder.sh`
    (both emit `hookSpecificOutput.additionalContext`; exit 0).
  - `PostToolUse` `Bash` with `if: Bash(cp *)`, `if: Bash(mv *)`,
    `if: Bash(sed *)` filters → catches `.ebuild` edits made via shell
    that bypass `Write|Edit`.
  - `PostToolUseFailure` `Bash` → `manifest-failure-diagnose.sh` classifies
    `ebuild ... manifest` failures (network / checksum / 404 / permission)
    and emits `additionalContext` with targeted next-step guidance.
  - `SubagentStop` matched on `ebuild-creator` →
    `ebuild-creator-validate.sh` walks the cached overlay for
    newly-modified `.ebuild` files and emits `{decision:"block", reason}`
    if any package is missing `metadata.xml` or `Manifest`. Honours
    `stop_hook_active` loop guard.
  - `Stop` → `manifest-stale-check.sh` — deterministic Manifest staleness
    check that respects `thin-manifests = true` in `metadata/layout.conf`;
    no LLM call, no token cost per turn; canonical
    `{decision:"block", reason}` shape with `stop_hook_active` loop guard.
  - `StopFailure` (v2.1.78+) → `stopfailure-log.sh` logs API errors that
    terminate a turn (`rate_limit`, `authentication_failed`,
    `billing_error`, `invalid_request`, `server_error`,
    `max_output_tokens`, `unknown`) to
    `${CLAUDE_PLUGIN_DATA}/stop-failures.log` (TSV: timestamp, session_id,
    error_type, error_message). Auto-trims to the last 1000 lines. Useful
    for headless/CI runs where the operator otherwise can't tell why
    Claude stopped responding.
  - `PreCompact` (v2.1.105+) → `precompact-reinject-overlay.sh` reads the
    cached `${CLAUDE_PLUGIN_DATA}/overlay.json` and emits
    `hookSpecificOutput.additionalContext` so the active overlay name,
    root, and `thin-manifests` flag survive context compaction without
    re-running `detect-overlay.sh`. No-op when the cache is missing or
    `jq` is unavailable.
- `monitors/monitors.json` (v2.1.105) declaring two background monitors:
  - `portage-elog` — tails `/var/log/portage/elog/summary.log` while
    `ebuild-create` is active.
  - `pkgcheck-watch` — periodic `pkgcheck scan --keywords=error` against the
    cached overlay during `overlay-clean` runs.
- `output-styles/qa-report.md` — deterministic severity-prefixed format for
  QA reports (so CI/grep can parse them).
- `bin/` wrappers (auto-PATH via Claude Code v2.1.90+):
  - `gentoo-overlay-detect`, `gentoo-ebuild-lint`, `gentoo-overlay-cache`.
- `scripts/`:
  - `detect-overlay.sh`, `quick-lint.sh`, `manifest-reminder.sh`,
    `manifest-stale-check.sh`, `safety-rm-check.sh`, `cache-overlay.sh`,
    `monitor-elog.sh`, `monitor-pkgcheck.sh`.
  - `render-template.sh` — substitutes `@@VAR@@` placeholders; reads
    `CLAUDE_PLUGIN_OPTION_<KEY>` (the documented spec-current prefix); wired
    into the `ebuild-creator` agent protocol so all generated ebuilds get
    consistent header/maintainer substitution.
  - `plugin-data-dir.sh` — resolves `${CLAUDE_PLUGIN_DATA}` and creates the
    directory; use this for any future cache or persistent state.
  - `scheduled-pkgcheck.sh` — wireable into Claude Code's `/schedule` skill
    (e.g. daily at 09:00). Runs `pkgcheck scan --keywords=warning` against
    the cached overlay and appends to
    `${CLAUDE_PLUGIN_DATA}/pkgcheck-daily.log` (auto-trimmed to 5000 lines).
    No-ops gracefully without `pkgcheck` or overlay cache.
- 11 ebuild templates in `assets/templates/` (CMake, Meson, Autotools, Cargo,
  Go, Python, `.deb`, AppImage, binary direct, live+snapshot, GStreamer plugin)
  plus `metadata.xml`.
- 2 overlay profiles in `assets/profiles/` (`bentoo`, `default`).
- 4 reference docs in `references/` (`gotchas.md`, `eclass-guide.md`,
  `dependency-syntax.md`, `language-ecosystems.md`); `gotchas.md` is preloaded
  via the `bentoo-dev:gotchas` skill, the others are lazy-loaded by the
  agents that need them.
- Evals in `evals/evals.json` (17 cases) covering both skill outputs and
  deterministic hook behaviour: `safety-rm-check` deny/ask paths,
  `manifest-stale-check` block + thin-manifests skip, `session-title` rename,
  `ebuild-creator-validate` block on incomplete package, and
  `manifest-failure-diagnose` network classification. Trigger negatives in
  `evals/trigger-queries.json` (5 sets + global negatives).
- `.github/workflows/validate.yml` — runs `claude plugin validate` on every PR.
- `.github/workflows/release.yml` — on `v*.*.*` tags, validates and runs
  `claude plugin tag` (v2.1.118+) to publish the release to marketplaces.
- README: minimum-Claude-Code-versions matrix per feature; expanded hook
  table with all entries; section "permissionDecision: ask vs defer"
  clarifying the interactive vs headless semantics.
- `LICENSE` (MIT), `README.md`, `.gitignore` (excludes `.epic/`,
  `.claude/settings.local.json`).

### Notes

- **Persistent state convention**: any caching (overlay detection, pkgcheck
  snapshots, vendor tarballs, distfile metadata) MUST be written to
  `${CLAUDE_PLUGIN_DATA}` — never `${CLAUDE_PLUGIN_ROOT}`, which is wiped on
  every plugin update. Use `scripts/plugin-data-dir.sh` to resolve and create
  the path. The overlay cache (`overlay.json`) is the canonical example.
- Loadable via `claude --plugin-dir ./bentoo-dev` for local iteration.
- Recommended CI gate (now wired): `claude plugin validate` on every PR.
- `--bare` flag (Claude Code v2.1.81+) skips plugin loading entirely (along
  with hooks, skills, MCP, CLAUDE.md). It is therefore incompatible with
  `--plugin-dir` for invoking `/bentoo-dev:*` commands. For locked-down CI
  use `--permission-mode dontAsk` plus an explicit `--allowedTools` allowlist.
- The `bentoo-dev:gotchas` skill omits `disable-model-invocation: true` so the
  10 critical gotchas reach sub-agents declared via `skills:` frontmatter.
  Per Claude Code v2.1.x docs (`/en/sub-agents#preload-skills-into-subagents`),
  skills with `disable-model-invocation: true` are silently skipped when
  preloaded that way. `user-invocable: false` is retained so the skill stays
  out of the user `/` menu.
- `FileChanged` (v2.1.83) is intentionally not used: per
  `/en/hooks-reference` it accepts literal pipe-separated filenames, not
  globs, so coverage of shell-driven `.ebuild` edits is delivered via
  `PostToolUse` `Bash` matchers with `if:` filters instead.
