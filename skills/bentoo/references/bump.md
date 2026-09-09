# Reference: bump

Operational detail for the `bump` intent (version update of an existing ebuild) of the `bentoo` skill.

## Sub-agent

`ebuild-bumper`

## Bump mode detection

- **Standard bump**: `<pkg>-<old>` → `<pkg>-<new>` (ordinary semver-style version)
- **Snapshot bump**: `<pkg>-<base>_p<YYYYMMDD>` (updates `GIT_COMMIT` + the date)
- **Live ebuild**: `9999.ebuild` — usually needs no explicit bump; tell the user when this is the case.

## Payload to sub-agent

Invoke `ebuild-bumper` through the `Agent` tool with:

1. **Task**: bump `<category/package>` to version `<new-version>`
2. **Mode**: `standard` | `snapshot` (detect from the `_p<YYYYMMDD>` shape in `<new-version>`)
3. **New commit hash** (snapshot only — ask the user if it was not supplied)
4. **Profile content**: the profile markdown loaded by the skill
5. **Old ebuild path**: absolute path of the previous version's ebuild (the highest version found with `Glob` in the package directory)
6. **Remove old version?**: `yes` / `no` (default: `no`)

## Required arguments

Before delegating, make sure you have:
- `<category/package>` (already present in the overlay)
- `<new-version>`
- For snapshot bumps: `<commit-hash>` + the `YYYYMMDD` date

If the package does not exist, confirm with the user whether this is a `create` rather than a `bump`.

## Post-action

1. Confirm the new ebuild is valid and the Manifest was regenerated.
1b. If the overlay carries `metadata/md5-cache/`, confirm the package's cache was
   regenerated with `egencache ... --repo <repo> <cat>/<pkg>` (explicit target).
   Without it the previous version's entry is orphaned and the litter grows with
   every bump.
2. Report: `old → new`, files created/removed, and any non-obvious change
   (`S=`, `GIT_COMMIT`, `MY_P`, `MY_PV`).
3. If `pkgcheck` is available, suggest running the `qa` intent next.
