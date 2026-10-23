#!/usr/bin/env bash
# The model is plugin-plugin's own (decision i, US-38): no component, template, test, eval,
# manifest or usage document names another plugin of Soon's, nor reads a copy of one — these
# plugins change over time. History is exempt: CHANGELOG, PROGRESS, PRD, PLAN, the state of
# .plugin-plugin/, and the provenance of each fact (source, statement, note); its id and the way
# to recheck it are not.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_independence
# shellcheck source=../../scripts/lib/check.sh
source "$PLUGIN_ROOT/scripts/lib/check.sh"

# Soon's other plugins, by their published and former names, and the read copies the tests used
# to need. Bracketed letters keep these patterns from matching this very file.
OTHERS='plugin-[f]lutter|plugin-[n]ixos|flutter-[f]orge|build/[r]ef|PP_[R]EF_[D]IR'
HISTORY='^(CHANGELOG\.md|PROGRESS\.md|docs/PRD\.md|docs/PLAN\.md|\.plugin-plugin/.*|scripts/facts/facts\.json)$'

files=$(visible_files "$PLUGIN_ROOT")
[[ -n $files ]] && pass "fichiers du plugin listés" || fail "fichiers du plugin listés" "aucun sous $PLUGIN_ROOT"

echo "# composants, gabarits, tests, évaluations, manifestes, documents d'usage"
hits=""
while IFS= read -r file; do
  [[ -n $file && ! $file =~ $HISTORY ]] || continue
  hits+=$(grep -nIoE -- "$OTHERS" "$PLUGIN_ROOT/$file" 2>/dev/null | sed "s#^#$file:#")$'\n'
done <<<"$files"
hits=$(grep . <<<"$hits")
[[ -z $hits ]] && pass "aucun ne nomme un autre plugin ni ne lit sa copie" \
  || fail "aucun ne nomme un autre plugin ni ne lit sa copie" "$(wc -l <<<"$hits") occurrences : $(head -n 12 <<<"$hits" | tr '\n' ' ')"

echo "# base de faits : identifiants et façons de revérifier"
facts="$PLUGIN_ROOT/scripts/facts/facts.json"
hits=$(jq -r '.[] | . as $f | del(.source, .statement, .note) | tostring | select(test("'"$OTHERS"'")) | $f.id' "$facts" 2>&1)
[[ -z $hits ]] && pass "aucun fait n'exige un autre plugin pour se revérifier" \
  || fail "aucun fait n'exige un autre plugin pour se revérifier" "$(tr '\n' ' ' <<<"$hits")"

finish
