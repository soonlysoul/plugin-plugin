#!/usr/bin/env bash
# pp.sh add-script: a tool of scripts/ written with its test, nothing written when it is refused.
# The skeleton refuses every call by its usage, under the # CALLER: mark of the component that
# will cite it; the generated test's contract passes on it and its placeholder fails; cases written
# fail on the skeleton, then pass with the code. Until a component cites it, the plugin's test_paths
# skips a script its mark declares and fails one without the mark; a hook script that cites it
# counts; check sees no gap (MODEL.md, R9, R12, R14; US-8, US-39).
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../helpers/plugin.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/plugin.sh"
SUITE=test_add_script
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
# file_sums <dir>: one "sum  ./path" line per file, .git/ left out.
file_sums() {
  (cd "$1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum)
}
# own <command...>: a test of the created plugin, run on that plugin: its lib.sh would otherwise
# follow PLUGIN_UNDER_TEST, set when this test is pointed at a mutated copy of plugin-plugin.
own() { (cd "$work" && env -u PLUGIN_UNDER_TEST "$@"); }
# paths <dir>: runs the plugin's test_paths; PATHS_STATUS and PATHS_OUTPUT.
paths() {
  PATHS_OUTPUT=$(own bash "$1/tests/static/test_paths.sh" 2>&1)
  PATHS_STATUS=$?
}
CITED='outil-demo\.sh est cité par \$\{CLAUDE_PLUGIN_ROOT\}'

plugin=$(new_plugin "$work" plugin-outil) && pass "plugin d'essai créé" || fail "plugin d'essai créé"
script="$plugin/scripts/outil-demo.sh"
test_file="$plugin/tests/static/test_script_outil_demo.sh"

echo "# refus, sans rien écrire"
before=$(file_sums "$plugin")
# refused <label> <pattern> <args...>
refused() {
  local label=$1 pattern=$2
  shift 2
  run_pp add-script "$plugin" "$@"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT"; then pass "$label : refusé, raison nommée"
  else fail "$label : refusé, raison nommée" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"; fi
}
refused "nom hors kebab-case" 'kebab-case' --name Outil_X --caller skills/demo/SKILL.md
refused "sans appelant" 'usage : pp\.sh add-script' --name outil-demo
refused "appelant hors des composants" 'appelant « docs/USER_GUIDE\.md »' --name outil-demo --caller docs/USER_GUIDE.md
refused "appelant hooks.json, qui câble les scripts de hooks/scripts/" 'appelant « hooks/hooks\.json »' --name outil-demo --caller hooks/hooks.json
run_pp add-script "$work/nowhere" --name outil-demo --caller skills/demo/SKILL.md
expect_pp "dossier hors modèle : refusé" 1
[[ $(file_sums "$plugin") == "$before" ]] && pass "après les refus, plugin identique" || fail "après les refus, plugin identique"

echo "# écriture : le script et son test, rien d'autre"
run_pp add-script "$plugin" --name outil-demo --caller skills/demo/SKILL.md
expect_pp "add-script : exit 0" 0
grep -qxF 'écrit : scripts/outil-demo.sh, tests/static/test_script_outil_demo.sh' <<<"$PP_OUTPUT" \
  && pass "les fichiers écrits sont nommés" || fail "les fichiers écrits sont nommés" "$(tr '\n' '|' <<<"$PP_OUTPUT")"
grep -q '^avertissement' <<<"$PP_OUTPUT" && fail "aucun avertissement : la copie de test_paths connaît la marque" "$(grep '^avertissement' <<<"$PP_OUTPUT")" \
  || pass "aucun avertissement : la copie de test_paths connaît la marque"
after=$(file_sums "$plugin")
# comm reads whole lines, which start with the sum: both sides sorted the same way first.
gone=$(LC_ALL=C comm -23 <(LC_ALL=C sort <<<"$before") <(LC_ALL=C sort <<<"$after"))
added=$(LC_ALL=C comm -13 <(LC_ALL=C sort <<<"$before") <(LC_ALL=C sort <<<"$after") | sed 's#^[0-9a-f]*  \./##' | LC_ALL=C sort | paste -sd' ' -)
[[ -z $gone && $added == "scripts/outil-demo.sh tests/static/test_script_outil_demo.sh" ]] \
  && pass "seuls le script et son test sont ajoutés, aucun fichier existant modifié" \
  || fail "seuls le script et son test sont ajoutés, aucun fichier existant modifié" "ajoutés : $added ; retirés ou modifiés : $(tr '\n' '|' <<<"$gone")"

[[ $(head -n 1 "$script" 2>/dev/null) == '#!/usr/bin/env bash' ]] && pass "squelette : #!/usr/bin/env bash" || fail "squelette : #!/usr/bin/env bash"
grep -qx '# CALLER: skills/demo/SKILL.md' "$script" 2>/dev/null && pass "squelette : marque # CALLER: de l'appelant" \
  || fail "squelette : marque # CALLER: de l'appelant" "$(grep -n 'CALLER' "$script" 2>/dev/null)"
bash -n "$script" 2>/dev/null && pass "squelette : bash -n" || fail "squelette : bash -n"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning "$script" >/dev/null 2>&1 && pass "squelette : shellcheck -S warning" || fail "squelette : shellcheck -S warning"
  shellcheck -S warning -x --source-path=SCRIPTDIR "$test_file" >/dev/null 2>&1 && pass "test généré : shellcheck -S warning" \
    || fail "test généré : shellcheck -S warning" "$(shellcheck -S warning -x --source-path=SCRIPTDIR -f gcc "$test_file" 2>&1 | head -n 2)"
else
  skip "squelette et test généré : shellcheck -S warning" "shellcheck absent"
fi
# run_skeleton <args...>: the script run by bash, as its callers run it.
run_skeleton() {
  SK_STDOUT=$("$BASH" "$script" "$@" 2>"$work/stderr")
  SK_STATUS=$?
  SK_STDERR=$(<"$work/stderr")
}
run_skeleton __inconnu__
[[ $SK_STATUS == 1 && $SK_STDERR == *usage* && -z $SK_STDOUT ]] && pass "squelette : appel inconnu refusé, exit 1, usage sur stderr" \
  || fail "squelette : appel inconnu refusé, exit 1, usage sur stderr" "exit $SK_STATUS ; stdout : $SK_STDOUT ; stderr : $SK_STDERR"
run_skeleton
[[ $SK_STATUS == 1 && $SK_STDERR == *usage* ]] && pass "squelette : sans argument, refusé par l'usage" \
  || fail "squelette : sans argument, refusé par l'usage" "exit $SK_STATUS ; stderr : $SK_STDERR"

test_output=$(own bash "$test_file" 2>&1)
test_status=$?
[[ $test_status == 1 ]] && pass "test généré, sur le squelette : rouge (exit 1)" || fail "test généré, sur le squelette : rouge (exit 1)" "exit $test_status"
grep -qE '^  ok +appel inconnu : refusé, exit 1, raison sur stderr$' <<<"$test_output" \
  && pass "son contrat passe déjà sur le squelette" || fail "son contrat passe déjà sur le squelette" "$(tr '\n' '|' <<<"$test_output" | head -c 400)"
grep -qE '^  ÉCHEC +cas de outil-demo : à écrire$' <<<"$test_output" \
  && pass "rouge pour la bonne raison : les cas ne sont pas écrits" || fail "rouge pour la bonne raison : les cas ne sont pas écrits" "$(tr '\n' '|' <<<"$test_output" | head -c 400)"
[[ $(grep -c 'ÉCHEC' <<<"$test_output") == 1 ]] && pass "seule la marque échoue" || fail "seule la marque échoue" "$(grep 'ÉCHEC' <<<"$test_output" | tr '\n' '|')"

run_pp add-script "$plugin" --name outil-demo --caller skills/demo/SKILL.md
[[ $PP_STATUS == 1 ]] && grep -q 'scripts/outil-demo.sh existe déjà' <<<"$PP_OUTPUT" && pass "script déjà présent : refusé" \
  || fail "script déjà présent : refusé" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT")"
mv "$script" "$work/outil-demo.sh"
run_pp add-script "$plugin" --name outil-demo --caller skills/demo/SKILL.md
[[ $PP_STATUS == 1 ]] && grep -q 'test_script_outil_demo.sh existe déjà' <<<"$PP_OUTPUT" && [[ ! -e $script ]] \
  && pass "test déjà présent : refusé, rien n'est écrit" || fail "test déjà présent : refusé, rien n'est écrit" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT")"
mv "$work/outil-demo.sh" "$script"

echo "# test_paths : un script que rien ne cite encore"
paths "$plugin"
[[ $PATHS_STATUS == 0 ]] && pass "marqué : test_paths vert" || fail "marqué : test_paths vert" "exit $PATHS_STATUS ; $(grep -A1 'ÉCHEC' <<<"$PATHS_OUTPUT" | tr '\n' '|')"
grep -qE "^  sauté +$CITED \(en construction : skills/demo/SKILL\.md ne le cite pas encore\)$" <<<"$PATHS_OUTPUT" \
  && pass "marqué : sauté, l'appelant nommé" || fail "marqué : sauté, l'appelant nommé" "$(grep 'outil-demo' <<<"$PATHS_OUTPUT" | tr '\n' '|')"
unmarked="$work/unmarked"
cp -R "$plugin" "$unmarked"
sed -i '/^# CALLER: /d' "$unmarked/scripts/outil-demo.sh"
paths "$unmarked"
[[ $PATHS_STATUS == 1 ]] && grep -qE "^  ÉCHEC +$CITED$" <<<"$PATHS_OUTPUT" \
  && pass "sans marque : échec" || fail "sans marque : échec" "exit $PATHS_STATUS ; $(grep 'outil-demo' <<<"$PATHS_OUTPUT" | tr '\n' '|')"
hooked="$work/hooked"
cp -R "$plugin" "$hooked"
run_pp add-hook "$hooked" --name appel-outil --event PostToolUse --matcher Edit --mode fail-open
expect_pp "un hook ajouté à côté : exit 0" 0
printf '"$BASH" "${CLAUDE_PLUGIN_ROOT}/scripts/outil-demo.sh" bonjour hook >/dev/null 2>&1 || true\n' >>"$hooked/hooks/scripts/appel-outil.sh"
paths "$hooked"
grep -qE "^  ok +$CITED$" <<<"$PATHS_OUTPUT" && pass "cité depuis un script de hooks/scripts/ : réussi" \
  || fail "cité depuis un script de hooks/scripts/ : réussi" "$(grep 'outil-demo' <<<"$PATHS_OUTPUT" | tr '\n' '|')"
skilled="$work/skilled"
cp -R "$plugin" "$skilled"
mkdir -p "$skilled/skills/demo"
printf -- '---\nname: demo\ndescription: "Demo."\n---\n\nRun `bash "${CLAUDE_PLUGIN_ROOT}/scripts/outil-demo.sh" bonjour <nom>`.\n' >"$skilled/skills/demo/SKILL.md"
paths "$skilled"
grep -qE "^  ok +$CITED$" <<<"$PATHS_OUTPUT" && pass "cité par l'appelant nommé : réussi, la marque ne compte plus" \
  || fail "cité par l'appelant nommé : réussi, la marque ne compte plus" "$(grep 'outil-demo' <<<"$PATHS_OUTPUT" | tr '\n' '|')"

echo "# check : un script en construction n'est pas un écart"
run_pp check "$plugin"
[[ $PP_STATUS == 0 ]] && grep -q '^écarts : 0' <<<"$PP_OUTPUT" && pass "check : aucun écart, l'appelant peut s'ajouter" \
  || fail "check : aucun écart, l'appelant peut s'ajouter" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"

echo "# rouge, puis vert"
suite_output=$(own bash "$plugin/tests/run-all.sh" 2>&1)
suite_status=$?
[[ $suite_status == 1 ]] && grep -qE '^  ÉCHEC +cas de outil-demo : à écrire$' <<<"$suite_output" \
  && pass "suite du plugin : rouge, les cas du script ne sont pas écrits" \
  || fail "suite du plugin : rouge, les cas du script ne sont pas écrits" "exit $suite_status ; $(grep -E 'ÉCHEC' <<<"$suite_output" | head -3 | tr '\n' '|')"
grep -qE "^  ÉCHEC +$CITED" <<<"$suite_output" && fail "suite du plugin : la citation attendue ne la rend pas rouge" \
  || pass "suite du plugin : la citation attendue ne la rend pas rouge"
# What add then has Claude do: the cases in place of the placeholder, red on the skeleton.
cat >"$work/cases.sh" <<'EOF'
run_script bonjour Soon
if [[ $STATUS == 0 && $STDOUT == "bonjour, Soon" ]]; then pass "bonjour Soon : salue, exit 0"
else fail "bonjour Soon : salue, exit 0" "exit $STATUS ; stdout : $STDOUT ; stderr : $STDERR"; fi
run_script bonjour
if [[ $STATUS == 1 && -n $STDERR ]]; then pass "bonjour sans nom : refusé"; else fail "bonjour sans nom : refusé" "exit $STATUS"; fi
EOF
sed -i -e "/^case_placeholder\$/{r $work/cases.sh" -e 'd}' "$test_file"
test_output=$(own bash "$test_file" 2>&1)
test_status=$?
[[ $test_status == 1 ]] && grep -qE '^  ÉCHEC +bonjour Soon : salue, exit 0$' <<<"$test_output" && grep -qE '^ +exit 1 ; stdout :  ; stderr : .*usage' <<<"$test_output" \
  && pass "cas écrits : rouges sur le refus du squelette" || fail "cas écrits : rouges sur le refus du squelette" "exit $test_status ; $(tr '\n' '|' <<<"$test_output" | head -c 400)"
# Then the code.
sed -i 's/^  \*) usage ;;$/  bonjour) [[ -n ${2:-} ]] || usage; printf '"'"'bonjour, %s\\n'"'"' "$2" ;;\n&/' "$script"
test_output=$(own bash "$test_file" 2>&1)
[[ $? == 0 ]] && pass "code écrit : test du script vert" || fail "code écrit : test du script vert" "$(tr '\n' '|' <<<"$test_output" | head -c 400)"
suite_output=$(own bash "$plugin/tests/run-all.sh" 2>&1)
suite_status=$?
[[ $suite_status == 0 ]] && pass "code écrit : suite du plugin verte, le script toujours en construction" \
  || fail "code écrit : suite du plugin verte, le script toujours en construction" "exit $suite_status ; $(grep -E 'ÉCHEC' <<<"$suite_output" | head -3 | tr '\n' '|')"
grep -qE "^  sauté +$CITED \(en construction" <<<"$suite_output" && pass "la suite verte dit le script en construction" \
  || fail "la suite verte dit le script en construction"

echo "# une copie de test_paths qui ne connaît pas la marque"
old="$work/old/plugin-outil"
mkdir -p "$work/old"
cp -R "$plugin" "$old"
rm -f "$old/scripts/outil-demo.sh" "$old/tests/static/test_script_outil_demo.sh"
printf '#!/usr/bin/env bash\n# An older copy, from before the mark.\n' >"$old/tests/static/test_paths.sh"
run_pp add-script "$old" --name outil-demo --caller agents/lecteur.md
expect_pp "copie ancienne : add-script écrit quand même, exit 0" 0
grep -qE "^avertissement : la copie de tests/static/test_paths\.sh de ce plugin ne connaît pas la marque # CALLER: ; sa suite restera rouge jusqu'à ce que agents/lecteur\.md cite \\$\{CLAUDE_PLUGIN_ROOT\}/scripts/outil-demo\.sh\.$" <<<"$PP_OUTPUT" \
  && pass "copie ancienne : avertissement, l'appelant nommé" || fail "copie ancienne : avertissement, l'appelant nommé" "$(tr '\n' '|' <<<"$PP_OUTPUT")"

echo "# le skill add mène au genre script"
grep -qF '${CLAUDE_PLUGIN_ROOT}/skills/add/reference/script.md' "$PLUGIN_ROOT/skills/add/SKILL.md" \
  && pass "SKILL.md, étape 2 : reference/script.md" || fail "SKILL.md, étape 2 : reference/script.md"
grep -qE 'add-script .*--caller' "$PLUGIN_ROOT/skills/add/reference/script.md" 2>/dev/null \
  && pass "reference/script.md : add-script et son appelant" || fail "reference/script.md : add-script et son appelant"
grep -qF 'reference/script.md' "$PLUGIN_ROOT/skills/add/reference/mcp.md" \
  && pass "reference/mcp.md : un lanceur absent s'ajoute comme script" || fail "reference/mcp.md : un lanceur absent s'ajoute comme script"

finish
