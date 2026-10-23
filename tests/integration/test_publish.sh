#!/usr/bin/env bash
# pp.sh publish and pp.sh mount: the real gestures, against local bare repositories and a gh stub —
# nothing reaches GitHub. Each step (local gestures up to one GitHub gesture) is announced with its
# exact commands and runs only through the command announced, after a « oui » captured by
# consent-capture and let through once by gesture-guard (US-20, criterion 6). The marketplace
# changes through a branch and a PR, never main, never merged (US-21). A cut in the middle names the
# failed gesture, what is done and the command that resumes; the resumption redoes nothing (US-27).
# A published plugin is mounted as a submodule of a host repository, pinned on its tag (US-26).
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../helpers/plugin.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers/plugin.sh"
SUITE=test_publish
PP="$PLUGIN_ROOT/scripts/pp.sh"
CAPTURE="$PLUGIN_ROOT/hooks/scripts/consent-capture.sh"
GUARD="$PLUGIN_ROOT/hooks/scripts/gesture-guard.sh"
NAME=plugin-essai-publish
TAG="$NAME--v0.1.0"
TODAY=$(date +%F)

work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
# The test works from its throwaway folder, and git never looks above it.
cd "$work" || exit 2
export GIT_CEILING_DIRECTORIES="$work"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$work/tmp"
export TMPDIR="$work/tmp"

for file in "$PP" "$CAPTURE" "$GUARD"; do
  [[ -f $file ]] && pass "présent : ${file#"$PLUGIN_ROOT"/}" || fail "présent : ${file#"$PLUGIN_ROOT"/}" "absent"
done
((FAIL == 0)) || { finish; exit; }

# GitHub, simulated: every https://github.com/soonlysoul/<repo> is the bare repository
# $GITHUB/<repo>.git. The marketplace soon lists plugin-alpha and plugin-beta on main.
GITHUB="$work/github"
mkdir -p "$GITHUB"
export GIT_CONFIG_GLOBAL="$work/gitconfig"
git config --global "url.$GITHUB/.insteadOf" https://github.com/soonlysoul/
git config --global protocol.file.allow always
git config --global init.defaultBranch main
seed="$work/seed-marketplace"
git init -q -b main "$seed"
mkdir -p "$seed/.claude-plugin"
jq -n '{name: "soon", description: "Plugins Claude Code de Soon.", owner: {name: "Soon"},
  plugins: (["plugin-alpha", "plugin-beta"] | map({name: ., source: {source: "github", repo: "soonlysoul/\(.)"}, description: "Plugin \(.)."}))}' \
  >"$seed/.claude-plugin/marketplace.json"
printf 'plugin-alpha\tPlugin plugin-alpha.\nplugin-beta\tPlugin plugin-beta.\n' | market_readme >"$seed/README.md"
git -C "$seed" add -A && git -C "$seed" commit -qm "init"
git clone -q --bare "$seed" "$GITHUB/claude-plugins.git"
market_main=$(git --git-dir="$GITHUB/claude-plugins.git" rev-parse main)

