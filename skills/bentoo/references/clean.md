# Reference: clean

Operational detail for the `clean` intent (overlay maintenance) of the `bentoo` skill.

## Sub-agent

`overlay-maintainer`

## Modes

- `clean`: remove obsolete versions (preserves live ebuilds and the newest version; never empties a directory).
- `refresh-manifests`: regenerate stale Manifests in batch. With `pkgdev manifest`,
  **always pass an explicit target** — with no target it rewrites the whole overlay.
- `refresh-cache`: regenerate `metadata/md5-cache` per package via `egencache`
  (only when the overlay keeps that directory); drops orphan entries left behind
  by earlier bumps.
- `full-audit`: detect problems (obsolete versions, stale Manifests, missing metadata.xml, orphan DIST entries) and apply fixes.
- `news`: create or edit a GLEP 42 news item under `metadata/news/YYYY-MM-DD-slug/` from the template at `${CLAUDE_PLUGIN_ROOT}/assets/templates/news-item.txt` (`Title/Author/Posted/Revision/News-Item-Format` headers plus `Display-If-*` conditions).
- `updates`: record package renames and moves in `profiles/updates/<Qn-YYYY>` (`move <old> <new>`, `slotmove <atom> <old> <new>`).
- `mask`: add or edit entries in `profiles/package.mask` (a comment carrying author, date and reason above the atom is mandatory).

> For the `mask` and `full-audit` modes, load `package.mask` verbatim with
> `bash ${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh --full`. It is **not**
> part of the skill's default context — those are ~15 KB the other modes never use.

## Payload to sub-agent

Invoke `overlay-maintainer` through the `Agent` tool with:

1. **Task**: `clean` | `refresh-manifests` | `refresh-cache` | `full-audit` | `news` | `updates` | `mask`
2. **Scope**: a single package `<category/package>`, or `--all` (whole overlay)
3. **Profile content**: the profile markdown loaded by the skill
4. **Safety flags**:
   - **NEVER** remove live ebuilds (`*-9999.ebuild`)
   - **NEVER** empty a package directory (always keep the newest version)
   - State explicitly that confirmation was already obtained, so the sub-agent
     does not try to ask for it. It cannot: confirmation is the router's job
     (see below), and the sub-agent has no interactive channel of its own.

## Required arguments

Before delegating, make sure you have:
- `<scope>`: a specific `<category/package>` or `--all`
- The intended mode (if ambiguous, ask: "prune old versions, regenerate manifests, or a full audit?")

When the scope is `--all` and the mode is `clean`, ask the user for explicit
confirmation **before delegating** — that is a destructive action at scale, and
this is the only point in the flow where a question can be asked. The router
runs inline and can prompt; the sub-agent runs in its own context and cannot.
Never delegate a destructive `--all` on the assumption that the sub-agent will
check with the user.

## Post-action

Report to the user:
- Packages scanned / removed / Manifest regenerated / metadata created
- Orphan md5-cache entries before and after (or "the overlay keeps no md5-cache")
- Failures (network errors during manifest fetch, and so on)
- Final overlay state
