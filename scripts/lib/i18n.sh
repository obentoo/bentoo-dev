#!/usr/bin/env bash
# Message catalogs for the hook text a HUMAN reads. Sourced, never executed.
#
# Scope -- read this before adding an ID. Only text Claude Code shows to the
# user goes through here. Text the model reads stays English and must NOT be
# routed through this file: `additionalContext`, a `deny` reason, a Stop /
# SubagentStop `block` reason, monitor stdout, and the output of `bin/` tools
# (they run on the Bash tool's PATH, so Claude is the reader). Translating a
# prompt makes the model worse at acting on it and helps no user. The current
# human-facing set is the PreToolUse `ask` reason, which Claude Code renders in
# the permission prompt (see the hooks reference, PreToolUse decision control).
#
# Mechanism: plain bash, no gettext. The plugin is installed by a Claude Code
# marketplace, not a package manager, so there is no /usr/share/locale to load
# .mo files from and no guarantee the gettext binaries exist.
#
# Language selection mirrors gettext:
#   1. The locale is the first non-empty of LC_ALL, LC_MESSAGES, LANG.
#   2. A "C" or "POSIX" locale (or none) means English, and LANGUAGE is ignored.
#   3. Otherwise each entry of the colon-separated LANGUAGE list is tried first,
#      then the locale itself. The first one with a catalog wins.
#   4. Nothing matches -> English.
#
# Placeholders are named, `{name}`, so a translation can reorder them; bash
# printf has no positional `%1$s`. Callers pass `name=value` pairs.
#
# Adding a message: add the ID to EVERY catalog below. tests/i18n.bats fails
# when a catalog is missing an ID or drops a placeholder.

# shellcheck disable=SC2034  # the catalogs are read through a nameref

declare -gA I18N_en=(
    [rm.ask.recursive]="recursive or globbed rm near .ebuild files — confirm it will not empty a package directory"
    [rm.ask.orphan_dist]="{target} removal would orphan DIST entries in {manifest} — confirm rm + manifest regenerate"
)

declare -gA I18N_pt_BR=(
    [rm.ask.recursive]="rm recursivo ou com glob perto de arquivos .ebuild — confirme que ele não vai esvaziar um diretório de pacote"
    [rm.ask.orphan_dist]="a remoção de {target} deixaria entradas DIST órfãs em {manifest} — confirme o rm e a regeneração do Manifest"
)

declare -gA I18N_es=(
    [rm.ask.recursive]="rm recursivo o con glob cerca de archivos .ebuild — confirme que no vaciará un directorio de paquete"
    [rm.ask.orphan_dist]="la eliminación de {target} dejaría huérfanas las entradas DIST en {manifest} — confirme el rm y la regeneración del Manifest"
)

declare -gA I18N_ru=(
    [rm.ask.recursive]="рекурсивный rm или rm с glob-шаблоном рядом с файлами .ebuild — убедитесь, что каталог пакета не опустеет"
    [rm.ask.orphan_dist]="удаление {target} оставит осиротевшие записи DIST в {manifest} — подтвердите rm и повторную генерацию Manifest"
)

declare -gA I18N_zh_CN=(
    [rm.ask.recursive]="在 .ebuild 文件附近执行递归或带通配符的 rm — 请确认它不会清空软件包目录"
    [rm.ask.orphan_dist]="删除 {target} 会使 {manifest} 中的 DIST 条目成为孤立条目 — 请确认 rm 并重新生成 Manifest"
)

# Languages that have a catalog, in the order the tests check them.
I18N_LANGS=(en pt_BR es ru zh_CN)

# i18n_catalog_for <locale-or-language-tag>
# Maps one tag (pt_BR.UTF-8, pt-BR, zh_CN@x, ru, en_US ...) to a catalog name.
# Prints nothing when no catalog matches, so the caller tries the next tag.
i18n_catalog_for() {
    local tag="$1"
    tag="${tag%%.*}"   # drop .codeset
    tag="${tag%%@*}"   # drop @modifier
    tag="${tag//-/_}"  # BCP 47 pt-BR -> POSIX pt_BR
    case "$tag" in
        en|en_*)                  printf 'en' ;;
        # Only Brazilian Portuguese has a catalog; it is the closest one for
        # every other Portuguese locale too.
        pt|pt_*)                  printf 'pt_BR' ;;
        es|es_*)                  printf 'es' ;;
        ru|ru_*)                  printf 'ru' ;;
        # Simplified script only. zh_TW / zh_HK use Traditional characters, so
        # they fall through to the next tag (ultimately English).
        zh|zh_CN|zh_SG|zh_Hans*)  printf 'zh_CN' ;;
        *)                        : ;;
    esac
}

# i18n_lang -> prints the catalog name to use for this process.
i18n_lang() {
    local locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" cat tag
    local -a tags=()

    case "$locale" in
        ""|C|C.*|POSIX) printf 'en'; return 0 ;;
    esac

    if [[ -n "${LANGUAGE:-}" ]]; then
        IFS=: read -ra tags <<<"$LANGUAGE"
    fi
    tags+=("$locale")

    for tag in "${tags[@]}"; do
        [[ -n "$tag" ]] || continue
        cat=$(i18n_catalog_for "$tag")
        if [[ -n "$cat" ]]; then
            printf '%s' "$cat"
            return 0
        fi
    done
    printf 'en'
}

# i18n_msg <id> [name=value ...]
# Prints the message for <id> in the selected language, falling back to the
# English text when the catalog lacks the ID, and to the bare ID when English
# lacks it too (a bug, but a visible one rather than an empty prompt).
# Substitution is one pass per name, in argument order.
i18n_msg() {
    local id="$1" lang msg pair name value
    shift
    lang=$(i18n_lang)
    local -n _i18n_cat="I18N_${lang}"
    msg="${_i18n_cat[$id]:-${I18N_en[$id]:-$id}}"
    for pair in "$@"; do
        name="${pair%%=*}"
        value="${pair#*=}"
        msg="${msg//\{${name}\}/"${value}"}"
    done
    printf '%s' "$msg"
}
