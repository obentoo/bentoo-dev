#!/usr/bin/env bash
# Shared helpers for bentoo-dev hook scripts. Sourced, never executed.
#
# Why this exists: Write/Edit hook payloads carry `tool_input.file_path`, but a
# Bash payload only carries `tool_input.command`. Hooks matched on
# `Bash(cp|mv|sed …)` that read only `file_path` silently no-op — which is what
# happened to the ebuild-bumper flow, whose Step 2 is literally
# `cp old.ebuild new.ebuild`. These helpers resolve targets from either shape.

# hook_json_field <payload> <jq-filter> <fallback-key>
# Extracts a string field. Uses jq when available; otherwise falls back to a
# regex that handles the flat, unescaped case only (best effort, as before).
hook_json_field() {
    local payload="$1" filter="$2" key="$3"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$payload" | jq -r "$filter" 2>/dev/null
        return 0
    fi
    printf '%s' "$payload" \
        | grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" \
        | head -1 \
        | sed -E "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/"
}

# hook_event_name <payload> [default]
hook_event_name() {
    local payload="$1" default="${2:-PostToolUse}" ev
    ev=$(hook_json_field "$payload" '.hook_event_name // empty' 'hook_event_name')
    printf '%s' "${ev:-$default}"
}

# hook_ebuild_targets <payload>
# Prints one existing *.ebuild path per line, deduplicated.
#
# LIMITATION: command parsing tokenises on whitespace and cannot resolve
# quoting, `$()`, or globs. It is a guard rail, not a parser — same contract as
# safety-rm-check.sh.
hook_ebuild_targets() {
    local payload="$1" fp cmd tok
    local -a toks=()

    fp=$(hook_json_field "$payload" \
        '.tool_input.file_path // .tool_input.path // .file_path // .path // empty' \
        'file_path')
    if [[ -n "$fp" ]]; then
        [[ "$fp" == *.ebuild && -f "$fp" ]] && printf '%s\n' "$fp"
        return 0
    fi

    cmd=$(hook_json_field "$payload" '.tool_input.command // empty' 'command')
    [[ -z "$cmd" ]] && return 0

    # Only file-shuffling commands can create or alter an ebuild without Write/Edit.
    grep -qE '(^|[[:space:];&|(])(cp|mv|sed|install|tee)([[:space:]]|$)' <<<"$cmd" || return 0

    cmd="${cmd//$'\n'/ }"
    read -ra toks <<<"$cmd"
    for tok in "${toks[@]}"; do
        [[ "$tok" == -* ]] && continue
        tok="${tok%\"}"; tok="${tok#\"}"
        tok="${tok%\'}"; tok="${tok#\'}"
        [[ "$tok" == *.ebuild ]] || continue
        [[ -f "$tok" ]] || continue
        printf '%s\n' "$tok"
    done | awk '!seen[$0]++'
}

# hook_emit_context <event> <message>
hook_emit_context() {
    local event="$1" msg="$2" esc
    if command -v jq >/dev/null 2>&1; then
        jq -Rn --arg e "$event" --arg c "$msg" \
            '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
    else
        esc=${msg//\\/\\\\}
        esc=${esc//\"/\\\"}
        printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
            "$event" "$esc"
    fi
}
