# Reference: edit

Operational detail for the `edit` intent (surgical change to an existing ebuild) of the `bentoo` skill.

## Sub-agent

`ebuild-editor`

## Payload to sub-agent

Invoke `ebuild-editor` through the `Agent` tool with:

1. **Task**: a precise description of the change (`add USE flag X`, `add patch Y`, `fix dep Z`, `bump dep min version`, `add src_install hook`, and so on)
2. **Target ebuild**: absolute path of the ebuild to modify
3. **Profile content**: the profile markdown loaded by the skill
4. **Reference loading hints**: point the sub-agent at the plugin reference it should consult:
   - `${CLAUDE_PLUGIN_ROOT}/references/eclass-guide.md` → choosing or switching an eclass
   - `${CLAUDE_PLUGIN_ROOT}/references/dependency-syntax.md` → USE-conditional blocks, REQUIRED_USE, slot deps
   - `${CLAUDE_PLUGIN_ROOT}/references/language-ecosystems.md` → Go/Rust/Java/Python/Ruby/Perl/Electron

## Required arguments

Before delegating, make sure you have:
- `<target ebuild>` (a path or `<category/package>`)
- A clear description of the change

If the change involves a patch file, confirm the patch's path and content before delegating.

## Post-action

1. Verify cross-file consistency: IUSE ↔ deps ↔ metadata.xml ↔ phase functions.
2. If `SRC_URI` changed → confirm the Manifest was regenerated.
3. Present a summarised diff to the user.
4. If `pkgcheck` is available, suggest running the `qa` intent next.
