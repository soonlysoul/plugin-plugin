#!/usr/bin/env bash
# An approved framing for plugin-recettes, written as pp.sh init-state and approve would.
set -euo pipefail
dir=plugin-recettes
mkdir -p "$dir/docs" "$dir/.plugin-plugin"
printf '# Décisions déléguées\n\n' >"$dir/.plugin-plugin/decisions.md"
: >"$dir/.plugin-plugin/approvals.log"
for doc in PRD ARCHITECTURE; do
  printf '# %s — plugin-recettes\n\n**Statut : APPROUVÉ** le 2026-10-19 (« je valide »).\n\n- **Nom** : `plugin-recettes`.\n\n## Solution\n\nGérer mes recettes de cuisine.\n' \
    "$doc" >"$dir/docs/$doc.md"
  fingerprint=$(awk '!done && /^\*\*Statut : (BROUILLON|REVUE|APPROUVÉ)\*\*/ { done = 1; next } { print }' "$dir/docs/$doc.md" |
    sha256sum | cut -d' ' -f1)
  printf '2026-10-19\tdocs/%s.md\t%s\tje valide\n' "$doc" "$fingerprint" >>"$dir/.plugin-plugin/approvals.log"
done
