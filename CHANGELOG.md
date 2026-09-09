# Changelog

All notable changes to the `bentoo-dev` plugin are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_No changes yet._

## [0.3.0] — 2026-09-09

Context-budget and hook-correctness release. The skill now injects a bounded
overlay summary instead of a verbatim dump, three silent hook defects are fixed,
and the shipped `bentoo` profile is realigned with the overlay's own
`CLAUDE.md`. All prose in the skill is now English.

### Breaking

- **`ebuild-creator` no longer runs under `isolation: worktree`.** It writes
  directly into the target overlay. A worktree branches from the repository's
  *default branch*, not the session HEAD, and never auto-merges — so the
  generated ebuild landed in a throwaway checkout instead of the overlay.
- **`overlay-maintainer` no longer declares `background: true`.** A background
  subagent loses `AskUserQuestion`, which the `--all` destructive-scope
  confirmation depended on. Confirmation moved to the inline router.
- **`scripts/scheduled-pkgcheck.sh` was removed.** The `pkgcheck-watch` monitor
  is the single pkgcheck path and absorbed its persistent log.
- **`detect-overlay.sh` defaults to `--summary`.** It previously dumped
  `metadata/layout.conf` and `profiles/package.mask` verbatim. Anything parsing
  the old output — including via `bin/gentoo-overlay-detect` — must pass
  `--full` to get it back.
- **Missing `SLOT` or `LICENSE` is now an error, not a warning**, per PMS (SLOT
  has no implicit default in EAPI 8). A pipeline treating `quick-lint.sh` as a
  gate will start failing ebuilds that previously passed. `LICENSE` is exempt
  for `virtual/*`, `acct-user/*` and `acct-group/*`, which install no files.

### Added

- Persistent `${CLAUDE_PLUGIN_DATA}/pkgcheck.log` written by the
  `pkgcheck-watch` monitor; tune the interval with
  `BENTOO_DEV_PKGCHECK_INTERVAL`.
- `experimental.cacheTtl: 1h` on `ebuild-creator` and `overlay-maintainer`.
- `scripts/overlay-context.sh` — serves the cached overlay summary to the skill,
  with `--full` for the verbatim `layout.conf` + `package.mask` dump that only
  the `clean` / `mask` intents need.
- `scripts/lib/hook-common.sh` — shared hook payload/target resolution.
- `quick-lint.sh --json` — batch report consumed by `qa-checker` so the seven
  mechanical checks cost no tokens. Adds a copyright-year warning.
- `egencache` handling: a bump step in `ebuild-bumper` and a `refresh-cache`
  mode in `overlay-maintainer`, for overlays that keep a `metadata/md5-cache`.
- `qa-checker` runs the overlay's own `check-*.sh` / `*-parity.sh` scripts when
  present — they catch failures that pass `pkgcheck` and merge cleanly.
- `bootstrap` eval and trigger-query coverage; seven hook evals for the
  behaviours fixed here.

### Changed

- The overlay summary gained `profile-formats`, `eapis-banned`,
  `eapis-deprecated` and the overlay's verification-script list;
  `detect-overlay.sh` now reads `profiles/eapi`, which is authoritative over
  `profile-eapi-when-unspecified`.
- `assets/profiles/bentoo.md` rewritten from the overlay's `CLAUDE.md`: the
  OpenRC-for-every-daemon rule, the inverted mask/unmask atom semantics under
  `profile-repo-deps`, `~arm64` as the default rather than the exception,
  `pkgdev manifest` requiring an explicit target, and the working rules
  (checkout is not what Portage reads; no sudo; one worktree per session).
- `bootstrap.md` no longer treats `profiles/categories` as mandatory.
- The `bentoo` skill and its six intent references are in English. Portuguese
  trigger phrases are retained as match strings, labelled `PT triggers:`, with
  English equivalents added where they were missing.
- **All 19 hook commands use exec form (`"args": []`)** — spawned directly with
  no shell, so a plugin path containing a space cannot break them. The reference
  requires shell-form paths to be double-quoted, which none were. Monitor
  commands remain shell-form and are now quoted.
- Every hook declares a `statusMessage`.
- README: overall version target corrected to **v2.1.259+**. It claimed
  v2.1.119+ while its own table listed a v2.1.163 feature, and v2.1.259 fixed
  `if:` conditions firing on unrelated Bash commands — six hooks depend on those.
- README: the checkpointing caveat now covers both halves. Rewind tracks neither
  Bash-modified files **nor subagent edits**, and every write in this plugin
  happens inside a subagent, so `/rewind` is not a safety net for overlay work.
- README: documented the eight-block `Stop` cap and
  `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`.
- Router `effort` lowered from `high` to `medium` — it classifies and delegates;
  the sub-agents declare their own.

### Fixed

- **The six `PostToolUse` hooks matched on `Bash(cp|mv|sed)` were silent
  no-ops.** They read `tool_input.file_path`, which a Bash payload never
  carries. The `ebuild-bumper` flow — whose Step 2 is `cp old.ebuild
  new.ebuild` — therefore ran with no lint and no Manifest reminder.
