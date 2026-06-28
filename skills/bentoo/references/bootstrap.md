# Reference: bootstrap

Detalhes operacionais para a intenção `bootstrap` (criar um overlay Gentoo novo do zero) da skill `bentoo`.

## Sub-agent

`overlay-maintainer`

## O que um overlay mínimo precisa

```
<overlay>/
├── metadata/
│   └── layout.conf          # masters, thin-manifests, manifest-hashes, sign-manifests
├── profiles/
│   ├── repo_name            # nome único do repositório (uma linha)
│   ├── categories           # uma categoria por linha (ex.: dev-libs)
│   └── eapi                 # opcional: EAPI default dos profiles (ex.: 8)
└── <category>/<package>/    # ebuilds vêm depois (intenção `create`)
```

### `metadata/layout.conf` recomendado

```
masters = gentoo
thin-manifests = true
sign-manifests = false
manifest-hashes = BLAKE2B SHA512
manifest-required-hashes = BLAKE2B SHA512
cache-formats = md5-dict
```

- `masters` lista os repos herdados (no mínimo `gentoo`; some overlays mastram outros, ex. `gentoo guru`).
- `thin-manifests = true` é o padrão moderno para overlays (Manifest só com entradas DIST).
- `manifest-hashes` segue GLEP 84 (BLAKE2B + SHA512).

### `profiles/repo_name`

Uma linha com o nome do repositório (sem espaços), ex.: `myoverlay`. Deve ser único.

### `profiles/categories`

Uma categoria por linha. Só liste categorias que o overlay realmente usa.

## Payload to sub-agent

Invoque `overlay-maintainer` via tool `Agent` com:

1. **Task**: `bootstrap`
2. **Overlay path**: diretório raiz onde criar a estrutura (confirme que está vazio ou não é já um overlay)
3. **Repo name**: nome desejado (`profiles/repo_name`)
4. **Masters**: lista de masters (default `gentoo`)
5. **Manifest mode**: `thin` (default) ou `thick`
6. **Profile content**: o markdown do profile carregado pela skill

## Required arguments

- Caminho do overlay novo
- Nome do repositório

Se faltarem, pergunte ao usuário antes de delegar. Confirme que o caminho não contém já um `metadata/layout.conf` (não sobrescreva um overlay existente).

## Post-action

1. Listar os arquivos criados (paths absolutos).
2. Sugerir registrar o overlay localmente com `eselect repository` ou um `repos.conf` entry.
3. Sugerir a intenção `create` para adicionar o primeiro pacote.

## Referências canônicas

- https://wiki.gentoo.org/wiki/Creating_an_ebuild_repository
- https://wiki.gentoo.org/wiki/Repository_format/metadata/layout.conf
- https://wiki.gentoo.org/wiki/Repository_format/profiles