# Stubs. gh: reads answered from $GITHUB, a repository's description in $GITHUB/<repo>.description;
# gestures (repo create, repo edit, pr create) done on $GITHUB and logged to $work/gh-gestures.log;
# STUB_GH_CUT=before|after fails the gesture matching STUB_GH_MATCH before or after doing it, like a
# network cut. git: push is logged to $work/push.log; STUB_PUSH_CUT=before|after
# fails the push matching STUB_PUSH_MATCH before or after doing it. claude: the real one.
real_git=$(command -v git)
mkdir -p "$work/stub"
cat >"$work/stub/gh" <<EOF
#!/usr/bin/env bash
GITHUB=$(printf %q "$GITHUB") LOG=$(printf %q "$work/gh-gestures.log") GIT=$(printf %q "$real_git")
EOF
cat >>"$work/stub/gh" <<'EOF'
all="$*"
cut() {
  if [[ ${STUB_GH_CUT:-} == "$1" && $all == *"${STUB_GH_MATCH:-}"* ]]; then echo "error connecting to api.github.com" >&2; exit 1; fi
}
# description_of <args...>: the value given to --description.
description_of() { while [[ $# -gt 0 ]]; do [[ $1 == --description ]] && { printf '%s' "$2"; return; }; shift; done; }
case "$1 $2" in
  "api repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json")
    "$GIT" --git-dir="$GITHUB/claude-plugins.git" show main:.claude-plugin/marketplace.json ;;
  "api repos/soonlysoul/claude-plugins/contents/README.md")
    "$GIT" --git-dir="$GITHUB/claude-plugins.git" show main:README.md ;;
  "api repos/soonlysoul/claude-plugins/branches/"*)
    branch=${2#repos/soonlysoul/claude-plugins/branches/}
    if "$GIT" --git-dir="$GITHUB/claude-plugins.git" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then printf '{"name": "%s"}\n' "$branch"
    else echo "gh: Branch not found (HTTP 404)" >&2; exit 1; fi ;;
  "api repos/soonlysoul/claude-plugins/pulls?"*)
    head=${2#*head=soonlysoul:} head=${head%%&*}
    n=$(grep -n "^$head	" "$GITHUB/prs" 2>/dev/null | head -n 1) n=${n%%:*}
    if [[ -n $n ]]; then printf '[{"number": %d, "html_url": "https://github.com/soonlysoul/claude-plugins/pull/%d"}]\n' "$n" "$n"; else echo '[]'; fi ;;
  "api repos/soonlysoul/"*)
    repo=${2#repos/soonlysoul/}
    if [[ -d $GITHUB/$repo.git ]]; then
      jq -n --arg n "soonlysoul/$repo" --arg d "$(cat "$GITHUB/$repo.description" 2>/dev/null)" '{full_name: $n, description: $d}'
    else echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi ;;
  "repo create")
    printf '%s\n' "$*" >>"$LOG"
    cut before
    repo=${3#soonlysoul/}
    [[ -d $GITHUB/$repo.git ]] && { echo "GraphQL: Name already exists on this account" >&2; exit 1; }
    "$GIT" init -q --bare "$GITHUB/$repo.git"
    description_of "$@" >"$GITHUB/$repo.description"
    echo "https://github.com/soonlysoul/$repo"
    cut after ;;
  "repo edit")
    printf '%s\n' "$*" >>"$LOG"
    cut before
    repo=${3#soonlysoul/}
    [[ -d $GITHUB/$repo.git ]] || { echo "GraphQL: Could not resolve to a Repository" >&2; exit 1; }
    description_of "$@" >"$GITHUB/$repo.description"
    echo "✓ Edited repository soonlysoul/$repo"
    cut after ;;
  "repo clone")
    "$GIT" clone -q "https://github.com/$3.git" "$4" ;;
  "pr create")
    printf '%s\n' "$*" >>"$LOG"
    cut before
    head="" base="" title=""
    while [[ $# -gt 0 ]]; do
      case $1 in --head) head=$2; shift 2 ;; --base) base=$2; shift 2 ;; --title) title=$2; shift 2 ;; *) shift ;; esac
    done
    "$GIT" --git-dir="$GITHUB/claude-plugins.git" rev-parse -q --verify "refs/heads/$head" >/dev/null \
      || { echo "pull request create failed: head branch $head not found" >&2; exit 1; }
    grep -q "^$head	" "$GITHUB/prs" 2>/dev/null && { echo "a pull request for branch \"$head\" already exists" >&2; exit 1; }
    printf '%s\t%s\t%s\n' "$head" "$base" "$title" >>"$GITHUB/prs"
    echo "https://github.com/soonlysoul/claude-plugins/pull/$(grep -c . "$GITHUB/prs")"
    cut after ;;
  "pr list")
    head=""
    while [[ $# -gt 0 ]]; do case $1 in --head) head=$2; shift 2 ;; *) shift ;; esac; done
    n=$(grep -c "^$head	" "$GITHUB/prs" 2>/dev/null)
    jq -n --argjson n "${n:-0}" '[range($n)] | map({number: (. + 1)})' ;;
  *)
    printf 'unexpected: %s\n' "$*" >>"$LOG"
    echo "gh stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
EOF
cat >"$work/stub/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [[ \$arg == push ]]; then
    printf '%s\n' "\$*" >>$(printf %q "$work/push.log")
    if [[ -n \${STUB_PUSH_CUT:-} && "\$*" == *"\${STUB_PUSH_MATCH:-}"* ]]; then
      if [[ \$STUB_PUSH_CUT == after ]]; then $(printf %q "$real_git") "\$@" >/dev/null 2>&1; fi
      echo "fatal: unable to access 'https://github.com/': Could not resolve host: github.com" >&2
      exit 128
    fi
    break
  fi
done
exec $(printf %q "$real_git") "\$@"
EOF
chmod +x "$work/stub/gh" "$work/stub/git"
STUBPATH="$work/stub:$PATH"

# pp <args...> [-- env...]: pp.sh through the stubs. Sets PP_OUTPUT and PP_STATUS.
pp() {
  local -a args=()
  while [[ $# -gt 0 && $1 != -- ]]; do args+=("$1"); shift; done
  [[ ${1:-} == -- ]] && shift
  PP_OUTPUT=$(env PATH="$STUBPATH" "$@" "$BASH" "$PP" "${args[@]}" 2>&1)
  PP_STATUS=$?
}
# announced: the command the last announcement asks to type.
announced() { sed -n 's/^commande : //p' <<<"$PP_OUTPUT" | tail -n 1; }
# answer <dir> <prompt>: the message Soon types, seen by consent-capture.
answer() {
  run_hook "$CAPTURE" "$(jq -nc --arg cwd "$1" --arg p "$2" \
    '{session_id: "test", transcript_path: "/dev/null", cwd: $cwd, permission_mode: "default", hook_event_name: "UserPromptSubmit", prompt: $p}')"
}
# guard <dir> <command>: the Bash call Claude makes, seen by gesture-guard. Sets GUARD_STATUS.
guard() {
  run_hook "$GUARD" "$(jq -nc --arg cwd "$1" --arg c "$2" \
    '{session_id: "test", cwd: $cwd, hook_event_name: "PreToolUse", permission_mode: "default", tool_name: "Bash", tool_input: {command: $c}, tool_use_id: "t"}')"
  GUARD_STATUS=$HOOK_STATUS
}
# run_announced [env...]: Claude runs the announced command, as typed. Sets PP_OUTPUT and PP_STATUS.
run_announced() {
  local command
  command=$(announced)
  PP_OUTPUT=$(env PATH="$STUBPATH" "$@" "$BASH" -c "$command" 2>&1)
  PP_STATUS=$?
}
# step <dir> <label> [env...]: « oui », the guard lets the announced command through, it runs.
step() {
  local dir=$1 label=$2 command
  shift 2
  command=$(announced)
  [[ -n $command ]] || { fail "$label : commande annoncée" "aucune ; sortie : $(tail -n 5 <<<"$PP_OUTPUT" | tr '\n' '|')"; return 1; }
  answer "$dir" "oui"
  guard "$dir" "$command"
  [[ $GUARD_STATUS == 0 ]] || { fail "$label : le garde laisse passer après « oui »" "exit $GUARD_STATUS ; ${HOOK_STDERR:0:300}"; return 1; }
  run_announced "$@"
}
expect_exit() {
  if [[ $PP_STATUS == "$2" ]]; then pass "$1"
  else fail "$1" "attendu exit $2, obtenu $PP_STATUS ; sortie : $(tail -n 12 <<<"$PP_OUTPUT" | tr '\n' '|' | head -c 700)"; fi
}
expect_line() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then pass "$1"
  else fail "$1" "motif absent : $2 ; sortie : $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 700)"; fi
}
trial() {
  [[ $1 == "$work"/* && -d $1 && $(git -C "$1" rev-parse --show-toplevel 2>/dev/null) == "$1" ]] && return 0
  fail "dépôt d'essai sous le dossier jetable" "refusé : « $1 »"
  return 1
}
commit() { trial "$1" && git -C "$1" add -A && git -C "$1" commit -qm "$2"; }
count() { grep -c -- "$2" "$1" 2>/dev/null || true; }
gestures_log() { cat "$1/.plugin-plugin/gestures.log" 2>/dev/null; }
remote() { git --git-dir="$GITHUB/$NAME.git" "$@"; }

echo "# plugin d'essai"
if base=$(new_plugin "$work/base" "$NAME"); then pass "plugin d'essai créé par pp.sh create"; else fail "plugin d'essai créé par pp.sh create"; fi
mkdir -p "$base/skills/demo"
cat >"$base/skills/demo/SKILL.md" <<'EOF'
---
name: demo
description: "Give the codename of a project. Use when Soon asks for a codename; not for anything else. « nom de code d'Atlas »."
argument-hint: "[projet]"
when_to_use: "When a codename is asked."
---

# demo

Answer with the codename of the project.
EOF
printf '\n- Skill `demo`.\n' >>"$base/README.md"
commit "$base" "chore: charpente de $NAME"
for file in publication.json pending consents.log gestures.log checkpoint.md; do
  git -C "$base" check-ignore -q ".plugin-plugin/$file" && pass "état ignoré par git : .plugin-plugin/$file" \
    || fail "état ignoré par git : .plugin-plugin/$file"
done
for file in approvals.log decisions.md; do
  git -C "$base" ls-files --error-unmatch ".plugin-plugin/$file" >/dev/null 2>&1 && pass "versionné : .plugin-plugin/$file" \
    || fail "versionné : .plugin-plugin/$file"
done
copy() {
  git clone -q "$base" "$work/$1/$NAME" >/dev/null 2>&1 && git -C "$work/$1/$NAME" remote remove origin
  printf '%s' "$work/$1/$NAME"
}

echo "# refus avant toute annonce"
p=$(copy refused)
printf 'retouche\n' >>"$p/README.md"
pp publish "$p"
expect_exit "arbre sale : refusé (US-23)" 1
expect_line "arbre sale : raison nommée" 'refusé : changements non enregistrés'
[[ ! -e $p/.plugin-plugin/publication.json && ! -e $p/.plugin-plugin/pending ]] && pass "arbre sale : rien de figé, rien d'annoncé" \
  || fail "arbre sale : rien de figé, rien d'annoncé"
trial "$p" && git -C "$p" checkout -q README.md
sed -i '/^\.plugin-plugin\/gestures\.log$/d' "$p/.gitignore"
commit "$p" "chore: journal des gestes versionné"
pp publish "$p"
expect_exit "journal des gestes non ignoré : refusé" 1
expect_line "journal des gestes non ignoré : raison nommée" 'refusé : .*\.plugin-plugin/gestures\.log.*ignoré'

echo "# première publication : l'annonce"
p=$(copy first)
before_head=$(git -C "$p" rev-parse HEAD)
pp publish "$p"
expect_exit "publish : exit 0" 0
expect_line "publication annoncée : nom, version, étiquette" "^publication : $NAME 0\.1\.0 \(étiquette $TAG\)$"
expect_line "aucun geste fait" '^fait : aucun geste$'
expect_line "étape annoncée : gestes 1 à 4" '^prochaine étape — gestes 1 à 4, dont 1 vers GitHub :$'
expect_line "geste 1 avec sa commande exacte" "^  1\. \[local\] écrire la version et le CHANGELOG : bash .*pp\.sh release-write $p --version 0\.1\.0$"
expect_line "geste 4 : création du dépôt" "^  4\. \[GitHub\] création du dépôt : gh repo create soonlysoul/$NAME --public --description "
expect_line "commande à taper" "^commande : bash .*pp\.sh publish $p --run 1$"
expect_line "seul un « oui »" '^accord : seul un « oui » tapé lance cette étape ; toute autre réponse la retire\.$'
[[ $(git -C "$p" rev-parse HEAD) == "$before_head" && -z $(git -C "$p" tag -l) && -z $(git -C "$p" status --porcelain) ]] \
  && pass "l'annonce n'exécute rien : HEAD, étiquettes, arbre propre" || fail "l'annonce n'exécute rien : HEAD, étiquettes, arbre propre"
[[ ! -e $work/gh-gestures.log && ! -e $work/push.log && ! -d $GITHUB/$NAME.git ]] && pass "rien vers GitHub" || fail "rien vers GitHub"
[[ -f $p/.plugin-plugin/publication.json && -f $p/.plugin-plugin/pending ]] && pass "plan figé, geste annoncé" || fail "plan figé, geste annoncé"
jq -e --arg t "$TAG" '.tag == $t and .version == "0.1.0" and (.gestures | length) == 13' "$p/.plugin-plugin/publication.json" >/dev/null 2>&1 \
  && pass "plan figé : version, étiquette, 13 gestes" || fail "plan figé : version, étiquette, 13 gestes" "$(head -c 300 "$p/.plugin-plugin/publication.json" 2>&1)"

echo "# sans « oui », rien ne part (US-20, critère 6)"
run1=$(announced)
guard "$p" "$run1"
[[ $GUARD_STATUS == 2 ]] && pass "silence : le garde bloque" || fail "silence : le garde bloque" "exit $GUARD_STATUS"
pp publish "$p" --run 1
expect_exit "pp.sh lancé sans accord capté : refusé" 1
expect_line "pp.sh : raison nommée" 'refusé : aucun « oui » capté'
answer "$p" "ok"
guard "$p" "$run1"
[[ $GUARD_STATUS == 2 ]] && pass "« ok » : le garde bloque" || fail "« ok » : le garde bloque" "exit $GUARD_STATUS"
pp publish "$p"
answer "$p" "oui mais attends"
guard "$p" "$(announced)"
[[ $GUARD_STATUS == 2 ]] && pass "« oui mais attends » : le garde bloque" || fail "« oui mais attends » : le garde bloque" "exit $GUARD_STATUS"
[[ $(git -C "$p" rev-parse HEAD) == "$before_head" && ! -e $work/gh-gestures.log ]] && pass "après trois refus, rien n'a bougé" \
  || fail "après trois refus, rien n'a bougé"

echo "# « oui » : une fois, la commande annoncée"
pp publish "$p"
answer "$p" "oui"
guard "$p" "git -C $p push origin main"
[[ $GUARD_STATUS == 2 ]] && pass "accord : une autre commande reste bloquée" || fail "accord : une autre commande reste bloquée" "exit $GUARD_STATUS"
guard "$p" "$(announced)"
[[ $GUARD_STATUS == 0 ]] && pass "accord : la commande annoncée passe" || fail "accord : la commande annoncée passe" "${HOOK_STDERR:0:300}"
guard "$p" "$(announced)"
[[ $GUARD_STATUS == 2 ]] && pass "accord : une seule fois" || fail "accord : une seule fois" "exit $GUARD_STATUS"
run_announced
expect_exit "étape 1 : exit 0" 0
expect_line "geste 1 fait, avec son code" '^fait : 1\. \[local\] écrire la version et le CHANGELOG : .* → exit 0$'
expect_line "geste 4 fait" "^fait : 4\. \[GitHub\] création du dépôt : gh repo create soonlysoul/$NAME .* → exit 0$"
[[ $(git -C "$p" tag -l) == "$TAG" ]] && pass "étiquette posée par claude plugin tag" || fail "étiquette posée par claude plugin tag" "$(git -C "$p" tag -l)"
grep -qx "## \[0.1.0\] — $TODAY" "$p/CHANGELOG.md" && pass "CHANGELOG daté" || fail "CHANGELOG daté"
[[ -d $GITHUB/$NAME.git ]] && pass "dépôt créé (nu, local)" || fail "dépôt créé (nu, local)"
expect_line "étape suivante : gestes 5 à 6" '^prochaine étape — gestes 5 à 6, dont 1 vers GitHub :$'
expect_line "commande suivante" "^commande : bash .*pp\.sh publish $p --run 5$"
run_announced
expect_exit "commande suivante lancée sans nouvel accord : refusée" 1
expect_line "sans nouvel accord : raison nommée" 'refusé : aucun « oui » capté'
pp publish "$p" --run 1
expect_exit "étape déjà faite : refusé" 1
expect_line "étape déjà faite : le prochain geste est nommé" 'refusé : le geste 1 est fait ; prochain geste : 5'

echo "# jusqu'au bout"
pp publish "$p"
step "$p" "étape 5"
expect_exit "étape 5 (origin, push de main) : exit 0" 0
[[ $(remote rev-parse main 2>/dev/null) == "$(git -C "$p" rev-parse main)" ]] && pass "main poussé" || fail "main poussé"
step "$p" "étape 7"
expect_exit "étape 7 (push de l'étiquette) : exit 0" 0
[[ -n $(remote tag -l "$TAG") ]] && pass "étiquette poussée" || fail "étiquette poussée"
expect_line "étape de la marketplace : gestes 8 à 12" '^prochaine étape — gestes 8 à 12, dont 1 vers GitHub :$'
step "$p" "étape 8"
expect_exit "étape 8 (marketplace jusqu'au push de la branche) : exit 0" 0
step "$p" "étape 13"
expect_exit "étape 13 (PR) : exit 0" 0
expect_line "publication terminée" "^publication terminée : $NAME 0\.1\.0, 13 gestes faits$"
expect_line "installation après la fusion (US-29)" "^  claude plugin install $NAME@soon$"
[[ ! -e $p/.plugin-plugin/publication.json && ! -e $p/.plugin-plugin/pending ]] && pass "plan et annonce retirés à la fin" \
  || fail "plan et annonce retirés à la fin"

echo "# état des dépôts et des journaux"
[[ $(git --git-dir="$GITHUB/claude-plugins.git" rev-parse main) == "$market_main" ]] && pass "marketplace : main inchangé (US-21)" \
  || fail "marketplace : main inchangé (US-21)"
git --git-dir="$GITHUB/claude-plugins.git" show "add-$NAME:.claude-plugin/marketplace.json" 2>/dev/null |
  jq -e --arg n "$NAME" 'any(.plugins[]; . == {name: $n, source: {source: "github", repo: "soonlysoul/\($n)"}, description: "Plugin d'"'"'essai."})' >/dev/null \
  && pass "marketplace : l'entrée est sur la branche add-$NAME" || fail "marketplace : l'entrée est sur la branche add-$NAME"
readme=$(git --git-dir="$GITHUB/claude-plugins.git" show "add-$NAME:README.md" 2>/dev/null)
grep -qFx "| \`$NAME\` | Plugin d'essai. | [soonlysoul/$NAME](https://github.com/soonlysoul/$NAME) |" <<<"$readme" \
  && grep -qFx "claude plugin install $NAME@soon --scope user" <<<"$readme" \
  && pass "marketplace : la ligne du README et la commande d'installation sur la branche (US-35)" \
  || fail "marketplace : la ligne du README et la commande d'installation sur la branche (US-35)"
[[ $(cat "$GITHUB/$NAME.description" 2>/dev/null) == "Plugin d'essai." ]] && pass "dépôt créé avec la description de plugin.json" \
  || fail "dépôt créé avec la description de plugin.json" "$(cat "$GITHUB/$NAME.description" 2>&1)"
[[ $(git --git-dir="$GITHUB/claude-plugins.git" rev-list --count "main..add-$NAME") == 1 ]] && pass "marketplace : un seul commit sur la branche" \
  || fail "marketplace : un seul commit sur la branche"
[[ $(cat "$GITHUB/prs" 2>/dev/null) == "add-$NAME	main	Ajouter $NAME 0.1.0" ]] && pass "une PR, de add-$NAME vers main" || fail "une PR, de add-$NAME vers main" "$(cat "$GITHUB/prs" 2>&1)"
[[ $(count "$work/gh-gestures.log" .) == 2 && $(count "$work/gh-gestures.log" '^repo create') == 1 && $(count "$work/gh-gestures.log" '^pr create') == 1 ]] \
  && pass "gestes gh : un dépôt, une PR, rien d'autre" || fail "gestes gh : un dépôt, une PR, rien d'autre" "$(cat "$work/gh-gestures.log")"
grep -qE 'merge|delete' "$work/gh-gestures.log" && fail "aucune fusion, aucune suppression" || pass "aucune fusion, aucune suppression"
grep -qE -- '--force|-f |--delete|\+' "$work/push.log" && fail "aucun push forcé" "$(cat "$work/push.log")" || pass "aucun push forcé"
[[ $(count "$p/.plugin-plugin/consents.log" $'\taccord\t') == 5 && $(count "$p/.plugin-plugin/consents.log" $'\trefus\t') == 2 ]] \
  && pass "journal des accords : 5 accords, 2 refus" || fail "journal des accords : 5 accords, 2 refus" "$(cat "$p/.plugin-plugin/consents.log" 2>&1)"
[[ $(gestures_log "$p" | grep -c $'\tfait\texit 0\t') == 13 ]] && pass "journal des gestes : 13 faits, chacun avec son code et sa commande" \
  || fail "journal des gestes : 13 faits, chacun avec son code et sa commande" "$(gestures_log "$p")"
[[ -z $(git -C "$p" status --porcelain) ]] && pass "plugin : arbre propre après la publication" || fail "plugin : arbre propre après la publication" "$(git -C "$p" status --porcelain)"

echo "# coupure en cours de publication, puis reprise (US-27)"
NAME2=plugin-essai-coupure
if c=$(new_plugin "$work/cut" "$NAME2"); then pass "deuxième plugin d'essai créé"; else fail "deuxième plugin d'essai créé"; fi
commit "$c" "chore: charpente de $NAME2"
rm -f "$work/push.log"
pp publish "$c"
step "$c" "étape 1"
expect_exit "étape 1 : exit 0" 0
step "$c" "étape 5, coupée" STUB_PUSH_CUT=before STUB_PUSH_MATCH="push origin main"
expect_exit "coupure avant le push de main : exit 1" 1
expect_line "le geste échoué est nommé, avec son code" "^échoué : 6\. \[GitHub\] push de main : git -C $c push origin main → exit 128$"
expect_line "ce qui est fait" '^fait : gestes 1 à 5$'
expect_line "ce qui reste" '^reste : gestes 6 à 13$'
expect_line "la commande qui reprend" "^reprise : bash .*pp\.sh publish $c$"
gestures_log "$c" | grep -q $'\tgeste 6\t.*\téchoué\texit 128\t.*\treprise : bash ' && pass "journal : échoué, code, commande qui reprend" \
  || fail "journal : échoué, code, commande qui reprend" "$(gestures_log "$c")"
pp resume "$c"
expect_line "pp.sh resume signale la publication en cours (US-34)" "^publication en cours : $NAME2 0\.1\.0 \(étiquette $NAME2--v0\.1\.0\) ; reprise : bash .*pp\.sh publish $c$"
(($(grep -c . <<<"$PP_OUTPUT") <= 10)) && pass "pp.sh resume : dix lignes au plus" || fail "pp.sh resume : dix lignes au plus" "$PP_OUTPUT"
pp publish "$c"
expect_exit "reprise : exit 0" 0
expect_line "reprise : fait jusqu'au geste 5" '^fait : gestes 1 à 5$'
expect_line "reprise : seul le push de main est annoncé" '^prochaine étape — gestes 6 à 6, dont 1 vers GitHub :$'
step "$c" "reprise du push de main, coupée de nouveau" STUB_PUSH_CUT=before STUB_PUSH_MATCH="push origin main"
expect_exit "deuxième coupure : exit 1" 1
pp publish "$c" --run 6
expect_exit "la même étape relancée sur le même « oui » : refusée" 1
expect_line "un « oui » ne sert qu'une fois" 'refusé : aucun « oui » capté'
pp publish "$c"
step "$c" "reprise du push de main"
expect_exit "push de main repris : exit 0" 0
step "$c" "étape 7, coupée après coup" STUB_PUSH_CUT=after STUB_PUSH_MATCH="refs/tags/"
expect_exit "push de l'étiquette parti, réponse perdue : exit 1" 1
pp publish "$c"
expect_exit "reprise après la réponse perdue : exit 0" 0
expect_line "le geste parti est reconnu fait" '^déjà fait : 7\. \[GitHub\] push de l.étiquette'
[[ $(count "$work/push.log" 'refs/tags/') == 1 ]] && pass "l'étiquette n'est poussée qu'une fois" || fail "l'étiquette n'est poussée qu'une fois" "$(cat "$work/push.log")"
step "$c" "étape 8, coupée au push de la branche" STUB_PUSH_CUT=before STUB_PUSH_MATCH="push origin add-"
expect_exit "coupure au push de la branche : exit 1" 1
# The copy of the marketplace goes back to main, its branch emptied: the entry is to be written again.
work_clone="$TMPDIR/plugin-plugin-release/$NAME2/add-$NAME2"
trial "$work_clone" && git -C "$work_clone" switch -q main && git -C "$work_clone" branch -qf "add-$NAME2" origin/main
pp publish "$c"
expect_line "reprise : l'entrée est à refaire" '^prochaine étape — gestes 10 à 12, dont 1 vers GitHub :$'
step "$c" "reprise sur la copie remise sur main"
expect_exit "marketplace remise sur main : refusé" 1
expect_line "jamais de commit sur main de la marketplace" 'jamais sur main'
[[ $(git -C "$work_clone" rev-parse main) == "$(git -C "$work_clone" rev-parse origin/main)" && -z $(git -C "$work_clone" status --porcelain) ]] \
  && pass "copie de la marketplace : main intact, rien d'écrit" || fail "copie de la marketplace : main intact, rien d'écrit"
[[ $(git --git-dir="$GITHUB/claude-plugins.git" rev-parse main) == "$market_main" ]] && pass "main de la marketplace toujours inchangé" \
  || fail "main de la marketplace toujours inchangé"
trial "$work_clone" && git -C "$work_clone" switch -q "add-$NAME2"
pp publish "$c"
step "$c" "reprise de la branche"
expect_exit "branche reprise : exit 0" 0
step "$c" "PR, réponse perdue" STUB_GH_CUT=after STUB_GH_MATCH="pr create"
expect_exit "PR créée, réponse perdue : exit 1" 1
pp publish "$c"
expect_exit "reprise après la PR : exit 0" 0
expect_line "la PR créée est reconnue faite" '^déjà fait : 13\. \[GitHub\] PR de marketplace'
expect_line "publication terminée sans geste en double" "^publication terminée : $NAME2 0\.1\.0, 13 gestes faits$"
[[ $(count "$work/gh-gestures.log" "^repo create soonlysoul/$NAME2 ") == 1 && $(count "$GITHUB/prs" "^add-$NAME2	") == 1 ]] \
  && pass "un seul dépôt créé, une seule PR" || fail "un seul dépôt créé, une seule PR" "$(cat "$work/gh-gestures.log")"
[[ $(count "$work/push.log" 'push origin main') == 3 ]] && pass "main : deux tentatives coupées, une réussie" || fail "main : deux tentatives coupées, une réussie" "$(cat "$work/push.log")"

echo "# mise à jour, après la fusion de la PR par Soon"
merged="$work/merge-by-soon"
git clone -q "$GITHUB/claude-plugins.git" "$merged" && git -C "$merged" merge -q --ff-only "origin/add-$NAME" \
  && git -C "$merged" push -q origin main 2>/dev/null
mkdir -p "$p/skills/extra"
sed 's/^name: demo$/name: extra/; s/^# demo$/# extra/' "$p/skills/demo/SKILL.md" >"$p/skills/extra/SKILL.md"
printf -- '- Skill `extra`.\n' >>"$p/README.md"
awk '/^## \[/ && !done { print "## [à venir] — en cours\n\n### Ajouté\n\n- Skill `extra`.\n"; done = 1 } { print }' "$p/CHANGELOG.md" >"$p/c.tmp" && mv "$p/c.tmp" "$p/CHANGELOG.md"
commit "$p" "feat: ajouter le skill extra"
rm -f "$work/gh-gestures.log"
pp publish "$p"
expect_exit "mise à jour : annonce" 0
expect_line "mise à jour : 0.2.0" "^publication : $NAME 0\.2\.0 \(étiquette $NAME--v0\.2\.0\)$"
expect_line "mise à jour : gestes 1 à 4" '^prochaine étape — gestes 1 à 4, dont 1 vers GitHub :$'
step "$p" "mise à jour, étape 1"
expect_exit "mise à jour, étape 1 : exit 0" 0
step "$p" "mise à jour, étape 5"
expect_line "mise à jour terminée" "^publication terminée : $NAME 0\.2\.0, 5 gestes faits$"
expect_line "mise à jour sur chaque appareil" "^  claude plugin update $NAME@soon$"
[[ ! -s $work/gh-gestures.log ]] && pass "mise à jour : ni dépôt ni PR" || fail "mise à jour : ni dépôt ni PR" "$(cat "$work/gh-gestures.log")"
[[ -n $(remote tag -l "$NAME--v0.2.0") && $(remote rev-parse main) == "$(git -C "$p" rev-parse "$NAME--v0.2.0^{commit}")" ]] \
  && pass "mise à jour : main et étiquette poussés" || fail "mise à jour : main et étiquette poussés"
remote show "$NAME--v0.2.0:README.md" | grep -qF 'Version **0.2.0**' && pass "mise à jour : le README publié porte 0.2.0 (US-36)" \
  || fail "mise à jour : le README publié porte 0.2.0 (US-36)"

echo "# alignement des descriptions, rien à publier (US-37)"
# The descriptions drift on GitHub: the repository's, edited by hand; the entry and the README line
# of the marketplace, on main.
printf 'Ancienne description.' >"$GITHUB/$NAME.description"
git -C "$merged" pull -q --ff-only
jq --arg n "$NAME" '(.plugins[] | select(.name == $n) | .description) = "Ancienne description."' \
  "$merged/.claude-plugin/marketplace.json" >"$merged/m.tmp" && mv "$merged/m.tmp" "$merged/.claude-plugin/marketplace.json"
sed -i "s/^| \`$NAME\` | Plugin d'essai\. |/| \`$NAME\` | Ancienne description. |/" "$merged/README.md"
git -C "$merged" commit -qam "Soon : descriptions retouchées" && git -C "$merged" push -q origin main 2>/dev/null
market_main=$(git --git-dir="$GITHUB/claude-plugins.git" rev-parse main)
head_before=$(git -C "$p" rev-parse HEAD) tags_before=$(remote tag -l | paste -sd' ' -)
rm -f "$work/gh-gestures.log" "$work/push.log"
pp publish "$p"
expect_exit "alignement : annonce" 0
expect_line "alignement annoncé, à la version publiée" "^alignement : $NAME 0\.2\.0 \(étiquette $NAME--v0\.2\.0, publiée\) ; ni version, ni CHANGELOG, ni étiquette$"
expect_line "alignement : la description du dépôt d'abord" '^prochaine étape — gestes 1 à 1, dont 1 vers GitHub :$'
expect_line "geste 1 : gh repo edit" "^  1\. \[GitHub\] description du dépôt : gh repo edit soonlysoul/$NAME --description \"Plugin d'essai\.\"$"
step "$p" "alignement, étape 1, réponse perdue" STUB_GH_CUT=after STUB_GH_MATCH="repo edit"
expect_exit "description posée, réponse perdue : exit 1" 1
expect_line "le geste coupé est nommé" "^échoué : 1\. \[GitHub\] description du dépôt"
pp publish "$p"
expect_exit "alignement : reprise" 0
expect_line "la description posée est reconnue faite" '^déjà fait : 1\. \[GitHub\] description du dépôt'
expect_line "alignement : la marketplace ensuite" '^prochaine étape — gestes 2 à 6, dont 1 vers GitHub :$'
step "$p" "alignement, étape 2"
expect_exit "alignement, étape 2 : exit 0" 0
step "$p" "alignement, étape 7"
expect_exit "alignement, étape 7 (PR) : exit 0" 0
expect_line "alignement terminé" "^alignement terminé : $NAME 0\.2\.0, 7 gestes faits$"
expect_line "après la fusion, sur chaque appareil" '^  claude plugin marketplace update soon$'
[[ $(cat "$GITHUB/$NAME.description") == "Plugin d'essai." ]] && pass "alignement : la description du dépôt est celle de plugin.json" \
  || fail "alignement : la description du dépôt est celle de plugin.json" "$(cat "$GITHUB/$NAME.description")"
[[ $(count "$work/gh-gestures.log" '^repo edit') == 1 ]] && pass "alignement : gh repo edit une seule fois" || fail "alignement : gh repo edit une seule fois" "$(cat "$work/gh-gestures.log")"
branch="align-$NAME-0.2.0"
git --git-dir="$GITHUB/claude-plugins.git" show "$branch:.claude-plugin/marketplace.json" 2>/dev/null |
  jq -e --arg n "$NAME" '[.plugins[] | select(.name == $n)] == [{name: $n, source: {source: "github", repo: "soonlysoul/\($n)"}, description: "Plugin d'"'"'essai."}]' >/dev/null \
  && pass "alignement : l'entrée réécrite sur $branch, une seule" || fail "alignement : l'entrée réécrite sur $branch, une seule"
readme=$(git --git-dir="$GITHUB/claude-plugins.git" show "$branch:README.md" 2>/dev/null)
grep -qFx "| \`$NAME\` | Plugin d'essai. | [soonlysoul/$NAME](https://github.com/soonlysoul/$NAME) |" <<<"$readme" \
  && ! grep -qF 'Ancienne description.' <<<"$readme" && pass "alignement : la ligne du README réécrite" || fail "alignement : la ligne du README réécrite"
[[ $(grep -cFx "claude plugin install $NAME@soon --scope user" <<<"$readme") == 1 ]] && pass "alignement : la commande d'installation n'est pas doublée" \
  || fail "alignement : la commande d'installation n'est pas doublée"
[[ $(git --git-dir="$GITHUB/claude-plugins.git" rev-parse main) == "$market_main" ]] && pass "alignement : main de la marketplace inchangé" \
  || fail "alignement : main de la marketplace inchangé"
[[ $(tail -n 1 "$GITHUB/prs") == "$branch	main	Aligner la description de $NAME" ]] && pass "alignement : une PR, de $branch vers main" \
  || fail "alignement : une PR, de $branch vers main" "$(tail -n 1 "$GITHUB/prs")"
[[ $(git -C "$p" rev-parse HEAD) == "$head_before" && $(remote tag -l | paste -sd' ' -) == "$tags_before" && -z $(git -C "$p" status --porcelain) ]] \
  && pass "alignement : ni commit, ni étiquette, arbre propre" || fail "alignement : ni commit, ni étiquette, arbre propre"
[[ $(cat "$work/push.log") == "-C $work/tmp/plugin-plugin-release/$NAME/$branch push origin $branch" ]] \
  && pass "alignement : seul le push de la branche" || fail "alignement : seul le push de la branche" "$(cat "$work/push.log")"
[[ $(gestures_log "$p" | grep -c $'\talignement [0-9]*\t.*\tfait\texit 0\t') == 6 ]] && pass "journal : l'alignement à part, 6 faits et un déjà fait" \
  || fail "journal : l'alignement à part, 6 faits et un déjà fait" "$(gestures_log "$p" | grep alignement)"
pp release "$p"
expect_exit "PR d'alignement ouverte : nouvelle répétition refusée" 1
expect_line "la PR ouverte est nommée" "refusé : la branche $branch est déjà sur GitHub \(soonlysoul/claude-plugins\) ; PR ouverte : https://github\.com/soonlysoul/claude-plugins/pull/[0-9]+"

echo "# montage en sous-module (US-26)"
host="$work/hote"
git init -q -b main "$host" && printf '# hôte\n' >"$host/README.md" && commit "$host" "init"
pp mount "$p" --host "$host"
expect_exit "montage : annonce" 0
expect_line "montage : sous-module à la racine de l'hôte" "^  1\. \[local\] sous-module : git -C $host submodule add https://github.com/soonlysoul/$NAME\.git $NAME$"
expect_line "montage : épinglé sur l'étiquette" "^  2\. \[local\] épinglage : git -C $host/$NAME checkout -q refs/tags/$NAME--v0\.2\.0$"
expect_line "montage : commande à taper" "^commande : bash .*pp\.sh mount $p --host $host --run$"
guard "$p" "$(announced)"
[[ $GUARD_STATUS == 2 ]] && pass "montage sans « oui » : bloqué" || fail "montage sans « oui » : bloqué" "exit $GUARD_STATUS"
[[ ! -e $host/.gitmodules ]] && pass "montage annoncé : hôte intact" || fail "montage annoncé : hôte intact"
step "$p" "montage"
expect_exit "montage : exit 0" 0
[[ $(git -C "$host" config -f .gitmodules "submodule.$NAME.url") == "https://github.com/soonlysoul/$NAME.git" ]] \
  && pass "hôte : .gitmodules vers le dépôt GitHub" || fail "hôte : .gitmodules vers le dépôt GitHub" "$(cat "$host/.gitmodules" 2>&1)"
[[ $(git -C "$host" ls-tree HEAD "$NAME" | awk '{print $3}') == "$(git -C "$p" rev-parse "$NAME--v0.2.0^{commit}")" ]] \
  && pass "hôte : sous-module épinglé sur l'étiquette, commité" || fail "hôte : sous-module épinglé sur l'étiquette, commité"
[[ -z $(git -C "$host" status --porcelain) ]] && pass "hôte : arbre propre" || fail "hôte : arbre propre" "$(git -C "$host" status --porcelain)"
pp mount "$p" --host "$host"
expect_exit "montage refait : refusé" 1
expect_line "montage refait : déjà monté" 'refusé : .*déjà monté'
pp mount "$c" --host "$host" --path plugins/coupure
expect_exit "montage d'un autre plugin, chemin choisi : annonce" 0
pp mount "$work/first/$NAME" --host "$work/nulle-part"
expect_exit "hôte absent : refusé" 1
unpublished=$(copy unpublished)
pp mount "$unpublished" --host "$host"
expect_exit "plugin jamais publié : refusé" 1
expect_line "plugin jamais publié : raison nommée" 'refusé : .*aucune étiquette'

finish
