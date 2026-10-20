#!/usr/bin/env bash
# pp.sh release, the rehearsal of a publication, on a plugin created by pp.sh create: refused on a
# dirty tree, a red strict validation or suite (US-23); version proposed by the nature of the
# change, CHANGELOG entry drafted, tag checked by claude plugin tag --dry-run (US-22); marketplace
# read on GitHub through gh api (US-28); context cost per component, alert above 1 000 tokens
# (US-25); every gesture listed with its exact command and none run — the gh and git push stubs
# log nothing, the plugin is left identical (US-24); the install or update command (US-29).
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../helpers/plugin.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/plugin.sh"
SUITE=test_release
PP="$PLUGIN_ROOT/scripts/pp.sh"
NAME=plugin-essai-release
TODAY=$(date +%F)

work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
# The test works from its throwaway folder, and git never looks for a repository above it: a wrong
# path can then never reach the repository the test is run from.
cd "$work" || exit 2
export GIT_CEILING_DIRECTORIES="$work"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

# Stubs. gh: a read (gh api without a method or a field) is logged to STUB_GH_READS and answered;
# any other call is a gesture, logged to STUB_GH_LOG and refused. The marketplace soon lists
# plugin-flutter, plugin-nixos and the names of STUB_LISTED, these described by
# STUB_ENTRY_DESCRIPTION (« Plugin d'essai. » by default) in its marketplace.json and by
# STUB_README_DESCRIPTION in the table of its README, whose install commands leave them out with
# STUB_README_NO_INSTALL=1; the repositories of STUB_REPOS exist, described by
# STUB_REPO_DESCRIPTION; the branches of STUB_BRANCHES exist in the marketplace, with STUB_PR as
# their open PR; STUB_GH_FAIL=1 fails every read like a network error. git: push is a gesture,
# logged to STUB_PUSH_LOG and refused; anything else is the real git. claude: plugin details
# answers STUB_ALWAYS_ON tokens when it is set; plugin tag is logged to STUB_TAG_LOG, and refused
# with STUB_TAG_REFUSE when it is set; anything else is the real claude.
real_git=$(command -v git) real_claude=$(command -v claude)
mkdir -p "$work/stub" "$work/stub-nogh"
printf '#!/usr/bin/env bash\nsource %q\n' "$PLUGIN_ROOT/tests/helpers/plugin.sh" >"$work/stub/gh"
cat >>"$work/stub/gh" <<'EOF'
essai="Plugin d'essai."
gesture=0
[[ $1 == api ]] || gesture=1
for arg in "$@"; do
  case $arg in -X* | --method* | -f | -F | --field* | --raw-field* | --input*) gesture=1 ;; esac
done
if ((gesture)); then
  printf '%s\n' "$*" >>"${STUB_GH_LOG:-/dev/null}"
  echo "gh stub: gesture refused: $*" >&2
  exit 3
