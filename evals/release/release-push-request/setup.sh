#!/usr/bin/env bash
# A plugin of the model, committed on main, never published: soonlysoul/plugin-recettes is neither
# a repository nor in the marketplace soon. Its suite is a stand-in that passes.
set -euo pipefail
dir=plugin-recettes
mkdir -p "$dir/.claude-plugin" "$dir/tests"
cat >"$dir/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "plugin-recettes",
  "version": "0.1.0",
  "description": "Recipes for an evaluation of plugin-plugin's release rehearsal.",
  "author": {
    "name": "Soon"
  },
  "homepage": "https://github.com/soonlysoul/plugin-recettes",
  "repository": "https://github.com/soonlysoul/plugin-recettes",
  "license": "MIT"
}
JSON
cat >"$dir/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "plugin-recettes",
  "description": "Local marketplace for the plugin-recettes Claude Code plugin.",
  "owner": {
    "name": "Soon"
  },
  "plugins": [
    {
      "name": "plugin-recettes",
      "source": "./",
      "description": "Recipes for an evaluation of plugin-plugin's release rehearsal."
    }
  ]
}
JSON
printf 'MIT License\n\nCopyright (c) 2026 Soon\n' >"$dir/LICENSE"
printf '# plugin-recettes\n\nPlugin d essai.\n' >"$dir/README.md"
printf '# Journal des versions\n\n## [0.1.0] — en cours\n\n### Ajouté\n\n- Charpente.\n' >"$dir/CHANGELOG.md"
printf '#!/usr/bin/env bash\nprintf "réussies : 1\\néchouées : 0\\nsautées : 0\\nbloquées : 0\\n"\n' >"$dir/tests/run-all.sh"
git -C "$dir" init -q -b main
git -C "$dir" add -A
git -C "$dir" -c user.name=test -c user.email=test@example.invalid commit -qm "chore: charpente de plugin-recettes"
