#!/usr/bin/env bash
# gesture-guard (PreToolUse, Bash|Edit|Write, fail-closed): in a managed plugin repository or a
# clone of the marketplace soon, a GitHub gesture runs only when it is the command announced in
# .plugin-plugin/pending and consents.log holds the « oui » captured for that announcement — once.
# Destructive gestures are refused even then. The journal of consents is never written by a tool.
# Inert anywhere else, and without depending on any other hook: the consent is read from disk.
# Its context is tested first, with bash builtins only (R7): outside it, a call goes through even
# without jq, without any command at all, or on an unreadable input; in it, those block.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_gesture_guard
HOOK="$PLUGIN_ROOT/hooks/scripts/gesture-guard.sh"

work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
export GIT_CEILING_DIRECTORIES="$work"

if [[ ! -f $HOOK ]]; then
  fail "hooks/scripts/gesture-guard.sh présent" "absent : $HOOK"
  finish
  exit
fi

# Repositories: P a managed plugin, F a plugin of the model that plugin-plugin does not manage,
# M a clone of the marketplace soon, U an unrelated repository.
P="$work/plugin-essai" F="$work/plugin-autre" M="$work/claude-plugins" U="$work/autre"
for repo in "$P" "$F" "$M" "$U"; do git init -q -b main "$repo"; done
mkdir -p "$P/.claude-plugin" "$P/.plugin-plugin" "$P/skills/demo" "$F/.claude-plugin" "$M/.claude-plugin"
echo '{"name": "plugin-essai"}' >"$P/.claude-plugin/plugin.json"
echo '{"name": "plugin-autre"}' >"$F/.claude-plugin/plugin.json"
echo '{"name": "soon", "owner": {"name": "Soon"}, "plugins": []}' >"$M/.claude-plugin/marketplace.json"
# Q, a managed plugin whose path the JSON input has to escape: the context reads it without jq.
Q="$work/plugin à \"part\" \\x"
mkdir -p "$Q/.plugin-plugin"

RUN="bash /opt/pp/scripts/pp.sh publish $P --run 4"
SHA=2222222222222222222222222222222222222222222222222222222222222222
ID="publish plugin-essai--v0.1.0 4"

bash_input() {
  jq -nc --arg cwd "$1" --arg c "$2" \
    '{session_id: "test", cwd: $cwd, hook_event_name: "PreToolUse", permission_mode: "default",
      tool_name: "Bash", tool_input: {command: $c}, tool_use_id: "toolu_test"}'
}
# file_input <cwd> <tool> <file> [content]
file_input() {
  jq -nc --arg cwd "$1" --arg t "$2" --arg f "$3" --arg c "${4:-x}" \
    '{session_id: "test", cwd: $cwd, hook_event_name: "PreToolUse", permission_mode: "default",
      tool_name: $t, tool_input: {file_path: $f, content: $c}, tool_use_id: "toolu_test"}'
}
guard() { run_hook "$HOOK" "$(bash_input "$1" "$2")"; }
# announce <command> [epoch]: the announcement pp.sh writes; consent [epoch]: the « oui » the
# capture hook writes for it.
announce() { printf '%s\t%s\t%s\t%s\n' "${2:-100}" "$ID" "$SHA" "$1" >"$P/.plugin-plugin/pending"; }
consent() { printf '2026-10-20T10:00:00+02:00\taccord\t%s\t%s\t%s\t« oui »\n' "$ID" "${1:-100}" "$SHA" >>"$P/.plugin-plugin/consents.log"; }
refusal() { printf '2026-10-20T10:00:00+02:00\trefus\t%s\t%s\t%s\n' "$ID" "${1:-100}" "$SHA" >>"$P/.plugin-plugin/consents.log"; }
reset_state() { rm -f "$P/.plugin-plugin/pending" "$P/.plugin-plugin/consents.log"; }
expect_reason() {
  if [[ $HOOK_STATUS == 2 ]] && grep -qiE -- "$2" <<<"$HOOK_STDERR"; then pass "$1"
  else fail "$1" "attendu exit 2 et « $2 », obtenu exit $HOOK_STATUS ; stderr : ${HOOK_STDERR:0:300}"; fi
}