fi
printf '%s\n' "$*" >>"${STUB_GH_READS:-/dev/null}"
if [[ ${STUB_GH_FAIL:-0} == 1 ]]; then echo "error connecting to api.github.com" >&2; exit 1; fi
case $2 in
  repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json)
    jq -n --arg listed "${STUB_LISTED:-}" --arg d "${STUB_ENTRY_DESCRIPTION-$essai}" \
      '{name: "soon", description: "Plugins Claude Code de Soon.", owner: {name: "Soon"},
      plugins: ((["plugin-flutter", "plugin-nixos"] | map({name: ., description: "Plugin \(.)."}))
        + ($listed | split(" ") | map(select(length > 0)) | map({name: ., description: $d}))
        | map({name, source: {source: "github", repo: "soonlysoul/\(.name)"}, description}))}' ;;
  repos/soonlysoul/claude-plugins/contents/README.md)
    {
      printf 'plugin-flutter\tPlugin plugin-flutter.\nplugin-nixos\tPlugin plugin-nixos.\n'
      for name in ${STUB_LISTED:-}; do printf '%s\t%s\n' "$name" "${STUB_README_DESCRIPTION-$essai}"; done
    } | market_readme | if [[ ${STUB_README_NO_INSTALL:-0} == 1 ]]; then grep -v "install plugin-essai"; else cat; fi ;;
  repos/soonlysoul/claude-plugins/branches/*)
    if [[ " ${STUB_BRANCHES:-} " == *" ${2##*/} "* ]]; then printf '{"name": "%s"}\n' "${2##*/}"
    else echo '{"message": "Branch not found", "status": "404"}'; echo "gh: Branch not found (HTTP 404)" >&2; exit 1; fi ;;
  repos/soonlysoul/claude-plugins/pulls\?*)
    if [[ -n ${STUB_PR:-} ]]; then printf '[{"number": 7, "html_url": "%s"}]\n' "$STUB_PR"; else echo '[]'; fi ;;
  repos/soonlysoul/*)
    if [[ " ${STUB_REPOS:-} " == *" ${2#repos/soonlysoul/} "* ]]; then
      jq -n --arg n "${2#repos/}" --arg d "${STUB_REPO_DESCRIPTION-$essai}" \
        '{full_name: $n, default_branch: "main", visibility: "public", description: $d}'
    else
      echo '{"message": "Not Found", "status": "404"}'
      echo "gh: Not Found (HTTP 404)" >&2
      exit 1
    fi ;;
  *) echo "gh stub: unexpected read: $*" >&2; exit 3 ;;
esac
EOF
cat >"$work/stub/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [[ \$arg == push ]]; then
    printf '%s\n' "\$*" >>"\${STUB_PUSH_LOG:-/dev/null}"
    echo "git stub: push refused" >&2
    exit 3
  fi
done
exec $(printf %q "$real_git") "\$@"
EOF
cat >"$work/stub/claude" <<EOF
#!/usr/bin/env bash
if [[ -n \${STUB_ALWAYS_ON:-} && " \$* " == *" plugin details "* ]]; then
  printf 'Projected token cost\n  Always-on:   ~%s tok   added to every session\n\n' "\$STUB_ALWAYS_ON"
  printf 'Per-component (rounded)\n  component  always-on  on-invoke\n  demo          ~%s       ~2k\n' "\$STUB_ALWAYS_ON"
  exit 0
fi
if [[ " \$* " == *" plugin tag "* ]]; then
  printf '%s\n' "\$*" >>"\${STUB_TAG_LOG:-/dev/null}"
  if [[ -n \${STUB_TAG_REFUSE:-} ]]; then printf '✘ %s\n' "\$STUB_TAG_REFUSE" >&2; exit 1; fi
fi
exec $(printf %q "$real_claude") "\$@"
EOF
chmod +x "$work/stub/gh" "$work/stub/git" "$work/stub/claude"
ln -s "$work/stub/git" "$work/stub/claude" "$work/stub-nogh/"
STUBPATH="$work/stub:$PATH"

# run_release <dir> [options...] [-- env assignments...]: pp.sh release through the stubs.
run_release() {
  local dir=$1
  local -a opts=()
  shift
  while [[ $# -gt 0 && $1 != -- ]]; do opts+=("$1"); shift; done
  [[ ${1:-} == -- ]] && shift
  PP_OUTPUT=$(env PATH="$STUBPATH" STUB_GH_LOG="$work/gh-gestures.log" STUB_GH_READS="$work/gh-reads.log" \
    STUB_PUSH_LOG="$work/push.log" STUB_TAG_LOG="$work/tag.log" "$@" "$BASH" "$PP" release "$dir" ${opts[@]+"${opts[@]}"} 2>&1)
  PP_STATUS=$?
}
expect_exit() {
  if [[ $PP_STATUS == "$2" ]]; then pass "$1"
  else fail "$1" "attendu exit $2, obtenu $PP_STATUS ; sortie : $(tail -n 12 <<<"$PP_OUTPUT" | tr '\n' '|' | head -c 600)"; fi
}
expect_line() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then pass "$1"
  else fail "$1" "motif absent : $2 ; sortie : $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 600)"; fi
}
refuse_line() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then fail "$1" "motif présent : $(grep -E -- "$2" <<<"$PP_OUTPUT" | head -n 1)"; else pass "$1"; fi
}
# tree_sum <dir>: fingerprint of every path and every file content under <dir>, .git included.
tree_sum() {
  (cd "$1" && find . -print0 | sort -z | xargs -0 -I{} sh -c 'printf "%s\n" "{}"; [ -f "{}" ] && sha256sum < "{}"' | sha256sum | cut -d' ' -f1)
}
# trial <dir>: true for the root of a repository of this test, under its throwaway folder.
trial() {
  [[ $1 == "$work"/* && $1 != *$'\n'* && -d $1 && $(git -C "$1" rev-parse --show-toplevel 2>/dev/null) == "$1" ]] && return 0
  fail "dépôt d'essai sous le dossier jetable" "refusé : « $1 »"
  return 1
}
commit() { trial "$1" && git -C "$1" add -A && git -C "$1" commit -qm "$2"; }
# demo_skill <plugin> <skill>: a skill whose header holds the structure rules of the model, named
# in the README; bare_skill, the same skill, the README left as it was.
demo_skill() {
  bare_skill "$@" || return 1
  printf '\n- Skill `%s`.\n' "$2" >>"$1/README.md"
}
bare_skill() {
  trial "$1" || return 1
  mkdir -p "$1/skills/$2"
  cat >"$1/skills/$2/SKILL.md" <<EOF
---
name: $2
description: "Give the codename of a project. Use when Soon asks for a codename; not for anything else. « nom de code d'Atlas »."
argument-hint: "[projet]"
when_to_use: "When a codename is asked."
---

# $2

Answer with the codename of the project.
EOF
}
# gestures: the commands of the listed gestures, one per line, in order.
gestures() { sed -n 's/^  [0-9]\{1,2\}\. \[\(local\|GitHub\)\] [^:]* : //p' <<<"$PP_OUTPUT"; }
# gesture_keys: one key per listed gesture, in order.
gesture_keys() {
  local command
  while IFS= read -r command; do
    case $command in
      *" release-write "*" --version "*) echo write ;;
      "git -C "*" commit -m "*" -- "*) echo commit ;;
      "claude plugin tag "*) echo tag ;;
      "gh repo create soonlysoul/$NAME --public --description "*) echo repo ;;
      "git -C "*" remote add origin https://github.com/soonlysoul/$NAME.git") echo origin ;;
      "git -C "*" push origin main") echo push-main ;;
      "git -C "*" push origin refs/tags/$NAME--v"*) echo push-tag ;;
      "gh repo edit soonlysoul/$NAME --description "*) echo describe ;;
      "gh repo clone soonlysoul/claude-plugins "*) echo clone ;;
      "git -C "*" switch -c add-$NAME") echo branch ;;
      "git -C "*" switch -c align-$NAME-"*) echo branch ;;
      *" marketplace-entry "*" --name $NAME --description "*" --update") echo entry-update ;;
      *" marketplace-entry "*" --name $NAME --description "*) echo entry ;;
      "git -C "*" commit -am "*) echo market-commit ;;
      "git -C "*" push origin add-$NAME" | "git -C "*" push origin align-$NAME-"*) echo push-branch ;;
      "gh pr create --repo soonlysoul/claude-plugins --base main --head add-$NAME "*) echo pr ;;
      "gh pr create --repo soonlysoul/claude-plugins --base main --head align-$NAME-"*) echo pr ;;
      *) echo "inconnu[$command]" ;;
    esac
  done < <(gestures) | paste -sd' ' -
}
# nothing_sent <label>: the gh and git push stubs logged no gesture.
nothing_sent() {
  [[ ! -s $work/gh-gestures.log ]] && pass "$1 : aucun geste gh" || fail "$1 : aucun geste gh" "$(head -n 3 "$work/gh-gestures.log")"
  [[ ! -s $work/push.log ]] && pass "$1 : aucun git push" || fail "$1 : aucun git push" "$(head -n 3 "$work/push.log")"
}

echo "# plugin d'essai"
if base=$(new_plugin "$work/base" "$NAME"); then pass "plugin d'essai créé par pp.sh create"; else fail "plugin d'essai créé par pp.sh create"; fi
demo_skill "$base" demo
commit "$base" "chore: charpente de $NAME"
# copy <scenario>: a clone of the test plugin, without the clone's origin.
copy() {
  git clone -q "$base" "$work/$1/$NAME" >/dev/null 2>&1 && git -C "$work/$1/$NAME" remote remove origin >/dev/null 2>&1 \
    || { fail "copie $1" "git clone a échoué"; return 1; }
  printf '%s' "$work/$1/$NAME"
}
# published <scenario>: a copy released as 0.1.0 by the local gestures, its origin the GitHub
# repository — rewritten to an empty local bare repository, so that nothing can leave the machine.
published() {
  local dir output
  dir=$(copy "$1") && trial "$dir" || return 1
  if ! output=$(PATH="$STUBPATH" bash "$PP" release-write "$dir" --version 0.1.0 2>&1); then
    fail "publication 0.1.0 de $1 : release-write" "${output:0:300}"
    return 1
  fi
  { git -C "$dir" commit -qm "chore(release): $NAME 0.1.0" -- .claude-plugin/plugin.json CHANGELOG.md \
    && git -C "$dir" tag -a "$NAME--v0.1.0" -m "$NAME 0.1.0" \
    && git init -q --bare "$work/$1/remotes/$NAME.git" \
    && git -C "$dir" config "url.$work/$1/remotes/.insteadOf" https://github.com/soonlysoul/ \
    && git -C "$dir" remote add origin "https://github.com/soonlysoul/$NAME.git"; } >/dev/null 2>&1 \
    || { fail "publication 0.1.0 de $1" "commit, étiquette ou origin"; return 1; }
  printf '%s' "$dir"
}

echo "# refus (US-23), plugin identique"
# refused <label> <dir> <exit> <pattern> [options... [-- env...]]
refused() {
  local label=$1 dir=$2 code=$3 pattern=$4 before
  shift 4
  before=$(tree_sum "$dir")
  run_release "$dir" "$@"
  if [[ $PP_STATUS == "$code" ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT"; then pass "$label : refusé, raison nommée"
  else fail "$label : refusé, raison nommée" "exit $PP_STATUS ; sortie : $(tail -n 8 <<<"$PP_OUTPUT" | tr '\n' '|' | head -c 500)"; fi
  [[ $(tree_sum "$dir") == "$before" ]] && pass "$label : plugin identique" || fail "$label : plugin identique"
}
p=$(copy dirty)
printf 'retouche\n' >>"$p/README.md"
refused "changement non enregistré" "$p" 1 'refusé : changements non enregistrés.*README\.md'
p=$(copy untracked)
printf 'brouillon\n' >"$p/notes.txt"
refused "fichier non suivi" "$p" 1 'refusé : changements non enregistrés.*notes\.txt'
p=$(copy invalid)
jq '. + {bogus: 1}' "$p/.claude-plugin/plugin.json" >"$p/manifest.tmp" && mv "$p/manifest.tmp" "$p/.claude-plugin/plugin.json"
commit "$p" "chore: champ inconnu"
refused "validation stricte rouge" "$p" 1 "refusé : la validation stricte n'est pas verte"
p=$(copy red)
cat >"$p/tests/static/test_rouge.sh" <<'EOF'
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_rouge
fail "toujours rouge"
finish
EOF
commit "$p" "test: toujours rouge"
refused "suite rouge" "$p" 1 "refusé : la suite du plugin n'est pas verte \(exit 1\)"
mkdir -p "$work/nested/$NAME"
git -C "$work/nested" init -q -b main
git -C "$base" archive HEAD | tar -x -C "$work/nested/$NAME"
commit "$work/nested" "chore: un dépôt qui contient le plugin"
refused "plugin hors de la racine de son dépôt" "$work/nested/$NAME" 1 "n'est pas la racine de son dépôt git"
p=$(copy branch)
trial "$p" && git -C "$p" switch -q -c feat/essai
refused "autre branche que main" "$p" 1 'refusé : on publie depuis main.*feat/essai'
p=$(copy tagged)
trial "$p" && git -C "$p" tag -a "$NAME--v0.1.0" -m "$NAME 0.1.0"
refused "rien depuis la dernière étiquette" "$p" 1 "refusé : rien à publier depuis $NAME--v0\.1\.0"
p=$(copy elsewhere)
trial "$p" && git -C "$p" remote add origin "https://github.com/autrui/$NAME.git"
refused "origin ailleurs que sur le dépôt du plugin" "$p" 1 "refusé : origin pointe vers https://github.com/autrui/$NAME\.git"
p=$(copy offline)
refused "GitHub illisible" "$p" 2 'bloqué : GitHub illisible' -- STUB_GH_FAIL=1
no_gh=$(path_without gh)
refused "gh absent" "$p" 2 'bloqué : gh introuvable' -- PATH="$work/stub-nogh:$no_gh"
rm -rf "$no_gh"
refused "claude plugin tag --dry-run refuse" "$p" 1 "refusé : claude plugin tag --dry-run refuse l'étiquette : ✘ Tag \"$NAME--v0\.1\.0\" already exists" \
  -- STUB_TAG_REFUSE="Tag \"$NAME--v0.1.0\" already exists locally."
refused "--bump inconnu" "$p" 1 'refusé : --bump' --bump huge
refused "--bump à la première publication" "$p" 1 'refusé : première publication' --bump minor

echo "# refus : documents et description (US-36, US-35)"
# describe <dir> <jq filter>: plugin.json rewritten by the filter, then committed.
describe() {
  trial "$1" && jq "$2" "$1/.claude-plugin/plugin.json" >"$1/manifest.tmp" && mv "$1/manifest.tmp" "$1/.claude-plugin/plugin.json"
  commit "$1" "chore: description retouchée"
}
p=$(copy noversion)
sed -i -E 's/^Version \*\*[0-9.]+\*\*/Version inconnue/' "$p/README.md"
commit "$p" "docs: version retirée du README"
refused "README sans ligne de version" "$p" 1 'refusé : README\.md n.a pas de ligne « Version \*\*X\.Y\.Z\*\* »'
p=$(copy unnamed)
bare_skill "$p" secret
commit "$p" "feat: skill secret, absent du README"
refused "README qui ne nomme pas un composant" "$p" 1 'refusé : le README ne nomme pas : skill secret ;'
p=$(copy nodesc)
describe "$p" 'del(.description)'
refused "description absente" "$p" 1 'refusé : description absente de \.claude-plugin/plugin\.json'
p=$(copy multiline)
describe "$p" '.description = "Deux\nlignes."'
refused "description sur deux lignes" "$p" 1 'refusé : la description de plugin\.json tient sur plusieurs lignes'
p=$(copy longdesc)
describe "$p" '.description = ([range(351)] | map("x") | join(""))'
refused "description au-delà de 350 caractères" "$p" 1 'refusé : description de plugin\.json de 351 caractères, au-delà des 350 que GitHub accepte'
p=$(copy accents)
describe "$p" '.description = ([range(350)] | map("é") | join(""))'
run_release "$p"
expect_exit "350 caractères accentués : acceptés, comptés en caractères" 0

