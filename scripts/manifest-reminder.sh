#!/usr/bin/env bash
# PostToolUse hook: reminds Claude (via additionalContext) to regenerate the
# Manifest when an ebuild carrying SRC_URI is written, edited, copied or sed-ed.
#
# Targets are resolved from tool_input.file_path (Write|Edit) OR parsed out of
# tool_input.command (Bash cp|mv|sed). The Bash path matters most: the
# ebuild-bumper creates the new version with `cp old.ebuild new.ebuild`, which
# never produces a file_path — so before this the reminder never fired on the
# one flow that always needs a fresh Manifest.
#
# Emits hookSpecificOutput.additionalContext + exit 0 (canonical for
# non-blocking informational hooks).
set -euo pipefail

# shellcheck source=scripts/lib/hook-common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/hook-common.sh"

if [[ -t 0 ]]; then
    # Manual invocation: treat args as paths.
    PAYLOAD=""
    TARGETS=("$@")
else
    PAYLOAD="$(cat)"
    mapfile -t TARGETS < <(hook_ebuild_targets "$PAYLOAD")
fi

(( ${#TARGETS[@]} == 0 )) && exit 0

EVENT=$(hook_event_name "$PAYLOAD" "PostToolUse")

PKGS=()
CMDS=()
for eb in "${TARGETS[@]}"; do
    [[ -f "$eb" && "$eb" == *.ebuild ]] || continue
    grep -q '^[[:space:]]*SRC_URI' "$eb" 2>/dev/null || continue
    PKGS+=("$(basename -- "$(dirname -- "$eb")")")
    CMDS+=("ebuild ${eb} manifest")
done

(( ${#CMDS[@]} == 0 )) && exit 0

# Deduplicate package names for the human-readable half of the message.
UNIQ_PKGS=$(printf '%s\n' "${PKGS[@]}" | awk '!seen[$0]++' | paste -sd, -)
MSG="[bentoo-dev] Reminder: regenerate Manifest for ${UNIQ_PKGS} — run: $(printf '%s; ' "${CMDS[@]}")"
MSG="${MSG%; }"

hook_emit_context "$EVENT" "$MSG"
exit 0
