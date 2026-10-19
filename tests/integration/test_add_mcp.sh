#!/usr/bin/env bash
# pp.sh add-mcp declares an existing MCP server — local through a bash launcher of the plugin
# cited by ${CLAUDE_PLUGIN_ROOT}, or remote in HTTPS or WSS — with user variables as ${VAR}, no
# secret and no imperative install; its test fails before the declaration, then passes. pp.sh
# out-of-scope refuses each excluded component with its reason and what would reopen it.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../helpers/plugin.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/plugin.sh"
SUITE=test_add_mcp
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

echo "# hors périmètre : refus motivés, chacun avec son déclencheur"
# out <kind> <pattern of the reason> <pattern of the trigger>
out() {
  run_pp out-of-scope "$1"
  if [[ $PP_STATUS == 1 && $PP_OUTPUT == refusé* ]] && grep -qE -- "$2" <<<"$PP_OUTPUT" && grep -qE -- "rouvert.*$3" <<<"$PP_OUTPUT"; then
    pass "$1 : refusé, raison et déclencheur"
  else
    fail "$1 : refusé, raison et déclencheur" "exit $PP_STATUS ; ${PP_OUTPUT:0:300}"
  fi
}
out mcp-code 'code d.un serveur MCP' 'système sans ligne de commande'
out channel 'channel' 'channel'
out lsp 'serveur de langage' 'v0\.2'
out output-style 'style de sortie' 'PRD'
out command 'commands/' 'skill'
out plugin-option 'option' 'PRD'
out plugin-dependency 'dépendance' 'autre plugin'
run_pp out-of-scope teleporter
expect_pp "type inconnu : usage" 1

plugin=$(new_plugin "$work" plugin-serveur) && pass "plugin d'essai créé" || fail "plugin d'essai créé"
mkdir -p "$plugin/scripts"
printf '#!/usr/bin/env bash\n# Launches the existing server of this plugin.\nexec mcp-notes-server --stdio\n' >"$plugin/scripts/mcp-notes.sh"
printf '#!/usr/bin/env bash\nnpm install --prefix "$HOME/.notes" notes-server\nexec notes-server\n' >"$plugin/scripts/mcp-installs.sh"

echo "# refus, sans rien écrire"
before=$(tree_sum "$plugin")
refused() {
  local label=$1 pattern=$2
  shift 2
  run_pp add-mcp "$plugin" "$@"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT"; then pass "$label : refusé, raison nommée"
  else fail "$label : refusé, raison nommée" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"; fi
}
refused "serveur distant en HTTP" 'HTTPS ou WSS' --name notes --url http://notes.example.invalid/mcp
refused "lanceur absent" 'lanceur absent' --name notes --launcher scripts/absent.sh
refused "lanceur hors du plugin" 'scripts/<nom>\.sh' --name notes --launcher /usr/bin/notes-server
refused "lanceur qui remonte" 'scripts/<nom>\.sh' --name notes --launcher scripts/../../notes.sh
refused "installation impérative" 'installation impérative' --name notes --launcher '${CLAUDE_PLUGIN_ROOT}/scripts/mcp-notes.sh' --args 'bun install,--silent'
refused "lanceur qui installe" 'installation impérative' --name notes --launcher scripts/mcp-installs.sh
refused "valeur secrète en clair" 'secret' --name notes --url https://notes.example.invalid/mcp --header 'Authorization=Bearer sk-abcdefghijklmnopqrstuvwxyz0123'
refused "secret dans l'adresse" 'secret' --name notes --url 'https://notes.example.invalid/mcp?token=abc123'
refused "variable hors \${VAR}" 'variable' --name notes --launcher scripts/mcp-notes.sh --env 'notes token'
refused "\$VAR sans accolades" 'variable' --name notes --url https://notes.example.invalid/mcp --header 'Authorization=Bearer $NOTES_TOKEN'
refused "--env sur un serveur distant" 'local' --name notes --url https://notes.example.invalid/mcp --env NOTES_TOKEN
refused "nom hors kebab-case" 'kebab-case' --name Notes_Server --url https://notes.example.invalid/mcp
[[ $(tree_sum "$plugin") == "$before" ]] && pass "après les refus, plugin identique" || fail "après les refus, plugin identique"
rm "$plugin/scripts/mcp-installs.sh"

echo "# rouge : le test de la déclaration, avant elle"
run_pp add-mcp "$plugin" --name notes --launcher scripts/mcp-notes.sh --env NOTES_TOKEN,NOTES_DIR --test-only
expect_pp "--test-only : exit 0" 0
[[ -f $plugin/tests/static/test_mcp_notes.sh && ! -e $plugin/.mcp.json ]] \
  && pass "--test-only écrit le test, pas la déclaration" || fail "--test-only écrit le test, pas la déclaration"
suite_of
[[ $SUITE_STATUS == 1 ]] && grep -qE 'ÉCHEC +serveur notes déclaré' <<<"$SUITE_OUTPUT" \
  && pass "suite du plugin : rouge, le serveur n'est pas déclaré" || fail "suite du plugin : rouge, le serveur n'est pas déclaré" "exit $SUITE_STATUS"