echo "# première publication : la répétition"
p=$(copy first)
before=$(tree_sum "$p")
rm -f "$work/gh-gestures.log" "$work/gh-reads.log" "$work/push.log" "$work/tag.log"
run_release "$p"
expect_exit "répétition : exit 0" 0
tag_calls=$(cat "$work/tag.log" 2>/dev/null)
[[ $(grep -c . <<<"$tag_calls") == 1 && $tag_calls == "plugin tag --dry-run /"* && $tag_calls != *" $p" ]] \
  && pass "claude plugin tag --dry-run lancé une fois, sur la copie jetable" || fail "claude plugin tag --dry-run lancé une fois, sur la copie jetable" "$tag_calls"
expect_line "annonce : rien n'est envoyé" "^répétition de publication : $NAME — rien n'est envoyé$"
expect_line "dépôt propre, sur main" '^dépôt : .*, branche main, arbre propre$'
expect_line "version de première publication" '^version : 0\.1\.0 \(première publication, version de plugin\.json\)$'
expect_line "coût permanent et seuil (US-25)" '^coût en contexte : ~[0-9]+ tokens permanents \(seuil 1000\)$'
expect_line "coût du composant demo" "^  - demo : ~[0-9.]+k? permanent, ~[0-9.]+k? à l'appel$"
refuse_line "aucune alerte sous le seuil" '^alerte'
expect_line "validation stricte de l'état étiqueté" '^validation stricte : ok \., ok \.claude-plugin/plugin\.json, ok skills$'
expect_line "suite du plugin verte" '^suite du plugin : exit 0 \(réussies : [0-9]+, échouées : 0'
expect_line "entrée du CHANGELOG datée" "^  ## \[0\.1\.0\] — $TODAY$"
expect_line "coût inscrit dans l'entrée" '^  Coût en contexte permanent : ~[0-9]+ tokens — demo ~[0-9.]+k?\.$'
expect_line "étiquette vérifiée par claude plugin tag --dry-run" "^étiquette : $NAME--v0\.1\.0, vérifiée par claude plugin tag --dry-run \(exit 0\)$"
expect_line "marketplace lue sur GitHub (US-28)" "^marketplace soon \(GitHub\) : $NAME absent, PR d'ajout$"
expect_line "dépôt lu sur GitHub" "^dépôt soonlysoul/$NAME \(GitHub\) : absent, à créer$"
expect_line "entrée de marketplace validée" "^marketplace modifiée : validation stricte ok$"
grep -q '^api repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json ' "$work/gh-reads.log" 2>/dev/null \
  && pass "la marketplace est lue par gh api" || fail "la marketplace est lue par gh api" "$(cat "$work/gh-reads.log" 2>&1)"
