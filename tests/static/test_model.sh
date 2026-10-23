#!/usr/bin/env bash
# docs/MODEL.md, the only source of the model (decision i, US-38): a status line; one section per
# rule, each with its check and its reason; every category of gap pp.sh check can name points to
# a rule; every fact a rule cites is in the base; every kind pp.sh out-of-scope refuses is
# excluded there with what would reopen it, and no refusal leans on another plugin's usage.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_model
MODEL="$PLUGIN_ROOT/docs/MODEL.md"
PP="$PLUGIN_ROOT/scripts/pp.sh"
KINDS="mcp-code channel lsp output-style command plugin-option plugin-dependency"

if [[ ! -f $MODEL ]]; then
  fail "docs/MODEL.md présent" "absent"
  finish
  exit
fi
pass "docs/MODEL.md présent"
grep -qE '^\*\*Statut : (BROUILLON|REVUE|APPROUVÉ)\*\*' "$MODEL" && pass "ligne de statut" || fail "ligne de statut" "aucune ligne « **Statut : … ** »"

# items <prefix>: each list item of the model that starts with <prefix>, its wrapped lines joined,
# one per line.
items() {
  awk -v p="$1" '
    on && /^(- |#|$)/ { print line; on = 0 }
    index($0, p) == 1 { line = $0; on = 1; next }
    on { sub(/^ +/, " "); line = line $0 }
    END { if (on) print line }' "$MODEL"
}

echo "# une section par règle, son contrôle et sa raison"
# rules: one line per rule, « title<TAB>has check<TAB>has reason ».
rules=$(awk '
  function flush() { if (title != "") printf "%s\t%d\t%d\n", title, check, reason }
  /^### R[0-9]+ / { flush(); title = $0; check = 0; reason = 0; next }
  /^##? / { flush(); title = "" }
  title != "" && /^- \*\*Contrôle\*\* : / { check = 1 }
  title != "" && /^- \*\*Raison\*\* : / { reason = 1 }
  END { flush() }' "$MODEL")
[[ $(grep -c . <<<"$rules") -ge 10 ]] && pass "au moins dix règles (### R<n>)" || fail "au moins dix règles (### R<n>)" "$(grep -c . <<<"$rules") trouvées"
missing=$(awk -F'\t' '$2 == 0 || $3 == 0 { print $1 }' <<<"$rules")
[[ -z $missing ]] && pass "chaque règle a son contrôle et sa raison" || fail "chaque règle a son contrôle et sa raison" "$(tr '\n' '|' <<<"$missing")"

echo "# chaque catégorie de check renvoie à une règle"
checks=$(items '- **Contrôle** : ')
while IFS= read -r category; do
  grep -qF -- "\`$category\`" <<<"$checks" && pass "check $category : une règle" || fail "check $category : une règle" "aucun « Contrôle » ne cite \`$category\`"
done < <(grep -oE "[\"'#]\[[^]\"'\$]+\]" "$PLUGIN_ROOT/scripts/lib/check.sh" | cut -c2- | sort -u)

echo "# chaque fait cité est dans la base"
cited=$(items '- **Faits** : ' | grep -oE '`[a-z0-9-]+`' | tr -d '`' | sort -u)
[[ -n $cited ]] && pass "des faits sont cités" || fail "des faits sont cités" "aucune ligne « - **Faits** : `…` »"
unknown=$(comm -23 <(printf '%s\n' "$cited") <(jq -r '.[].id' "$PLUGIN_ROOT/scripts/facts/facts.json" | sort -u))
[[ -z $unknown ]] && pass "aucun fait inconnu" || fail "aucun fait inconnu" "$(tr '\n' ' ' <<<"$unknown")"

echo "# exclusions"
for kind in $KINDS; do
  line=$(items "- **\`$kind\`**")
  [[ -n $line && $line == *Rouvert* ]] && pass "exclusion $kind : raison et ce qui la rouvrirait" \
    || fail "exclusion $kind : raison et ce qui la rouvrirait" "${line:-aucun élément « - **\`$kind\`** »}"
  refusal=$("$BASH" "$PP" out-of-scope "$kind" 2>&1)
  [[ $refusal == refusé* && $refusal == *rouvert* && $refusal != *"aucun plugin du modèle"* ]] \
    && pass "refus $kind : raison propre et réouverture" || fail "refus $kind : raison propre et réouverture" "$refusal"
done

finish
