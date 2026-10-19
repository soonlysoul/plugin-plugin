#!/usr/bin/env bash
# pp.sh add-hook: warns that the hook will run in every session before writing anything, wires
# hooks.json in exec form, writes the script and its simulated-input test; the created plugin's
# suite shows the hook test failing for the right reason, then green once the rule is written.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../helpers/plugin.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/plugin.sh"
SUITE=test_add_hook
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

plugin=$(new_plugin "$work" plugin-garde) && pass "plugin d'essai créé" || fail "plugin d'essai créé"

echo "# refus, sans rien écrire"
before=$(tree_sum "$plugin")
# refused <label> <pattern> <args...>
refused() {
  local label=$1 pattern=$2
  shift 2
  run_pp add-hook "$plugin" "$@"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT"; then pass "$label : refusé, raison nommée"
  else fail "$label : refusé, raison nommée" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"; fi
}
refused "nom hors kebab-case" 'kebab-case' --name Garde_X --event PreToolUse --matcher Bash --mode fail-closed
refused "événement inconnu" 'événement inconnu' --name garde --event PreBash --matcher Bash --mode fail-closed
refused "filtre absent sur un outil" 'filtre' --name garde --event PreToolUse --mode fail-closed
refused "filtre sur Stop" 'Stop n.a pas de filtre' --name garde --event Stop --matcher Bash --mode fail-open
refused "fail-closed sur PostToolUse" 'PostToolUse ne peut pas bloquer' --name garde --event PostToolUse --matcher 'Edit|Write' --mode fail-closed
refused "fail-closed sur Stop" 'Stop' --name garde --event Stop --mode fail-closed
refused "mode inconnu" 'mode' --name garde --event PreToolUse --matcher Bash --mode prudent
run_pp add-hook "$work/nowhere" --name garde --event PreToolUse --matcher Bash --mode fail-closed
expect_pp "dossier hors modèle : refusé" 1
[[ $(tree_sum "$plugin") == "$before" ]] && pass "après les refus, plugin identique" || fail "après les refus, plugin identique"

echo "# avertissement de portée, avant toute écriture"
run_pp add-hook "$plugin" --name garde-rm --event PreToolUse --matcher 'Bash|Monitor' --mode fail-closed --dry-run
expect_pp "--dry-run : exit 0" 0
head -n 1 <<<"$PP_OUTPUT" | grep -qE '^avertissement : .*toutes les sessions' && pass "l'avertissement de portée vient en premier" \
  || fail "l'avertissement de portée vient en premier" "$(head -n 2 <<<"$PP_OUTPUT")"
grep -qF 'hooks/scripts/garde-rm.sh' <<<"$PP_OUTPUT" && pass "--dry-run nomme les fichiers qu'il écrirait" || fail "--dry-run nomme les fichiers qu'il écrirait"
[[ $(tree_sum "$plugin") == "$before" ]] && pass "--dry-run n'écrit rien" || fail "--dry-run n'écrit rien"

echo "# écriture"
run_pp add-hook "$plugin" --name garde-rm --event PreToolUse --matcher 'Bash|Monitor' --mode fail-closed
expect_pp "add-hook : exit 0" 0
head -n 1 <<<"$PP_OUTPUT" | grep -qE '^avertissement : ' && pass "l'avertissement précède aussi l'écriture" || fail "l'avertissement précède aussi l'écriture"
hook=$(jq -c '.hooks.PreToolUse[]? | select(.hooks[0].args[0] == "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/garde-rm.sh")' "$plugin/hooks/hooks.json" 2>/dev/null)
jq -e '.matcher == "Bash|Monitor" and .hooks[0].type == "command" and .hooks[0].command == "bash"
       and (.hooks[0].args | length) == 1 and (.hooks[0].timeout | type) == "number" and .hooks[0].onFailure == "block"' \
  <<<"$hook" >/dev/null 2>&1 && pass "hooks.json : forme exec, \${CLAUDE_PLUGIN_ROOT}, timeout, onFailure block" \
  || fail "hooks.json : forme exec, \${CLAUDE_PLUGIN_ROOT}, timeout, onFailure block" "${hook:-absent}"
script="$plugin/hooks/scripts/garde-rm.sh"
[[ $(head -n 1 "$script" 2>/dev/null) == '#!/usr/bin/env bash' ]] && pass "script : #!/usr/bin/env bash" || fail "script : #!/usr/bin/env bash"
grep -q '^# Fail-closed' "$script" && pass "script : mode déclaré en tête" || fail "script : mode déclaré en tête"
test_file="$plugin/tests/hooks/test_garde_rm.sh"
[[ -f $test_file ]] && pass "test d'entrées simulées écrit" || fail "test d'entrées simulées écrit"
grep -q 'garde-rm' "$plugin/docs/INSTALLATION.md" && grep -q 'toutes les sessions' "$plugin/docs/INSTALLATION.md" \
  && pass "INSTALLATION nomme le hook et sa portée" || fail "INSTALLATION nomme le hook et sa portée"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning "$script" >/dev/null 2>&1 && pass "squelette : shellcheck -S warning" || fail "squelette : shellcheck -S warning"