grep -qx "api repos/soonlysoul/$NAME" "$work/gh-reads.log" 2>/dev/null \
  && pass "le dépôt est cherché par gh api" || fail "le dépôt est cherché par gh api" "$(cat "$work/gh-reads.log" 2>&1)"
keys=$(gesture_keys)
want="write commit tag repo origin push-main push-tag clone branch entry market-commit push-branch pr"
[[ $keys == "$want" ]] && pass "gestes ordonnés, chacun avec sa commande (US-24)" || fail "gestes ordonnés, chacun avec sa commande (US-24)" "obtenu : $keys"
expect_line "étiquette annoncée exactement" "^  3\. \[local\] étiquette : claude plugin tag $p$"
expect_line "PR : coût par composant (US-25)" '^  [0-9]+\. \[GitHub\] PR de marketplace : .*Coût en contexte permanent : ~[0-9]+ tokens — demo ~'
expect_line "annonce : aucun geste exécuté" '^répétition terminée : 13 gestes listés, aucun exécuté$'
expect_line "installation après la fusion (US-29)" '^  claude plugin marketplace update soon$'
expect_line "commande d'installation" "^  claude plugin install $NAME@soon$"
nothing_sent "première publication"
[[ $(tree_sum "$p") == "$before" ]] && pass "plugin identique après la répétition" || fail "plugin identique après la répétition"
[[ -z $(git -C "$p" tag -l) ]] && pass "aucune étiquette posée" || fail "aucune étiquette posée" "$(git -C "$p" tag -l)"

echo "# les gestes locaux annoncés sont exacts"
mapfile -t local_gestures < <(gestures | head -n 3)
for command in "${local_gestures[@]}"; do
  if PATH="$STUBPATH" bash -c "$command" >/dev/null 2>&1; then pass "lancé tel quel : ${command:0:60}"; else fail "lancé tel quel : $command"; fi
done
[[ $(jq -r .version "$p/.claude-plugin/plugin.json") == 0.1.0 ]] && pass "plugin.json : 0.1.0" || fail "plugin.json : 0.1.0"
grep -qx "## \[0.1.0\] — $TODAY" "$p/CHANGELOG.md" && pass "CHANGELOG : [0.1.0] — $TODAY" || fail "CHANGELOG : [0.1.0] — $TODAY"
grep -q 'en cours' "$p/CHANGELOG.md" && fail "CHANGELOG : plus de section en cours" || pass "CHANGELOG : plus de section en cours"
[[ $(git -C "$p" tag -l) == "$NAME--v0.1.0" ]] && pass "étiquette $NAME--v0.1.0 posée" || fail "étiquette $NAME--v0.1.0 posée" "$(git -C "$p" tag -l)"
[[ -z $(git -C "$p" status --porcelain) ]] && pass "arbre propre après le commit de version" || fail "arbre propre après le commit de version" "$(git -C "$p" status --porcelain)"

