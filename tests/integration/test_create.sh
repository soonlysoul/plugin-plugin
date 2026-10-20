#!/usr/bin/env bash
# pp.sh create: refuses a name out of the rule or already taken (marketplace soon, GitHub
# repository, both read through a gh stub), a folder holding anything but an approved framing;
# leaves a refused folder identical byte for byte; creates a plugin whose own suite and strict
# validation pass with no hand edit.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_create
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A gh stub: the marketplace soon lists plugin-flutter and plugin-nixos; the repository
# soonlysoul/plugin-taken-repo exists; STUB_GH_FAIL=1 makes every call fail like a network error,
# STUB_GH_REPO_FAIL=1 only the repository lookups.
mkdir "$work/stub"
cat >"$work/stub/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STUB_GH_LOG:-/dev/null}"
if [[ ${STUB_GH_FAIL:-0} == 1 ]]; then echo "error connecting to api.github.com" >&2; exit 1; fi
case "$*" in
  "api repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json"*)
    printf '%s' '{"name":"soon","owner":{"name":"Soon"},"plugins":[{"name":"plugin-flutter","source":{"source":"github","repo":"soonlysoul/plugin-flutter"}},{"name":"plugin-nixos","source":{"source":"github","repo":"soonlysoul/plugin-nixos"}}]}' ;;
  "api repos/soonlysoul/plugin-taken-repo"*) echo '{"full_name":"soonlysoul/plugin-taken-repo"}' ;;
  "api repos/soonlysoul/"*) if [[ ${STUB_GH_REPO_FAIL:-0} == 1 ]]; then echo "error connecting to api.github.com" >&2; exit 1; fi ;;&
  "api repos/soonlysoul/"*) echo '{"message":"Not Found","status":"404"}'; echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  *) echo "gh stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
EOF
chmod +x "$work/stub/gh"
STUBPATH="$work/stub:$PATH"

