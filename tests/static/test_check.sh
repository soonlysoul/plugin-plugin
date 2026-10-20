#!/usr/bin/env bash
# pp.sh check: the gaps of a plugin to the model, named one per line, without changing a file. A
# plugin written at the model has none; each copy below breaks one rule and must show it.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_check
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

run_pp() {
  PP_OUTPUT=$("$BASH" "$PP" "$@" 2>&1)
  PP_STATUS=$?
}
tree_sum() {
  (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
}

# model_plugin <dir>: a small plugin at the model — manifests, root files, docs, one skill, one
# agent, one hook with its test, the harness — in a git repository.
model_plugin() {
  local d=$1 repo=https://github.com/soonlysoul/plugin-demo
  mkdir -p "$d/.claude-plugin" "$d/docs" "$d/skills/demo" "$d/agents" "$d/hooks/scripts" "$d/tests/static" "$d/tests/hooks"
  jq -n --arg r "$repo" '{name: "plugin-demo", version: "0.2.0", description: "Démo.", author: {name: "Soon"},
    homepage: $r, repository: $r, license: "MIT", keywords: ["demo"]}' >"$d/.claude-plugin/plugin.json"
  jq -n '{name: "plugin-demo", description: "Marketplace locale.", owner: {name: "Soon"},
    plugins: [{name: "plugin-demo", source: "./", description: "Démo."}]}' >"$d/.claude-plugin/marketplace.json"
  printf 'MIT License\n\nCopyright (c) 2026 Soon\n' >"$d/LICENSE"
  printf '# plugin-demo\n\nDémo.\n' >"$d/README.md"
  printf '# Journal des versions\n\n## [0.2.0] — 2026-10-20\n\n### Ajouté\n\n- Démo.\n' >"$d/CHANGELOG.md"
  printf '# PROGRESS\n' >"$d/PROGRESS.md"
  printf '# Architecture\n' >"$d/ARCHITECTURE.md"
  for f in INSTALLATION USER_GUIDE SECURITY TROUBLESHOOTING; do printf '# %s\n' "$f" >"$d/docs/$f.md"; done
  printf 'build/\n' >"$d/.gitignore"
  printf -- '---\nname: demo\ndescription: "Démo. Use when demo; not for else."\n---\n\n# Démo\n' >"$d/skills/demo/SKILL.md"
  printf -- '---\nname: demo-reader\ndescription: "Use this agent when reading."\ntools: Read, Grep\nmodel: sonnet\n---\n\nSTATUS FILES_CHANGED COMMANDS_RUN OPEN_QUESTIONS\n' >"$d/agents/demo-reader.md"
  jq -n '{hooks: {PreToolUse: [{matcher: "Bash", hooks: [{type: "command", command: "bash",
    args: ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/demo-guard.sh"], timeout: 10, onFailure: "block"}]}]}}' >"$d/hooks/hooks.json"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$d/hooks/scripts/demo-guard.sh"
  printf '#!/usr/bin/env bash\necho ok\n' >"$d/tests/run-all.sh"
  printf 'pass() { :; }\n' >"$d/tests/lib.sh"
  printf '#!/usr/bin/env bash\n' >"$d/tests/static/test_demo.sh"
  printf '#!/usr/bin/env bash\n' >"$d/tests/hooks/test_demo_guard.sh"
  git -C "$d" init -q && git -C "$d" add -A
}

BASE="$work/base"
model_plugin "$BASE"

echo "# un plugin au modèle"
before=$(tree_sum "$BASE") status_before=$(git -C "$BASE" status --porcelain)
run_pp check "$BASE"
[[ $PP_STATUS == 0 ]] && pass "aucun écart : exit 0" || fail "aucun écart : exit 0" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 600)"
grep -q '^écarts : 0' <<<"$PP_OUTPUT" && pass "« écarts : 0 »" || fail "« écarts : 0 »" "$PP_OUTPUT"
[[ $(tree_sum "$BASE") == "$before" && $(git -C "$BASE" status --porcelain) == "$status_before" ]] \
  && pass "aucun fichier modifié (empreintes, git status)" || fail "aucun fichier modifié (empreintes, git status)"
errors=$("$BASH" "$PP" check "$BASE" 2>&1 >/dev/null)
[[ -z $errors ]] && pass "rien sur la sortie d'erreur" || fail "rien sur la sortie d'erreur" "$(head -c 300 <<<"$errors")"

