#!/usr/bin/env bash
# The strict frontmatter reader and pp.sh check-skill: the seven broken forms are rejected; a
# skill header at the model (name, description « … Use when …; not for … » with a French
# trigger phrase, argument-hint, when_to_use, never allowed-tools), 1 536 characters at most,
# under 500 lines, no $0-$9; plugin-plugin's own skills conform.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_frontmatter
PP="$PLUGIN_ROOT/scripts/pp.sh"
LIB="$PLUGIN_ROOT/scripts/lib/frontmatter.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "# l'analyseur strict refuse les en-têtes cassés"
if [[ ! -f $LIB ]]; then
  fail "scripts/lib/frontmatter.sh présent" "absent : $LIB"
else
  # shellcheck source=../../scripts/lib/frontmatter.sh
  source "$LIB"
  printf -- '---\nname: ok\ndescription: Un en-tête valide.\ntools: Read, Grep\n---\nCorps\n' >"$work/valid.md"
  printf -- '---\nname: x\ndescription: [unclosed\n---\n' >"$work/bracket.md"
  printf -- '---\nname: x\ndescription: Use when: anything\n---\n' >"$work/colon.md"
  printf -- '---\nname: x\ntools:\n  - Read\n---\n' >"$work/list.md"
  printf -- '---\nname: x\nname: y\n---\n' >"$work/duplicate.md"
  printf -- '---\nname: x\ndescription: "unbalanced\n---\n' >"$work/quote.md"
  printf -- '---\nname: x\ndescription: no end\n' >"$work/unclosed.md"
  printf -- 'name: x\n---\n' >"$work/noopen.md"
  read_frontmatter "$work/valid.md" && [[ ${FM[tools]} == "Read, Grep" ]] \
    && pass "un en-tête valide est lu" || fail "un en-tête valide est lu" "$FM_ERROR"
  for broken in bracket colon list duplicate quote unclosed noopen; do
    if read_frontmatter "$work/$broken.md"; then fail "refuse $broken"; else pass "refuse $broken ($FM_ERROR)"; fi
  done
fi

echo "# check-skill"
# skill <name> <frontmatter lines> [body]: writes skills/<name>/SKILL.md under $work.
skill() {
  mkdir -p "$work/skills/$1"
  printf -- '---\n%s\n---\n\n%s\n' "$2" "${3:-Corps du skill.}" >"$work/skills/$1/SKILL.md"
  printf '%s' "$work/skills/$1/SKILL.md"
}
GOOD='name: demo
description: "Do one thing. Use when Soon asks for it; not for anything else. « fais la chose »."
argument-hint: "[cible]"
when_to_use: "When the thing is needed."'
run_check() {
  PP_OUTPUT=$("$BASH" "$PP" check-skill "$1" 2>&1)
  PP_STATUS=$?
}
run_check "$(skill demo "$GOOD")"
[[ $PP_STATUS == 0 && $PP_OUTPUT == *conforme* ]] && pass "un skill au modèle est conforme" \
  || fail "un skill au modèle est conforme" "exit $PP_STATUS ; ${PP_OUTPUT:0:300}"
# refused <label> <frontmatter> <pattern> [body]
refused() {
  run_check "$(skill demo "$2" "${4:-}")"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$3" <<<"$PP_OUTPUT"; then pass "$1 : refusé, règle nommée"
  else fail "$1 : refusé, règle nommée" "exit $PP_STATUS ; ${PP_OUTPUT:0:300}"; fi
}
refused "en-tête cassé" "${GOOD/argument-hint: \"\[cible\]\"/argument-hint: [cible]}" 'indicateur YAML'
refused "allowed-tools" "$GOOD
allowed-tools: Bash" 'allowed-tools'
refused "clé inconnue" "$GOOD
version: 1.0.0" 'clé inconnue : version'
refused "argument-hint absent" "$(grep -v '^argument-hint' <<<"$GOOD")" 'argument-hint absent'
refused "when_to_use absent" "$(grep -v '^when_to_use' <<<"$GOOD")" 'when_to_use absent'
refused "nom différent du dossier" "${GOOD/name: demo/name: autre}" 'nom'
refused "sans « Use when »" "${GOOD/Use when Soon asks for it/Whenever}" 'Use when'
refused "sans « not for »" "${GOOD/not for anything else/even for the rest}" 'not for'
refused "sans phrase française citée" "${GOOD/ « fais la chose »./}" 'phrase de déclenchement'
long=$(printf 'x%.0s' {1..1500})
refused "plus de 1 536 caractères" "${GOOD/Do one thing./Do one thing $long.}" '1 536'
refused "\$1 dans le corps" "$GOOD" '\$0-\$9' 'Lance la commande sur $1.'
many=$(printf 'ligne\n%.0s' {1..500})
refused "500 lignes ou plus" "$GOOD" '500 lignes' "$many"

echo "# les skills de plugin-plugin"
for file in "$PLUGIN_ROOT"/skills/*/SKILL.md; do
  run_check "$file"
  rel=${file#"$PLUGIN_ROOT"/}
  [[ $PP_STATUS == 0 ]] && pass "$rel conforme" || fail "$rel conforme" "$PP_OUTPUT"
done

finish
