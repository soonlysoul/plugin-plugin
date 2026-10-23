#!/usr/bin/env bash
# pp.sh add-* on a plugin of the model it did not create — plugin-essai, written by
# tests/helpers/foreign.sh with a harness and a scope guard of its own (decision i): the diff
# touches only the component and its wiring, existing lines stay as they were, the generated tests
# run under the plugin's own harness, and its original suite stays at 100 % once the hook's rule
# is written (US-17).
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../helpers/foreign.sh
source "$PLUGIN_ROOT/tests/helpers/foreign.sh"
SUITE=test_add_existing
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_CEILING_DIRECTORIES=$work

run_pp() {
  PP_OUTPUT=$("$BASH" "$PP" "$@" 2>&1)
  PP_STATUS=$?
}
tree_sum() {
  (cd "$1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
}
# suite <plugin>: runs the plugin's own suite; SUITE_STATUS, SUITE_OUTPUT and FAILED, the failed
# suites of its summary, one per line.
suite() {
  SUITE_OUTPUT=$(cd "$1" && bash tests/run-all.sh 2>&1)
  SUITE_STATUS=$?
  FAILED=$(awk '/^failed:/ { on = 1; next } /^blocked:/ { on = 0 } on && /^  - / { print $2 }' <<<"$SUITE_OUTPUT")
}

pf="$work/plugin-essai"
foreign_plugin "$pf" && [[ ! -e $pf/.plugin-plugin && ! -e $pf/tests/headers.sh ]] \
  && pass "plugin d'essai écrit, sans .plugin-plugin/ ni tests/headers.sh" || fail "plugin d'essai écrit, sans .plugin-plugin/ ni tests/headers.sh"
suite "$pf"
[[ $SUITE_STATUS == 0 ]] && pass "suite d'origine, avant l'ajout : exit 0" \
  || fail "suite d'origine, avant l'ajout : exit 0" "$(tail -n 8 <<<"$SUITE_OUTPUT" | tr '\n' '|')"
hooks_before=$(jq -c .hooks "$pf/hooks/hooks.json")

echo "# un hook ajouté"
run_pp add-hook "$pf" --name note-edit --event PostToolUse --matcher 'Edit|Write' --mode fail-open
[[ $PP_STATUS == 0 ]] && pass "add-hook : exit 0" || fail "add-hook : exit 0" "$(tr '\n' '|' <<<"$PP_OUTPUT")"
changed=$(git -C "$pf" status --porcelain | LC_ALL=C sort)
expected=$(printf '%s\n' ' M docs/INSTALLATION.md' ' M hooks/hooks.json' '?? hooks/scripts/note-edit.sh' '?? tests/hooks/test_note_edit.sh' | LC_ALL=C sort)
[[ $changed == "$expected" ]] && pass "le diff ne touche que le hook, son test et son câblage" \
  || fail "le diff ne touche que le hook, son test et son câblage" "$(tr '\n' '|' <<<"$changed")"
for file in hooks/hooks.json docs/INSTALLATION.md; do
  deleted=$(git -C "$pf" diff --numstat -- "$file" | cut -f2)
  [[ $deleted == 0 ]] && pass "$file : aucune ligne existante modifiée" \
    || fail "$file : aucune ligne existante modifiée" "$(git -C "$pf" diff -- "$file" | grep '^-' | head -n 6 | tr '\n' '|')"
done
jq -e --argjson old "$hooks_before" '.hooks as $new | all($old | to_entries[]; .value == $new[.key][0:(.value | length)])
  and ([$new[] | length] | add) == ([$old[] | length] | add) + 1' "$pf/hooks/hooks.json" >/dev/null \
  && pass "hooks.json : les hooks d'origine intacts, un seul ajouté" || fail "hooks.json : les hooks d'origine intacts, un seul ajouté"

suite "$pf"
[[ $FAILED == tests/hooks/test_note_edit.sh ]] && pass "suite d'origine à 100 % ; seul le test du hook échoue, règle non écrite" \
  || fail "suite d'origine à 100 % ; seul le test du hook échoue, règle non écrite" "échouées : $(tr '\n' ' ' <<<"$FAILED")"
grep -qE 'FAIL +règle de note-edit : à écrire' <<<"$SUITE_OUTPUT" && pass "le test du hook échoue pour la bonne raison" \
  || fail "le test du hook échoue pour la bonne raison" "$(grep -A3 'test_note_edit' <<<"$SUITE_OUTPUT" | tr '\n' '|' | head -c 400)"
grep -qiE 'introuvable|not found' <<<"$SUITE_OUTPUT" && fail "le test généré n'appelle que les aides du harnais du plugin" \
  "$(grep -iE 'introuvable|not found' <<<"$SUITE_OUTPUT" | head -n 2)" || pass "le test généré n'appelle que les aides du harnais du plugin"

# The rule, as the add skill has it written: the hook lets every edit through; its case replaces
# the placeholder.
sed -i 's/^rule_placeholder$/run_hook "$HOOK" "{\\"tool_name\\": \\"Edit\\"}"\nexpect_status "une édition passe" 0/' "$pf/tests/hooks/test_note_edit.sh"
suite "$pf"
[[ $SUITE_STATUS == 0 ]] && pass "règle écrite : suite d'origine et test du hook, exit 0" \
  || fail "règle écrite : suite d'origine et test du hook, exit 0" "échouées : $(tr '\n' ' ' <<<"$FAILED")"
run_pp check "$pf"
[[ $PP_STATUS == 0 ]] && pass "check : toujours aucun écart" || fail "check : toujours aucun écart" "$(tr '\n' '|' <<<"$PP_OUTPUT")"

echo "# un agent, sous le garde de portée du plugin"
before=$(tree_sum "$pf")
run_pp add-agent "$pf" --name doc-writer --tools 'Read, Write' --model sonnet --writes docs/
[[ $PP_STATUS == 1 ]] && grep -q 'ne lit pas hooks/agent-scope.json' <<<"$PP_OUTPUT" \
  && pass "agent qui écrit, garde propre au plugin : refusé, raison nommée" \
  || fail "agent qui écrit, garde propre au plugin : refusé, raison nommée" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT")"
[[ $(tree_sum "$pf") == "$before" ]] && pass "refusé : rien n'est écrit" || fail "refusé : rien n'est écrit"
run_pp add-agent "$pf" --name doc-reader --tools 'Read, Grep, Glob' --model sonnet
[[ $PP_STATUS == 0 ]] && pass "agent en lecture seule : exit 0" || fail "agent en lecture seule : exit 0" "$(tr '\n' '|' <<<"$PP_OUTPUT")"
[[ -f $pf/tests/headers.sh ]] && pass "l'aide de test tests/headers.sh, absente, est posée" || fail "l'aide de test tests/headers.sh, absente, est posée"
agent_output=$(cd "$pf" && bash tests/static/test_agent_doc_reader.sh 2>&1)
[[ $? == 0 ]] && pass "le test de l'agent passe sous le harnais du plugin" \
  || fail "le test de l'agent passe sous le harnais du plugin" "$(tr '\n' '|' <<<"$agent_output" | head -c 400)"

finish
