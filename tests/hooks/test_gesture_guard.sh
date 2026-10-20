#!/usr/bin/env bash
# gesture-guard (PreToolUse, Bash|Edit|Write, fail-closed): in a managed plugin repository or a
# clone of the marketplace soon, a GitHub gesture runs only when it is the command announced in
# .plugin-plugin/pending and consents.log holds the « oui » captured for that announcement — once.
# Destructive gestures are refused even then. The journal of consents is never written by a tool.
# Inert anywhere else, and without depending on any other hook: the consent is read from disk.
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

RUN="bash /opt/pp/scripts/pp.sh publish $P --run 4"
SHA=2222222222222222222222222222222222222222222222222222222222222222
ID="publish plugin-essai--v0.1.0 4"

bash_input() {
  jq -nc --arg cwd "$1" --arg c "$2" \
    '{session_id: "test", cwd: $cwd, hook_event_name: "PreToolUse", permission_mode: "default",
      tool_name: "Bash", tool_input: {command: $c}, tool_use_id: "toolu_test"}'
}
file_input() {
  jq -nc --arg cwd "$1" --arg t "$2" --arg f "$3" \
    '{session_id: "test", cwd: $cwd, hook_event_name: "PreToolUse", permission_mode: "default",
      tool_name: $t, tool_input: {file_path: $f, content: "x"}, tool_use_id: "toolu_test"}'
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

echo "# lectures dans le contexte"
for cmd in "git status" "git log --oneline" "gh api repos/soonlysoul/plugin-essai" "gh pr list --repo soonlysoul/claude-plugins" \
  "git -C $P ls-remote origin" "cat .plugin-plugin/consents.log" "bash /opt/pp/scripts/pp.sh publish $P"; do
  guard "$P" "$cmd"
  expect_silent_allow "lecture : « $cmd » passe"
done

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
for cmd in "printf 'x' >> .plugin-plugin/consents.log" "echo x > $P/.plugin-plugin/pending" "tee -a .plugin-plugin/consents.log </dev/null" \
  "sed -i d .plugin-plugin/consents.log" "rm .plugin-plugin/pending"; do
  guard "$P" "$cmd"
  expect_reason "« $cmd » : bloqué" "hook"
done

echo "# entrée illisible, jq absent"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": "git push origin main"'
expect_blocked "entrée illisible qui contient un geste : bloquée"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": "ls"'
expect_silent_allow "entrée illisible sans geste : passe"
no_jq=$(path_without jq)
run_hook "$HOOK" "$(bash_input "$P" "git push origin main")" PATH="$no_jq"
expect_blocked "jq absent, geste : bloqué"
run_hook "$HOOK" "$(bash_input "$P" "git status")" PATH="$no_jq"
expect_silent_allow "jq absent, sans geste : passe"
run_hook "$HOOK" "$(file_input "$U" Write "$U/notes.md")" PATH="$no_jq"
expect_silent_allow "jq absent, écriture ailleurs : passe"
rm -rf "$no_jq"

finish