echo "# inerte hors contexte"
for cmd in "git push origin main" "git push --force origin main" "gh repo delete soonlysoul/x --yes" "gh pr create --title x"; do
  guard "$U" "$cmd"
  expect_silent_allow "dépôt sans rapport : « $cmd » passe"
done
guard "$F" "git push origin main"
expect_silent_allow "plugin non géré par plugin-plugin : inerte"
guard "$work" "ls -la"
expect_silent_allow "hors de tout dépôt : inerte"
guard "$U" "cd build && git push origin main"
expect_silent_allow "cd vers un dossier sans rapport : inerte"

echo "# lectures dans le contexte"
for cmd in "git status" "git log --oneline" "gh api repos/soonlysoul/plugin-essai" "gh pr list --repo soonlysoul/claude-plugins" \
  "git -C $P ls-remote origin" "cat .plugin-plugin/consents.log" "bash /opt/pp/scripts/pp.sh publish $P"; do
  guard "$P" "$cmd"
  expect_silent_allow "lecture : « $cmd » passe"
done

echo "# gh api graphql : seule une mutation est un geste"
reset_state
for dir in "$P" "$U"; do
  printf 'query($owner: String!, $name: String!) {\n  repository(owner: $owner, name: $name) { stargazerCount }\n}\n' >"$dir/q.graphql"
done
printf 'mutation($id: ID!) {\n  addStar(input: {starrableId: $id}) { clientMutationId }\n}\n' >"$P/m.graphql"
printf '{"query": "mutation { addStar(input: {starrableId: \\"R_1\\"}) { clientMutationId } }"}\n' >"$P/m.json"
printf '{"query": "query { viewer { login } }"}\n' >"$P/q.json"
MUTATION="gh api graphql -f query='mutation { addStar(input: {starrableId: \"R_1\"}) { clientMutationId } }'"
for cmd in "gh api graphql -f query='query { viewer { login } }'" \
  "gh api graphql -F query=@q.graphql -f owner=cli -f name=cli" \
  "gh api graphql --raw-field query='query(\$n: Int!) { viewer { repositories(first: \$n) { totalCount } } }' -F n=10" \
  "gh api graphql --input q.json" "gh api -F query=@q.graphql graphql" "cd skills/demo && gh api graphql -F query=@../../q.graphql"; do
  guard "$P" "$cmd"
  expect_silent_allow "lecture GraphQL : « $cmd » passe"
done
guard "$P/skills/demo" "gh api graphql -F query=@../../q.graphql -F first=10"
expect_silent_allow "lecture GraphQL, fichier relatif au dossier de l'appel : passe"
guard "$P" "$MUTATION"
expect_reason "mutation en ligne : bloquée, nommée POST et mutation" "gh api POST graphql \(mutation\)"
for cmd in "gh api graphql -F query=@m.graphql -f id=R_1" "gh api graphql --input m.json" "gh api graphql -F query=@absent.graphql" \
  "gh api graphql --input -" "gh api graphql -F query=@-" "gh api graphql -f owner=cli -f name=cli" \
  "gh api graphql -f query=\"\$(cat q.graphql)\""; do
  guard "$P" "$cmd"
  expect_reason "mutation ou requête illisible : « $cmd » bloqué" "POST graphql \(mutation\)"