echo "# release-write"
p=$(copy write)
run_write() { PP_OUTPUT=$(PATH="$STUBPATH" "$BASH" "$PP" release-write "$@" 2>&1); PP_STATUS=$?; }
run_write "$p" --version 0.1
expect_exit "version hors SemVer : refusé" 1
run_write "$p" --version 0.2.0
expect_exit "release-write : exit 0" 0
changed=$(git -C "$p" diff --numstat -- .claude-plugin/plugin.json | cut -f1-2)
[[ $changed == $'1\t1' ]] && pass "plugin.json : seule la ligne de version change" || fail "plugin.json : seule la ligne de version change" "$changed"
[[ $(jq -r .version "$p/.claude-plugin/plugin.json") == 0.2.0 ]] && pass "plugin.json : 0.2.0" || fail "plugin.json : 0.2.0"
grep -qx "## \[0.2.0\] — $TODAY" "$p/CHANGELOG.md" && pass "section en cours datée : [0.2.0] — $TODAY" || fail "section en cours datée : [0.2.0] — $TODAY"
grep -qF 'Version **0.2.0**' "$p/README.md" && pass "README : Version **0.2.0** (US-36)" || fail "README : Version **0.2.0** (US-36)" "$(grep -m 1 'Version' "$p/README.md")"
changed=$(git -C "$p" diff --numstat -- README.md | cut -f1-2)
[[ $changed == $'1\t1' ]] && pass "README : seule la ligne de version change" || fail "README : seule la ligne de version change" "$changed"
[[ -z $(git -C "$p" diff --name-only -- .claude-plugin/marketplace.json) ]] && pass "marketplace locale déjà alignée : inchangée" \
  || fail "marketplace locale déjà alignée : inchangée" "$(git -C "$p" diff -- .claude-plugin/marketplace.json)"
expect_line "release-write nomme le README" '^écrit : .*, README\.md \(Version \*\*0\.2\.0\*\*\)$'
snapshot=$(tree_sum "$p")
run_write "$p" --version 0.2.0
[[ $PP_STATUS == 0 && $(tree_sum "$p") == "$snapshot" ]] && pass "release-write rejoué : rien ne change" || fail "release-write rejoué : rien ne change" "exit $PP_STATUS"
p=$(published write-old)
run_write "$p" --version 0.1.0
expect_exit "version déjà étiquetée : refusé" 1
expect_line "raison : version pas plus récente" 'refusé : 0\.1\.0 .*plus récente.*0\.1\.0'
p=$(copy write-local)
trial "$p" && jq '.plugins[0].description = "Ancienne."' "$p/.claude-plugin/marketplace.json" >"$p/m.tmp" && mv "$p/m.tmp" "$p/.claude-plugin/marketplace.json"
commit "$p" "chore: marketplace locale en retard"
run_write "$p" --version 0.2.0
expect_exit "marketplace locale divergente : exit 0" 0
[[ $(jq -r '.plugins[0].description' "$p/.claude-plugin/marketplace.json") == "Plugin d'essai." ]] \
  && pass "marketplace locale : la description de plugin.json (US-35)" || fail "marketplace locale : la description de plugin.json (US-35)"
changed=$(git -C "$p" diff --numstat -- .claude-plugin/marketplace.json | cut -f1-2)
[[ $changed == $'1\t1' ]] && pass "marketplace locale : seule la description change" || fail "marketplace locale : seule la description change" "$changed"
expect_line "release-write nomme la marketplace locale" '^écrit : .*, \.claude-plugin/marketplace\.json \(description\)$'
p=$(copy write-noversion)
sed -i -E 's/^Version \*\*[0-9.]+\*\*/Version inconnue/' "$p/README.md"
commit "$p" "docs: version retirée du README"
before=$(tree_sum "$p")
run_write "$p" --version 0.2.0
expect_exit "release-write, README sans ligne de version : refusé" 1
expect_line "release-write : raison nommée" 'refusé : .*README\.md n.a pas de ligne « Version \*\*X\.Y\.Z\*\* »'
[[ $(tree_sum "$p") == "$before" ]] && pass "release-write refusé : plugin identique" || fail "release-write refusé : plugin identique"

# After a release, add opens « ## [à venir] — en cours » above the dated section.
p=$(published unreleased)
awk '/^## \[/ && !done { print "## [à venir] — en cours\n\n### Ajouté\n\n- Skill `extra`, entrée écrite par add.\n"; done = 1 } { print }' \
  "$p/CHANGELOG.md" >"$p/changelog.tmp" && mv "$p/changelog.tmp" "$p/CHANGELOG.md"
demo_skill "$p" extra
commit "$p" "feat: ajouter le skill extra"
run_write "$p" --version 0.2.0
expect_exit "section à venir : exit 0" 0
section=$(awk '/^## \[0\.2\.0\] — / { on = 1 } on && /^## \[0\.1\.0\]/ { exit } on' "$p/CHANGELOG.md")
grep -qx "## \[0.2.0\] — $TODAY" <<<"$section" && grep -qxF -- '- Skill `extra`, entrée écrite par add.' <<<"$section" \
  && pass "section à venir datée, ses entrées gardées" || fail "section à venir datée, ses entrées gardées" "$(tr '\n' '|' <<<"$section")"
[[ $(grep -c '^### Ajouté$' <<<"$section") == 1 ]] && pass "aucune entrée rédigée en double" || fail "aucune entrée rédigée en double" "$(tr '\n' '|' <<<"$section")"
[[ $(grep -c "^## \[0\.1\.0\] — $TODAY$" "$p/CHANGELOG.md") == 1 ]] && ! grep -q 'en cours' "$p/CHANGELOG.md" \
  && pass "section publiée intacte, plus de section en cours" || fail "section publiée intacte, plus de section en cours"

