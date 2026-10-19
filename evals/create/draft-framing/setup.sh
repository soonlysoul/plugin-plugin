#!/usr/bin/env bash
# A framing still in draft: the creation must be refused.
set -euo pipefail
mkdir -p plugin-brouillon/docs plugin-brouillon/.plugin-plugin
: >plugin-brouillon/.plugin-plugin/approvals.log
for doc in PRD ARCHITECTURE; do
  printf '# %s — plugin-brouillon\n\n**Statut : BROUILLON**\n\nÀ trancher.\n' "$doc" >"plugin-brouillon/docs/$doc.md"
done
