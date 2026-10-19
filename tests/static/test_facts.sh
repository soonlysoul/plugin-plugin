#!/usr/bin/env bash
# The fact base (scripts/facts/facts.json): each fact carries its statement, the Claude Code
# version, the date, the source, how to re-verify it and its status; probes point at existing
# examples; the initial import holds the facts the plan names.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_facts
FACTS="$PLUGIN_ROOT/scripts/facts/facts.json"
PROBES="$PLUGIN_ROOT/scripts/facts/probes"

# check <label> <jq filter returning true>
check() {
  if jq -e "$2" "$FACTS" >/dev/null 2>&1; then pass "$1"; else fail "$1" "$(jq -c "$2" "$FACTS" 2>&1 | head -c 300)"; fi
}

echo "# schéma"
if [[ ! -f $FACTS ]]; then
  fail "base de faits présente" "absente : scripts/facts/facts.json"
  finish
  exit
fi
if ! jq -e 'type == "array" and length > 0' "$FACTS" >/dev/null 2>&1; then
  fail "la base est un tableau JSON non vide" "$FACTS"
  finish
  exit
fi
pass "la base est un tableau JSON non vide ($(jq length "$FACTS") faits)"
check "chaque fait n'a que des champs connus" \
  'all(.[]; (keys - ["id", "statement", "claude_version", "date", "source", "recheck", "status", "probe", "note"]) == [])'
check "id en kebab-case" 'all(.[]; .id | type == "string" and test("^[a-z0-9]+(-[a-z0-9]+)*$"))'
check "id uniques" '(map(.id) | length) == (map(.id) | unique | length)'
check "énoncé, source et façon de revérifier non vides" \
  'all(.[]; ([.statement, .source, .recheck] | all(type == "string" and length > 0)))'
check "date au format AAAA-MM-JJ" 'all(.[]; .date | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))'
check "statut confirmé, infirmé ou à vérifier" 'all(.[]; .status | IN("confirmé", "infirmé", "à vérifier"))'
check "un fait mesuré porte sa version de Claude Code" \
  'all(.[] | select(.status != "à vérifier"); .claude_version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))'
check "un fait à vérifier porte une version ou null" \
  'all(.[] | select(.status == "à vérifier"); .claude_version == null or (.claude_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))'
check "une sonde nomme un exemple, une cible et un résultat attendu" \
  'all(.[] | select(has("probe")); .probe | (keys == ["example", "expect", "target"]) and (.expect | IN("pass", "fail")))'

while IFS=$'\t' read -r id example target; do
  [[ -d $PROBES/$example ]] && pass "sonde $id : exemple présent" || fail "sonde $id : exemple présent" "$PROBES/$example"
  [[ -e $PROBES/$example/$target ]] && pass "sonde $id : cible présente" || fail "sonde $id : cible présente" "$example/$target"
done < <(jq -r '.[] | select(has("probe")) | [.id, .probe.example, .probe.target] | @tsv' "$FACTS")

echo "# import initial"
# expect_fact <id> <status or ""> : the fact exists, with that status when one is given.
expect_fact() {
  local status
  status=$(jq -r --arg id "$1" '.[] | select(.id == $id) | .status' "$FACTS")
  if [[ -z $status ]]; then
    fail "fait $1" "absent de la base"
  elif [[ -n $2 && $status != "$2" ]]; then
    fail "fait $1 : $2" "statut : $status"
  else
    pass "fait $1${2:+ : $2}"
  fi
}
# Phase A of plugin-flutter, then its findings of phases B to F.
for id in manifest-unknown-field hook-exit-1-not-blocking hook-onfailure-block hook-exec-form \
  agent-tools-omitted-inherits-all skill-description-limit-1536 hooks-scope-all-sessions \
  plugin-root-not-in-bash-env validator-ignores-hooks validator-accepts-broken-agent-frontmatter \
  argument-hint-yaml-list dontask-claude-settings-protected; do
  expect_fact "$id" ""
done
# Facts of 2026-10-19.
for id in validate-root-marketplace-only plugin-init-scaffold plugin-eval-command plugin-tag-command \
  plugin-details-cost flutter-forge-guard-rm-rf local-catalog-lag homepage-missing-repo-loads; do
  expect_fact "$id" ""
done
# Phase 9: what the strict validation sees of an MCP declaration.
for id in mcp-validated-with-manifest mcp-declaration-forms mcp-server-unknown-field-tolerated; do
  expect_fact "$id" confirmé
done
# From plugin-dev, unverified, with its two contradictions of phase A.
expect_fact plugindev-when-to-use-deprecated "à vérifier"
expect_fact plugindev-hooks-need-restart "à vérifier"
expect_fact plugin-nixos-description-limit-1024 "à vérifier"
check "toute source plugin-dev est à vérifier" \
  'all(.[] | select(.source | test("plugin-dev")) | select(.id | startswith("plugindev-")); .status == "à vérifier")'
check "au moins trois sondes par la validation stricte" '[.[] | select(has("probe"))] | length >= 3'

finish