echo "# marketplace-entry"
mkdir -p "$work/market/.claude-plugin"
PATH="$STUBPATH" gh api repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json >"$work/market/.claude-plugin/marketplace.json"
PATH="$STUBPATH" gh api repos/soonlysoul/claude-plugins/contents/README.md >"$work/market/README.md"
cp "$work/market/README.md" "$work/readme-before.md"
run_entry() { PP_OUTPUT=$("$BASH" "$PP" marketplace-entry "$@" 2>&1); PP_STATUS=$?; }
row="| \`$NAME\` | Plugin d'essai. | [soonlysoul/$NAME](https://github.com/soonlysoul/$NAME) |"
install="claude plugin install $NAME@soon --scope user"
run_entry "$work/market" --name "$NAME" --description "Plugin d'essai."
expect_exit "marketplace-entry : exit 0" 0
jq -e --arg n "$NAME" '.plugins[-1] == {name: $n, source: {source: "github", repo: "soonlysoul/\($n)"}, description: "Plugin d'"'"'essai."}
                       and (.plugins | length) == 3' "$work/market/.claude-plugin/marketplace.json" >/dev/null \
  && pass "entrée au format de la marketplace soon" || fail "entrée au format de la marketplace soon" "$(jq -c '.plugins[-1]' "$work/market/.claude-plugin/marketplace.json")"
added=$(diff "$work/readme-before.md" "$work/market/README.md" | grep -E '^[<>]')
[[ $added == "> $row"$'\n'"> $install" ]] && pass "README : la ligne du plugin et sa commande d'installation, rien d'autre (US-35)" \
  || fail "README : la ligne du plugin et sa commande d'installation, rien d'autre (US-35)" "$(tr '\n' '|' <<<"$added")"
[[ $(grep -n -A1 -F '| `plugin-nixos` |' "$work/market/README.md" | tail -n 1) == *"-$row" ]] \
  && pass "README : la ligne à la fin du tableau" || fail "README : la ligne à la fin du tableau"
[[ $(grep -n -A1 -Fx 'claude plugin install plugin-nixos@soon --scope user' "$work/market/README.md" | tail -n 1) == *"-$install" ]] \
  && pass "README : la commande à la suite des autres, dans le premier bloc" || fail "README : la commande à la suite des autres, dans le premier bloc"
expect_line "marketplace-entry nomme le README" "^écrit : $work/market/README\.md \(ligne de $NAME, commande d'installation\)$"
run_entry "$work/market" --name plugin-flutter --description "Doublon."
expect_exit "nom déjà présent : refusé" 1
expect_line "nom déjà présent : --update proposé" 'refusé : plugin-flutter est déjà dans .* ; --update pour aligner sa description'
cp "$work/market/README.md" "$work/readme-before.md"
run_entry "$work/market" --name "$NAME" --description "Nouvelle | description." --update
expect_exit "marketplace-entry --update : exit 0" 0
jq -e --arg n "$NAME" '(.plugins | length) == 3 and (.plugins[-1] == {name: $n, source: {source: "github", repo: "soonlysoul/\($n)"}, description: "Nouvelle | description."})' \
  "$work/market/.claude-plugin/marketplace.json" >/dev/null \
  && pass "--update : la description de l'entrée, rien d'autre" || fail "--update : la description de l'entrée, rien d'autre" "$(jq -c '.plugins[-1]' "$work/market/.claude-plugin/marketplace.json")"
changed=$(diff "$work/readme-before.md" "$work/market/README.md" | grep -E '^[<>]')
[[ $changed == "< $row"$'\n'"> | \`$NAME\` | Nouvelle \\| description. | [soonlysoul/$NAME](https://github.com/soonlysoul/$NAME) |" ]] \
  && pass "--update : la ligne remplacée en place, la barre échappée" || fail "--update : la ligne remplacée en place, la barre échappée" "$(tr '\n' '|' <<<"$changed")"
[[ $(grep -cFx "$install" "$work/market/README.md") == 1 ]] && pass "--update : la commande d'installation n'est pas doublée" \
  || fail "--update : la commande d'installation n'est pas doublée"
run_entry "$work/market" --name plugin-absent --description "x" --update
expect_exit "--update d'un plugin absent : refusé" 1
expect_line "--update d'un plugin absent : raison nommée" "refusé : plugin-absent n'est pas dans .*marketplace\.json"
mkdir -p "$work/market-notable/.claude-plugin"
cp "$work/market/.claude-plugin/marketplace.json" "$work/market-notable/.claude-plugin/"
printf '# Marketplace\n\nSans tableau.\n' >"$work/market-notable/README.md"
before=$(tree_sum "$work/market-notable")
run_entry "$work/market-notable" --name plugin-autre --description "x"
expect_exit "README sans tableau des plugins : refusé" 1
expect_line "README sans tableau : raison nommée" 'refusé : .*README\.md : pas de tableau des plugins'
[[ $(tree_sum "$work/market-notable") == "$before" ]] && pass "README sans tableau : rien d'écrit, ni l'entrée" || fail "README sans tableau : rien d'écrit, ni l'entrée"
rm "$work/market-notable/README.md"
run_entry "$work/market-notable" --name plugin-autre --description "x"
expect_exit "README absent : refusé" 1
run_entry "$work/nowhere" --name "$NAME" --description "x"
expect_exit "marketplace absente : refusé" 1