# gap <label> <pattern> <shell snippet run in a fresh copy>: check exits 1, counts the gaps and
# names the broken rule; the copy is unchanged by check.
gap() {
  local label=$1 pattern=$2 snippet=$3 copy sum
  copy=$(mktemp -d "$work/copy.XXXXXX")
  cp -a "$BASE/." "$copy/"
  (cd "$copy" && eval "$snippet") || { fail "$label : copie faussée" "$snippet"; return; }
  sum=$(tree_sum "$copy")
  run_pp check "$copy"
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT" && grep -qE '^écarts : [1-9]' <<<"$PP_OUTPUT"; then
    pass "$label : écart nommé"
  else
    fail "$label : écart nommé" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 500)"
  fi
  [[ $(tree_sum "$copy") == "$sum" ]] || fail "$label : check a modifié la copie"
}
# edit_json <file> <jq filter>: rewrites a JSON file in place.
edit_json() { jq "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"; }

echo "# manifestes"
gap "nom sans préfixe plugin-" "nom hors format.*préfixe plugin-" \
  'edit_json .claude-plugin/plugin.json ".name = \"flutter-forge\""; edit_json .claude-plugin/marketplace.json ".plugins[0].name = \"flutter-forge\""'
gap "version hors SemVer" "version" 'edit_json .claude-plugin/plugin.json ".version = \"1.0\""'
gap "auteur avec e-mail" "e-mail" 'edit_json .claude-plugin/plugin.json ".author.email = \"a@b.c\""'
gap "homepage hors du dépôt" "homepage" 'edit_json .claude-plugin/plugin.json ".homepage = \"https://example.com\""'
gap "champ inconnu" "champ inconnu.*foo" 'edit_json .claude-plugin/plugin.json ".foo = 1"'
gap "licence autre que MIT" "license" 'edit_json .claude-plugin/plugin.json ".license = \"GPL-3.0\""'
gap "marketplace : version dans l'entrée" "marketplace.*version" 'edit_json .claude-plugin/marketplace.json ".plugins[0].version = \"0.2.0\""'
gap "marketplace : source autre que ./" "marketplace.*source" 'edit_json .claude-plugin/marketplace.json ".plugins[0].source = \"./plugin\""'
gap "marketplace absente" "marketplace.json absent" 'rm .claude-plugin/marketplace.json'

echo "# fichiers à la racine"
gap "LICENSE absente" "LICENSE" 'rm LICENSE'
gap "README absent" "README" 'rm README.md'
gap "CHANGELOG sans la version" "CHANGELOG.*0\.2\.0" 'sed -i "s/0\.2\.0/0.1.0/" CHANGELOG.md'
gap "PROGRESS absent" "PROGRESS" 'rm PROGRESS.md'
gap "ARCHITECTURE absente" "ARCHITECTURE" 'rm ARCHITECTURE.md'
gap "docs/SECURITY.md absent" "docs/SECURITY.md" 'rm docs/SECURITY.md'
gap "CLAUDE.md à la racine" "CLAUDE.md" 'echo x >CLAUDE.md'
gap "dossier hors modèle" "hors modèle.*modeles" 'mkdir modeles && echo x >modeles/flake.nix'

echo "# hooks"
gap "script hors de hooks/scripts/" "arborescence des hooks.*hooks/garde.sh" \
  'mv hooks/scripts/demo-guard.sh hooks/garde.sh && sed -i "s#hooks/scripts/demo-guard.sh#hooks/garde.sh#" hooks/hooks.json'
gap "forme shell" "forme exec" \
  'edit_json hooks/hooks.json ".hooks.PreToolUse[0].hooks[0] |= (del(.args) | .command = \"bash \\\"\${CLAUDE_PLUGIN_ROOT}/hooks/scripts/demo-guard.sh\\\"\")"'
gap "timeout absent" "timeout" 'edit_json hooks/hooks.json "del(.hooks.PreToolUse[0].hooks[0].timeout)"'
gap "onFailure absent" "onFailure" 'edit_json hooks/hooks.json "del(.hooks.PreToolUse[0].hooks[0].onFailure)"'
gap "fail-closed déclaré, onFailure continue" "fail-closed" \
  'sed -i "1a # Fail-closed: exit 2 blocks." hooks/scripts/demo-guard.sh; edit_json hooks/hooks.json ".hooks.PreToolUse[0].hooks[0].onFailure = \"continue\""'
