# Reference: qa

Operational detail for the `qa` intent (read-only ebuild validation) of the `bentoo` skill.

## Sub-agent

`qa-checker`

## Payload to sub-agent

Invoke `qa-checker` through the `Agent` tool with:

1. **Targets**: ebuild paths or a package directory (`<category/package>`)
2. **Run pkgcheck?**: `yes` by default when `pkgcheck` is on `PATH`
2b. **Overlay verification scripts**: the list of `check-*.sh` / `*-parity.sh`
   reported by the overlay context (when present) — the sub-agent must run them
3. **Output format**: structured `[ERROR|WARNING|INFO]` plus a closing summary

## Required arguments

Before delegating, make sure you have:
- `<target>`: an ebuild path, a package directory, or `--all` for the whole overlay

If the user does not specify, ask whether this is a single package or the whole overlay.

## Notes

- **Read-only**: never modify a file during this intent.
- The seven mechanical checks (EAPI, copyright header, copyright year,
  `eapply_user`, empty KEYWORDS on 9999, SLOT, LICENSE) come from
  `scripts/quick-lint.sh --json` in **a single batch call** — the sub-agent must
  not reproduce them by reading each ebuild with the model.
- The `qa-checker` sub-agent is configured in `agents/qa-checker.md` and can run
  on a lighter model (haiku) when desired.

## Post-action

Present to the user:
- The structured finding list, grouped by severity
- Summary count: `N error(s), N warning(s), N info — PASS|FAIL`
- When `pkgcheck` is unavailable, suggest `emerge dev-util/pkgcheck`