echo "# composant ajouté après une publication"
p=$(published minor)
demo_skill "$p" extra
commit "$p" "feat: ajouter le skill extra"
before=$(tree_sum "$p")
rm -f "$work/gh-gestures.log" "$work/push.log"
run_release "$p" -- STUB_REPOS="$NAME" STUB_LISTED="$NAME"
expect_exit "répétition : exit 0" 0
expect_line "version mineure, depuis l'étiquette" "^version : 0\.1\.0 → 0\.2\.0 \(mineure : composant ajouté : skill extra ; depuis $NAME--v0\.1\.0\)$"
expect_line "entrée nouvelle" "^  ## \[0\.2\.0\] — $TODAY$"
expect_line "composant ajouté au CHANGELOG" '^  - Skill `extra`\.$'
expect_line "dépôt déjà présent" "^dépôt soonlysoul/$NAME \(GitHub\) : présent$"
expect_line "plugin déjà dans la marketplace" "^marketplace soon \(GitHub\) : $NAME présent, aucune PR$"
keys=$(gesture_keys)
[[ $keys == "write commit tag push-main push-tag" ]] && pass "gestes d'une mise à jour" || fail "gestes d'une mise à jour" "obtenu : $keys"
expect_line "descriptions déjà alignées" '^descriptions : alignées sur plugin\.json$'
expect_line "commit de version : README et marketplace locale compris" "^  2\. \[local\] commit de version : git -C $p commit -m .* -- \.claude-plugin/plugin\.json CHANGELOG\.md README\.md$"
expect_line "mise à jour sur chaque appareil (US-29)" "^  claude plugin update $NAME@soon$"
nothing_sent "mise à jour"
[[ -z $(git --git-dir="$work/minor/remotes/$NAME.git" for-each-ref) ]] && pass "dépôt distant (nu) vide" || fail "dépôt distant (nu) vide"
[[ $(tree_sum "$p") == "$before" ]] && pass "plugin identique après la répétition" || fail "plugin identique après la répétition"
run_release "$p" --bump major -- STUB_REPOS="$NAME" STUB_LISTED="$NAME"
expect_line "--bump plus fort : imposé, nature rappelée" "^version : 0\.1\.0 → 1\.0\.0 \(majeure, imposée par --bump ; la nature du changement donne mineure : composant ajouté : skill extra ; depuis $NAME--v0\.1\.0\)$"
refused "--bump plus faible que la nature du changement" "$p" 1 'refusé : --bump patch est plus faible que la nature du changement \(mineure' --bump patch -- STUB_REPOS="$NAME" STUB_LISTED="$NAME"

echo "# descriptions divergentes après une publication (US-35)"
p=$(published describe)
demo_skill "$p" extra
commit "$p" "feat: ajouter le skill extra"
before=$(tree_sum "$p")
rm -f "$work/gh-gestures.log" "$work/push.log"
listed=(STUB_REPOS="$NAME" STUB_LISTED="$NAME")
run_release "$p" -- "${listed[@]}" STUB_REPO_DESCRIPTION="" STUB_ENTRY_DESCRIPTION="Ancienne." STUB_README_DESCRIPTION="Ancienne."
expect_exit "trois surfaces divergentes : exit 0" 0
expect_line "chaque surface divergente nommée" '^descriptions : à aligner sur plugin\.json — dépôt GitHub, entrée de marketplace, README de marketplace$'
keys=$(gesture_keys)
want="write commit tag push-main push-tag describe clone branch entry-update market-commit push-branch pr"
[[ $keys == "$want" ]] && pass "gestes : la mise à jour, puis l'alignement" || fail "gestes : la mise à jour, puis l'alignement" "obtenu : $keys"
expect_line "description du dépôt, celle de plugin.json" "^  6\. \[GitHub\] description du dépôt : gh repo edit soonlysoul/$NAME --description \"Plugin d'essai\.\"$"
expect_line "copie de la marketplace propre à la branche" "^  7\. \[local\] copie de la marketplace : gh repo clone soonlysoul/claude-plugins .*/plugin-plugin-release/$NAME/align-$NAME-0\.2\.0$"
expect_line "branche d'alignement à la version" "^  8\. \[local\] branche de marketplace : git -C .* switch -c align-$NAME-0\.2\.0$"
expect_line "entrée mise à jour, pas ajoutée" "^  9\. \[local\] entrée de marketplace : .* marketplace-entry .* --name $NAME --description \"Plugin d'essai\.\" --update$"
expect_line "PR de mise à jour" "^  12\. \[GitHub\] PR de marketplace : gh pr create --repo soonlysoul/claude-plugins --base main --head align-$NAME-0\.2\.0 --title \"Mettre à jour la description de $NAME 0\.2\.0\""
expect_line "marketplace modifiée : validée" '^marketplace modifiée : validation stricte ok$'
expect_line "mise à jour, puis marketplace rafraîchie" "^  claude plugin update $NAME@soon$"
nothing_sent "descriptions divergentes"
[[ $(tree_sum "$p") == "$before" ]] && pass "plugin identique après la répétition" || fail "plugin identique après la répétition"
run_release "$p" -- "${listed[@]}" STUB_REPO_DESCRIPTION="Ancienne."
expect_line "seul le dépôt diverge : nommé" '^descriptions : à aligner sur plugin\.json — dépôt GitHub$'
keys=$(gesture_keys)
[[ $keys == "write commit tag push-main push-tag describe" ]] && pass "seul le dépôt diverge : un geste de plus" || fail "seul le dépôt diverge : un geste de plus" "obtenu : $keys"
run_release "$p" -- "${listed[@]}" STUB_README_NO_INSTALL=1
expect_line "commande d'installation absente : README à aligner" '^descriptions : à aligner sur plugin\.json — README de marketplace$'
keys=$(gesture_keys)
[[ $keys == "write commit tag push-main push-tag clone branch entry-update market-commit push-branch pr" ]] \
  && pass "commande d'installation absente : une PR" || fail "commande d'installation absente : une PR" "obtenu : $keys"
refused "branche d'alignement déjà sur GitHub, PR ouverte nommée" "$p" 1 \
  "refusé : la branche align-$NAME-0\.2\.0 est déjà sur GitHub \(soonlysoul/claude-plugins\) ; PR ouverte : https://github\.com/soonlysoul/claude-plugins/pull/7" \
  -- "${listed[@]}" STUB_ENTRY_DESCRIPTION="Ancienne." STUB_BRANCHES="align-$NAME-0.2.0" STUB_PR="https://github.com/soonlysoul/claude-plugins/pull/7"

