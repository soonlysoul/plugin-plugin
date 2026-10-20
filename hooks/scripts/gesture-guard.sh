#!/usr/bin/env bash
# gesture-guard — PreToolUse hook for Bash, Edit and Write.
# In a managed plugin repository (a .plugin-plugin/ at or above it) or a clone of the marketplace
# soon, a GitHub gesture — git push, a gh command that writes, claude plugin tag --push, a step run
# by pp.sh --run — goes through only when it is the command announced in .plugin-plugin/pending of
# the session's project, and consents.log holds the « oui » consent-capture captured for that
# announcement; the announcement is then consumed, so the command passes once. Destructive gestures
# are refused even so: deleting a repository, a forced push, rewriting history, a push on main of
# the marketplace, a merge. The announcement and the journal of consents are never written by a
# tool. The consent is read from disk: the guard depends on no other hook.
# Inert anywhere else, even without jq: installed for the account, it sees every Bash call and
# every write of every session. Not proof against a determined bypass (a script that pushes), it
# stops the gesture typed by mistake.
# Fail-closed: exit 2 blocks with the reason on stderr; hooks.json sets "onFailure": "block".

IFS= read -r -d '' input || true
# Fast path: nothing that could be a gesture or touch the journal of consents.
grep -qE 'push|gh[[:space:]]|pp\.sh|\.plugin-plugin/|filter-(branch|repo)|plugin[[:space:]]+tag' <<<"$input" || exit 0
block() { printf 'gesture-guard : %s\n' "$1" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || block "jq absent : ce geste ne peut pas être vérifié ; bloqué par prudence."
# shellcheck source=../../scripts/lib/consent.sh
source "${BASH_SOURCE[0]%/*}/../../scripts/lib/consent.sh" 2>/dev/null || block "scripts/lib/consent.sh illisible ; bloqué par prudence."
tool=$(jq -r '.tool_name // empty | strings' <<<"$input" 2>/dev/null) || block "entrée illisible ; bloquée par prudence."
cwd=$(jq -r '.cwd // empty | strings' <<<"$input")
JOURNAL='\.plugin-plugin/(pending|consents\.log)'
JOURNAL_REASON="l'annonce (.plugin-plugin/pending) ne s'écrit que par pp.sh, le journal des accords (.plugin-plugin/consents.log) que par le hook consent-capture ; jamais par un outil."

case $tool in
  Edit | Write | MultiEdit | NotebookEdit)
    file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty | strings' <<<"$input")
    [[ $file =~ /$JOURNAL$ ]] && block "$file : $JOURNAL_REASON"
    exit 0
    ;;
  Bash) ;;
  *) exit 0 ;;
esac
command=$(jq -r '.tool_input.command // empty | strings' <<<"$input")
if [[ $command =~ $JOURNAL ]] && grep -qE '>|(^|[^[:alnum:]_-])(tee|rm|mv|cp|touch|truncate|dd|ln|install|chmod)([^[:alnum:]_-]|$)|sed[^|;&]*[[:space:]]-i' <<<"$command"; then
  block "$JOURNAL_REASON"
fi

