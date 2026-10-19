#!/usr/bin/env bash
# doc-status-guard — PostToolUse hook for Edit and Write.
# A framing document (docs/NAME.md beside a .plugin-plugin/ directory) whose status says
# APPROUVÉ, but whose body no longer matches the fingerprint recorded at its approval, goes
# back to REVUE, and Claude is told so. Inert anywhere else: installed for the account, the
# hook runs in every session.
# Fail-open: it always exits 0; hooks.json sets "onFailure": "continue".

command -v jq >/dev/null 2>&1 || exit 0
# shellcheck source=../../scripts/lib/doc-status.sh
source "${BASH_SOURCE[0]%/*}/../../scripts/lib/doc-status.sh" 2>/dev/null || exit 0
IFS= read -r -d '' input || true
file=$(jq -r 'select(.tool_name == "Edit" or .tool_name == "Write") | .tool_input.file_path // empty | strings' \
  <<<"$input" 2>/dev/null) || exit 0
[[ $file == /*/docs/*.md && -f $file ]] || exit 0
docs=${file%/*}
root=${docs%/*}
[[ ${docs##*/} == docs && -d $root/.plugin-plugin ]] || exit 0
[[ $(doc_status "$file") == APPROUVÉ ]] || exit 0
[[ $(doc_fingerprint "$file") == "$(approved_fingerprint "$root" "docs/${file##*/}")" ]] && exit 0

approved_on=$(grep -m 1 -oE '^\*\*Statut : APPROUVÉ\*\* le [0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" | grep -oE '[0-9-]{10}$')
doc_set_status "$file" "**Statut : REVUE** — approuvé le ${approved_on:-?}, modifié depuis : à réapprouver." || exit 0
jq -nc --arg doc "docs/${file##*/}" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse",
    additionalContext: ("plugin-plugin : \($doc) était approuvé et vient d'\''être modifié ; son statut repasse à REVUE. Le présenter de nouveau pour approbation explicite avant de s'\''en servir.")}}'
exit 0
