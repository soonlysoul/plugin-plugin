#!/usr/bin/env bash
# Checkpoints and resumption: pp.sh checkpoint writes step, command, exit code and next action;
# pp.sh resume crosses the checkpoint with git, says what is done and what remains in ten lines
# at most, flags inconsistencies, and writes nothing.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_resume
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

run_pp() {
  PP_OUTPUT=$("$BASH" "$PP" "$@" 2>&1)
  PP_STATUS=$?
}
expect_pp() {
  if [[ $PP_STATUS == "$2" ]]; then pass "$1"; else fail "$1" "attendu exit $2, obtenu $PP_STATUS ; sortie : ${PP_OUTPUT:0:300}"; fi
}
expect_output() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then pass "$1"; else fail "$1" "motif absent : $2 ; sortie : $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 600)"; fi
}
refuse_output() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then fail "$1" "motif présent : $2"; else pass "$1"; fi
}
# tree_sum <dir>: every path and content under <dir>, .git included, plus HEAD.
tree_sum() {
  (cd "$1" && { find . -path ./.git/index -prune -o -print0 | sort -z | xargs -0 -I{} sh -c 'printf "%s\n" "{}"; [ -f "{}" ] && sha256sum < "{}"'
    git rev-parse HEAD; } | sha256sum | cut -d' ' -f1)
}

# An interrupted creation: the plugin is created and committed, the first commit proposal and
# the hand-over are left.
target="$work/plugin-recettes"
mkdir -p "$target/.plugin-plugin" "$target/.claude-plugin"
git -C "$target" init -q -b main
echo '{"name": "plugin-recettes"}' >"$target/.claude-plugin/plugin.json"
git -C "$target" add -A && git -C "$target" commit -qm "chore: charpente de plugin-recettes"
CREATE_STEPS="Vérifier le cadrage|Nom et description|Créer|Rapport et premier commit|Étape suivante"

echo "# checkpoint"
run_pp checkpoint "$target" start --skill create --steps "$CREATE_STEPS"
expect_pp "checkpoint start : exit 0" 0
cp="$target/.plugin-plugin/checkpoint.md"
grep -q '^skill : create$' "$cp" 2>/dev/null && pass "le point nomme le skill" || fail "le point nomme le skill" "$(cat "$cp" 2>&1 | head -c 300)"
grep -q "^dernier commit : $(git -C "$target" rev-parse --short HEAD)$" "$cp" 2>/dev/null && pass "le point note le dernier commit" || fail "le point note le dernier commit"
grep -q '^branche : main$' "$cp" 2>/dev/null && pass "le point note la branche" || fail "le point note la branche"
[[ $(grep -c '^- \[ \] ' "$cp" 2>/dev/null) == 5 ]] && pass "cinq étapes à faire" || fail "cinq étapes à faire" "$(grep '^- ' "$cp" 2>&1)"
run_pp checkpoint "$target" "done" 1 --command "pp.sh status docs/PRD.md" --exit 0
run_pp checkpoint "$target" "done" 2 --command "lecture de docs/PRD.md" --exit 0
run_pp checkpoint "$target" "done" 3 --command "pp.sh create plugin-recettes" --exit 0 --test "bash tests/run-all.sh"
expect_pp "checkpoint done : exit 0" 0
grep -qE '^- \[x\] 3 Créer — `pp\.sh create plugin-recettes` → exit 0$' "$cp" && pass "étape faite : commande et code de sortie" \
  || fail "étape faite : commande et code de sortie" "$(grep '^- ' "$cp")"
grep -qE '^test ciblé : `bash tests/run-all\.sh`$' "$cp" && pass "le test ciblé de l'étape est noté" || fail "le test ciblé de l'étape est noté"
grep -qE '^- \[ \] 4 Rapport et premier commit$' "$cp" && pass "l'étape suivante reste à faire" || fail "l'étape suivante reste à faire"
run_pp checkpoint "$target" "done" 9 --command x --exit 0
expect_pp "étape inconnue : refusé" 1
run_pp checkpoint "$target" "done" 4 --command "x"
expect_pp "étape sans code de sortie : refusé" 1