# framed <dir> [draft]: a folder holding an approved framing, or a draft one.
framed() {
  mkdir -p "$1/docs"
  bash "$PP" init-state "$1" >/dev/null
  printf '# PRD — essai\n\n**Statut : BROUILLON**\n\nUn plugin d essai.\n' >"$1/docs/PRD.md"
  printf '# Architecture — essai\n\n**Statut : BROUILLON**\n\nAucun composant.\n' >"$1/docs/ARCHITECTURE.md"
  if [[ ${2:-} != draft ]]; then
    bash "$PP" approve "$1/docs/PRD.md" --quote "je valide" >/dev/null
    bash "$PP" approve "$1/docs/ARCHITECTURE.md" --quote "je valide" >/dev/null
  fi
}
# tree_sum <dir>: fingerprint of every path and every file content under <dir>.
tree_sum() {
  (cd "$1" && find . -print0 | sort -z | xargs -0 -I{} sh -c 'printf "%s\n" "{}"; [ -f "{}" ] && sha256sum < "{}"' | sha256sum | cut -d' ' -f1)
}
run_create() {
  local dir=$1 name=$2
  shift 2
  PP_OUTPUT=$(env "$@" "$BASH" "$PP" create "$dir" --name "$name" --description "Plugin d'essai." 2>&1)
  PP_STATUS=$?
}
# refused <label> <dir> <name> <exit> <pattern> [env...]: refused with that exit code and reason,
# the folder identical.
refused() {
  local label=$1 dir=$2 name=$3 code=$4 pattern=$5 before
  shift 5
  before=$(tree_sum "$dir")
  run_create "$dir" "$name" "$@"
  if [[ $PP_STATUS == "$code" ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT"; then pass "$label : refusé, raison nommée"
  else fail "$label : refusé, raison nommée" "exit $PP_STATUS ; sortie : ${PP_OUTPUT:0:300}"; fi
  [[ $(tree_sum "$dir") == "$before" ]] && pass "$label : dossier identique" || fail "$label : dossier identique"
}

echo "# nom hors règle"
framed "$work/rule"
refused "majuscules" "$work/rule" Plugin-Essai 1 'majuscules' PATH="$STUBPATH"
refused "soulignés" "$work/rule" plugin_essai 1 'soulignés' PATH="$STUBPATH"
refused "préfixe absent" "$work/rule" flutter-forge 1 'préfixe plugin-' PATH="$STUBPATH"
refused "domaine vide" "$work/rule" plugin- 1 'domaine vide' PATH="$STUBPATH"

echo "# nom déjà pris"
refused "dans la marketplace soon" "$work/rule" plugin-flutter 1 'déjà dans la marketplace soon' PATH="$STUBPATH"
refused "dépôt GitHub existant" "$work/rule" plugin-taken-repo 1 'le dépôt soonlysoul/plugin-taken-repo existe' PATH="$STUBPATH"
refused "GitHub illisible" "$work/rule" plugin-essai 2 'bloqué : GitHub' PATH="$STUBPATH" STUB_GH_FAIL=1
refused "dépôt illisible, marketplace lisible" "$work/rule" plugin-essai 2 'bloqué : GitHub illisible \(gh api repos/soonlysoul/plugin-essai\)' PATH="$STUBPATH" STUB_GH_REPO_FAIL=1
no_gh=$(path_without gh)
refused "gh absent" "$work/rule" plugin-essai 2 'bloqué : gh introuvable' PATH="$no_gh"
rm -rf "$no_gh"

echo "# dossier cible"
framed "$work/extra"
printf 'travail existant\n' >"$work/extra/notes.txt"
refused "fichier hors cadrage" "$work/extra" plugin-essai 1 'notes\.txt' PATH="$STUBPATH"
framed "$work/draft" draft
refused "cadrage en brouillon" "$work/draft" plugin-essai 1 'cadrage non approuvé : docs/PRD\.md \(BROUILLON\)' PATH="$STUBPATH"
framed "$work/forged" draft
sed -i 's/^\*\*Statut : BROUILLON\*\*$/**Statut : APPROUVÉ** le 2026-10-19 (« je valide »)./' "$work/forged/docs/PRD.md" "$work/forged/docs/ARCHITECTURE.md"
refused "approbation écrite à la main" "$work/forged" plugin-essai 1 'cadrage non approuvé : docs/PRD\.md' PATH="$STUBPATH"
run_create "$work/nope" plugin-essai PATH="$STUBPATH"
[[ $PP_STATUS == 1 && $PP_OUTPUT == *"cadrage non approuvé"* && ! -e $work/nope ]] \
  && pass "dossier sans cadrage : refusé, rien n'est créé" || fail "dossier sans cadrage : refusé, rien n'est créé" "exit $PP_STATUS ; ${PP_OUTPUT:0:200}"

echo "# création"
target="$work/plugin-essai"
framed "$target"
framing_before=$( (cd "$target" && sha256sum docs/PRD.md docs/ARCHITECTURE.md .plugin-plugin/approvals.log) )
log="$work/gh.log"
run_create "$target" plugin-essai PATH="$STUBPATH" STUB_GH_LOG="$log"
if [[ $PP_STATUS == 0 ]]; then pass "create : exit 0"; else fail "create : exit 0" "exit $PP_STATUS ; sortie : $(tail -n 15 <<<"$PP_OUTPUT" | tr '\n' '|')"; fi
grep -qF 'api repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json' "$log" 2>/dev/null \
  && pass "la marketplace est lue sur GitHub par gh api" || fail "la marketplace est lue sur GitHub par gh api"
grep -qE '^api repos/soonlysoul/plugin-essai( |$)' "$log" 2>/dev/null && pass "le dépôt soonlysoul/plugin-essai est cherché" \
  || fail "le dépôt soonlysoul/plugin-essai est cherché"
grep -qE 'suite du plugin créé : exit 0' <<<"$PP_OUTPUT" && pass "create lance la suite du plugin créé, qui passe" \
  || fail "create lance la suite du plugin créé, qui passe" "$(tail -n 5 <<<"$PP_OUTPUT" | tr '\n' '|')"
for file in .claude-plugin/plugin.json .claude-plugin/marketplace.json LICENSE README.md CHANGELOG.md PROGRESS.md .gitignore \
  docs/INSTALLATION.md docs/USER_GUIDE.md docs/SECURITY.md docs/TROUBLESHOOTING.md \
  tests/lib.sh tests/headers.sh tests/mcp.sh tests/run-all.sh tests/static/test_manifest.sh tests/static/test_paths.sh \
  tests/static/test_run_all.sh tests/static/test_headers.sh; do
  [[ -f $target/$file ]] && pass "créé : $file" || fail "créé : $file"
done
jq -e '.name == "plugin-essai" and .version == "0.1.0" and .description == "Plugin d'"'"'essai." and .author == {name: "Soon"}
       and .license == "MIT" and .homepage == "https://github.com/soonlysoul/plugin-essai" and .repository == .homepage' \
  "$target/.claude-plugin/plugin.json" >/dev/null 2>&1 && pass "plugin.json au modèle, sans e-mail" \
  || fail "plugin.json au modèle, sans e-mail" "$(cat "$target/.claude-plugin/plugin.json" 2>&1 | head -c 300)"
grep -q '@' "$target/.claude-plugin/plugin.json" 2>/dev/null && fail "aucune adresse e-mail dans plugin.json" || pass "aucune adresse e-mail dans plugin.json"
personal=$(grep -rnE --exclude-dir=.git '/home/|/Users/|/nix/store/' "$target" 2>/dev/null)
[[ -z $personal ]] && pass "aucun chemin personnel ni du store dans ce qui est produit" \
  || fail "aucun chemin personnel ni du store dans ce qui est produit" "$personal"
[[ -e $target/CLAUDE.md ]] && fail "aucun CLAUDE.md à la racine" || pass "aucun CLAUDE.md à la racine"
[[ $( (cd "$target" && sha256sum docs/PRD.md docs/ARCHITECTURE.md .plugin-plugin/approvals.log) ) == "$framing_before" ]] \
  && pass "le cadrage approuvé est laissé intact" || fail "le cadrage approuvé est laissé intact"
[[ $(git -C "$target" symbolic-ref --short HEAD 2>/dev/null) == main ]] && pass "git initialisé, branche main" \
  || fail "git initialisé, branche main"

echo "# le plugin créé, sans retouche"
suite_output=$(cd "$work" && bash "$target/tests/run-all.sh" 2>&1)
suite_status=$?
[[ $suite_status == 0 ]] && pass "bash tests/run-all.sh du plugin créé : exit 0" \
  || fail "bash tests/run-all.sh du plugin créé : exit 0" "exit $suite_status ; $(tail -n 12 <<<"$suite_output" | tr '\n' '|')"
grep -qx 'échouées : 0' <<<"$suite_output" && pass "son bilan compte zéro échec" || fail "son bilan compte zéro échec"
for target_name in . .claude-plugin/plugin.json; do
  grep -qE "^  ok +${target_name//./\\.}$" <<<"$suite_output" && pass "sa validation stricte passe : $target_name" \
    || fail "sa validation stricte passe : $target_name"
done
check_output=$("$BASH" "$PP" check "$target" 2>&1)
[[ $? == 0 ]] && grep -q '^écarts : 0' <<<"$check_output" && pass "pp.sh check : aucun écart au modèle" \
  || fail "pp.sh check : aucun écart au modèle" "$(tr '\n' '|' <<<"$check_output" | head -c 400)"
refused "plugin déjà créé" "$target" plugin-essai 1 'hors cadrage' PATH="$STUBPATH"

finish
