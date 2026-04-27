---
name: qa-report
description: >
  Structured output style for Gentoo ebuild QA reports. Forces the qa-checker
  sub-agent to emit findings in a deterministic format (severity-prefixed
  lines + summary) so downstream tooling and CI can grep/parse the output.
---

# QA Report Output Style

When this output style is active, all stdout from QA workflows (manual lint,
pkgcheck, etc.) MUST follow this exact shape:

## Section 1 — Findings

One line per finding, in this order:

```
[ERROR] <file>: <description>
[WARNING] <file>: <description>
[INFO] <file>: <description>
```

Order findings ERROR → WARNING → INFO. Within a severity, group by file path.

## Section 2 — pkgcheck Output (optional)

If `pkgcheck` ran, include its raw output verbatim under a fenced block:

```
=== pkgcheck output ===
<raw stdout from pkgcheck scan>
```

If pkgcheck was unavailable, emit one line:

```
[INFO] pkgcheck not available — skipping automated scan
```

## Section 3 — Summary

End every report with exactly one line of this shape:

```
Summary: <N> error(s), <N> warning(s), <N> info — <PASS|FAIL>
```

Result is `FAIL` if any `[ERROR]` line was emitted. Otherwise `PASS`.

## Constraints

- No prose preamble. No commentary between findings. No emoji.
- One line per finding — never wrap descriptions across lines.
- Absolute paths preferred when available; otherwise the basename.
- Stable ordering: identical inputs MUST produce byte-identical output (so
  diffs in CI surface real changes only).
