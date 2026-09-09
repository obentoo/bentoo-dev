---
name: bentoo
description: >
  Full maintenance of Gentoo ebuilds and overlays behind a single entry point.
  Takes a natural-language instruction, routes it to the right operation
  (create / bump / edit / QA / clean overlay), and asks when it is ambiguous.
when_to_use: >
  Use for ANY operation on Gentoo ebuilds or overlays. Triggers:
  "create ebuild", "new package", "package from source/deb/AppImage/git",
  "bump version", "update package", "bump mesa to 26.0.5", "snapshot bump",
  "new version", "update ebuild", "edit ebuild", "add USE flag",
  "fix dependencies", "add patch", "modify src_install",
  "fix build with gcc-15", "check QA", "validate ebuild", "lint ebuild",
  "pkgcheck", "audit ebuild", "clean overlay", "prune old versions",
  "remove old versions", "regenerate manifests", "refresh manifests",
  "fix overlay health", "create news item", "record pkgmove", "package move",
  "mask a package", "new overlay", "bootstrap overlay", "init repository".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
argument-hint: "<natural-language instruction>"
effort: medium
paths:
  - "**/*.ebuild"
  - "**/metadata.xml"
  - "**/Manifest"
  - "**/files/**"
  - "**/profiles/**"
  - "**/eclass/**"
  - "**/metadata/layout.conf"
---

# bentoo

Single entry point for Gentoo ebuild and overlay work. Takes a natural-language
instruction through `$ARGUMENTS`, classifies the intent, asks the user when it is
ambiguous, loads the reference for that intent, and delegates to the specialised
sub-agent.

## Overlay context (preprocessed)

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh 2>/dev/null || echo "No overlay detected"`

Pick the profile from the **actual conventions of the detected overlay** — the
output above: `masters`, `thin-manifests`, `manifest-hashes`, custom eclasses —
not from its name:

- If `${CLAUDE_PLUGIN_ROOT}/assets/profiles/<detected-name>.md` exists, use it as
  the worked example for that overlay (e.g. `bentoo.md`).
- Otherwise use `${CLAUDE_PLUGIN_ROOT}/assets/profiles/default.md`, which is
  self-contained and follows official Gentoo policy only.

Whatever the overlay's own `layout.conf` / `profiles/` declares always wins over
a convention assumed by an example profile.

The block above is the **bounded summary** (~1.3 KB), served from the session
cache written by `cache-overlay.sh`. The verbatim dump of `layout.conf` +
`profiles/package.mask` (~17 KB on a real overlay) is **not** included: load it
on demand, and only for the `clean` / `mask` intents, with

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh --full
```

If the summary lists **"Overlay verification scripts"**, those belong to the
overlay and catch failures `pkgcheck` lets through — the `qa` intent must run them.

## User input

```
$ARGUMENTS
```

## Step 1 — Classify the intent

Read `$ARGUMENTS` together with the conversation context and settle on ONE of the
six intents below. **If the input is empty**, ask the user what they want to do
and list the six options.

| Intent | When it applies | Sub-agent | Reference |
|--------|-----------------|-----------|-----------|
| `create` | A brand-new package that does not exist in the overlay yet. E.g. "create an ebuild for X", "new package", "package XYZ from source/deb/AppImage/git" | `ebuild-creator` | `references/create.md` |
| `bump`   | Raise the version of an existing ebuild (copy the previous version, update version/commit/SRC_URI). E.g. "bump mesa to 26.0.5", "snapshot bump", "update to the new version" | `ebuild-bumper` | `references/bump.md` |
| `edit`   | A surgical change to an ebuild that already exists, keeping the same version. E.g. "add USE flag", "fix dependencies", "add patch", "fix build with gcc-15", "modify src_install" | `ebuild-editor` | `references/edit.md` |
| `qa`     | Read-only validation of ebuilds. E.g. "validate QA", "lint", "pkgcheck", "audit ebuild" | `qa-checker` | `references/qa.md` |
| `clean`  | Overlay-wide maintenance: prune old versions, regenerate Manifests in batch, create missing metadata.xml, news items (GLEP 42), `profiles/updates`, `package.mask`. E.g. "clean the overlay", "remove old versions", "fix overlay health", "create news", "record pkgmove" | `overlay-maintainer` | `references/clean.md` |
| `bootstrap` | Create a new overlay from scratch (`profiles/repo_name`, `profiles/categories`, `metadata/layout.conf`). E.g. "new overlay", "bootstrap overlay", "init repository" | `overlay-maintainer` | `references/bootstrap.md` |

### Disambiguation rules

When two intents could apply, **ask the user before proceeding**. The common cases:

- **"update foo"** → could be `bump` (raise the version) OR `edit` (fix a build at
  the same version). Ask: *"Update to a new version (bump), or apply a fix while
  keeping the current version (edit)?"*
- **"create a new version"** → could be `create` (a package that does not exist)
  OR `bump` (the next version of an existing one). Check whether the package is
  already in the overlay; if it is, this is `bump`. Ask if it is still ambiguous
  after that check.
- **"fix overlay"** → could be `clean` (batch maintenance) OR `qa` (read-only
  audit). Ask whether the user wants a report only (`qa`) or fixes applied (`clean`).
- **Empty or generic input** ("help with an ebuild", "work on the overlay") → ask
  which of the six operations they mean.

Never invent a missing argument: when the intent is clear but a parameter is
absent (`<category/package>`, `<version>`, a description of the change), ask for
it explicitly.

## Step 2 — Load the reference

Once the intent is classified (and disambiguated if needed), read the matching
file with the `Read` tool:

- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/create.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/bump.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/edit.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/qa.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/clean.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bentoo/references/bootstrap.md`

The reference carries the operational detail, the exact payload to hand the
sub-agent, and the post-execution checks specific to that intent.

## Step 3 — Delegate to the sub-agent

Invoke the sub-agent named in the reference through the `Agent` tool (matching
`subagent_type`). Always pass:

1. The user's original instruction (`$ARGUMENTS`)
2. The profile content (loaded via the overlay context above)
3. Anything else the reference specifies

## Step 4 — Post-execution

Once the sub-agent returns, follow the checks listed in that intent's reference
and present the final result to the user: absolute paths, diff, counts, and a
PASS/FAIL status where applicable.

## Notes

- This skill **runs inline** (do not use `context: fork`) so it can ask the user
  for clarification when the intent is ambiguous.
- The five sub-agents (`ebuild-creator`, `ebuild-bumper`, `ebuild-editor`,
  `qa-checker`, `overlay-maintainer`) already live in `agents/` and do the real
  work — this skill only routes.
- The critical Gentoo gotchas are preloaded into the sub-agents through the
  internal `gotchas` skill; you do not need to load it here.
- Canonical Gentoo docs (PMS, devmanual, wiki, GLEPs) are indexed in
  `${CLAUDE_PLUGIN_ROOT}/references/external-docs.md` — consult it on demand when
  the embedded knowledge is not enough.