else
  skip "squelette : shellcheck -S warning" "shellcheck absent"
fi
run_hook "$script" 'pas du json'
[[ $HOOK_STATUS == 2 && -n $HOOK_STDERR ]] && pass "squelette fail-closed : entrée illisible bloquée, raison sur stderr" \
  || fail "squelette fail-closed : entrée illisible bloquée, raison sur stderr" "exit $HOOK_STATUS"
no_jq=$(path_without jq)
run_hook "$script" '{}' PATH="$no_jq"
rm -rf "$no_jq"
[[ $HOOK_STATUS == 2 && -n $HOOK_STDERR ]] && pass "squelette fail-closed : jq absent bloqué" || fail "squelette fail-closed : jq absent bloqué" "exit $HOOK_STATUS"
run_pp add-hook "$plugin" --name garde-rm --event PreToolUse --matcher Bash --mode fail-closed
expect_pp "hook déjà présent : refusé" 1

echo "# rouge, puis vert"
suite_output=$(cd "$work" && bash "$plugin/tests/run-all.sh" 2>&1)
suite_status=$?
[[ $suite_status == 1 ]] && pass "suite du plugin : rouge (exit 1)" || fail "suite du plugin : rouge (exit 1)" "exit $suite_status"
grep -qE "ÉCHEC +règle de garde-rm : à écrire" <<<"$suite_output" && pass "rouge pour la bonne raison : la règle n'est pas écrite" \
  || fail "rouge pour la bonne raison : la règle n'est pas écrite" "$(grep -E 'ÉCHEC' <<<"$suite_output" | head -3 | tr '\n' '|')"
grep -qE '^  ok +.*squelette' <<<"$suite_output" || grep -qE 'test_garde_rm : [0-9]+ réussis' <<<"$suite_output" \
  && pass "le contrat du squelette passe déjà" || fail "le contrat du squelette passe déjà"
# What add then has Claude do: the rule and its simulated inputs, replacing the placeholders.
sed -i 's|^# RULE: the rule is not written yet\.$|command=$(jq -r ".tool_input.command // empty" <<<"$input")\nif [[ $command == *"rm -rf /"* ]]; then echo "garde-rm : rm -rf / refusé." >\&2; exit 2; fi|' "$script"
sed -i 's|^rule_placeholder$|run_hook "$HOOK" "$(jq -nc '"'"'{tool_name: "Bash", tool_input: {command: "rm -rf /"}}'"'"')"\nexpect_blocked "règle de garde-rm : rm -rf / bloqué"\nrun_hook "$HOOK" "$(jq -nc '"'"'{tool_name: "Bash", tool_input: {command: "ls"}}'"'"')"\nexpect_silent_allow "règle de garde-rm : ls autorisé"|' "$test_file"
suite_output=$(cd "$work" && bash "$plugin/tests/run-all.sh" 2>&1)
suite_status=$?
[[ $suite_status == 0 ]] && pass "règle écrite : suite du plugin verte (exit 0)" \
  || fail "règle écrite : suite du plugin verte (exit 0)" "exit $suite_status ; $(grep -E 'ÉCHEC' <<<"$suite_output" | head -3 | tr '\n' '|')"

echo "# hooks fail-open et Stop"
run_pp add-hook "$plugin" --name note-edit --event PostToolUse --matcher 'Edit|Write' --mode fail-open
expect_pp "PostToolUse fail-open : exit 0" 0
jq -e '.hooks.PostToolUse[]? | select(.hooks[0].args[0] | endswith("note-edit.sh")) | .hooks[0].onFailure == "continue"' \
  "$plugin/hooks/hooks.json" >/dev/null 2>&1 && pass "fail-open : onFailure continue" || fail "fail-open : onFailure continue"
run_hook "$plugin/hooks/scripts/note-edit.sh" 'pas du json'
expect_status "squelette fail-open : entrée illisible, exit 0" 0
run_pp add-hook "$plugin" --name rappel --event Stop --mode fail-open
expect_pp "Stop : exit 0" 0
jq -e '.hooks.Stop[]? | select(.hooks[0].args[0] | endswith("rappel.sh")) | (has("matcher") | not) and (.hooks[0] | has("onFailure") | not)' \
  "$plugin/hooks/hooks.json" >/dev/null 2>&1 && pass "Stop : ni filtre ni onFailure (sans effet sur Stop)" || fail "Stop : ni filtre ni onFailure (sans effet sur Stop)"
[[ $(jq '[.hooks[][]] | length' "$plugin/hooks/hooks.json") == 3 ]] && pass "les trois hooks coexistent dans hooks.json" \
  || fail "les trois hooks coexistent dans hooks.json"

finish