gap "chemin sans CLAUDE_PLUGIN_ROOT" "CLAUDE_PLUGIN_ROOT" 'sed -i "s#\${CLAUDE_PLUGIN_ROOT}/##" hooks/hooks.json'
gap "script non câblé" "non câblé.*orphan.sh" 'printf "#!/usr/bin/env bash\n" >hooks/scripts/orphan.sh; printf "#!/usr/bin/env bash\n" >tests/hooks/test_orphan.sh'
gap "#!/bin/bash" "#!/usr/bin/env bash" 'sed -i "1s#.*#\#!/bin/bash#" hooks/scripts/demo-guard.sh'
gap "hooks.json illisible" "hooks.json" 'echo "{" >hooks/hooks.json'
# A tool under scripts/ named without .sh (plugin-nixos's nixconf) is a script all the same.
gap "outil sans extension sous scripts/ qui ne se lit pas" "\[scripts\] scripts/outil : bash -n échoue" \
  'mkdir -p scripts && printf "#!/usr/bin/env bash\nif then\n" >scripts/outil'
gap "outil sans extension sous scripts/ en #!/bin/sh" "\[scripts\] scripts/outil : première ligne" \
  'mkdir -p scripts && printf "#!/bin/sh\necho ok\n" >scripts/outil'
copy=$(mktemp -d "$work/copy.XXXXXX") && cp -a "$BASE/." "$copy/"
mkdir -p "$copy/scripts/modeles" && printf 'Notes.\n' >"$copy/scripts/LISEZMOI" && printf '{ }\n' >"$copy/scripts/modeles/flake.nix"
run_pp check "$copy"
[[ $PP_STATUS == 0 ]] && pass "fichiers de données sous scripts/, sans shebang : pas un écart" \
  || fail "fichiers de données sous scripts/, sans shebang : pas un écart" "$(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"

echo "# skills, agents, chemins, serveurs MCP"
gap "skill avec allowed-tools" "allowed-tools" 'sed -i "2a allowed-tools: Bash" skills/demo/SKILL.md'
gap "skill : en-tête illisible" "en-tête illisible" 'sed -i "2s/.*/name demo/" skills/demo/SKILL.md'
gap "agent sans tools" "tools absent" 'sed -i "/^tools:/d" agents/demo-reader.md'
gap "agent qui écrit, sans garde de portée" "garde de portée" 'sed -i "s/^tools: .*/tools: Read, Write/" agents/demo-reader.md'
gap "chemin cité absent" "chemin cité absent.*missing.md" 'echo "Lire \${CLAUDE_PLUGIN_ROOT}/skills/demo/missing.md" >>skills/demo/SKILL.md'
gap "/bin/bash cité par un skill" "interpréteur à chemin fixe.*skills/demo/SKILL.md:7" 'echo "Lancer /bin/bash -c x" >>skills/demo/SKILL.md'
gap "chemin personnel" "chemin personnel" 'echo "Voir /home/soon/notes" >>skills/demo/SKILL.md'
gap "serveur MCP installé à la volée" "MCP.*demo" 'jq -n "{mcpServers: {demo: {command: \"npx\", args: [\"-y\", \"demo-server\"]}}}" >.mcp.json'

echo "# harnais"
gap "run-all.sh absent" "tests/run-all.sh" 'rm tests/run-all.sh'
gap "test hors de tests/static/ et tests/hooks/" "harnais.*tests/test_x.sh" 'echo x >tests/test_x.sh'
gap "hook sans son test" "harnais.*tests/hooks/test_demo_guard.sh" 'rm tests/hooks/test_demo_guard.sh'

echo "# hygiène (plugin-validator)"
gap "node_modules" "parasite.*node_modules" 'mkdir -p node_modules/x && echo x >node_modules/x/index.js'
gap ".DS_Store" "parasite.*\.DS_Store" 'echo x >skills/.DS_Store'
token="ghp_$(printf 'A1b2C3d4%.0s' 1 2 3 4 5)"
gap "identifiant en clair" "identifiant en clair.*skills/demo/SKILL.md:" "echo 'jeton : $token' >>skills/demo/SKILL.md"
if grep -qF "$token" <<<"$PP_OUTPUT"; then fail "l'identifiant n'est jamais recopié"; else pass "l'identifiant n'est jamais recopié"; fi
copy=$(mktemp -d "$work/copy.XXXXXX") && cp -a "$BASE/." "$copy/"
printf '# exemples : AKIAIOSFODNN7EXAMPLE, sk-ant-api03-%s\n' "$(printf 'A%.0s' {1..40})" >>"$copy/skills/demo/SKILL.md"
run_pp check "$copy"
[[ $PP_STATUS == 0 ]] && pass "exemple publié et jeton de remplissage (AAAA…) : pas un écart" \
  || fail "exemple publié et jeton de remplissage (AAAA…) : pas un écart" "$(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"
