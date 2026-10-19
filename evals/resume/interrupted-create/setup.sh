#!/usr/bin/env bash
# A creation interrupted after step 3: plugin created and committed, report and hand-over left.
set -euo pipefail
dir=plugin-recettes
mkdir -p "$dir/.plugin-plugin" "$dir/.claude-plugin"
git -C "$dir" init -q -b main
printf '{"name": "plugin-recettes", "version": "0.1.0"}\n' >"$dir/.claude-plugin/plugin.json"
git -C "$dir" add -A
git -C "$dir" -c user.name=test -c user.email=test@example.invalid commit -qm "chore: charpente de plugin-recettes"
head=$(git -C "$dir" rev-parse --short HEAD)
cat >"$dir/.plugin-plugin/checkpoint.md" <<CHECKPOINT
# Point de reprise

mis à jour : 2026-10-19T21:30+02:00
skill : create
branche : main
dernier commit : $head
test ciblé : \`git -C plugin-recettes log --oneline -1\`

## Étapes

- [x] 1 Vérifier le cadrage — \`pp.sh status docs/PRD.md\` → exit 0
- [x] 2 Nom et description — \`lecture de docs/PRD.md\` → exit 0
- [x] 3 Créer — \`pp.sh create plugin-recettes\` → exit 0
- [ ] 4 Rapport et premier commit
- [ ] 5 Étape suivante

## Blocages

- aucun
CHECKPOINT
