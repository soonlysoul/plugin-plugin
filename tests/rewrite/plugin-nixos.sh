#!/usr/bin/env bash
# The rewrite of plugin-nixos at the model (phase 14): a test of plugin-plugin, never published.
# pp.sh rebuild lays the scaffolding and imports the content as is; this recipe then makes only the
# changes the model imposes — hooks in exec form, the hooks/scripts/ tree, the model's harness —,
# each one closing a gap pp.sh check lists on the original, and declares the MCP server again with
# pp.sh add-mcp. Then it proves the rewrite: its ported
# suite exits 0, check finds no gap, every case of the original suite has its equivalent, and the
# original has not changed.
# Usage: bash tests/rewrite/plugin-nixos.sh ORIGINAL DIR   (DIR absent or empty)
# Exit codes: 0 rewritten and proven; 1 a proof fails or the port no longer applies; 2 a
# prerequisite is missing.
set -uo pipefail
shopt -u patsub_replacement 2>/dev/null
# Each suite run here checks the folder it lives in, whatever its caller points the harnesses at.
unset PLUGIN_UNDER_TEST NIXOS_PLUGIN_RACINE

PP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PP="$PP_ROOT/scripts/pp.sh"
orig=${1:-} dest=${2:-}

die() { printf '%s\n' "$1" >&2; exit "${2:-1}"; }
[[ -n $orig && -n $dest ]] || die "usage : bash tests/rewrite/plugin-nixos.sh ORIGINAL DOSSIER"
for tool in jq git; do command -v "$tool" >/dev/null 2>&1 || die "bloqué : $tool introuvable dans le PATH." 2; done
[[ $(git -C "$orig" show HEAD:.claude-plugin/plugin.json 2>/dev/null | jq -r .name 2>/dev/null) == plugin-nixos ]] \
  || die "refusé : $orig n'est pas un dépôt de plugin-nixos."