- **`eapply_user` was checked with a file-wide grep**, so any
  `--enable-default-foo` elsewhere in the ebuild satisfied it. Now scoped to the
  `src_prepare()` body.
- **`ebuild-creator-validate.sh` reported "validation passed" for zero packages
  examined.** It now distinguishes blocked / passed / inconclusive, and searches
  the subagent's cwd as well as the cached overlay root — `ebuild-creator`
  declares `isolation: worktree`, so its files never land in the cached root.
- `evals/*.json` referenced five skills removed in the v0.2.0 consolidation.
- README undercounted the intents (five, not six) and the hook events (5, not
  11), and its hooks table omitted `StopFailure` and `PreCompact`.

### Performance

| | Before | After |
|---|---:|---:|
| Context injected per skill invocation | 16,987 B | 1,387 B (−92%) |
| `Stop` hook, per turn (375-ebuild overlay) | 992 ms | 174 ms (−82%) |

Measured against `/var/db/repos/bentoo`. Stop-hook output verified identical to
the previous implementation on the real overlay and on thick/thin fixtures.

## [0.2.0] — 2026-06-28

Overlay-agnostic generalization, EAPI 9 support, and bug fixes. The plugin now
targets **any** active Gentoo overlay; conventions are derived from the detected
overlay's `metadata/layout.conf`, not its name.

### Fixed

- **Broken monitors.** `monitors/monitors.json` used `on-skill-invoke:ebuild-create`
  / `overlay-clean`, skills removed in the v0.1.2 consolidation — both never
  fired. Now target `on-skill-invoke:bentoo`, and are declared under
  `experimental.monitors` in the manifest.
- **`session-title.sh`** matched slash-commands removed in v0.1.2; rewritten for
  the single `bentoo` router.
- **`binary-appimage.ebuild`** reassigned `S=` inside `src_unpack` (no effect in
  EAPI 8); `S` is now global (`squashfs-root`) with a correct install/symlink.
- **`@@KEYWORDS@@` was a phantom** — mapped by `render-template.sh` but absent
  from every template, so `default_keywords` was silently ignored. Added to all
  templates.
- **`source-go.ebuild`** recommended the deprecated `EGO_SUM` (fatal QA notice)
  and used `== 9999` (exact) instead of `== *9999*`.
- **`metadata.xml`** left a literal `@@MAINTAINER_NAME@@` when the name was
  unset (invalid against the DTD); the renderer now drops the optional `<name>`.
- `source-python` dropped a redundant `test? ( … )` conflicting with
  `distutils_enable_tests`; cmake/meson renamed `EGIT_COMMIT` → `GIT_COMMIT` in
  the non-git-r3 branch; `binary-direct` `${A[0]}` → `${A}`.

### Changed (generalization)

- **`gstreamer-plugin.ebuild`** dropped the bentoo-only custom `gstreamer-meson`
  eclass for the official `gstreamer` eclass.
- **Overlay detection** (`detect-overlay.sh` / `cache-overlay.sh`) derives and
  caches `masters`, `thin-manifests`, `sign-manifests`, `manifest-hashes` from
  `layout.conf`; profile selection in `SKILL.md` is metadata-driven; `ls`/`cat`
  parsing replaced with globs. Cross-overlay `masters` are honoured.
- **References**: `cargo` no longer inherits the legacy `rust-toolchain`;
  EGO_SUM removed as a recommendation.
- **`ebuild-creator`** dropped redundant `disallowedTools: WebFetch` and the
  false "template enforces empty KEYWORDS" claim; honours the router-provided
  template (single source of template selection).

### Added

- **EAPI 9 support** (Council-approved 2025-12-14): templates render `EAPI=8`
  by default and accept `EAPI=9`; new `references/eapi9-migration.md`.
- **GLEP 68 metadata.xml**: `stabilize-allarches`, rich `<upstream>`
  (`bugs-to`/`doc`/`changelog`/`maintainer`), `longdescription`, `remote-id`
  type list.
- **GLEP 84 hash validation** in `qa-checker` (BLAKE2B+SHA512; flag deprecated
  hashes); SLOT is now an ERROR when missing (mandatory in EAPI 8+).
- **New `bootstrap` intent** (6th) to create an overlay from scratch
  (`profiles/repo_name`, `profiles/categories`, `metadata/layout.conf`);
  `references/bootstrap.md`.
- **`clean` intent** extended with `news` (GLEP 42), `updates`
  (pkgmove/slotmove), and `mask` modes.
- **New templates**: `source-pypi`, `virtual`, `acct-user`, `acct-group`, plus
  a GLEP 42 `news-item.txt`.
- **New references**: `eapi9-migration.md`, `keywords-arches.md`; expanded
  `eclass-guide.md` (`pypi`, `acct-user/group`, `udev`, `systemd`, `tmpfiles`,
  `fcaps`, `font`, `dist-kernel`, `xdg` vs `desktop`).