echo "# vert : la déclaration locale"
run_pp add-mcp "$plugin" --name notes --launcher scripts/mcp-notes.sh --env NOTES_TOKEN,NOTES_DIR
expect_pp "add-mcp local : exit 0" 0
jq -e '.mcpServers.notes == {command: "bash", args: ["${CLAUDE_PLUGIN_ROOT}/scripts/mcp-notes.sh"],
       env: {NOTES_TOKEN: "${NOTES_TOKEN}", NOTES_DIR: "${NOTES_DIR}"}}' "$plugin/.mcp.json" >/dev/null 2>&1 \
  && pass ".mcp.json : bash et lanceur par \${CLAUDE_PLUGIN_ROOT}, variables en \${VAR}" || fail ".mcp.json : bash et lanceur par \${CLAUDE_PLUGIN_ROOT}, variables en \${VAR}" "$(cat "$plugin/.mcp.json" 2>&1)"
grep -q 'NOTES_TOKEN' "$plugin/README.md" && grep -q 'NOTES_DIR' "$plugin/README.md" && pass "variables documentées dans le README" \
  || fail "variables documentées dans le README"
grep -qE 'evals/mocks/notes/' <<<"$PP_OUTPUT" && grep -q 'evals/mocks/notes/' "$plugin/README.md" \
  && pass "rappel : une doublure dans evals/mocks/ pour évaluer un skill qui en dépend" || fail "rappel de la doublure evals/mocks/"
suite_of
[[ $SUITE_STATUS == 0 ]] && pass "suite du plugin : verte" || fail "suite du plugin : verte" "exit $SUITE_STATUS ; $(grep ÉCHEC <<<"$SUITE_OUTPUT" | head -3 | tr '\n' '|')"

echo "# la déclaration distante"
run_pp add-mcp "$plugin" --name agenda --url https://agenda.example.invalid/mcp --header 'Authorization=Bearer ${AGENDA_TOKEN}'
expect_pp "add-mcp distant : exit 0" 0
jq -e '.mcpServers.agenda == {type: "http", url: "https://agenda.example.invalid/mcp", headers: {Authorization: "Bearer ${AGENDA_TOKEN}"}}' \
  "$plugin/.mcp.json" >/dev/null 2>&1 && pass "serveur distant HTTPS, en-tête par \${VAR}" || fail "serveur distant HTTPS, en-tête par \${VAR}" "$(cat "$plugin/.mcp.json")"
jq -e '.mcpServers | has("notes")' "$plugin/.mcp.json" >/dev/null && pass "les deux serveurs coexistent" || fail "les deux serveurs coexistent"
grep -q 'AGENDA_TOKEN' "$plugin/README.md" && pass "variable de l'en-tête documentée" || fail "variable de l'en-tête documentée"
run_pp add-mcp "$plugin" --name agenda --url wss://agenda.example.invalid/mcp
expect_pp "serveur déjà déclaré : refusé" 1
run_pp add-mcp "$plugin" --name flux --url wss://flux.example.invalid/mcp
jq -e '.mcpServers.flux.type == "ws"' "$plugin/.mcp.json" >/dev/null 2>&1 && pass "serveur distant WSS" || fail "serveur distant WSS"

echo "# test_paths : ce qui est déclaré, même à la main"
cp "$plugin/.mcp.json" "$work/good.mcp.json"
printf '{"mcpServers": {"x": {"command": "npx", "args": ["-y", "server"]}}}\n' >"$plugin/.mcp.json"
suite_of
grep -qE 'ÉCHEC +aucune installation impérative' <<<"$SUITE_OUTPUT" && pass "test_paths refuse une installation impérative dans .mcp.json" \
  || fail "test_paths refuse une installation impérative dans .mcp.json"
grep -qE 'ÉCHEC +serveur x : lancé par bash' <<<"$SUITE_OUTPUT" && pass "test_paths refuse un serveur local hors lanceur bash" \
  || fail "test_paths refuse un serveur local hors lanceur bash"
printf '{"mcpServers": {"x": {"type": "http", "url": "https://x.example.invalid/mcp", "headers": {"Authorization": "Bearer sk-abcdefghijklmnopqrstuvwxyz0123"}}}}\n' >"$plugin/.mcp.json"
suite_of
grep -qE 'ÉCHEC +aucune valeur secrète' <<<"$SUITE_OUTPUT" && pass "test_paths refuse un secret écrit dans .mcp.json" \
  || fail "test_paths refuse un secret écrit dans .mcp.json"
cp "$work/good.mcp.json" "$plugin/.mcp.json"
cp "$plugin/scripts/mcp-notes.sh" "$work/launcher.sh"
printf 'pip install notes-server\n' >>"$plugin/scripts/mcp-notes.sh"
suite_of
grep -qE 'ÉCHEC +aucune installation impérative' <<<"$SUITE_OUTPUT" && pass "test_paths refuse un lanceur qui installe" \
  || fail "test_paths refuse un lanceur qui installe"
cp "$work/launcher.sh" "$plugin/scripts/mcp-notes.sh"
suite_of
[[ $SUITE_STATUS == 0 ]] && pass "rétabli : suite du plugin verte" || fail "rétabli : suite du plugin verte" "exit $SUITE_STATUS"

finish
