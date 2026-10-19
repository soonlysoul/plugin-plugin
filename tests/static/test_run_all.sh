#!/usr/bin/env bash
# tests/run-all.sh itself: its exit codes (0, 1, 2), a missing component directory skipped and
# never passed, the validator and the context cost blocked without claude, the cost budget.
# Each case runs the suite of a copy of the plugin, without this file, against a claude stub.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_run_all

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A claude stub: validation passes, plugin details reports STUB_ALWAYS_ON tokens.
mkdir "$work/stub"
cat >"$work/stub/claude" <<'EOF'
#!/usr/bin/env bash
case " $* " in
  *" plugin validate "*) echo "✔ Validation passed" ;;
  *" plugin details "*) printf 'Projected token cost\n  Always-on:   ~%s tok   added to every session\n' "${STUB_ALWAYS_ON:-0}" ;;
  *) echo "claude stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
EOF
chmod +x "$work/stub/claude"

# copy_plugin <name>: a copy of the plugin without VCS nor build output.
copy_plugin() {
  local copy="$work/$1" entry
  mkdir "$copy"
  for entry in "$PLUGIN_ROOT"/* "$PLUGIN_ROOT"/.[!.]*; do
    case ${entry##*/} in .git | build | .superpowers | .shots) continue ;; esac
    cp -R "$entry" "$copy/"
  done
  # Neither this test (it would recurse) nor the integration tests, which create plugins and need
  # claude: the copies only exercise run-all.sh.
  rm -rf "$copy/tests/static/test_run_all.sh" "$copy/tests/integration"
  printf '%s' "$copy"
}

# run_suite <copy> [env assignments...]: sets RUN_STATUS and RUN_OUTPUT (stdout and stderr).
run_suite() {
  local copy=$1
  shift
  RUN_OUTPUT=$(env "$@" "$BASH" "$copy/tests/run-all.sh" 2>&1)
  RUN_STATUS=$?
}

expect_run() {
  if [[ $RUN_STATUS == "$2" ]]; then pass "$1"; else fail "$1" "attendu exit $2, obtenu $RUN_STATUS ; sortie : $(tail -n 12 <<<"$RUN_OUTPUT" | tr '\n' '|')"; fi
}
expect_output() {
  if grep -qE -- "$2" <<<"$RUN_OUTPUT"; then pass "$1"; else fail "$1" "motif absent : $2"; fi
}
refuse_output() {
  if grep -qE -- "$2" <<<"$RUN_OUTPUT"; then fail "$1" "motif présent : $2"; else pass "$1"; fi
}

echo "# copie intacte"
intact=$(copy_plugin intact)
run_suite "$intact" PATH="$work/stub:$PATH" STUB_ALWAYS_ON=840
expect_run "copie intacte : exit 0" 0
expect_output "le bilan compte zéro échec" '^échouées : 0$'
expect_output "le coût permanent est affiché" 'ok +coût permanent : 840 tokens \(seuil 1000\)'

run_suite "$intact" PATH="$work/stub:$PATH" PLUGIN_UNDER_TEST="$work/nope"
expect_run "PLUGIN_UNDER_TEST hérité : la suite vérifie quand même son propre dossier" 0

echo "# dossiers de composants absents"
bare=$(copy_plugin bare)
rm -rf "$bare/skills" "$bare/agents"
run_suite "$bare" PATH="$work/stub:$PATH"
expect_output "skills/ absent : sauté" 'sauté +skills \(absent\)'
expect_output "agents/ absent : sauté" 'sauté +agents \(absent\)'
refuse_output "skills/ absent : jamais réussi" 'ok +skills$'

echo "# manifeste faussé ou absent"
falsified=$(copy_plugin falsified)
jq '.license = "Apache-2.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" >"$falsified/.claude-plugin/plugin.json" 2>/dev/null \
  || echo '{}' >"$falsified/.claude-plugin/plugin.json"
run_suite "$falsified" PATH="$work/stub:$PATH"
expect_run "manifeste faussé : exit 1" 1
expect_output "le contrôle faussé est nommé" 'ÉCHEC +license est MIT'
missing=$(copy_plugin missing)
rm -f "$missing/.claude-plugin/plugin.json"
run_suite "$missing" PATH="$work/stub:$PATH"
expect_run "manifeste absent : exit 1" 1
expect_output "le manifeste absent est nommé" 'manifeste absent : \.claude-plugin/plugin\.json'
expect_output "manifeste absent : sa validation échoue" 'ÉCHEC +\.claude-plugin/plugin\.json \(absent\)'
refuse_output "manifeste absent : sa validation n'est jamais sautée" 'sauté +\.claude-plugin/plugin\.json'

echo "# prérequis manquants"
no_jq=$(path_without jq)
run_suite "$intact" PATH="$work/stub:$no_jq"
expect_run "jq absent : exit 2" 2
expect_output "jq absent : la cause est dite" 'bloqué : jq est requis'
rm -rf "$no_jq"
no_claude=$(path_without claude)
run_suite "$intact" PATH="$no_claude"
expect_run "claude absent : exit 2" 2
expect_output "claude absent : validation bloquée" 'claude plugin validate \(claude introuvable dans le PATH\)'
expect_output "claude absent : coût bloqué" 'coût en contexte \(claude introuvable dans le PATH\)'
refuse_output "claude absent : rien n'est réussi en silence" '^  ok +(\.|\.claude-plugin/plugin\.json|coût .*)$'
rm -rf "$no_claude"

echo "# budget de contexte"
run_suite "$intact" PATH="$work/stub:$PATH" STUB_ALWAYS_ON=1.2k
expect_run "1.2k tokens permanents : exit 1" 1
expect_output "le dépassement est nommé" 'coût permanent : 1200 tokens, au-delà du seuil de 1000'
run_suite "$intact" PATH="$work/stub:$PATH" STUB_ALWAYS_ON=1k
expect_run "1k tokens permanents, au seuil : exit 0" 0

finish