- **Hardening**: `safety-rm-check.sh` matches DIST versions as fixed strings,
  escalates recursive/globbed rm to `ask`, and documents its fail-open nature
  (README "Hardening rm"); `manifest-stale-check.sh` / `ebuild-creator-validate.sh`
  prune `.git` and the latter emits `additionalContext` on success (v2.1.163+).
- **Manifest**: `$schema`, `displayName`. **CI**: actions pinned by commit SHA,
  ShellCheck step, `claude plugin validate --strict`.
- **README**: overlay-agnostic note, "Hardening rm", checkpointing caveat,
  scheduling guidance for `scheduled-pkgcheck.sh`.

## [0.1.3] — 2026-04-28

### Added

- **Canonical Gentoo documentation index.** New `references/external-docs.md`
  — a curated, lazy-loaded index of upstream Gentoo documentation organised
  in 13 sections (foundational reading, variables/dependencies/USE flags,
  phase functions / EAPI / PMS, common mistakes, eclasses, Manifest /
  SRC_URI, overlay / repository format, QA tools, live ebuilds and patches,
  cross-compile / multilib, binary packages, GLEPs, and policy / governance).
  Encodes the rule "prefer **devmanual** (normative) over **wiki**
  (descriptive) when both exist; cite **PMS** for cross-package-manager
  behaviour."
- **Sub-agent fallback to canonical docs.** All five sub-agents
  (`ebuild-bumper`, `ebuild-creator`, `ebuild-editor`, `overlay-maintainer`,
  `qa-checker`) now end with a short "Canonical Gentoo Docs" section
  pointing at `${CLAUDE_PLUGIN_ROOT}/references/external-docs.md`. The
  `qa-checker` variant additionally instructs the agent to cite the
  canonical URL in findings rather than paraphrasing PMS / devmanual /
  pkgcheck rationale.
- **Topical reference preambles.** The four embedded references
  (`gotchas.md`, `eclass-guide.md`, `dependency-syntax.md`,
  `language-ecosystems.md`) gained a "Canonical references" block at the
  top with the most relevant upstream URLs for that topic and a pointer to
  the full index.
- **`skills/bentoo/SKILL.md`** now documents the index as the on-demand
  fallback when embedded knowledge is insufficient.

### Notes

- `external-docs.md` is consulted on demand (lazy-loaded) — it is **not**
  preloaded into sub-agent context. Embedded references
  (`gotchas.md`, `eclass-guide.md`, `dependency-syntax.md`,
  `language-ecosystems.md`) remain the primary source; the canonical index
  is a fallback for normative wording, uncommon eclass behaviour, and
  policy citations.

## [0.1.2] — 2026-04-27

### Changed

- **Single-skill API.** The five user-invocable skills (`/bentoo-dev:ebuild-create`,
  `/bentoo-dev:ebuild-bump`, `/bentoo-dev:ebuild-edit`, `/bentoo-dev:ebuild-qa`,
  `/bentoo-dev:overlay-clean`) have been consolidated into a single
  natural-language entry point: **`/bentoo-dev:bentoo "<instruction>"`**.

  The new skill receives a free-form instruction, classifies the intent
  (`create` / `bump` / `edit` / `qa` / `clean`), asks the user when ambiguous,
  loads the matching reference from `skills/bentoo/references/<intent>.md`,
  and delegates to the same five sub-agents that previously backed the
  individual skills (`ebuild-creator`, `ebuild-bumper`, `ebuild-editor`,
  `qa-checker`, `overlay-maintainer`). No sub-agent behavior changed.

  Migration:
  - `/bentoo-dev:ebuild-create dev-libs/foo 1.2.3` →
    `/bentoo-dev:bentoo "create dev-libs/foo 1.2.3 from <upstream>"`
  - `/bentoo-dev:ebuild-bump app-misc/bar 2.1` →
    `/bentoo-dev:bentoo "bump app-misc/bar to 2.1"`
  - `/bentoo-dev:ebuild-edit games-util/baz "add USE flag wayland"` →
    `/bentoo-dev:bentoo "add USE flag wayland to games-util/baz"`
  - `/bentoo-dev:ebuild-qa dev-libs/foo` →
    `/bentoo-dev:bentoo "run QA on dev-libs/foo"`
  - `/bentoo-dev:overlay-clean --all` →
    `/bentoo-dev:bentoo "clean the whole overlay"`

  Auto-trigger by natural-language description still works — saying
  *"bump mesa to 26.0.5"* or *"package XYZ from .deb"* invokes the new
  `bentoo` skill automatically because all triggers from the previous five
  skills were consolidated into its `description` and `when_to_use` fields.

- The internal `gotchas` skill (`user-invocable: false`) is unchanged and
  still preloaded by sub-agents.

### Removed

- `skills/ebuild-create/`, `skills/ebuild-bump/`, `skills/ebuild-edit/`,
  `skills/ebuild-qa/`, `skills/overlay-clean/`.

### Added

- `skills/bentoo/SKILL.md` — natural-language router with intent
  classification and disambiguation prompts.
- `skills/bentoo/references/{create,bump,edit,qa,clean}.md` — operational
  details per intent (loaded on demand via progressive disclosure, per the
  Claude Code skills authoring guidance).

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
