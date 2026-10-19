#!/usr/bin/env bash
# pp.sh check-skill and check-agent, structure and house style together: a
# skill header at the model (name, description « … Use when …; not for … » with a French
# trigger phrase, argument-hint, when_to_use, never allowed-tools), 1 536 characters at most,
# under 500 lines, no $0-$9; an agent with its tools declared and known, never Agent, a reviewer
# without Write nor Edit, « Use this agent when …; not for … » in 200 to 1 000 characters, its
# responsibilities, approach and report format; plugin-plugin's own skills conform.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_frontmatter
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

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

echo "# check-agent"
DESCRIPTION="Use when Soon needs one bounded task done and reported; this text is long enough to pass the rule of two hundred characters, and it says what the agent does, when to use it and what it returns; not for anything else."
# agent <name> <frontmatter lines> [body]: writes agents/<name>.md under $work.
agent() {
  mkdir -p "$work/agents"
  printf -- '---\n%s\n---\n\n%s\n' "$2" "${3:-$AGENT_BODY}" >"$work/agents/$1.md"
  printf '%s' "$work/agents/$1.md"
}
AGENT_BODY='## Responsibilities

One bounded task.

## Approach

Read, then report.

## Output format

STATUS, FILES_CHANGED, COMMANDS_RUN, OPEN_QUESTIONS.'
AGENT="name: doc-reviewer
description: \"Use this agent when ${DESCRIPTION#Use when }\"
tools: Read, Grep, Glob
model: sonnet"
run_agent() {
  PP_OUTPUT=$("$BASH" "$PP" check-agent "$1" 2>&1)
  PP_STATUS=$?
}
run_agent "$(agent doc-reviewer "$AGENT")"
[[ $PP_STATUS == 0 && $PP_OUTPUT == *conforme* ]] && pass "un agent au modèle est conforme" \
  || fail "un agent au modèle est conforme" "exit $PP_STATUS ; ${PP_OUTPUT:0:300}"
# refused_agent <label> <frontmatter> <pattern> [name] [body]
refused_agent() {
  run_agent "$(agent "${4:-doc-reviewer}" "$2" "${5:-$AGENT_BODY}")"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$3" <<<"$PP_OUTPUT"; then pass "$1 : refusé, règle nommée"
  else fail "$1 : refusé, règle nommée" "exit $PP_STATUS ; ${PP_OUTPUT:0:300}"; fi
}
refused_agent "tools absent" "$(grep -v '^tools' <<<"$AGENT")" 'tools absent'
refused_agent "outil Agent" "${AGENT/tools: Read, Grep, Glob/tools: Read, Agent}" 'outil Agent (est )?interdit'
refused_agent "outil inconnu" "${AGENT/tools: Read, Grep, Glob/tools: Read, Telepathy}" 'outil inconnu : Telepathy'
refused_agent "relecteur qui écrit" "${AGENT/tools: Read, Grep, Glob/tools: Read, Edit}" 'relecteur'
refused_agent "model absent" "$(grep -v '^model' <<<"$AGENT")" 'model absent'
refused_agent "nom de deux caractères" "${AGENT/name: doc-reviewer/name: ab}" '3 à 50' ab
refused_agent "nom qui finit par un tiret" "${AGENT/name: doc-reviewer/name: doc-}" '3 à 50' doc-
refused_agent "description sans « Use this agent when »" "${AGENT/Use this agent when/Call it when}" 'Use this agent when'
refused_agent "description sans « not for »" "${AGENT/; not for anything else/}" 'not for'
refused_agent "description trop courte" "${AGENT/description: */description: \"Use this agent when short; not for long.\"}" '200 à 1 000'
refused_agent "format de rapport absent" "$AGENT" 'OPEN_QUESTIONS' doc-reviewer "${AGENT_BODY/, OPEN_QUESTIONS/}"
refused_agent "démarche absente" "$AGENT" 'Approach' doc-reviewer "${AGENT_BODY/Approach/Steps}"
refused_agent "clé inconnue" "$AGENT
permissionMode: plan" 'clé inconnue : permissionMode'

echo "# les skills de plugin-plugin"
for file in "$PLUGIN_ROOT"/skills/*/SKILL.md; do
  run_check "$file"
  rel=${file#"$PLUGIN_ROOT"/}
  [[ $PP_STATUS == 0 ]] && pass "$rel conforme" || fail "$rel conforme" "$PP_OUTPUT"
done

finish