echo "# un point inachevé n'est pas effacé"
# Resuming a skill runs it again; its start must not wipe the steps already done.
saved=$(cat "$cp")
run_pp checkpoint "$target" start --skill create --steps "$CREATE_STEPS"
expect_pp "start sur un point inachevé du même skill : refusé" 1
expect_output "le refus nomme l'étape suivante" 'Rapport et premier commit'
[[ $(cat "$cp") == "$saved" ]] && pass "le point inachevé reste tel quel" || fail "le point inachevé reste tel quel"
for case in "autre skill|--skill add" "abandon accordé|--skill create --restart"; do
  copy="$work/copie-${case%%|*}"
  copy=${copy// /-}
  cp -a "$target" "$copy"
  read -ra args <<<"${case#*|}"
  run_pp checkpoint "$copy" start "${args[@]}" --steps "$CREATE_STEPS"
  expect_pp "start, ${case%%|*} : exit 0" 0
  [[ $(grep -c '^- \[ \] ' "$copy/.plugin-plugin/checkpoint.md" 2>/dev/null) == 5 ]] \
    && pass "start, ${case%%|*} : cinq étapes à faire" || fail "start, ${case%%|*} : cinq étapes à faire"
done
finished="$work/copie-fini"
cp -a "$target" "$finished"
run_pp checkpoint "$finished" "done" 4 --command x --exit 0
run_pp checkpoint "$finished" "done" 5 --command x --exit 0
run_pp checkpoint "$finished" start --skill create --steps "$CREATE_STEPS"
expect_pp "start sur un point achevé du même skill : exit 0" 0

echo "# reprise d'une création interrompue"
before=$(tree_sum "$target")
run_pp resume "$target"
expect_pp "resume : exit 0" 0
lines=$(grep -c . <<<"$PP_OUTPUT")
((lines <= 10)) && pass "résumé en dix lignes au plus ($lines)" || fail "résumé en dix lignes au plus" "$lines lignes"
expect_output "le skill est nommé" '^skill : create'
expect_output "ce qui est fait" '^fait : 1 Vérifier le cadrage, 2 Nom et description, 3 Créer$'
expect_output "la dernière étape faite, avec commande et code" '^dernière étape : 3 Créer — `pp\.sh create plugin-recettes` → exit 0$'
expect_output "ce qui reste" '^reste : 4 Rapport et premier commit, 5 Étape suivante$'
expect_output "l'étape suivante, sans refaire les précédentes" '^étape suivante : 4 Rapport et premier commit$'
expect_output "le test ciblé à relancer" '^test ciblé : `bash tests/run-all\.sh`$'
expect_output "aucune incohérence" '^incohérences : aucune$'
[[ $(tree_sum "$target") == "$before" ]] && pass "resume n'écrit rien" || fail "resume n'écrit rien"

echo "# incohérences"
echo 'nouveau' >"$target/notes.md"
git -C "$target" add notes.md && git -C "$target" commit -qm "docs: notes"
echo 'modifié' >>"$target/notes.md"
echo 'neuf' >"$target/brouillon.md"
git -C "$target" checkout -q -b autre
run_pp resume "$target"
expect_output "commit plus récent que le point de reprise" 'incohérences : .*1 commit plus récent que le point de reprise'
expect_output "autre branche" 'incohérences : .*branche autre au lieu de main'
expect_output "fichiers modifiés non commités" 'incohérences : .*2 fichiers modifiés non commités \(brouillon\.md, notes\.md\)'
lines=$(grep -c . <<<"$PP_OUTPUT")
((lines <= 10)) && pass "avec incohérences, toujours dix lignes au plus ($lines)" || fail "avec incohérences, toujours dix lignes au plus" "$lines lignes"
refuse_output "le point de reprise lui-même n'est pas compté comme modifié" 'checkpoint\.md'

echo "# sans point de reprise"
bare="$work/plugin-nu"
mkdir -p "$bare/.plugin-plugin"
git -C "$bare" init -q -b main
echo x >"$bare/a.txt" && git -C "$bare" add a.txt && git -C "$bare" commit -qm "feat: a"
run_pp resume "$bare"
expect_pp "sans point de reprise : exit 0" 0
expect_output "sans point de reprise : dit, et repart de git" '^aucun point de reprise : état reconstruit depuis git'
expect_output "sans point de reprise : dernier commit donné" 'feat: a'
run_pp resume "$work/inexistant"
expect_pp "dossier sans état : refusé" 1

echo "# versionnement de l'état"
grep -qxF '.plugin-plugin/checkpoint.md' "$PLUGIN_ROOT/scripts/scaffold/gitignore" \
  && pass "un plugin créé ignore son point de reprise, et versionne accords et décisions" \
  || fail "un plugin créé ignore son point de reprise, et versionne accords et décisions"

finish