# state <repo>: HEAD, git status without taking the index lock, and the sum of every file but .git/.
state() {
  printf '%s|%s|%s' "$(git -C "$1" rev-parse HEAD)" "$(GIT_OPTIONAL_LOCKS=0 git -C "$1" status --porcelain)" \
    "$(cd "$1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
}
before=$(state "$orig")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# replace_once <file> <old> <new>: the one occurrence of a literal text replaced. Absent or repeated,
# the original has changed since the port was written: stop rather than guess.
replace_once() {
  local file=$1 old=$2 new=$3 content
  content=$(<"$dest/$file")
  [[ $content == *"$old"* ]] || die "échec du portage : texte attendu absent de $file : « ${old%%$'\n'*} »"
  [[ ${content#*"$old"} != *"$old"* ]] || die "échec du portage : texte répété dans $file : « ${old%%$'\n'*} »"
  printf '%s\n' "${content/"$old"/"$new"}" >"$dest/$file"
}
# move <from> <to>: a file of the original, moved where the model puts it.
move() { mkdir -p "$(dirname "$dest/$2")" && mv "$dest/$1" "$dest/$2" || die "échec du portage : $1 → $2"; }

# Where the model puts what the original kept elsewhere; applied to the files that cite these
# paths, and to the labels of the original's cases, to pair them with the ported ones.
PATH_MAP=(-e 's#hooks/garde-nixos\.sh#hooks/scripts/garde-nixos.sh#g'
  -e 's#hooks/lib-commande\.sh#hooks/scripts/lib/lib-commande.sh#g'
  -e 's#tests/test_garde\.sh#tests/hooks/test_garde_nixos.sh#g'
  -e 's#tests/test_nixconf\.sh#tests/static/test_nixconf.sh#g'
  -e 's#tests/test_statique\.sh#tests/static/test_statique.sh#g')
# The one case the model turns around — the original required the oldest hook form —, and a
# duration the case measures.
CASE_MAP=(-e 's#^hooks\.json : forme « command » seule, sans args ni onFailure$#hooks.json : forme exec, le garde dans args, onFailure block#'
  -e 's#(mesuré : [0-9]* s)$#(mesuré : N s)#')

printf "== liste de travail : pp.sh check sur l'original\n"
"$BASH" "$PP" check "$orig"
printf '\n== pp.sh rebuild : charpente produite, contenu importé tel quel\n'
"$BASH" "$PP" rebuild "$orig" "$dest" >"$work/rebuild.log" 2>&1
rc=$?
cat "$work/rebuild.log"
grep -qx 'original intact : HEAD, git status et empreintes identiques' "$work/rebuild.log" || die "échec : pp.sh rebuild (exit $rc)"
[[ -f $dest/.claude-plugin/plugin.json ]] || die "échec : pp.sh rebuild n'a rien produit (exit $rc)"

printf '\n== portage : ce que le modèle impose\n'
echo "- [arborescence des hooks] hooks/garde-nixos.sh → hooks/scripts/ ; hooks/lib-commande.sh → hooks/scripts/lib/"
move hooks/garde-nixos.sh hooks/scripts/garde-nixos.sh
move hooks/lib-commande.sh hooks/scripts/lib/lib-commande.sh
replace_once hooks/scripts/garde-nixos.sh "if [ ! -r \"\$ici/lib-commande.sh\" ]; then
  printf 'BLOQUÉ par garde-nixos.sh : lib-commande.sh introuvable à côté du garde.\n' >&2" \
  "if [ ! -r \"\$ici/lib/lib-commande.sh\" ]; then
  printf 'BLOQUÉ par garde-nixos.sh : lib/lib-commande.sh introuvable à côté du garde.\n' >&2"
replace_once hooks/scripts/garde-nixos.sh "# shellcheck source=lib-commande.sh
. \"\$ici/lib-commande.sh\"" "# shellcheck source=lib/lib-commande.sh
. \"\$ici/lib/lib-commande.sh\""
replace_once hooks/scripts/garde-nixos.sh 'verifier_cmd="bash ${ici%/hooks}/scripts/nixconf verifier"' \
  'verifier_cmd="bash ${ici%/hooks/scripts}/scripts/nixconf verifier"'

echo "- [forme des hooks] [hooks] forme exec, le garde seul dans args, onFailure block : il est fail-closed"
replace_once hooks/scripts/garde-nixos.sh "# PreToolUse / matcher Bash|Monitor. Sortie : 0 laisse passer, 2 refuse et
# renvoie stderr à Claude." "# PreToolUse / matcher Bash|Monitor. Sortie : 0 laisse passer, 2 refuse et
# renvoie stderr à Claude.
# Fail-closed : une commande gardée qu'il ne sait pas juger est refusée
# (sortie 2), et hooks.json pose \"onFailure\": \"block\"."
jq '.hooks.PreToolUse[0].hooks[0] |= ((.command | capture("^bash \"(?<s>[^\"]+)\"$").s) as $script
      | {type, command: "bash", args: [($script | sub("/hooks/garde-nixos\\.sh$"; "/hooks/scripts/garde-nixos.sh"))], timeout, onFailure: "block"})' \
  "$dest/hooks/hooks.json" >"$work/hooks.json" || die "échec du portage : hooks/hooks.json"
# Arrays of strings on one line, as the model writes them.
sed -E ':a;N;$!ba;s/\[\n\s*("[^"]*")\n\s*\]/[\1]/g' "$work/hooks.json" >"$dest/hooks/hooks.json"

echo "- [arborescence] modeles/ → scripts/modeles/ : le gabarit de nixconf, rangé avec son outil (décision a)"
move modeles/flake.nix scripts/modeles/flake.nix
rmdir "$dest/modeles"
replace_once scripts/nixconf 'modeles="$ici/../modeles"' 'modeles="$ici/modeles"'

echo "- [harnais] tests/test_garde.sh → tests/hooks/test_garde_nixos.sh ; test_nixconf.sh, test_statique.sh → tests/static/"
move tests/test_garde.sh tests/hooks/test_garde_nixos.sh
move tests/test_nixconf.sh tests/static/test_nixconf.sh
move tests/test_statique.sh tests/static/test_statique.sh
sed -i "${PATH_MAP[@]}" "$dest/ARCHITECTURE.md" "$dest/scripts/nixconf" \
  "$dest/tests/hooks/test_garde_nixos.sh" "$dest/tests/static/test_nixconf.sh" "$dest/tests/static/test_statique.sh"
# The model's helpers in place of the original's: pass, fail, skip, finish, restricted_path,
# bash_input; PLUGIN_ROOT and PLUGIN_UNDER_TEST in place of RACINE and NIXOS_PLUGIN_RACINE. The
# cases themselves stay word for word.
for file in tests/hooks/test_garde_nixos.sh tests/static/test_nixconf.sh tests/static/test_statique.sh; do
  replace_once "$file" '# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"' '# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"'
  sed -i -E -e 's/\bRACINE\b/PLUGIN_ROOT/g' -e 's/^(\s*)reussi /\1pass /' -e 's/^(\s*)echoue /\1fail /' \
    -e 's/^(\s*)saute /\1skip /' -e 's/^terminer$/finish/' -e 's/\$\(chemin_restreint /$(restricted_path /g' \
    -e 's/\$\(entree_outil /$(bash_input /g' "$dest/$file"
done
helpers='# Portage au harnais du modèle (plugin-plugin, phase 14) : les cas
# d'"'"'origine, mot pour mot, sur les aides de tests/lib.sh.
attendre() { if eval "$2"; then pass "$1"; else fail "$1" "condition fausse : $2"; fi; }'
replace_once tests/hooks/test_garde_nixos.sh 'SUITE=test_garde' "SUITE=test_garde
$helpers
GARDE=\"\$SCRIPTS/garde-nixos.sh\"
passe() { run_hook \"\$GARDE\" \"\$(bash_input \"\$1\" \"\${2:-Bash}\")\"; expect_status \"passe   : \$1\" 0; }
refuse() { run_hook \"\$GARDE\" \"\$(bash_input \"\$1\" \"\${2:-Bash}\")\"; expect_blocked \"refuse  : \$1\"; }"
replace_once tests/static/test_nixconf.sh 'SUITE=test_nixconf' "SUITE=test_nixconf
$helpers
NIXCONF=\"\$PLUGIN_ROOT/scripts/nixconf\"
# Une suite ne dépend pas de la configuration Nix de la session qui la lance.
unset NIXOS_CONF NIX_CONFIG"
replace_once tests/static/test_statique.sh 'SUITE=test_statique' "SUITE=test_statique
$helpers
NIXCONF=\"\$PLUGIN_ROOT/scripts/nixconf\""
replace_once tests/static/test_statique.sh "# La forme la plus ancienne — une chaîne « command » — et aucun champ récent
# (args, onFailure) : le plugin doit tourner sur le claude-code de nixpkgs
# stable, en retard sur la série courante.
verifier_json \"hooks.json : forme « command » seule, sans args ni onFailure\" '[.. | objects | select(has(\"args\") or has(\"onFailure\"))] | length == 0' \"\$HOOKS_JSON\"" \
  "# La forme exec du modèle — Claude Code 2.1.295 au moins — et onFailure block :
# le garde est fail-closed.
verifier_json \"hooks.json : forme exec, le garde dans args, onFailure block\" '.hooks.PreToolUse[0].hooks[0] | .command == \"bash\" and .args == [\"\${CLAUDE_PLUGIN_ROOT}/hooks/scripts/garde-nixos.sh\"] and .onFailure == \"block\"' \"\$HOOKS_JSON\""
replace_once tests/static/test_statique.sh "done < <(jq -r '.. | .command? // empty' \"\$HOOKS_JSON\"" \
  "done < <(jq -r '.. | objects | (.command, .args[]?) | strings' \"\$HOOKS_JSON\""
replace_once tests/static/test_statique.sh 'for script in "$PLUGIN_ROOT"/hooks/*.sh "$PLUGIN_ROOT"/scripts/* "$PLUGIN_ROOT"/tests/*.sh; do
  attendre' 'for script in "$PLUGIN_ROOT"/hooks/scripts/*.sh "$PLUGIN_ROOT"/hooks/scripts/lib/*.sh "$PLUGIN_ROOT"/scripts/* "$PLUGIN_ROOT"/tests/*.sh "$PLUGIN_ROOT"/tests/*/*.sh; do
  [ -f "$script" ] || continue
  attendre'
replace_once tests/static/test_statique.sh '  for script in "$PLUGIN_ROOT"/hooks/*.sh "$PLUGIN_ROOT"/scripts/*; do
    attendre' '  for script in "$PLUGIN_ROOT"/hooks/scripts/*.sh "$PLUGIN_ROOT"/hooks/scripts/lib/*.sh "$PLUGIN_ROOT"/scripts/*; do
    [ -f "$script" ] || continue
    attendre'
replace_once tests/static/test_statique.sh '"$PLUGIN_ROOT/scripts" "$PLUGIN_ROOT/modeles" "$PLUGIN_ROOT/.mcp.json"' \
  '"$PLUGIN_ROOT/scripts" "$PLUGIN_ROOT/.mcp.json"'
leftover=$(grep -nwE 'RACINE|NIXOS_PLUGIN_RACINE|reussi|echoue|saute|terminer|chemin_restreint|entree_outil' \
  "$dest/tests/hooks/test_garde_nixos.sh" "$dest/tests/static/test_nixconf.sh" "$dest/tests/static/test_statique.sh")
[[ -z $leftover ]] || die "échec du portage : aide de l'ancien harnais encore appelée : $leftover"

echo "- [racine] CHANGELOG au format du modèle (## [x.y.z]), PROGRESS.md et docs/ décrivant la réécriture"
sed -i -E 's/^## ([0-9]+\.[0-9]+\.[0-9]+) — /## [\1] — /' "$dest/CHANGELOG.md"
replace_once ARCHITECTURE.md "Un poste en 26.05 peut ensuite déclarer le claude-code de son canal.
\`hooks/hooks.json\` s'en tient donc à la forme la plus ancienne, une chaîne
\`command\`, sans \`args\` ni \`onFailure\`, et \`tests/static/test_statique.sh\` l'impose. Le
validateur de la 2.1.223 accepte ces champs récents (mesuré), mais ce qu'il en
fait à l'exécution ne l'est pas. La forme ancienne, elle, fonctionne partout." \
  "Réécrit au modèle par plugin-plugin, \`hooks/hooks.json\` prend la forme exec :
\`command\` « bash », le garde seul dans \`args\`, \`\"onFailure\": \"block\"\`. Elle
demande Claude Code 2.1.295 au moins, et \`tests/static/test_statique.sh\`
l'impose. La 2.1.296 de la première session y suffit. La 2.1.223 de la 26.05
est en dessous : son validateur accepte ces champs (mesuré), ce qu'elle en
fait à l'exécution ne l'est pas."
sha=$(git -C "$orig" rev-parse --short HEAD)
version=$(jq -r .version "$dest/.claude-plugin/plugin.json")
cat >"$dest/PROGRESS.md" <<EOF
# PROGRESS — plugin-nixos

Réécriture au modèle de plugin-flutter, produite par plugin-plugin le $(date +%F) depuis
plugin-nixos $version à $sha : un test de plugin-plugin (phase 14), jamais publié.

## État courant

Charpente de plugin-plugin ; contenu métier de l'original importé tel quel, sauf ce que le modèle
impose : forme exec des hooks, arborescence \`hooks/scripts/\`, harnais de tests. La suite portée
garde chaque cas d'origine. Le travail de plugin-nixos lui-même se suit dans son dépôt.
EOF
cat >"$dest/docs/INSTALLATION.md" <<'EOF'
# Installation — plugin-nixos

Claude Code **2.1.295 ou plus** requis : les hooks sont en forme exec. La procédure, première
session d'un poste neuf comprise, est dans le [README](../README.md#installer).

## Portée du garde

Installé pour le compte, le plugin pose son garde, `hooks/scripts/garde-nixos.sh`, dans toutes
les sessions de la machine, Flutter et web comprises. Il y reste inerte hors des commandes Nix :
voir [ce que le garde refuse](../README.md#ce-que-le-garde-refuse).
EOF
cat >"$dest/docs/USER_GUIDE.md" <<'EOF'
# Guide d'utilisation — plugin-nixos

Les quatre skills — `cherche`, `installe`, `modifie`, `verifie` — et leur enchaînement sont décrits
dans le README : [premier usage](../README.md#premier-usage) et
[où il cherche la configuration](../README.md#où-il-cherche-la-configuration).
EOF
cat >"$dest/docs/SECURITY.md" <<'EOF'
# Sécurité — plugin-nixos

- [Ce que le garde refuse](../README.md#ce-que-le-garde-refuse) et
  [ce que le plugin ne fait pas](../README.md#ce-quil-ne-fait-pas) : le README.
- Les décisions derrière le garde : [ARCHITECTURE](../ARCHITECTURE.md).
- Aucun secret dans le dépôt ; aucune installation impérative dans ce que le plugin exécute.
EOF
cat >"$dest/docs/TROUBLESHOOTING.md" <<'EOF'
# Dépannage — plugin-nixos

| Symptôme | Cause probable | Que faire |
| --- | --- | --- |
| Le serveur MCP annonce « disponible à la session suivante » | Premier démarrage : `mcp-nixos` se construit | Voir [le serveur MCP au premier démarrage](../README.md#le-serveur-mcp-au-premier-démarrage) |
| `claude plugin validate` inconnu | Claude Code de nixpkgs 25.05 (1.0.85) | Voir [installer](../README.md#installer) |
| `bash tests/run-all.sh` sort en 2 | `jq` ou `claude` absent du PATH | Les prendre dans un shell éphémère, comme à l'installation |
EOF

# Last, since pp.sh add-mcp refuses a plugin off the model: the server, declared by plugin-plugin.
echo "- [MCP] le serveur nixos redéclaré par pp.sh add-mcp, comme en phase 9 : même déclaration, son test, la section « Serveurs MCP » du README"
declared=$(jq -cS . "$dest/.mcp.json")
jq -e '.mcpServers | keys == ["nixos"] and (.nixos | keys == ["args", "command"] and .command == "bash" and (.args | length) == 1)' \
  "$dest/.mcp.json" >/dev/null || die "échec du portage : .mcp.json n'a plus la forme attendue (le seul serveur nixos, bash et son lanceur)."
launcher=$(jq -r '.mcpServers.nixos.args[0] | ltrimstr("${CLAUDE_PLUGIN_ROOT}/")' "$dest/.mcp.json")
rm "$dest/.mcp.json"
"$BASH" "$PP" add-mcp "$dest" --name nixos --launcher "$launcher" | sed 's/^/  /'
((PIPESTATUS[0] == 0)) || die "échec du portage : pp.sh add-mcp"
[[ $(jq -cS . "$dest/.mcp.json") == "$declared" ]] || die "échec du portage : la déclaration de pp.sh add-mcp n'est pas celle de l'original : $(jq -c . "$dest/.mcp.json")"

printf '\n== suite portée : bash tests/run-all.sh dans la réécriture\n'
(cd "$dest" && bash tests/run-all.sh) >"$work/suite.log" 2>&1
suite_rc=$?
grep -E '^test_[a-z_]+ : [0-9]+ réussis|^  (ok|ÉCHEC|sauté|bloqué) +(\.|\.claude-plugin/plugin\.json|skills|agents)( \(absent\))?$|^(réussies|échouées|sautées|bloquées|alertes) :|^  - ' "$work/suite.log"
printf 'suite portée : exit %d\n' "$suite_rc"

printf '\n== pp.sh check sur la réécriture\n'
"$BASH" "$PP" check "$dest"
check_rc=$?

printf "\n== cas d'origine : chacun a son équivalent dans la suite portée\n"
# cases <log>: the label of each case a suite printed, its status dropped.
cases() { sed -nE 's/^  (ok|ÉCHEC|sauté) +//p' "$1"; }
git clone -q "$orig" "$work/orig" || die "échec : git clone de $orig"
printf "| suite d'origine | réussis | portée | réussis | sans équivalent |\n| --- | --- | --- | --- | --- |\n"
missing_total=0
for pair in tests/test_garde.sh:tests/hooks/test_garde_nixos.sh tests/test_nixconf.sh:tests/static/test_nixconf.sh \
  tests/test_statique.sh:tests/static/test_statique.sh; do
  old=${pair%%:*} new=${pair#*:}
  (cd "$work/orig" && bash "$old") >"$work/old.log" 2>&1
  (cd "$dest" && bash "$new") >"$work/new.log" 2>&1
  cases "$work/old.log" | sed "${PATH_MAP[@]}" | sed "${CASE_MAP[@]}" | LC_ALL=C sort >"$work/old.cases"
  cases "$work/new.log" | sed "${CASE_MAP[@]}" | LC_ALL=C sort >"$work/new.cases"
  LC_ALL=C comm -23 "$work/old.cases" "$work/new.cases" >"$work/missing"
  missing=$(grep -c . "$work/missing")
  missing_total=$((missing_total + missing))
  printf '| %s | %s | %s | %s | %d |\n' "$old" "$(grep -oE '[0-9]+ réussis, [0-9]+ échoués, [0-9]+ sautés' "$work/old.log" | tail -n 1)" \
    "$new" "$(grep -oE '[0-9]+ réussis, [0-9]+ échoués, [0-9]+ sautés' "$work/new.log" | tail -n 1)" "$missing"
  sed 's/^/  sans équivalent : /' "$work/missing"
done
printf "cas d'origine sans équivalent : %d\n" "$missing_total"

after=$(state "$orig")
if [[ $after != "$before" ]]; then
  printf "ÉCHEC : l'original a changé pendant la réécriture (HEAD, git status ou empreintes).\n"
  exit 1
fi
printf '\noriginal intact : HEAD, git status et empreintes identiques\n'
((suite_rc == 0 && check_rc == 0 && missing_total == 0)) || exit 1
printf "réécriture au modèle : suite portée verte, aucun écart, chaque cas d'origine gardé\n"