done
guard "$P/skills/demo" "gh api graphql -F query=@q.graphql"
expect_reason "fichier absent du dossier de l'appel : bloqué" "sans accord"
guard "$P" "gh api repos/soonlysoul/plugin-essai -f a=b"
expect_reason "REST avec un champ : toujours un geste" "sans accord"
guard "$P" "gh api repos/soonlysoul/plugin-essai"
expect_silent_allow "REST sans champ : passe toujours"
guard "$U" "gh api graphql -F query=@q.graphql -f owner=cli -f name=cli"
expect_silent_allow "lecture GraphQL hors contexte : inerte"
guard "$U" "$MUTATION"
expect_silent_allow "mutation hors contexte : inerte"
rm -f "$P/q.graphql" "$P/m.graphql" "$P/m.json" "$P/q.json" "$U/q.graphql"

echo "# geste sans accord"
reset_state
guard "$P" "git push origin main"
expect_reason "push sans annonce : bloqué, raison nommée" "sans accord"
guard "$P" "$RUN"
expect_reason "commande d'exécution sans annonce : bloquée" "aucun geste annoncé"
guard "$P" "gh repo create soonlysoul/plugin-essai --public"
expect_blocked "création de dépôt sans accord : bloquée"
guard "$P" "gh api -X POST repos/soonlysoul/claude-plugins/pulls -f title=x"
expect_blocked "écriture par gh api sans accord : bloquée"
guard "$P" "claude plugin tag --push ."
expect_blocked "claude plugin tag --push sans accord : bloqué"
guard "$P" "claude plugin tag --dry-run ."
expect_silent_allow "claude plugin tag --dry-run : passe"
announce "$RUN"
guard "$P" "$RUN"
expect_reason "annoncé, sans « oui » : bloqué" "aucun « oui »"
refusal
guard "$P" "$RUN"
expect_reason "annoncé, puis refusé : bloqué" "aucun « oui »"

echo "# un « oui » laisse passer une fois la commande annoncée"
reset_state
announce "$RUN"
consent
guard "$P" "git -C $P push origin main"
expect_reason "accord, autre commande : bloquée" "annoncée"
[[ -f $P/.plugin-plugin/pending ]] && pass "une commande refusée ne consomme pas l'accord" || fail "une commande refusée ne consomme pas l'accord"
guard "$P" "  $RUN  "
expect_silent_allow "accord, commande annoncée : passe"
[[ ! -e $P/.plugin-plugin/pending ]] && pass "l'annonce est consommée" || fail "l'annonce est consommée"
guard "$P" "$RUN"
expect_blocked "la même commande, une seconde fois : bloquée"
announce "$RUN" 200
guard "$P" "$RUN"
expect_reason "nouvelle annonce, accord de l'ancienne : bloquée" "aucun « oui »"
consent 200
guard "$P/skills/demo" "$RUN"
expect_silent_allow "session dans un sous-dossier du projet : passe"

echo "# geste vers le contexte depuis ailleurs"
reset_state
guard "$U" "git -C $P push origin main"
expect_blocked "git -C vers le plugin géré, depuis ailleurs : bloqué"
guard "$U" "cd $P && git push origin main"
expect_blocked "cd vers le plugin géré, depuis ailleurs : bloqué"
guard "$M" "git push origin add-plugin-essai"
expect_blocked "push dans la marketplace sans accord : bloqué"
guard "$U" "gh pr create --repo soonlysoul/claude-plugins --base main --head add-x --title x --body y"
expect_blocked "PR vers la marketplace sans accord, depuis ailleurs : bloquée"
guard "$U" "bash /opt/pp/scripts/pp.sh publish $P --run 4"
expect_blocked "commande d'exécution de pp.sh, depuis ailleurs : bloquée"
guard "$U" "cd ../plugin-essai && git push origin main"
expect_reason "cd relatif vers le plugin géré, depuis ailleurs : bloqué" "sans accord"
guard "$work" "cd plugin-essai/skills && cd .. && git push origin main"
expect_reason "deux cd relatifs enchaînés vers le plugin géré : bloqué" "sans accord"
guard "$U" "cd \"../plugin-essai\" && git push origin main"
expect_reason "cd entre guillemets vers le plugin géré : bloqué" "sans accord"
guard "$U" "git -C ../plugin-essai push origin main"
expect_reason "git -C relatif vers le plugin géré, depuis ailleurs : bloqué" "sans accord"
guard "$U" "cd ../claude-plugins && git push origin main"
expect_reason "cd vers la marketplace, push sur main : refusé" "jamais"
guard "$Q" "git push origin main"
expect_reason "plugin géré dont le chemin s'échappe en JSON : bloqué" "aucun geste annoncé"

