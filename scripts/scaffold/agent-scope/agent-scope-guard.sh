#!/usr/bin/env bash
# agent-scope-guard — PreToolUse hook for Edit, Write, NotebookEdit, Bash and Monitor.
# Holds each agent of __PLUGIN__ to the write folders and the Bash allowlist that
# hooks/agent-scope.json declares for it. Inert for the main session and for any other agent:
# installed for the account, it runs in every session. It assumes no order among hooks.
# Fail-closed: exit 2 with the reason on stderr blocks; for this plugin's agents, an internal
# error blocks too (jq missing, unreadable input or scope); hooks.json sets "onFailure": "block".

PLUGIN=__PLUGIN__
IFS= read -r -d '' input || true
block() {
  echo "agent-scope-guard : $1" >&2
  exit 2
}
if ! command -v jq >/dev/null 2>&1 || ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$input"; then
  # Without a reader, only the raw text tells whose call this is.
  if [[ $input =~ \"agent_type\"[[:space:]]*:[[:space:]]*\"$PLUGIN: ]]; then
    block "jq absent ou entrée illisible ; blocage par précaution."
  fi
  exit 0
fi
agent=$(jq -r '.agent_type // empty' <<<"$input")
[[ $agent == "$PLUGIN:"* ]] || exit 0
scope=$(jq -c --arg agent "$agent" '.[$agent] // empty' "${BASH_SOURCE[0]%/*}/../agent-scope.json" 2>/dev/null) \
  || block "portée illisible : hooks/agent-scope.json."
[[ -n $scope ]] || block "$agent n'a pas de portée déclarée dans hooks/agent-scope.json."

case $(jq -r '.tool_name // empty' <<<"$input") in
  Edit | Write | NotebookEdit)
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
    root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input")}
    [[ -n $root && $path == "$root"/* ]] || block "$agent écrit hors du projet : $path."
    rel=${path#"$root"/}
    [[ /$rel/ != */../* ]] || block "$agent : chemin qui remonte, refusé : $rel."
    while IFS= read -r dir; do
      [[ -n $dir && $rel == "${dir%/}"/* ]] && exit 0
    done < <(jq -r '.write[]?' <<<"$scope")
    block "$agent n'écrit que sous : $(jq -r '.write // [] | if length == 0 then "rien" else join(", ") end' <<<"$scope") ; refusé : $rel."
    ;;
  Bash | Monitor)
    command=$(jq -r '.tool_input.command // empty' <<<"$input")
    # A Monitor call without a command watches a socket, and runs nothing.
    [[ -n $command || $(jq -r .tool_name <<<"$input") == Bash ]] || exit 0
    if [[ $command == *[\;\&\|\`\$\<\>\(\)]* || $command == *$'\n'* ]]; then
      block "$agent : commande composée, redirigée ou substituée, refusée : $command."
    fi
    while IFS= read -r allowed; do
      [[ -n $allowed && ($command == "$allowed" || $command == "$allowed "*) ]] && exit 0
    done < <(jq -r '.bash[]?' <<<"$scope")
    block "$agent ne lance que : $(jq -r '.bash // [] | if length == 0 then "rien" else join(", ") end' <<<"$scope") ; refusé : $command."
    ;;
esac
exit 0
