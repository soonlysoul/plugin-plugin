#!/usr/bin/env bash
# agent-scope-guard: each agent of hooks/agent-scope.json held to its folders and its Bash
# allowlist; inert for the main session and for other plugins' agents. Simulated inputs.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_agent_scope_guard
HOOK="$PLUGIN_ROOT/hooks/scripts/agent-scope-guard.sh"
SCOPE="$PLUGIN_ROOT/hooks/agent-scope.json"
PLUGIN=$(jq -r '.name' "$PLUGIN_ROOT/.claude-plugin/plugin.json")

project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT

# input <agent or ""> <tool> <field> <value>
input() {
  jq -nc --arg a "$1" --arg t "$2" --arg f "$3" --arg v "$4" --arg d "$project" \
    '{session_id: "t", cwd: $d, hook_event_name: "PreToolUse", tool_name: $t, tool_input: {($f): $v}}
     + (if $a == "" then {} else {agent_id: "a1", agent_type: $a} end)'
}

echo "# hors des agents du plugin"
run_hook "$HOOK" "$(input "" Write file_path "$project/src/x")" CLAUDE_PROJECT_DIR="$project"
expect_silent_allow "session principale : inerte"
run_hook "$HOOK" "$(input other-plugin:agent Write file_path "$project/src/x")" CLAUDE_PROJECT_DIR="$project"
expect_silent_allow "agent d'un autre plugin : inerte"
run_hook "$HOOK" "$(input "$PLUGIN:sans-portee" Write file_path "$project/src/x")" CLAUDE_PROJECT_DIR="$project"
expect_blocked "agent du plugin sans portée déclarée : bloqué"

while IFS= read -r agent; do
  echo "# $agent"
  while IFS= read -r dir; do
    run_hook "$HOOK" "$(input "$agent" Write file_path "$project/${dir%/}/x.md")" CLAUDE_PROJECT_DIR="$project"
    expect_silent_allow "$agent : écriture sous $dir autorisée"
  done < <(jq -r --arg a "$agent" '.[$a].write[]?' "$SCOPE")
  run_hook "$HOOK" "$(input "$agent" Edit file_path "$project/hors-portee-$RANDOM/x.md")" CLAUDE_PROJECT_DIR="$project"
  expect_blocked "$agent : écriture hors de sa portée bloquée"
  while IFS= read -r command; do
    run_hook "$HOOK" "$(input "$agent" Bash command "$command")" CLAUDE_PROJECT_DIR="$project"
    expect_silent_allow "$agent : « $command » autorisé"
    run_hook "$HOOK" "$(input "$agent" Bash command "$command; rm -rf src")" CLAUDE_PROJECT_DIR="$project"
    expect_blocked "$agent : « $command » composé bloqué"
  done < <(jq -r --arg a "$agent" '.[$a].bash[]?' "$SCOPE")
  run_hook "$HOOK" "$(input "$agent" Bash command "rm -rf src")" CLAUDE_PROJECT_DIR="$project"
  expect_blocked "$agent : commande hors liste bloquée"
done < <(jq -r 'keys[]' "$SCOPE")

echo "# fail-closed pour les agents du plugin seulement"
no_jq=$(path_without jq)
run_hook "$HOOK" "$(input "$PLUGIN:x" Write file_path "$project/x")" PATH="$no_jq" CLAUDE_PROJECT_DIR="$project"
expect_blocked "jq absent, agent du plugin : bloqué"
run_hook "$HOOK" "$(input "" Write file_path "$project/x")" PATH="$no_jq" CLAUDE_PROJECT_DIR="$project"
expect_status "jq absent, session principale : exit 0" 0
rm -rf "$no_jq"

finish