echo "# alignement, rien à publier (US-37)"
p=$(published align)
before=$(tree_sum "$p")
rm -f "$work/gh-gestures.log" "$work/push.log" "$work/tag.log"
run_release "$p" -- "${listed[@]}" STUB_REPO_DESCRIPTION="Ancienne." STUB_ENTRY_DESCRIPTION="Ancienne."
expect_exit "alignement : exit 0" 0
expect_line "alignement annoncé" "^alignement : rien à publier depuis $NAME--v0\.1\.0 ; ni version, ni CHANGELOG, ni étiquette$"
refuse_line "aucune version proposée" '^version : '
expect_line "surfaces nommées" '^descriptions : à aligner sur plugin\.json — dépôt GitHub, entrée de marketplace$'
keys=$(gesture_keys)
[[ $keys == "describe clone branch entry-update market-commit push-branch pr" ]] && pass "alignement : ses seuls gestes" || fail "alignement : ses seuls gestes" "obtenu : $keys"
expect_line "branche d'alignement à la version publiée" "switch -c align-$NAME-0\.1\.0$"
expect_line "PR d'alignement" "--head align-$NAME-0\.1\.0 --title \"Aligner la description de $NAME\" "
expect_line "après la fusion, la marketplace se rafraîchit" '^  claude plugin marketplace update soon$'
refuse_line "aucune mise à jour du plugin sur les appareils" "claude plugin (update|install) $NAME@soon"
expect_line "alignement : gestes listés, aucun exécuté" '^répétition terminée : 7 gestes listés, aucun exécuté$'
nothing_sent "alignement"
[[ ! -s $work/tag.log ]] && pass "alignement : claude plugin tag jamais lancé" || fail "alignement : claude plugin tag jamais lancé" "$(cat "$work/tag.log")"
[[ $(tree_sum "$p") == "$before" ]] && pass "alignement : plugin identique" || fail "alignement : plugin identique"
run_release "$p" -- "${listed[@]}" STUB_REPO_DESCRIPTION="Ancienne."
keys=$(gesture_keys)
[[ $keys == "describe" ]] && pass "alignement du seul dépôt : un geste, aucune PR" || fail "alignement du seul dépôt : un geste, aucune PR" "obtenu : $keys"
expect_line "sans PR : rien à lancer sur les appareils" "^aucune commande sur les appareils : aucune version nouvelle, aucune PR$"
refused "--bump sur un alignement" "$p" 1 "refusé : alignement sans version : --bump ne s'applique pas" --bump patch -- "${listed[@]}" STUB_REPO_DESCRIPTION="Ancienne."
refused "tout aligné : rien à publier" "$p" 1 "refusé : rien à publier depuis $NAME--v0\.1\.0 ; aucun changement depuis cette étiquette, descriptions alignées sur plugin\.json" -- "${listed[@]}"

echo "# composant retiré, consigne corrigée"
p=$(published major)
trial "$p" && git -C "$p" rm -rq skills/demo
trial "$p" && git -C "$p" commit -qm "refactor: retirer le skill demo"
run_release "$p" -- STUB_REPOS="$NAME" STUB_LISTED="$NAME"
expect_line "composant retiré : majeure" "^version : 0\.1\.0 → 1\.0\.0 \(majeure : composant retiré : skill demo ; depuis $NAME--v0\.1\.0\)$"
expect_line "composant retiré au CHANGELOG" '^  - Skill `demo`\.$'
p=$(published patch)
sed -i 's/^Answer with the codename of the project\.$/Answer with the codename of the project, and nothing else./' "$p/skills/demo/SKILL.md"
commit "$p" "fix: consigne de demo précisée"
run_release "$p" -- STUB_REPOS="$NAME" STUB_LISTED="$NAME"
expect_line "consigne corrigée : correctif" "^version : 0\.1\.0 → 0\.1\.1 \(correctif : aucun composant ajouté ni retiré ; depuis $NAME--v0\.1\.0\)$"
expect_line "commits repris au CHANGELOG" '^  - fix: consigne de demo précisée$'

echo "# hook passé de la forme shell à la forme exec"
# As plugin-nixos 0.1.2 declared its guard, under a former vX.Y.Z tag: the path in quotes inside
# the command string. Moved to hooks/scripts/ in exec form, it is the same component.
p=$(published shellform)
trial "$p" && mkdir -p "$p/hooks" && printf '#!/usr/bin/env bash\nexit 0\n' >"$p/hooks/garde.sh"
printf '\n- Hook `garde`.\n' >>"$p/README.md"
trial "$p" && jq -n '{hooks: {PreToolUse: [{matcher: "Bash", hooks: [{type: "command",
  command: "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/garde.sh\"", timeout: 15}]}]}}' >"$p/hooks/hooks.json"
commit "$p" "feat: garde en forme shell"
trial "$p" && git -C "$p" tag -d "$NAME--v0.1.0" >/dev/null && git -C "$p" tag -a v0.1.0 -m "$NAME 0.1.0"
trial "$p" && mkdir -p "$p/hooks/scripts" && git -C "$p" mv hooks/garde.sh hooks/scripts/garde.sh
trial "$p" && jq -n '{hooks: {PreToolUse: [{matcher: "Bash", hooks: [{type: "command", command: "bash",
  args: ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/garde.sh"], timeout: 15, onFailure: "block"}]}]}}' >"$p/hooks/hooks.json"
commit "$p" "refactor: garde en forme exec"
run_release "$p" -- STUB_REPOS="$NAME" STUB_LISTED="$NAME"
expect_line "forme shell entre guillemets, puis exec : correctif" "^version : 0\.1\.0 → 0\.1\.1 \(correctif : aucun composant ajouté ni retiré ; depuis v0\.1\.0\)$"
refuse_line "aucun hook retiré au CHANGELOG" '^  - Hook `'

echo "# alerte de coût (US-25)"
# Beyond the budget, a produced plugin's suite alerts and stays green: the rehearsal goes on.
p=$(copy heavy)
run_release "$p" -- STUB_ALWAYS_ON=1.2k
expect_exit "coût au-delà du seuil : la répétition continue, exit 0" 0
expect_line "alerte au-delà de 1 000 tokens" '^alerte : coût permanent ~1200 tokens, au-delà du seuil de 1000$'
expect_line "coût par composant, même en alerte" "^  - demo : ~1\.2k permanent, ~2k à l'appel$"
expect_line "l'alerte de la suite du plugin est comptée" '^suite du plugin : exit 0 \(.*alertes : 1'
run_release "$p" -- STUB_ALWAYS_ON=1,126
expect_line "~1,126 tok : 1126 tokens, séparateur de milliers lu" '^alerte : coût permanent ~1126 tokens, au-delà du seuil de 1000$'

finish
