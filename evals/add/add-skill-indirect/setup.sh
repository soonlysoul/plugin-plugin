#!/usr/bin/env bash
# plugin-changelog, the witness of phase 15, as it stood after its creation: framing approved, no
# component yet; its architecture names the three to add.
set -euo pipefail
dir=plugin-changelog
repo=https://github.com/soonlysoul/$dir
mkdir -p "$dir/.claude-plugin" "$dir/docs" "$dir/tests"
printf '{"name": "%s", "version": "0.1.0", "description": "Draft, guard and review the in-progress entry of a plugin'"'"'s French CHANGELOG, at the house format.", "author": {"name": "Soon"}, "homepage": "%s", "repository": "%s", "license": "MIT"}\n' "$dir" "$repo" "$repo" >"$dir/.claude-plugin/plugin.json"
printf '{"name": "%s", "owner": {"name": "Soon"}, "plugins": [{"name": "%s", "source": "./"}]}\n' "$dir" "$dir" >"$dir/.claude-plugin/marketplace.json"
cat >"$dir/docs/ARCHITECTURE.md" <<'EOF'
# Architecture — plugin-changelog

**Statut : APPROUVÉ** — 2026-10-20, « oui »

| Composant | Type | Histoire | Rôle |
| --- | --- | --- | --- |
| `draft-entry` | skill | US-1 | Rédige la section « en cours » du CHANGELOG au format de la maison. |
| `changelog-guard` | hook PreToolUse, fail-closed | US-2 | Refuse une modification du CHANGELOG qui casse le format ou touche une version datée. |
| `changelog-reviewer` | agent, lecture seule | US-3 | Nomme les commits depuis la dernière étiquette absents de l'entrée « en cours ». |
EOF
cat >"$dir/CHANGELOG.md" <<'EOF'
# Journal des versions

## [0.1.0] — en cours

### Ajouté

- Charpente posée par plugin-plugin le 2026-10-20 : manifeste, marketplace locale, licence, documents et suite de tests `tests/run-all.sh`.
EOF
printf '#!/usr/bin/env bash\necho "réussies : 0, échouées : 0"\n' >"$dir/tests/run-all.sh"
git -C "$dir" init -q -b main