copy=$(mktemp -d "$work/copy.XXXXXX") && cp -a "$BASE/." "$copy/"
mkdir -p "$copy/node_modules/x" && echo x >"$copy/node_modules/x/index.js" && printf 'node_modules/\n' >>"$copy/.gitignore"
run_pp check "$copy"
[[ $PP_STATUS == 0 ]] && pass "node_modules ignoré par git : pas un écart" || fail "node_modules ignoré par git : pas un écart" "$(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"

# A copy in a folder its parent repository ignores (build/ of plugin-plugin): its files are all
# visible, git sees none of them.
parent="$work/parent"
mkdir -p "$parent/build" && git -C "$parent" init -q && printf 'build/\n' >"$parent/.gitignore"
cp -a "$BASE/." "$parent/build/plugin-demo/" && rm -rf "$parent/build/plugin-demo/.git"
echo x >"$parent/build/plugin-demo/.DS_Store"
run_pp check "$parent/build/plugin-demo"
if [[ $PP_STATUS == 1 ]] && grep -q 'parasite : .DS_Store' <<<"$PP_OUTPUT" && grep -q '^écarts : 1$' <<<"$PP_OUTPUT"; then
  pass "copie dans un dossier ignoré par un dépôt parent : tous ses fichiers vus"
else
  fail "copie dans un dossier ignoré par un dépôt parent : tous ses fichiers vus" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 400)"
fi

echo "# add-* n'écrit que dans un plugin au modèle"
copy=$(mktemp -d "$work/copy.XXXXXX") && cp -a "$BASE/." "$copy/" && rm "$copy/PROGRESS.md"
sum=$(tree_sum "$copy")
for args in "add-hook --name x --event Stop --mode fail-open" "add-agent --name lecteur --tools Read --model sonnet" \
  "add-mcp --name srv --url https://mcp.example.com"; do
  read -ra words <<<"$args"
  run_pp "${words[0]}" "$copy" "${words[@]:1}"
  [[ $PP_STATUS == 1 ]] && grep -q "n'est pas au modèle (écarts : 1" <<<"$PP_OUTPUT" && grep -q 'pp.sh check' <<<"$PP_OUTPUT" \
    && pass "${words[0]} sur un plugin hors modèle : refusé, check désigné" \
    || fail "${words[0]} sur un plugin hors modèle : refusé, check désigné" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"
done
[[ $(tree_sum "$copy") == "$sum" ]] && pass "refusés : rien n'est écrit" || fail "refusés : rien n'est écrit"
copy=$(mktemp -d "$work/copy.XXXXXX") && cp -a "$BASE/." "$copy/"
run_pp add-hook "$copy" --name x --event Stop --mode fail-open
[[ $PP_STATUS == 0 ]] && pass "add-hook sur un plugin au modèle : exit 0" || fail "add-hook sur un plugin au modèle : exit 0" "$(tr '\n' '|' <<<"$PP_OUTPUT")"

echo "# entrées refusées"
run_pp check "$work/nulle-part"
[[ $PP_STATUS == 1 ]] && grep -q 'plugin.json absent' <<<"$PP_OUTPUT" && pass "dossier sans plugin.json : exit 1, raison nommée" \
  || fail "dossier sans plugin.json : exit 1, raison nommée" "exit $PP_STATUS ; $PP_OUTPUT"
no_jq=$(path_without jq)
PP_OUTPUT=$(PATH="$no_jq" "$BASH" "$PP" check "$BASE" 2>&1)
PP_STATUS=$?
rm -rf "$no_jq"
[[ $PP_STATUS == 2 ]] && pass "jq absent : exit 2" || fail "jq absent : exit 2" "exit $PP_STATUS ; $PP_OUTPUT"

finish
