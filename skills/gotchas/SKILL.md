---
name: gotchas
description: >
  Reference card with the 10 critical Gentoo ebuild gotchas (eapply_user, || die,
  KEYWORDS for 9999, S=, SRC_URI rename, QA_PREBUILT/RESTRICT, header ordering,
  thin-manifests, default in src_prepare, MY_P/MY_PN). Designed to be preloaded
  by ebuild-* sub-agents via the `skills:` frontmatter so they don't need to
  Read references/gotchas.md every turn.
user-invocable: false
---

```!
cat "${CLAUDE_PLUGIN_ROOT}/references/gotchas.md"
```
