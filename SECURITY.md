# Security Policy

bentoo-dev is a Claude Code plugin. Once installed, its hooks, monitors and
`bin/` helpers run as the user on that user's machine, and its sub-agents act
with the tools the plugin grants them. This policy covers that code.

## Scope

**In scope — report it here:**

- A hook, monitor, script or `bin/` helper that runs attacker-controlled input
  as code — for example a crafted ebuild, `Manifest`, `metadata/layout.conf`
  or file name in an overlay that leads to command injection.
- Unsafe file handling: predictable temp files, writes outside the overlay or
  the plugin's data directory, following symlinks into places it should not.
- A way around the `PreToolUse` safety hook (`scripts/safety-rm-check.sh`)
  that lets a destructive command run without the decision it should get.
- A skill or sub-agent definition that grants more tools than its task needs.
- The CI and release workflows in `.github/workflows/`.

**Out of scope — report it elsewhere:**

- Claude Code itself, including how it enforces permissions:
  [Anthropic](https://www.anthropic.com/responsible-disclosure-policy).
- A Gentoo package or Portage: [Gentoo Security](https://security.gentoo.org/).
- A package in the Bentoo overlay: [obentoo/bentoo](https://github.com/obentoo/bentoo).

## Reporting

Use GitHub's private vulnerability reporting:
**[Security → Report a vulnerability](https://github.com/obentoo/bentoo-dev/security/advisories/new)**.

Please do not open a public issue for anything exploitable before a fix is
released. Include the plugin version, the Claude Code version, the steps to
reproduce, and what an attacker gains.

## Supported versions

Only the latest release is supported; fixes are not backported.

## Response

The plugin is maintained on a best-effort basis. Expect an acknowledgment
within 7 days. Once a fix is released, the advisory is published with credit
to the reporter, unless you prefer to stay anonymous.
