#!/usr/bin/env bash
# pp.sh add-agent: an agent whose header declares its tools and model, never Agent, with the
# fixed report format; its test seen failing while the agent is absent, then green; an agent that
# writes held to its folders and its Bash allowlist by agent-scope-guard, inert for anyone else.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../helpers/plugin.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/plugin.sh"
SUITE=test_add_agent
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

run_pp() {
  PP_OUTPUT=$("$BASH" "$PP" "$@" 2>&1)
  PP_STATUS=$?
}
expect_pp() {
  if [[ $PP_STATUS == "$2" ]]; then pass "$1"; else fail "$1" "attendu exit $2, obtenu $PP_STATUS ; sortie : $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 400)"; fi
}
tree_sum() {
  (cd "$1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
}
suite_of() {
  SUITE_OUTPUT=$(cd "$work" && bash "$plugin/tests/run-all.sh" 2>&1)
  SUITE_STATUS=$?
}

plugin=$(new_plugin "$work" plugin-agents) && pass "plugin d'essai créé" || fail "plugin d'essai créé"

echo "# refus, sans rien écrire"
before=$(tree_sum "$plugin")
refused() {
  local label=$1 pattern=$2
  shift 2
  run_pp add-agent "$plugin" "$@"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT"; then pass "$label : refusé, raison nommée"
  else fail "$label : refusé, raison nommée" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"; fi
}
refused "nom de deux caractères" '3 à 50' --name ab --tools "Read" --model sonnet
refused "outil Agent" 'outil Agent (est )?interdit' --name doc-reader --tools "Read, Agent" --model sonnet
refused "outil inconnu" 'outil inconnu : Telepathy' --name doc-reader --tools "Read, Telepathy" --model sonnet
refused "relecteur qui écrit" 'relecteur' --name code-reviewer --tools "Read, Edit" --model sonnet --writes docs/
refused "Write sans dossiers d'écriture" '--writes' --name doc-writer --tools "Read, Write" --model sonnet
refused "Bash sans liste blanche" '--bash' --name doc-runner --tools "Read, Bash" --model sonnet
refused "Monitor sans liste blanche" '--bash' --name log-watcher --tools "Read, Monitor" --model sonnet
refused "dossier d'écriture qui remonte" '\.\.' --name doc-writer --tools "Read, Write" --model sonnet --writes ../docs/
refused "model inconnu" 'model' --name doc-reader --tools "Read" --model gpt
[[ $(tree_sum "$plugin") == "$before" ]] && pass "après les refus, plugin identique" || fail "après les refus, plugin identique"

echo "# rouge : le test de l'agent, avant l'agent"
run_pp add-agent "$plugin" --name doc-reader --tools "Read, Grep, Glob" --model sonnet --test-only
expect_pp "--test-only : exit 0" 0
[[ -f $plugin/tests/static/test_agent_doc_reader.sh && ! -e $plugin/agents/doc-reader.md ]] \
  && pass "--test-only écrit le test, pas l'agent" || fail "--test-only écrit le test, pas l'agent"
suite_of
[[ $SUITE_STATUS == 1 ]] && grep -qE 'ÉCHEC +agents/doc-reader\.md présent' <<<"$SUITE_OUTPUT" \
  && pass "suite du plugin : rouge, l'agent est absent" || fail "suite du plugin : rouge, l'agent est absent" "exit $SUITE_STATUS"

echo "# vert : l'agent"
run_pp add-agent "$plugin" --name doc-reader --tools "Read, Grep, Glob" --model sonnet
expect_pp "add-agent : exit 0" 0
file="$plugin/agents/doc-reader.md"
grep -qx 'tools: Read, Grep, Glob' "$file" && grep -qx 'model: sonnet' "$file" && pass "outils et modèle déclarés" || fail "outils et modèle déclarés"
for field in STATUS FILES_CHANGED COMMANDS_RUN OPEN_QUESTIONS; do
  grep -q "^$field:" "$file" || missing+=" $field"
done
[[ -z ${missing:-} ]] && pass "rapport STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS" || fail "rapport à format fixe" "manque :$missing"
suite_of
[[ $SUITE_STATUS == 0 ]] && pass "suite du plugin : verte" || fail "suite du plugin : verte" "exit $SUITE_STATUS ; $(grep ÉCHEC <<<"$SUITE_OUTPUT" | head -3 | tr '\n' '|')"
run_pp check-agent "$file"
[[ $PP_STATUS == 1 && $PP_OUTPUT == *"200 à 1 000"* ]] && pass "squelette : check-agent exige la description" \
  || fail "squelette : check-agent exige la description" "${PP_OUTPUT:0:300}"
[[ ! -e $plugin/hooks/scripts/agent-scope-guard.sh ]] && pass "un agent qui n'écrit pas n'a pas besoin du garde" \
  || fail "un agent qui n'écrit pas n'a pas besoin du garde"
run_pp add-agent "$plugin" --name doc-reader --tools "Read" --model sonnet
expect_pp "agent déjà présent : refusé" 1

echo "# un agent qui écrit"
run_pp add-agent "$plugin" --name doc-writer --tools "Read, Grep, Glob, Write, Edit, Bash" --model inherit --writes "docs/" --bash "git diff,git log"
expect_pp "add-agent qui écrit : exit 0" 0
head -n 1 <<<"$PP_OUTPUT" | grep -qE '^avertissement : .*toutes les sessions' && pass "le garde arrive avec l'avertissement de portée" \
  || fail "le garde arrive avec l'avertissement de portée" "$(head -n 1 <<<"$PP_OUTPUT")"
jq -e '."plugin-agents:doc-writer" == {write: ["docs/"], bash: ["git diff", "git log"]}' "$plugin/hooks/agent-scope.json" >/dev/null 2>&1 \
  && pass "portée déclarée dans hooks/agent-scope.json" || fail "portée déclarée dans hooks/agent-scope.json" "$(cat "$plugin/hooks/agent-scope.json" 2>&1)"
jq -e '.hooks.PreToolUse[] | select(.hooks[0].args[0] | endswith("agent-scope-guard.sh"))
       | .matcher == "Edit|Write|NotebookEdit|Bash|Monitor" and .hooks[0].onFailure == "block"' "$plugin/hooks/hooks.json" >/dev/null 2>&1 \
  && pass "garde câblé : PreToolUse, fail-closed" || fail "garde câblé : PreToolUse, fail-closed"
run_pp add-agent "$plugin" --name test-writer --tools "Read, Write" --model sonnet --writes "tests/"
expect_pp "second agent qui écrit : exit 0" 0
[[ $(jq '[.hooks.PreToolUse[] | select(.hooks[0].args[0] | endswith("agent-scope-guard.sh"))] | length' "$plugin/hooks/hooks.json") == 1 ]] \
  && pass "un seul garde pour tous les agents" || fail "un seul garde pour tous les agents"
run_pp add-agent "$plugin" --name code-reviewer --tools "Read, Grep, Bash" --model sonnet --bash "git diff"
expect_pp "relecteur à Bash restreint : exit 0" 0
# The scope sentence of the agent's approach, in words a reader takes as written.
scope_sentence() { grep -o 'Scope, enforced by the agent-scope-guard hook: [^.]*\.' "$plugin/agents/$1.md"; }
for expected in 'doc-writer|writes only under `docs/`; Bash only `git diff`, `git log`.' \
  'test-writer|writes only under `tests/`; no Bash.' \
  'code-reviewer|writes nothing; Bash only `git diff`.'; do
  agent=${expected%%|*} sentence="Scope, enforced by the agent-scope-guard hook: ${expected#*|}"
  [[ $(scope_sentence "$agent") == "$sentence" ]] && pass "portée de $agent : « ${expected#*|} »" \
    || fail "portée de $agent : « ${expected#*|} »" "$(scope_sentence "$agent")"
done

echo "# le garde de portée"
GUARD="$plugin/hooks/scripts/agent-scope-guard.sh"
# input <agent or ""> <tool> <field> <value>
input() {
  jq -nc --arg a "$1" --arg t "$2" --arg f "$3" --arg v "$4" --arg d "$plugin" \
    '{session_id: "t", cwd: $d, hook_event_name: "PreToolUse", tool_name: $t, tool_input: {($f): $v}}
     + (if $a == "" then {} else {agent_id: "a1", agent_type: $a} end)'
}
writer="plugin-agents:doc-writer"
run_hook "$GUARD" "$(input "" Write file_path "$plugin/src/x.sh")" CLAUDE_PROJECT_DIR="$plugin"
expect_silent_allow "session principale : inerte"
run_hook "$GUARD" "$(input other-plugin:writer Write file_path "$plugin/src/x.sh")" CLAUDE_PROJECT_DIR="$plugin"
expect_silent_allow "agent d'un autre plugin : inerte"
run_hook "$GUARD" "$(input "$writer" Write file_path "$plugin/docs/guide.md")" CLAUDE_PROJECT_DIR="$plugin"
expect_silent_allow "écriture dans docs/ : autorisée"
run_hook "$GUARD" "$(input "$writer" Edit file_path "$plugin/src/x.sh")" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "écriture hors de docs/ : bloquée"
run_hook "$GUARD" "$(input "$writer" Write file_path "$plugin/docs/../src/x.sh")" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "chemin qui remonte : bloqué"
run_hook "$GUARD" "$(input "$writer" Write file_path "/tmp/x.md")" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "hors du projet : bloqué"
run_hook "$GUARD" "$(input "$writer" Bash command "git diff --stat")" CLAUDE_PROJECT_DIR="$plugin"
expect_silent_allow "git diff --stat : autorisé"
run_hook "$GUARD" "$(input "$writer" Bash command "git push origin main")" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "git push : bloqué"
run_hook "$GUARD" "$(input "$writer" Bash command "git diff; rm -rf src")" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "commande composée : bloquée"
run_hook "$GUARD" "$(input "$writer" Bash command 'git log $(rm x)')" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "substitution de commande : bloquée"
run_hook "$GUARD" "$(input plugin-agents:code-reviewer Edit file_path "$plugin/docs/x.md")" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "relecteur : aucune écriture"
run_hook "$GUARD" "$(input plugin-agents:doc-reader Write file_path "$plugin/docs/x.md")" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "agent du plugin sans portée déclarée : bloqué"
no_jq=$(path_without jq)
run_hook "$GUARD" "$(input "$writer" Write file_path "$plugin/docs/x.md")" PATH="$no_jq" CLAUDE_PROJECT_DIR="$plugin"
expect_blocked "jq absent, agent du plugin : bloqué"
run_hook "$GUARD" "$(input "" Write file_path "$plugin/docs/x.md")" PATH="$no_jq" CLAUDE_PROJECT_DIR="$plugin"
expect_status "jq absent, session principale : exit 0" 0
rm -rf "$no_jq"

echo "# la suite du plugin, tous agents ajoutés"
suite_of
[[ $SUITE_STATUS == 0 ]] && pass "suite du plugin : verte (garde, câblage, en-têtes)" \
  || fail "suite du plugin : verte (garde, câblage, en-têtes)" "exit $SUITE_STATUS ; $(grep ÉCHEC <<<"$SUITE_OUTPUT" | head -3 | tr '\n' '|')"
grep -q 'test_agent_scope_guard : [0-9]* réussis, 0 échoués' <<<"$SUITE_OUTPUT" && pass "le garde a son test d'entrées simulées" \
  || fail "le garde a son test d'entrées simulées"

finish
