#!/usr/bin/env bats
# Tests for scripts/lib/i18n.sh and the one hook that uses it.
#
#   bats tests/i18n.bats

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # Start every test from a known locale environment.
    unset LANGUAGE LC_ALL LC_MESSAGES LANG
    # shellcheck source=scripts/lib/i18n.sh
    . "$ROOT/scripts/lib/i18n.sh"
}

# Sorted IDs of one catalog, one per line.
catalog_ids() {
    local -n _c="I18N_$1"
    printf '%s\n' "${!_c[@]}" | sort
}

# Sorted unique {placeholder} names of one message.
placeholders() {
    grep -oE '\{[a-z_]+\}' <<<"$1" | sort -u || true
}

@test "every catalog has exactly the English IDs" {
    local lang expected
    expected=$(catalog_ids en)
    [ -n "$expected" ]
    for lang in "${I18N_LANGS[@]}"; do
        run catalog_ids "$lang"
        [ "$status" -eq 0 ]
        if [ "$output" != "$expected" ]; then
            echo "catalog $lang differs from en:"
            diff <(echo "$expected") <(echo "$output") || true
            return 1
        fi
    done
}

@test "no catalog entry is empty" {
    local lang id
    for lang in "${I18N_LANGS[@]}"; do
        local -n c="I18N_$lang"
        for id in "${!c[@]}"; do
            [ -n "${c[$id]}" ] || { echo "$lang/$id is empty"; return 1; }
        done
        unset -n c
    done
}

@test "every translation keeps the English placeholders" {
    local lang id
    for id in "${!I18N_en[@]}"; do
        local want
        want=$(placeholders "${I18N_en[$id]}")
        for lang in "${I18N_LANGS[@]}"; do
            local -n c="I18N_$lang"
            local got
            got=$(placeholders "${c[$id]}")
            unset -n c
            [ "$got" = "$want" ] || { echo "$lang/$id: placeholders '$got' != '$want'"; return 1; }
        done
    done
}

@test "locale selection maps common tags to catalogs" {
    local spec tag want
    for spec in \
        "pt_BR.UTF-8 pt_BR" "pt_PT.UTF-8 pt_BR" "pt-BR pt_BR" "pt pt_BR" \
        "es_ES.UTF-8 es" "es_MX es" "es es" \
        "ru_RU.UTF-8 ru" "ru_UA@euro ru" \
        "zh_CN.UTF-8 zh_CN" "zh_SG zh_CN" "zh-Hans zh_CN" \
        "en_US.UTF-8 en" "en_GB en"; do
        tag="${spec% *}"; want="${spec#* }"
        LANG="$tag" run i18n_lang
        [ "$output" = "$want" ] || { echo "LANG=$tag -> '$output', want '$want'"; return 1; }
    done
}

@test "precedence: LC_ALL over LC_MESSAGES over LANG" {
    LANG=es_ES.UTF-8 LC_MESSAGES=ru_RU.UTF-8 run i18n_lang
    [ "$output" = "ru" ]
    LANG=es_ES.UTF-8 LC_MESSAGES=ru_RU.UTF-8 LC_ALL=zh_CN.UTF-8 run i18n_lang
    [ "$output" = "zh_CN" ]
}

@test "LANGUAGE list is tried first, skipping languages without a catalog" {
    LANG=en_US.UTF-8 LANGUAGE=de:fr:ru:es run i18n_lang
    [ "$output" = "ru" ]
}

@test "LANGUAGE is ignored under the C and POSIX locales, as in gettext" {
    LANG=C LANGUAGE=ru run i18n_lang
    [ "$output" = "en" ]
    LC_ALL=POSIX LANG=ru_RU.UTF-8 LANGUAGE=ru run i18n_lang
    [ "$output" = "en" ]
    LANG=C.UTF-8 LANGUAGE=ru run i18n_lang
    [ "$output" = "en" ]
}

@test "English fallback: no locale, unknown locale, Traditional Chinese" {
    run i18n_lang
    [ "$output" = "en" ]
    LANG=de_DE.UTF-8 run i18n_lang
    [ "$output" = "en" ]
    LANG=zh_TW.UTF-8 run i18n_lang
    [ "$output" = "en" ]
    LANG=de_DE.UTF-8 run i18n_msg rm.ask.recursive
    [ "$output" = "${I18N_en[rm.ask.recursive]}" ]
}

@test "an ID missing from a catalog falls back to English, an unknown ID to itself" {
    unset 'I18N_ru[rm.ask.recursive]'
    LANG=ru_RU.UTF-8 run i18n_msg rm.ask.recursive
    [ "$output" = "${I18N_en[rm.ask.recursive]}" ]
    LANG=ru_RU.UTF-8 run i18n_msg no.such.id
    [ "$output" = "no.such.id" ]
}