echo "# gestes destructifs, refusés même accordés"
for cmd in "git push --force origin main" "git push -f origin main" "git push --force-with-lease origin main" \
  "git push origin +main" "git push origin :refs/tags/plugin-essai--v0.1.0" "git push --delete origin main" \
  "git push --mirror origin" "gh repo delete soonlysoul/plugin-essai --yes" "gh pr merge 3 --repo soonlysoul/claude-plugins" \
  "gh api -X DELETE repos/soonlysoul/plugin-essai" "gh api --method PUT repos/soonlysoul/claude-plugins/pulls/3/merge" \
  "git filter-branch --tree-filter true HEAD" "git filter-repo --path skills"; do
  reset_state
  announce "$cmd"
  consent
  guard "$P" "$cmd"
  expect_reason "« $cmd » : refusé" "destructi|jamais"
done
reset_state
guard "$M" "git push origin main"
expect_reason "push sur main de la marketplace : refusé" "jamais"

echo "# le journal des accords ne s'écrit pas par un outil"
for tool in Edit Write; do
  for file in consents.log pending; do
    run_hook "$HOOK" "$(file_input "$P" "$tool" "$P/.plugin-plugin/$file")"
    expect_reason "$tool sur .plugin-plugin/$file : bloqué" "hook"
  done
done
run_hook "$HOOK" "$(file_input "$P" Edit "$P/skills/demo/SKILL.md")"
expect_silent_allow "Edit sur un fichier du plugin : passe"
run_hook "$HOOK" "$(file_input "$U" Write "$U/notes.md")"
expect_silent_allow "Write hors contexte : passe"
run_hook "$HOOK" "$(file_input "$U" Write "$P/.plugin-plugin/consents.log")"
expect_reason "Write du journal d'un plugin géré, depuis ailleurs : bloqué" "hook"
run_hook "$HOOK" "$(file_input "$U" Write "$U/x/.plugin-plugin/pending")"
expect_reason "Write d'une annonce dans un .plugin-plugin/ qui n'existe pas encore : bloqué" "hook"
guard "$U" "echo x > ../plugin-essai/.plugin-plugin/pending"
expect_reason "écriture du journal par Bash, depuis ailleurs : bloquée" "hook"
for cmd in "printf 'x' >> .plugin-plugin/consents.log" "echo x > $P/.plugin-plugin/pending" "tee -a .plugin-plugin/consents.log </dev/null" \
  "sed -i d .plugin-plugin/consents.log" "rm .plugin-plugin/pending"; do
  guard "$P" "$cmd"
  expect_reason "« $cmd » : bloqué" "hook"
done