# resolve <dir> <base>: <dir> made absolute against <base>.
resolve() {
  local dir=${1/#\~/$HOME}
  [[ $dir == /* ]] || dir="$2/$dir"
  (cd "$dir" 2>/dev/null && pwd -P) || printf '%s' "$dir"
}
# marketplace <dir>: true inside a clone of the marketplace soon.
marketplace() {
  local top
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
  jq -e '.name == "soon"' "$top/.claude-plugin/marketplace.json" >/dev/null 2>&1
}
in_context() { managed_project "$1" >/dev/null || marketplace "$1"; }

gesture="" destructive="" context=0
note_gesture() { gesture=${gesture:-$1}; }
note_destructive() { destructive=${destructive:-$1}; }

# git_push <dir> <args...>: a push from <dir>, and what makes it destructive.
git_push() {
  local dir=$1 arg remote="" dest branch
  local -a refspecs=()
  shift
  note_gesture "git push"
  for arg in "$@"; do
    case $arg in
      --force* | --mirror | --delete | --prune) note_destructive "push forcé ou suppression de référence ($arg)" ;;
      --*) ;;
      -*[fd]*) note_destructive "push forcé ou suppression de référence ($arg)" ;;
      -*) ;;
      +* | :*) note_destructive "push forcé ou suppression de référence ($arg)" ;;
      *) if [[ -z $remote ]]; then remote=$arg; else refspecs+=("$arg"); fi ;;
    esac
  done
  in_context "$dir" && context=1
  marketplace "$dir" || return 0
  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)
  ((${#refspecs[@]})) || refspecs=("$branch")
  for arg in "${refspecs[@]}"; do
    dest=${arg##*:}
    [[ $dest == HEAD ]] && dest=$branch
    [[ $dest == main || $dest == refs/heads/main ]] \
      && note_destructive "push sur main de la marketplace soon : elle ne change que par une branche et une PR, jamais sur main"
  done
}

# segment <dir> <tokens...>: one simple command, run from <dir>. Sets CURDIR after a cd.
segment() {
  local dir=$1 word i
  shift
  local -a t=("$@")
  i=0
  # Skip assignments, wrappers and an inline script: the command word is what runs.
  while ((i < ${#t[@]})); do
    case ${t[i]} in
      [A-Za-z_]*=*) i=$((i + 1)) ;;
      env | command | exec | sudo | time | nohup | nice) i=$((i + 1)) ;;
      bash | sh | zsh) if [[ ${t[i + 1]:-} =~ ^-[a-z]*c$ ]]; then i=$((i + 2)); else break; fi ;;
      *) break ;;
    esac
  done
  ((i < ${#t[@]})) || return 0
  word=${t[i]##*/}
  case $word in
    cd)
      CURDIR=$(resolve "${t[i + 1]:-$HOME}" "$dir")
      ;;
    git)
      local j=$((i + 1)) target=$dir
      while ((j < ${#t[@]})); do
        case ${t[j]} in
          -C) target=$(resolve "${t[j + 1]:-.}" "$target"); j=$((j + 2)) ;;
          -c) j=$((j + 2)) ;;
          -*) j=$((j + 1)) ;;
          *) break ;;
        esac
      done
      case ${t[j]:-} in
        push) git_push "$target" "${t[@]:j+1}" ;;
        filter-branch | filter-repo)
          note_destructive "réécriture d'historique (git ${t[j]})"
          in_context "$target" && context=1
          ;;
      esac
      ;;
    gh)
      local group=${t[i + 1]:-} action=${t[i + 2]:-} arg method=GET fields=0 endpoint=""
      [[ " ${t[*]} " == *soonlysoul/claude-plugins* ]] && context=1
      in_context "$dir" && context=1
      case "$group $action" in
        "repo delete") note_destructive "suppression de dépôt (gh repo delete)" ;;
        "pr merge") note_destructive "fusion (gh pr merge) : la PR de la marketplace se fusionne par Soon" ;;
      esac
      if [[ $group == api ]]; then
        for ((j = i + 2; j < ${#t[@]}; j++)); do
          arg=${t[j]}
          case $arg in
            -X | --method) method=${t[j + 1]:-}; j=$((j + 1)) ;;
            -X* | --method=*) method=${arg#-X}; method=${method#--method=} ;;
            -f | -F | --field | --raw-field | --input | -f* | -F* | --field=* | --raw-field=* | --input=*) fields=1 ;;
            -*) ;;
            *) [[ -n $endpoint ]] || endpoint=$arg ;;
          esac
        done
        method=${method^^}
        [[ $method == DELETE ]] && note_destructive "suppression par gh api (-X DELETE $endpoint)"
        [[ $endpoint == */merge && $method != GET ]] && note_destructive "fusion par gh api ($endpoint)"
        [[ $method != GET || $fields == 1 ]] && note_gesture "gh api $method $endpoint"
      elif [[ $group =~ ^(repo|pr|issue|release|secret|variable|label|workflow|gist|ruleset|project)$ \
        && $action =~ ^(create|delete|edit|rename|archive|unarchive|fork|sync|merge|close|reopen|comment|review|ready|upload|set|run|transfer|lock|unlock|pin|unpin|develop)$ ]]; then
        note_gesture "gh $group $action"
      fi
      ;;
    claude)
      if [[ " ${t[*]:i+1} " == *" plugin tag "* && " ${t[*]} " == *" --push "* ]]; then
        note_gesture "claude plugin tag --push"
        local last=${t[${#t[@]} - 1]}
        [[ $last == -* ]] && last=.
        in_context "$(resolve "$last" "$dir")" && context=1
      fi
      ;;
    *)
      # A step of pp.sh run with --run: always ours, always in context.
      if [[ $word == pp.sh || ( $word =~ ^(bash|sh)$ && ${t[i + 1]:-} == *pp.sh ) ]] && [[ " ${t[*]} " == *" --run "* ]]; then
        note_gesture "étape de pp.sh (--run)"
        context=1
      fi
      ;;
  esac
}

# Simple commands, split on the shell's separators and substitutions; quotes peeled off each word.
CURDIR=$(resolve "${cwd:-.}" /)
in_context "$CURDIR" && context_cwd=1 || context_cwd=0
split=$command
for separator in '&&' '||' ';' '|' '&' '$(' '`' '(' ')' $'\n'; do split=${split//"$separator"/$'\x1e'}; done
IFS=$'\x1e' read -r -d '' -a segments <<<"$split" || true
for part in "${segments[@]}"; do
  read -r -a words <<<"$part" || true
  ((${#words[@]})) || continue
  for k in "${!words[@]}"; do
    words[k]=${words[k]#[\"\'\{]}
    words[k]=${words[k]%[\"\'\}]}
  done
  segment "$CURDIR" "${words[@]}"
done
((context_cwd)) || ((context)) || exit 0
[[ -n $gesture || -n $destructive ]] || exit 0
[[ -z $destructive ]] || block "geste destructif refusé : $destructive. plugin-plugin ne supprime aucun dépôt, ne force aucun push, ne réécrit aucun historique publié, ne retire aucun plugin et ne fusionne rien."

trimmed=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$command")
project=$(managed_project "$cwd") \
  || block "geste GitHub sans accord ($gesture) : aucun geste annoncé dans cette session, ouverte hors d'un projet géré. Mener la publication depuis une session ouverte dans le dépôt du plugin."
pending="$project/.plugin-plugin/pending"
[[ -f $pending ]] && read_pending "$pending" \
  || block "geste GitHub sans accord ($gesture) : aucun geste annoncé. Annoncer l'étape par pp.sh publish (ou pp.sh mount), puis attendre un « oui » tapé par Soon."
[[ $trimmed == "$PENDING_COMMAND" ]] \
  || block "geste GitHub sans accord ($gesture) : la commande annoncée est « $PENDING_COMMAND » ; seule celle-là passe, telle quelle."
consented "$project" \
  || block "geste GitHub sans accord ($gesture) : aucun « oui » capté depuis l'annonce « $PENDING_ID ». Attendre la réponse de Soon ; toute autre réponse vaut refus."
rm -f "$pending" || block "l'annonce n'a pas pu être consommée ($pending) ; bloqué par prudence."
exit 0
