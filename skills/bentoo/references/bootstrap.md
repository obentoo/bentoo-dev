# Reference: bootstrap

Operational detail for the `bootstrap` intent (create a new Gentoo overlay from scratch) of the `bentoo` skill.

## Sub-agent

`overlay-maintainer`

## What a minimal overlay needs

```
<overlay>/
├── metadata/
│   └── layout.conf          # masters, thin-manifests, manifest-hashes, sign-manifests
├── profiles/
│   ├── repo_name            # unique repository name (single line) — mandatory
│   ├── categories           # optional: only for NEW categories (not inherited ones)
│   └── eapi                 # optional: default EAPI for the profiles (e.g. 8)
└── <category>/<package>/    # ebuilds come later (the `create` intent)
```

### Recommended `metadata/layout.conf`

```
masters = gentoo
thin-manifests = true
sign-manifests = false
manifest-hashes = BLAKE2B SHA512
manifest-required-hashes = BLAKE2B SHA512
cache-formats = md5-dict
```

- `masters` lists the inherited repos (at least `gentoo`; some overlays master others, e.g. `gentoo guru`).
- `thin-manifests = true` is the modern default for an overlay (the Manifest carries DIST entries only).
- `manifest-hashes` follows GLEP 84 (BLAKE2B + SHA512).

### `profiles/repo_name`

A single line holding the repository name, with no spaces — e.g. `myoverlay`. It must be unique.

### `profiles/categories`

**Optional.** It is only needed for categories the overlay *introduces*; those
that already exist in a master (`gentoo`) are inherited. The `bentoo` overlay
itself, with 54 categories in use, does not have this file. Create it only when
there is a genuinely new category — a file listing inherited categories adds
nothing and becomes one more thing that can drift.

## Payload to sub-agent

Invoke `overlay-maintainer` through the `Agent` tool with:

1. **Task**: `bootstrap`
2. **Overlay path**: root directory to create the structure in (confirm it is empty, or at least not already an overlay)
3. **Repo name**: the desired name (`profiles/repo_name`)
4. **Masters**: the masters list (default `gentoo`)
5. **Manifest mode**: `thin` (default) or `thick`
6. **Profile content**: the profile markdown loaded by the skill

## Required arguments

- Path of the new overlay
- Repository name

If either is missing, ask the user before delegating. Confirm the path does not already hold a `metadata/layout.conf` — never overwrite an existing overlay.

## Post-action

1. List every file created (absolute paths).
2. Suggest registering the overlay locally with `eselect repository` or a `repos.conf` entry.
3. Suggest the `create` intent to add the first package.

## Canonical references

- https://wiki.gentoo.org/wiki/Creating_an_ebuild_repository
- https://wiki.gentoo.org/wiki/Repository_format/metadata/layout.conf
- https://wiki.gentoo.org/wiki/Repository_format/profiles