echo "# AskUserQuestion : seul Soon répond"
# Claude Code 2.1.316, probe of phase 25: Claude may fill answers in its own call; the interactive
# dialog still shows, but another host may keep that answer without showing anything. In a managed
# project, a question whose answer Claude filled is refused; anywhere else, the guard stays inert.
QUESTION="Lancer l'étape « $ID » ?"
# ask_input <cwd> [answers as JSON]: the AskUserQuestion call Claude makes, seen by PreToolUse.
ask_input() {
  jq -nc --arg cwd "$1" --arg q "$QUESTION" --argjson a "${2:-null}" '
    {session_id: "test", cwd: $cwd, hook_event_name: "PreToolUse", permission_mode: "auto",
     tool_name: "AskUserQuestion", tool_use_id: "toolu_test",
     tool_input: ({questions: [{question: $q, header: "Accord", multiSelect: false,
                                options: [{label: "Non", description: "Ne pas lancer."}, {label: "Oui", description: "Lancer."}]}]}
                  + (if $a == null then {} else {answers: $a} end))}'
}
filled=$(jq -nc --arg q "$QUESTION" '{($q): "Oui"}')
run_hook "$HOOK" "$(ask_input "$P")"
expect_silent_allow "question sans réponse remplie, plugin géré : passe"
run_hook "$HOOK" "$(ask_input "$P" '{}')"
expect_silent_allow "réponses vides, plugin géré : passe"
run_hook "$HOOK" "$(ask_input "$P" "$filled")"
expect_reason "réponse remplie par Claude, plugin géré : refusée" "answers"
run_hook "$HOOK" "$(ask_input "$P/skills/demo" "$filled")"
expect_reason "réponse remplie par Claude, sous-dossier du plugin géré : refusée" "answers"
run_hook "$HOOK" "$(ask_input "$P" '{"Quelle langue pour les identifiants ?": "Anglais (Recommandé)"}')"
expect_reason "réponse remplie à une autre question, plugin géré : refusée" "answers"
run_hook "$HOOK" "$(jq -nc --arg cwd "$P" '{session_id: "test", cwd: $cwd, hook_event_name: "PreToolUse",
  tool_name: "AskUserQuestion", tool_use_id: "t", tool_input: {questions: [{question: "Le champ \"answers\": {\"x\": 1} est-il vide ?",
  header: "Champ", multiSelect: false, options: [{label: "Non", description: "n"}, {label: "Oui", description: "o"}]}]}}')"
expect_silent_allow "question qui cite answers sans le remplir, plugin géré : passe"
for dir in "$U" "$M" "$F"; do
  run_hook "$HOOK" "$(ask_input "$dir" "$filled")"
  expect_silent_allow "réponse remplie hors d'un projet géré (${dir##*/}) : inerte"
done
run_hook "$HOOK" "$(ask_input "$U" "$filled")" PATH=
expect_silent_allow "PATH vide, réponse remplie hors contexte : inerte"
no_jq=$(path_without jq)
run_hook "$HOOK" "$(ask_input "$P" "$filled")" PATH="$no_jq"
expect_reason "jq absent, réponse remplie dans le plugin géré : bloquée" "jq absent"
run_hook "$HOOK" "$(ask_input "$P")" PATH="$no_jq"
expect_silent_allow "jq absent, question sans réponse remplie : passe"
rm -rf "$no_jq"
run_hook "$HOOK" "$(ask_input "$Q" "$filled")" PATH=
expect_reason "PATH vide, réponse remplie, plugin géré dont le chemin s'échappe en JSON : bloquée" "jq absent"