@test "i18n_msg substitutes every placeholder, in every language" {
    local lang
    for lang in "${I18N_LANGS[@]}"; do
        local want="${lang}"
        [ "$lang" = en ] && want=en_US
        LANG="${want}.UTF-8" run i18n_msg rm.ask.orphan_dist \
            target="/o/cat/pkg/pkg-1.0.ebuild" manifest="/o/cat/pkg/Manifest"
        [ "$status" -eq 0 ]
        [[ "$output" == *"/o/cat/pkg/pkg-1.0.ebuild"* ]] || { echo "$lang: target missing: $output"; return 1; }
        [[ "$output" == *"/o/cat/pkg/Manifest"* ]]       || { echo "$lang: manifest missing: $output"; return 1; }
        [[ "$output" != *"{"* ]]                          || { echo "$lang: placeholder left: $output"; return 1; }
    done
}

@test "a value containing & or a slash is inserted literally" {
    LANG=en_US.UTF-8 run i18n_msg rm.ask.orphan_dist target='a&b/c d' manifest='M'
    [ "$output" = "a&b/c d removal would orphan DIST entries in M — confirm rm + manifest regenerate" ]
}

# --- safety-rm-check.sh: ask is localized, deny stays English ---------------

# The fixture lives outside BATS_TEST_TMPDIR on purpose: that path contains
# "bats-run-", and safety-rm-check.sh's recursive-rm heuristic
# (`-[a-zA-Z]*[rR]` anywhere in the command) matches any "-r" in a path, which
# would add an unrelated `ask` reason to every case. mktemp's suffix is
# alphanumeric, so this path has no dash.
make_pkg() {
    FIXTURE=$(mktemp -d /tmp/bentoodevi18n.XXXXXX)
    PKG="$FIXTURE/cat/pkg"
    mkdir -p "$PKG"
    : > "$PKG/pkg-1.0.ebuild"
}

teardown() {
    if [[ -n "${FIXTURE:-}" && "$FIXTURE" == /tmp/bentoodevi18n.* ]]; then
        rm -rf -- "$FIXTURE"
    fi
}

rm_payload() {
    jq -n --arg c "$1" '{hook_event_name:"PreToolUse", tool_input:{command:$c}}'
}

@test "safety-rm-check: ask reason follows the locale" {
    command -v jq >/dev/null || skip "jq not installed"
    make_pkg
    : > "$PKG/pkg-2.0.ebuild"
    echo "DIST pkg-1.0.tar.gz 1 BLAKE2B x SHA512 y" > "$PKG/Manifest"

    run env LANG=pt_BR.UTF-8 bash "$ROOT/scripts/safety-rm-check.sh" \
        < <(rm_payload "rm $PKG/pkg-1.0.ebuild")
    [ "$status" -eq 0 ]
    [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = "ask" ]
    reason=$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$output")
    want="${I18N_pt_BR[rm.ask.orphan_dist]}"
    want="${want//\{target\}/"$PKG/pkg-1.0.ebuild"}"
    want="${want//\{manifest\}/"$PKG/Manifest"}"
    [ "$reason" = "$want" ]

    run env LANG=C bash "$ROOT/scripts/safety-rm-check.sh" \
        < <(rm_payload "rm $PKG/pkg-1.0.ebuild")
    reason=$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$output")
    [[ "$reason" == *"would orphan DIST entries in $PKG/Manifest"* ]]
}

@test "safety-rm-check: deny reason stays English under any locale" {
    command -v jq >/dev/null || skip "jq not installed"
    make_pkg
    run env LANG=ru_RU.UTF-8 LANGUAGE=ru bash "$ROOT/scripts/safety-rm-check.sh" \
        < <(rm_payload "rm $PKG/pkg-1.0.ebuild")
    [ "$status" -eq 0 ]
    [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = "deny" ]
    reason=$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$output")
    [[ "$reason" == *"is the only .ebuild in $PKG"* ]]
}

@test "safety-rm-check: recursive rm prompt is localized" {
    command -v jq >/dev/null || skip "jq not installed"
    make_pkg
    # Two ebuilds and no Manifest: the glob expands to files that are neither
    # the last ebuild (deny) nor tied to a DIST entry, leaving only the
    # recursive-rm reason.
    : > "$PKG/pkg-2.0.ebuild"
    run env LANG=zh_CN.UTF-8 bash "$ROOT/scripts/safety-rm-check.sh" \
        < <(rm_payload "rm -r $PKG/*.ebuild")
    [ "$status" -eq 0 ]
    [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = "ask" ]
    reason=$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$output")
    [ "$reason" = "${I18N_zh_CN[rm.ask.recursive]}" ]
}
