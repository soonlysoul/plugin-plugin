#!/usr/bin/env bash
# The framing commands of scripts/pp.sh: init-state, check-name, delegate, approve. Only an
# explicit approval message moves a document to approved, with the date and the quote; any
# other answer leaves it byte for byte as it was.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_frame
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

run_pp() {
  PP_OUTPUT=$("$BASH" "$PP" "$@" 2>&1)
  PP_STATUS=$?
}
expect_pp() {
  if [[ $PP_STATUS == "$2" ]]; then pass "$1"; else fail "$1" "attendu exit $2, obtenu $PP_STATUS ; sortie : ${PP_OUTPUT:0:300}"; fi
}
expect_output() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then pass "$1"; else fail "$1" "motif absent : $2 ; sortie : ${PP_OUTPUT:0:300}"; fi
}
sum() { sha256sum "$1" | cut -d' ' -f1; }

echo "# init-state"
target="$work/plugin-essai"
mkdir -p "$target"
run_pp init-state "$target"
expect_pp "init-state : exit 0" 0
[[ -d $target/.plugin-plugin && -f $target/.plugin-plugin/approvals.log && -f $target/.plugin-plugin/decisions.md ]] \
  && pass "init-state : .plugin-plugin/ avec le journal des accords et des décisions" \
  || fail "init-state : .plugin-plugin/ avec le journal des accords et des décisions" "$(ls -A "$target/.plugin-plugin" 2>&1)"
printf 'trace\n' >>"$target/.plugin-plugin/decisions.md"
run_pp init-state "$target"
expect_pp "init-state relancé : exit 0" 0
grep -q '^trace$' "$target/.plugin-plugin/decisions.md" && pass "init-state relancé : n'écrase rien" || fail "init-state relancé : n'écrase rien"
# A plugin framed for the first time has no folder yet: init-state creates it, one level only.
run_pp init-state "$work/plugin-neuf"
expect_pp "init-state, dossier absent : exit 0" 0
[[ -f $work/plugin-neuf/.plugin-plugin/approvals.log ]] && pass "init-state, dossier absent : créé avec son état" \
  || fail "init-state, dossier absent : créé avec son état" "$PP_OUTPUT"
run_pp init-state "$work/absent/plugin-neuf"
expect_pp "init-state, parent absent : refusé" 1
expect_output "init-state, parent absent : le parent nommé" "$work/absent"
[[ ! -e $work/absent ]] && pass "init-state, parent absent : rien de créé" || fail "init-state, parent absent : rien de créé"

echo "# check-name"
run_pp check-name plugin-notes
expect_pp "plugin-notes : accepté" 0
# refuse <name> <label> <pattern of the rule named in the refusal>
refuse() {
  run_pp check-name "$1"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$3" <<<"$PP_OUTPUT"; then pass "$2 : refusé, règle nommée"
  else fail "$2 : refusé, règle nommée" "exit $PP_STATUS ; sortie : ${PP_OUTPUT:0:300}"; fi
}
refuse Plugin-Notes "majuscules" 'majuscule'
refuse plugin_notes "soulignés" 'souligné'
refuse alpha-forge "préfixe absent" 'préfixe plugin-'
refuse plugin- "domaine vide" 'domaine vide'
refuse plugin "nom nu" 'préfixe plugin-'
refuse plugin--notes "tirets doublés" 'kebab-case'
refuse "plugin notes" "espace" 'kebab-case'

echo "# delegate"
run_pp delegate "$target" --question "Langue des identifiants ?" --choice "anglais" --reason "convention de Soon"
expect_pp "delegate : exit 0" 0
line=$(grep -F 'Langue des identifiants ?' "$target/.plugin-plugin/decisions.md")
[[ $line == *"anglais"* && $line == *"convention de Soon"* && $line == *"révisable"* && $line =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]] \
  && pass "décision déléguée consignée : date, question, choix, raison, révisable" \
  || fail "décision déléguée consignée : date, question, choix, raison, révisable" "$line"
run_pp delegate "$target" --question "Sans choix ?"
expect_pp "delegate sans choix ni raison : refusé" 1

echo "# approve"
mkdir -p "$target/docs"
printf '# PRD — essai\n\n**Statut : BROUILLON**\n\nTexte.\n' >"$target/docs/PRD.md"
for answer in "ok" "oui mais change le nom" "d'accord" "" "on verra"; do
  before=$(sum "$target/docs/PRD.md")
  log_before=$(sum "$target/.plugin-plugin/approvals.log")
  run_pp approve "$target/docs/PRD.md" --quote "$answer"
  [[ $PP_STATUS == 1 && $PP_OUTPUT == *refusé* ]] && pass "« $answer » : refusé" || fail "« $answer » : refusé" "exit $PP_STATUS ; ${PP_OUTPUT:0:200}"
  [[ $(sum "$target/docs/PRD.md") == "$before" && $(sum "$target/.plugin-plugin/approvals.log") == "$log_before" ]] \
    && pass "« $answer » : document et journal identiques" || fail "« $answer » : document et journal identiques"
done
run_pp approve "$target/docs/PRD.md" --quote "Je valide."
expect_pp "« Je valide. » : approuvé" 0
status=$(grep -m 1 '^\*\*Statut : ' "$target/docs/PRD.md")
[[ $status =~ ^\*\*Statut\ :\ APPROUVÉ\*\*\ le\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ \(«\ Je\ valide\.\ »\)\.$ ]] \
  && pass "statut approuvé, avec la date et la citation exacte" || fail "statut approuvé, avec la date et la citation exacte" "$status"
grep -qP '^[0-9]{4}-[0-9]{2}-[0-9]{2}\tdocs/PRD\.md\t[0-9a-f]{64}\tJe valide\.$' "$target/.plugin-plugin/approvals.log" \
  && pass "journal des accords : date, document, empreinte, citation" \
  || fail "journal des accords : date, document, empreinte, citation" "$(cat "$target/.plugin-plugin/approvals.log")"
for answer in "oui" "j'approuve" "j’approuve" "validé !"; do
  printf '# Doc\n\n**Statut : REVUE**\n\nTexte.\n' >"$target/docs/ARCHITECTURE.md"
  run_pp approve "$target/docs/ARCHITECTURE.md" --quote "$answer"
  expect_pp "« $answer » : approuvé" 0
done

printf '# Sans statut\n\nTexte.\n' >"$target/docs/AUTRE.md"
run_pp approve "$target/docs/AUTRE.md" --quote "je valide"
expect_pp "document sans ligne de statut : refusé" 1
mkdir -p "$work/unmanaged/docs"
printf '# PRD\n\n**Statut : BROUILLON**\n' >"$work/unmanaged/docs/PRD.md"
run_pp approve "$work/unmanaged/docs/PRD.md" --quote "je valide"
expect_pp "projet non géré (pas de .plugin-plugin/) : refusé" 1
run_pp status "$target/docs/PRD.md"
expect_output "status lit le statut" '^APPROUVÉ$'

echo "# gabarits du cadrage"
for doc in PRD ARCHITECTURE; do
  file="$PLUGIN_ROOT/templates/$doc.md"
  [[ -f $file ]] && pass "templates/$doc.md présent" || fail "templates/$doc.md présent"
  grep -qx '\*\*Statut : BROUILLON\*\*' "$file" 2>/dev/null && pass "templates/$doc.md naît en brouillon" \
    || fail "templates/$doc.md naît en brouillon"
done
grep -q 'Décisions déléguées' "$PLUGIN_ROOT/templates/PRD.md" 2>/dev/null && pass "le PRD a une section des décisions déléguées" \
  || fail "le PRD a une section des décisions déléguées"

finish