echo "# entrée illisible, jq absent"
# truncated <cwd>: an input cut before its end, whose cwd and command still read.
truncated() { printf '{"session_id": "test", "cwd": "%s", "tool_name": "Bash", "tool_input": {"command": "git push origin main"' "$1"; }
run_hook "$HOOK" "$(truncated "$P")"
expect_reason "entrée illisible dans un plugin géré, avec un geste : bloquée" "illisible"
run_hook "$HOOK" "$(truncated "$U")"
expect_silent_allow "entrée illisible ailleurs, avec un geste : passe"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": "git push origin main"'
expect_silent_allow "cwd illisible, absent d'une entrée tronquée : hors contexte, passe"
run_hook "$HOOK" '{"cwd": null, "tool_name": "Bash", "tool_input": {"command": "git push origin main"}}'
expect_silent_allow "cwd illisible, null : hors contexte, passe"
run_hook "$HOOK" '{"cwd": "plugin-essai", "tool_name": "Bash", "tool_input": {"command": "git push origin main"}}'
expect_silent_allow "cwd illisible, relatif : hors contexte, passe"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": "ls"'
expect_silent_allow "entrée illisible sans geste : passe"
no_jq=$(path_without jq)
run_hook "$HOOK" "$(bash_input "$P" "git push origin main")" PATH="$no_jq"
expect_blocked "jq absent, geste : bloqué"
run_hook "$HOOK" "$(bash_input "$P" "git status")" PATH="$no_jq"
expect_silent_allow "jq absent, sans geste : passe"
run_hook "$HOOK" "$(file_input "$U" Write "$U/notes.md")" PATH="$no_jq"
expect_silent_allow "jq absent, écriture ailleurs : passe"
run_hook "$HOOK" "$(bash_input "$U" "git push origin main")" PATH="$no_jq"
expect_silent_allow "jq absent, geste hors contexte : passe"
run_hook "$HOOK" "$(bash_input "$U" "cd build && git push origin main")" PATH="$no_jq"
expect_silent_allow "jq absent, cd vers un dossier sans rapport : passe"
run_hook "$HOOK" "$(file_input "$U" Write "$U/notes.md" "Avant git push, relire.")" PATH="$no_jq"
expect_silent_allow "jq absent, texte écrit qui parle de git push : passe"
run_hook "$HOOK" "$(file_input "$P" Write "$P/docs/x.md" "Voir .plugin-plugin/consents.log.")" PATH="$no_jq"
expect_silent_allow "jq absent, texte écrit dans le plugin géré qui cite le journal : passe"
run_hook "$HOOK" "$(bash_input "$U" "cat ../plugin-essai/.plugin-plugin/consents.log")" PATH="$no_jq"
expect_silent_allow "jq absent, lecture du journal : passe"
run_hook "$HOOK" "$(bash_input "$U" "cd ../plugin-essai && git push origin main")" PATH="$no_jq"
expect_reason "jq absent, cd vers le plugin géré : bloqué" "jq absent"
run_hook "$HOOK" "$(file_input "$U" Write "$P/.plugin-plugin/consents.log")" PATH="$no_jq"
expect_reason "jq absent, écriture du journal depuis ailleurs : bloquée" "jq absent"
rm -rf "$no_jq"

echo "# sans aucune commande : le contexte se teste en builtins seuls"
for cmd in "git push origin main" "gh repo delete soonlysoul/x --yes" "cd build && git push origin main" "grep -r push docs"; do
  run_hook "$HOOK" "$(bash_input "$U" "$cmd")" PATH=
  expect_silent_allow "PATH vide, hors contexte : « $cmd » passe en silence"
done
run_hook "$HOOK" "$(file_input "$U" Write "$U/notes.md" "Avant git push, relire.")" PATH=
expect_silent_allow "PATH vide, texte écrit hors contexte : passe en silence"
for cmd in "cd ../plugin-essai && git push origin main" "git -C ../plugin-essai push origin main" \
  "$RUN" "gh pr create --repo soonlysoul/claude-plugins --base main --head add-x --title x --body y" \
  "echo x > ../plugin-essai/.plugin-plugin/pending"; do
  run_hook "$HOOK" "$(bash_input "$U" "$cmd")" PATH=
  expect_reason "PATH vide, dans le contexte : « $cmd » bloqué" "jq absent"
done
run_hook "$HOOK" "$(bash_input "$P" "git push origin main")" PATH=
expect_reason "PATH vide, session dans le plugin géré : bloqué" "jq absent"
run_hook "$HOOK" "$(bash_input "$M" "git push origin add-plugin-essai")" PATH=
expect_reason "PATH vide, session dans la marketplace : bloqué" "jq absent"
run_hook "$HOOK" "$(bash_input "$Q" "git push origin main")" PATH=
expect_reason "PATH vide, plugin géré dont le chemin s'échappe en JSON : bloqué" "jq absent"
run_hook "$HOOK" "$(file_input "$U" Write "$P/.plugin-plugin/pending")" PATH=
expect_reason "PATH vide, Write du journal depuis ailleurs : bloqué" "jq absent"

finish
