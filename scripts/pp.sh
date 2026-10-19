#!/usr/bin/env bash
# plugin-plugin's deterministic tool: what a skill must not leave to judgment. No session,
# no quota; `claude` is called only for local subcommands (--version, plugin validate,
# plugin init in a throwaway home).
# Usage: pp.sh <command> [options]
#   reaudit [--facts FILE] [--snapshots DIR] [--probes DIR]
#   snapshot --out FILE
#   diff-snapshots OLD.json NEW.json
#   init-state DIR
#   check-name NAME
#   delegate DIR --question Q --choice C --reason R
#   approve DOC --quote MESSAGE
#   status DOC
#   create DIR --name NAME --description TEXT
#   checkpoint DIR start --skill S --steps "a|b" | done N --command C --exit E [--test T] | block REASON
#   resume DIR
#   check-skill SKILL.md
#   check-agent agents/NAME.md
#   check-evals PLUGIN SKILL
#   eval-plan PLUGIN SKILL [--max-cost USD] [--keep-temp] [--one-arm]
#   eval-run PLUGIN SKILL --quote MESSAGE [--max-cost USD] [--keep-temp] [--one-arm]
#   eval-verdict PLUGIN SKILL aggregate-result.json
#   add-hook PLUGIN --name N --event E [--matcher M] --mode fail-open|fail-closed [--timeout S] [--dry-run]
#   add-agent PLUGIN --name N --tools T --model M [--writes D,…] [--bash C,…] [--test-only]
#   add-mcp PLUGIN --name N (--launcher scripts/S.sh [--args A,…] [--env VAR,…] | --url U [--header K=V]…) [--test-only]
#   out-of-scope KIND
# Exit codes: 0 done, 1 refused, bad usage or unreadable input, 2 a prerequisite is missing.
set -uo pipefail

PP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FACTS_DIR="$PP_ROOT/scripts/facts"
# shellcheck source=lib/doc-status.sh
source "$PP_ROOT/scripts/lib/doc-status.sh"
# shellcheck source=../tests/headers.sh
source "$PP_ROOT/tests/headers.sh"
# shellcheck source=../tests/mcp.sh
source "$PP_ROOT/tests/mcp.sh"
# Account, marketplace and its catalogue repository: written in hard, as the PRD says.
OWNER=soonlysoul
MARKETPLACE=soon
MARKETPLACE_REPO=soonlysoul/claude-plugins
# The only messages that approve a document, once lowercased and stripped of final punctuation.
APPROVALS=("oui" "je valide" "validé" "j'approuve" "je l'approuve" "approuvé" "c'est validé")
# plugin init scaffolds every component kind the platform knows; its output is the format probe.
PROBE_NAME=sonde-formats
PROBE_COMPONENTS=(skills agents hooks mcp lsp output-style channel)

die() { printf '%s\n' "$1" >&2; exit "${2:-1}"; }
need() { command -v "$1" >/dev/null 2>&1 || die "bloqué : $1 introuvable dans le PATH." 2; }

# version_lt <a> <b>: true when version a is strictly older than b (x.y.z).
version_lt() {
  [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1) == "$1" ]]
}

installed_version() {
  claude --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

# snapshot_to <file>: plugin init in a throwaway HOME and CLAUDE_CONFIG_DIR, never ~/.claude,
# with a placeholder e-mail, stored as one JSON object {relative path: content}.
snapshot_to() {
  local out=$1 tmp root file rel json
  tmp=$(mktemp -d)
  (cd "$tmp" && HOME="$tmp" CLAUDE_CONFIG_DIR="$tmp/.claude" claude plugin init "$PROBE_NAME" \
    --with "${PROBE_COMPONENTS[@]}" --author Soon --author-email sonde@example.invalid \
    --description "Sonde de formats" </dev/null >/dev/null 2>&1)
  root="$tmp/.claude/skills/$PROBE_NAME"
  if [[ ! -d $root ]]; then
    rm -rf "$tmp"
    die "échec : claude plugin init n'a rien produit sous un HOME jetable." 1
  fi
  json='{}'
  while IFS= read -r -d '' file; do
    rel=${file#"$root"/}
    json=$(jq --arg path "$rel" --rawfile content "$file" '. + {($path): $content}' <<<"$json")
  done < <(find "$root" -type f -print0 | sort -z)
  rm -rf "$tmp"
  jq -S . <<<"$json" >"$out"
}

# print_diff <old.json> <new.json> [label]: the files added, removed or modified.
print_diff() {
  local changes count
  changes=$(jq -rn --slurpfile a "$1" --slurpfile b "$2" '
    ($a[0]) as $old | ($b[0]) as $new
    | ([$old, $new] | map(keys) | add | unique)[] as $k
    | if ($old | has($k)) and ($new | has($k) | not) then "\($k) (retiré)"
      elif ($new | has($k)) and ($old | has($k) | not) then "\($k) (ajouté)"
      elif $old[$k] != $new[$k] then "\($k) (modifié)"
      else empty end')
  count=$(grep -c . <<<"$changes")
  printf 'formats changés : %d%s\n' "$count" "${3:+ ($3)}"
  [[ -z $changes ]] || sed 's/^/  - /' <<<"$changes"
}

cmd_snapshot() {
  local out=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --out) out=${2:-}; shift 2 ;;
      *) die "usage : pp.sh snapshot --out FICHIER" ;;
    esac
  done
  [[ -n $out ]] || die "usage : pp.sh snapshot --out FICHIER"
  need jq
  need claude
  snapshot_to "$out"
  printf 'instantané écrit : %s\n' "$out"
}

cmd_diff_snapshots() {
  [[ $# == 2 ]] || die "usage : pp.sh diff-snapshots ANCIEN.json NOUVEAU.json"
  need jq
  local file
  for file in "$1" "$2"; do
    jq -e 'type == "object"' "$file" >/dev/null 2>&1 || die "instantané illisible : $file"
  done
  print_diff "$1" "$2"
}

cmd_reaudit() {
  local facts="$FACTS_DIR/facts.json" snapshots="$FACTS_DIR/snapshots" probes="$FACTS_DIR/probes"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --facts) facts=${2:-}; shift 2 ;;
      --snapshots) snapshots=${2:-}; shift 2 ;;
      --probes) probes=${2:-}; shift 2 ;;
      *) die "usage : pp.sh reaudit [--facts FICHIER] [--snapshots DOSSIER] [--probes DOSSIER]" ;;
    esac
  done
  need jq
  jq -e 'type == "array"' "$facts" >/dev/null 2>&1 || die "base de faits illisible : $facts"
  need claude

  local installed latest stale count pending
  installed=$(installed_version)
  [[ -n $installed ]] || die "échec : version de Claude Code illisible (claude --version)."
  latest=$(jq -r '[.[] | select(.status != "à vérifier") | .claude_version] | unique | .[]' "$facts" | sort -V | tail -n 1)
  printf 'Claude Code installé : %s\n' "$installed"
  printf 'dernière version mesurée dans la base : %s\n' "${latest:-aucune}"

  # Facts measured on an older version than the installed one.
  stale=$(jq -r '.[] | select(.status != "à vérifier") | [.claude_version, .id, .status, .statement, .recheck] | @tsv' "$facts" |
    while IFS=$'\t' read -r version id status statement recheck; do
      version_lt "$version" "$installed" && printf '  - %s (%s, %s) : %s — revérifier : %s\n' "$id" "$version" "$status" "$statement" "$recheck"
    done)
  count=$(grep -c . <<<"$stale")

  # Formats: the newest stored snapshot not newer than the installed version.
  local reference="" version tmp formats
  shopt -s nullglob
  for file in "$snapshots"/*.json; do
    version=${file##*/}
    version=${version%.json}
    version_lt "$installed" "$version" && continue
    if [[ -z $reference ]] || version_lt "$reference" "$version"; then reference=$version; fi
  done
  shopt -u nullglob
  if [[ -z $reference ]]; then
    formats="formats changés : bloqué, aucun instantané de référence dans $snapshots"
  elif [[ $reference == "$installed" ]]; then
    formats="formats changés : 0"
  else
    tmp=$(mktemp)
    snapshot_to "$tmp"
    formats=$(print_diff "$snapshots/$reference.json" "$tmp" "instantané $reference → $installed")
    rm -f "$tmp"
  fi

  if ((count == 0)) && [[ $formats == "formats changés : 0" ]]; then
    printf 'rien à revérifier depuis la version %s\n' "$installed"
  fi
  printf 'faits à revérifier : %d\n' "$count"
  [[ -z $stale ]] || printf '%s\n' "$stale"
  printf '%s\n' "$formats"

  # Probes: strict validation on an example. When it contradicts the fact, validation wins.
  local contradicted="" id example target expect verdict
  while IFS=$'\t' read -r id example target expect; do
    [[ -n $id ]] || continue
    if (cd "$probes/$example" 2>/dev/null && claude plugin validate "$target" --strict >/dev/null 2>&1); then
      verdict=pass
    else
      verdict=fail
    fi
    if [[ $verdict != "$expect" ]]; then
      contradicted+="  - $id : la validation stricte $([[ $verdict == pass ]] && echo réussit || echo échoue) sur $example/$target, le fait attend $([[ $expect == pass ]] && echo une réussite || echo un échec)"$'\n'
    fi
  done < <(jq -r '.[] | select(has("probe")) | [.id, .probe.example, .probe.target, .probe.expect] | @tsv' "$facts")
  printf "faits à corriger (la validation stricte l'emporte) : %d\n" "$(grep -c . <<<"$contradicted")"
  printf '%s' "$contradicted"

  pending=$(jq '[.[] | select(.status == "à vérifier")] | length' "$facts")
  printf 'à vérifier, jamais tranchés : %d\n' "$pending"
}

# State of a managed project: .plugin-plugin/ beside docs/, never in the installed plugin.
cmd_init_state() {
  [[ $# == 1 && -d $1 ]] || die "usage : pp.sh init-state DOSSIER (dossier existant)"
  local state="$1/.plugin-plugin"
  mkdir -p "$state" || die "échec : impossible de créer $state"
  [[ -e $state/approvals.log ]] || : >"$state/approvals.log"
  [[ -e $state/decisions.md ]] || printf '# Décisions déléguées\n\n' >"$state/decisions.md"
  printf 'état du projet : %s\n' "$state"
}

# name_error <name>: the refusal naming the rule of the model the name breaks; empty if none.
name_error() {
  local name=$1 rule="règle : plugin-<domaine>, en minuscules, chiffres et tirets"
  if [[ $name =~ [A-Z] ]]; then echo "refusé : « $name » contient des majuscules ; $rule."
  elif [[ $name == *_* ]]; then echo "refusé : « $name » contient des soulignés ; $rule."
  elif [[ $name =~ [^a-z0-9-] ]]; then echo "refusé : « $name » contient un caractère hors kebab-case ; $rule."
  elif [[ $name != plugin-* ]]; then echo "refusé : « $name » n'a pas le préfixe plugin- ; $rule."
  elif [[ $name == plugin- ]]; then echo "refusé : « $name » a un domaine vide ; $rule."
  elif [[ ! $name =~ ^plugin-[a-z0-9]+(-[a-z0-9]+)*$ ]]; then echo "refusé : « $name » n'est pas en kebab-case ; $rule."
  fi
}

cmd_check_name() {
  [[ $# == 1 ]] || die "usage : pp.sh check-name NOM"
  local error
  error=$(name_error "$1")
  [[ -z $error ]] || die "$error"
  printf 'accepté : « %s » suit plugin-<domaine>.\n' "$1"
}

cmd_delegate() {
  local dir=${1:-} question="" choice="" reason=""
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --question) question=${2:-}; shift 2 ;;
      --choice) choice=${2:-}; shift 2 ;;
      --reason) reason=${2:-}; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n $dir && -n $question && -n $choice && -n $reason ]] \
    || die "usage : pp.sh delegate DOSSIER --question Q --choice CHOIX --reason RAISON"
  [[ -d $dir/.plugin-plugin ]] || die "refusé : $dir n'est pas un projet géré (pp.sh init-state d'abord)."
  printf -- '- %s — %s → %s. Raison : %s. Décision déléguée, révisable.\n' \
    "$(date +%F)" "$question" "$choice" "$reason" >>"$dir/.plugin-plugin/decisions.md"
  printf 'décision consignée : %s → %s\n' "$question" "$choice"
}

# managed_root <doc>: the project root of docs/NAME.md when .plugin-plugin/ sits beside docs/.
managed_root() {
  local docs
  docs=$(cd "$(dirname "$1")" 2>/dev/null && pwd) || return 1
  [[ ${docs##*/} == docs && -d ${docs%/*}/.plugin-plugin ]] || return 1
  printf '%s' "${docs%/*}"
}

cmd_approve() {
  local doc=${1:-} quote="" given=0 root status normalized allowed date
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --quote) quote=${2:-}; given=1; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -f $doc && $given == 1 ]] || die "usage : pp.sh approve DOCUMENT --quote MESSAGE"
  root=$(managed_root "$doc") || die "refusé : $doc n'est pas un document de docs/ d'un projet géré."
  status=$(doc_status "$doc")
  [[ -n $status ]] || die "refusé : $doc n'a pas de ligne « **Statut : … ** »."
  quote=$(tr '\t\n' '  ' <<<"$quote" | sed -E 's/^ +//; s/ +$//')
  normalized=$(tr '[:upper:]' '[:lower:]' <<<"$quote" | sed -E "s/’/'/g; s/[ .!]+$//")
  for allowed in "${APPROVALS[@]}"; do
    [[ $normalized == "$allowed" ]] || continue
    date=$(date +%F)
    doc_set_status "$doc" "**Statut : APPROUVÉ** le $date (« $quote »)." || die "échec : statut non écrit dans $doc"
    printf '%s\tdocs/%s\t%s\t%s\n' "$date" "${doc##*/}" "$(doc_fingerprint "$doc")" "$quote" >>"$root/.plugin-plugin/approvals.log"
    printf 'approuvé : docs/%s, le %s (« %s »)\n' "${doc##*/}" "$date" "$quote"
    return 0
  done
  die "refusé : « $quote » n'est pas une approbation explicite ; statut inchangé ($status)."
}

# name_taken <name>: where the name is already taken, read on GitHub, never in the local copy
# of the marketplace. Exits 2 when GitHub cannot be read.
name_taken() {
  local name=$1 names output
  need gh
  names=$(gh api "repos/$MARKETPLACE_REPO/contents/.claude-plugin/marketplace.json" \
    -H "Accept: application/vnd.github.raw+json" 2>&1 | jq -r '.plugins[].name' 2>/dev/null) \
    || die "bloqué : GitHub illisible (gh api repos/$MARKETPLACE_REPO/contents/.claude-plugin/marketplace.json) ; rien n'a été modifié." 2
  if grep -qxF "$name" <<<"$names"; then
    echo "refusé : « $name » est déjà dans la marketplace $MARKETPLACE ($MARKETPLACE_REPO) ; rien n'a été modifié."
    return 0
  fi
  if output=$(gh api "repos/$OWNER/$name" 2>&1); then
    echo "refusé : le dépôt $OWNER/$name existe déjà sur GitHub ; rien n'a été modifié."
  elif [[ $output != *"HTTP 404"* ]]; then
    die "bloqué : GitHub illisible (gh api repos/$OWNER/$name) : ${output:0:200} ; rien n'a été modifié." 2
  fi
}

# framing_error <dir>: why <dir> is not an approved framing alone; empty if it is.
framing_error() {
  local dir=$1 extra doc status
  if [[ ! -d $dir ]]; then
    echo "refusé : cadrage non approuvé : $dir n'existe pas (cadrer d'abord, /plugin-plugin:frame) ; rien n'a été modifié."
    return
  fi
  extra=$(cd "$dir" && find . -mindepth 1 -path ./.plugin-plugin -prune -o -print |
    grep -vxE '\./docs|\./docs/PRD\.md|\./docs/ARCHITECTURE\.md' | sed 's|^\./||' | sort | tr '\n' ' ')
  if [[ -n $extra ]]; then
    echo "refusé : $dir contient des fichiers hors cadrage : ${extra% } ; rien n'a été modifié."
    return
  fi
  for doc in PRD ARCHITECTURE; do
    if [[ ! -f $dir/docs/$doc.md ]]; then
      echo "refusé : cadrage non approuvé : docs/$doc.md absent ; rien n'a été modifié."
      return
    fi
    status=$(doc_status "$dir/docs/$doc.md")
    if [[ $status != APPROUVÉ ]]; then
      echo "refusé : cadrage non approuvé : docs/$doc.md (${status:-sans statut}) ; rien n'a été modifié."
      return
    fi
    if [[ $(doc_fingerprint "$dir/docs/$doc.md") != "$(approved_fingerprint "$dir" "docs/$doc.md")" ]]; then
      echo "refusé : cadrage non approuvé : docs/$doc.md (APPROUVÉ sans trace au journal des accords) ; rien n'a été modifié."
      return
    fi
  done
}

# render <scaffold file> <destination>: the file with __NAME__, __DESCRIPTION__, __DATE__ set.
render() {
  local content
  content=$(<"$1")
  content=${content//__NAME__/$NAME}
  content=${content//__DESCRIPTION__/$DESCRIPTION}
  content=${content//__DATE__/$TODAY}
  mkdir -p "$(dirname "$2")"
  printf '%s\n' "$content" >"$2"
}

cmd_create() {
  local dir=${1:-} file rc
  NAME="" DESCRIPTION=""
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) NAME=${2:-}; shift 2 ;;
      --description) DESCRIPTION=${2:-}; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n $dir && -n $NAME && -n $DESCRIPTION ]] || die "usage : pp.sh create DOSSIER --name NOM --description TEXTE"
  need jq
  local error
  error=$(name_error "$NAME")
  [[ -z $error ]] || die "$error"
  error=$(framing_error "$dir")
  [[ -z $error ]] || die "$error"
  error=$(name_taken "$NAME") || exit $?
  [[ -z $error ]] || die "$error"

  TODAY=$(date +%F)
  local scaffold="$PP_ROOT/scripts/scaffold" repository="https://github.com/$OWNER/$NAME"
  mkdir -p "$dir/.claude-plugin" "$dir/tests/static"
  jq -n --arg name "$NAME" --arg description "$DESCRIPTION" --arg repository "$repository" \
    '{name: $name, version: "0.1.0", description: $description, author: {name: "Soon"},
      homepage: $repository, repository: $repository, license: "MIT"}' >"$dir/.claude-plugin/plugin.json"
  jq -n --arg name "$NAME" --arg description "$DESCRIPTION" \
    '{name: $name, description: "Local marketplace for the \($name) Claude Code plugin.", owner: {name: "Soon"},
      plugins: [{name: $name, source: "./", description: $description}]}' >"$dir/.claude-plugin/marketplace.json"
  sed -E "s/^Copyright \(c\) [0-9]+ Soon$/Copyright (c) ${TODAY%%-*} Soon/" "$PP_ROOT/LICENSE" >"$dir/LICENSE"
  for file in README.md CHANGELOG.md PROGRESS.md docs/INSTALLATION.md docs/USER_GUIDE.md docs/SECURITY.md docs/TROUBLESHOOTING.md; do
    render "$scaffold/$file" "$dir/$file"
  done
  render "$scaffold/gitignore" "$dir/.gitignore"
  # The harness is plugin-plugin's own, so that both suites behave the same way.
  cp "$PP_ROOT/tests/lib.sh" "$PP_ROOT/tests/headers.sh" "$PP_ROOT/tests/mcp.sh" "$PP_ROOT/tests/run-all.sh" "$dir/tests/"
  cp "$PP_ROOT/tests/static/test_paths.sh" "$PP_ROOT/tests/static/test_run_all.sh" "$PP_ROOT/tests/static/test_headers.sh" "$dir/tests/static/"
  sed "s/^NAME=plugin-plugin$/NAME=$NAME/" "$PP_ROOT/tests/static/test_manifest.sh" >"$dir/tests/static/test_manifest.sh"
  git -C "$dir" init -q -b main || die "échec : git init dans $dir"
  printf 'créé : %s, plugin %s 0.1.0\n' "$dir" "$NAME"

  local log
  log=$(mktemp)
  (cd "$dir" && bash tests/run-all.sh) >"$log" 2>&1
  rc=$?
  grep -E '^(réussies|échouées|sautées|bloquées) :|^  - ' "$log"
  rm -f "$log"
  printf 'suite du plugin créé : exit %d\n' "$rc"
  ((rc == 0)) || exit 1
}

# The checkpoint, .plugin-plugin/checkpoint.md: header fields, one line per step of the running
# skill (done: command and exit code), blockers. Read into CP_* globals, written back whole.
read_checkpoint() {
  local line
  CP_SKILL="" CP_UPDATED="" CP_BRANCH="" CP_HEAD="" CP_TEST="" CP_STEPS=() CP_BLOCKERS=()
  while IFS= read -r line; do
    case $line in
      "skill : "*) CP_SKILL=${line#skill : } ;;
      "mis à jour : "*) CP_UPDATED=${line#mis à jour : } ;;
      "branche : "*) CP_BRANCH=${line#branche : } ;;
      "dernier commit : "*) CP_HEAD=${line#dernier commit : } ;;
      "test ciblé : "*) CP_TEST=${line#test ciblé : \`}; CP_TEST=${CP_TEST%\`} ;;
      "- ["[x\ ]"] "[0-9]*) CP_STEPS+=("$line") ;;
      "- aucun") ;;
      "- "*) CP_BLOCKERS+=("${line#- }") ;;
    esac
  done <"$1"
}

write_checkpoint() {
  {
    printf '# Point de reprise\n\n'
    printf 'mis à jour : %s\nskill : %s\nbranche : %s\ndernier commit : %s\n' "$CP_UPDATED" "$CP_SKILL" "$CP_BRANCH" "$CP_HEAD"
    [[ -z $CP_TEST ]] || printf 'test ciblé : `%s`\n' "$CP_TEST"
    printf '\n## Étapes\n\n'
    printf '%s\n' "${CP_STEPS[@]}"
    printf '\n## Blocages\n\n'
    if ((${#CP_BLOCKERS[@]} == 0)); then printf -- '- aucun\n'; else printf -- '- %s\n' "${CP_BLOCKERS[@]}"; fi
  } >"$1"
}

# step_name <step line>: the step's number and name, without its command and exit code.
step_name() {
  local text=${1#- \[?\] }
  printf '%s' "${text%% — \`*}"
}

cmd_checkpoint() {
  local dir=${1:-} action=${2:-} file
  [[ -d $dir/.plugin-plugin ]] || die "refusé : $dir n'est pas un projet géré (pp.sh init-state d'abord)."
  shift 2 || true
  file="$dir/.plugin-plugin/checkpoint.md"
  case $action in
    start)
      local skill="" steps="" step n=0
      while [[ $# -gt 0 ]]; do
        case $1 in
          --skill) skill=${2:-}; shift 2 ;;
          --steps) steps=${2:-}; shift 2 ;;
          *) shift ;;
        esac
      done
      [[ -n $skill && -n $steps ]] || die "usage : pp.sh checkpoint DOSSIER start --skill SKILL --steps \"étape|étape|…\""
      CP_SKILL=$skill CP_TEST="" CP_STEPS=() CP_BLOCKERS=()
      IFS='|' read -ra parts <<<"$steps"
      for step in "${parts[@]}"; do
        n=$((n + 1))
        CP_STEPS+=("- [ ] $n $step")
      done
      ;;
    done)
      local number=${1:-} command="" code="" test="" i found=0
      shift || true
      while [[ $# -gt 0 ]]; do
        case $1 in
          --command) command=${2//\`/\'}; shift 2 ;;
          --exit) code=${2:-}; shift 2 ;;
          --test) test=${2//\`/\'}; shift 2 ;;
          *) shift ;;
        esac
      done
      [[ $number =~ ^[0-9]+$ && -n $command && $code =~ ^[0-9]+$ ]] \
        || die "usage : pp.sh checkpoint DOSSIER done N --command COMMANDE --exit CODE [--test COMMANDE]"
      [[ -f $file ]] || die "refusé : aucun point de reprise dans $dir (checkpoint start d'abord)."
      read_checkpoint "$file"
      for i in "${!CP_STEPS[@]}"; do
        [[ ${CP_STEPS[$i]} =~ ^-\ \[.\]\ $number\  ]] || continue
        CP_STEPS[i]="- [x] $(step_name "${CP_STEPS[$i]}") — \`$command\` → exit $code"
        found=1
      done
      ((found)) || die "refusé : étape $number inconnue du point de reprise."
      [[ -z $test ]] || CP_TEST=$test
      ;;
    block)
      [[ -n ${1:-} && -f $file ]] || die "usage : pp.sh checkpoint DOSSIER block RAISON (après start)"
      read_checkpoint "$file"
      CP_BLOCKERS+=("$1")
      ;;
    *) die "usage : pp.sh checkpoint DOSSIER start|done|block …" ;;
  esac
  CP_UPDATED=$(date +%FT%H:%M%:z)
  CP_BRANCH=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo -)
  CP_HEAD=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo -)
  write_checkpoint "$file"
  printf 'point de reprise : %s\n' "$file"
}

# join <separator> <items...>
join() {
  local separator=$1 out=""
  shift
  for item in "$@"; do out+=${out:+$separator}$item; done
  printf '%s' "$out"
}

# uncommitted <dir>: the files changed and not committed, the state folder left out.
uncommitted() {
  git -C "$1" --no-optional-locks status --porcelain --untracked-files=all 2>/dev/null |
    cut -c4- | sed 's/^.* -> //' | grep -v '^\.plugin-plugin/' | sort
}

# Read-only: crosses the checkpoint with git, ten lines at most.
cmd_resume() {
  local dir=${1:-} file files count list problems=() newer branch
  [[ -d $dir/.plugin-plugin ]] || die "refusé : $dir n'est pas un projet géré (aucun dossier .plugin-plugin/)."
  file="$dir/.plugin-plugin/checkpoint.md"
  files=$(uncommitted "$dir")
  count=$(grep -c . <<<"$files")
  list=$(head -n 3 <<<"$files" | paste -sd, - | sed 's/,/, /g')
  ((count > 3)) && list+=", …"
  if [[ ! -f $file ]]; then
    printf 'aucun point de reprise : état reconstruit depuis git\n'
    printf 'dernier commit : %s\n' "$(git -C "$dir" log -1 --format='%h %s' 2>/dev/null || echo aucun)"
    printf 'branche : %s\n' "$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo -)"
    printf 'fichiers modifiés non commités : %d%s\n' "$count" "${list:+ ($list)}"
    return 0
  fi
  read_checkpoint "$file"
  local done=() todo=() last="" step
  for step in "${CP_STEPS[@]}"; do
    if [[ $step == "- [x] "* ]]; then done+=("$(step_name "$step")"); last=${step#- \[x\] }
    else todo+=("$(step_name "$step")"); fi
  done

  if [[ $CP_HEAD != - ]] && git -C "$dir" rev-parse -q --verify "$CP_HEAD^{commit}" >/dev/null; then
    newer=$(git -C "$dir" rev-list --count "$CP_HEAD..HEAD" 2>/dev/null)
    ((newer > 0)) && problems+=("$newer commit plus récent que le point de reprise")
  elif [[ $CP_HEAD != - ]]; then
    problems+=("dernier commit noté $CP_HEAD introuvable")
  fi
  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo -)
  [[ $branch == "$CP_BRANCH" ]] || problems+=("branche $branch au lieu de $CP_BRANCH")
  ((count == 0)) || problems+=("$count fichiers modifiés non commités ($list)")

  printf 'skill : %s (point du %s)\n' "$CP_SKILL" "$CP_UPDATED"
  printf 'fait : %s\n' "$( ((${#done[@]})) && join ', ' "${done[@]}" || echo rien)"
  [[ -z $last ]] || printf 'dernière étape : %s\n' "$last"
  printf 'reste : %s\n' "$( ((${#todo[@]})) && join ', ' "${todo[@]}" || echo rien)"
  ((${#todo[@]} == 0)) || printf 'étape suivante : %s\n' "${todo[0]}"
  [[ -z $CP_TEST ]] || printf 'test ciblé : `%s`\n' "$CP_TEST"
  printf 'incohérences : %s\n' "$( ((${#problems[@]})) && join ' ; ' "${problems[@]}" || echo aucune)"
  printf 'blocages : %s\n' "$( ((${#CP_BLOCKERS[@]})) && join ' ; ' "${CP_BLOCKERS[@]}" || echo aucun)"
}

# A skill or agent header at the model, house style included: every broken rule is named.
cmd_check_skill() {
  local file=${1:-} errors
  [[ -f $file ]] || die "usage : pp.sh check-skill CHEMIN/SKILL.md"
  errors=$(skill_structure_errors "$file")
  [[ $errors == "en-tête illisible"* ]] || errors+=$'\n'$(skill_style_errors "$file")
  errors=$(grep . <<<"$errors")
  [[ -z $errors ]] || die "$(sed "s|^|refusé : $file : |" <<<"$errors")"
  printf 'conforme : %s\n' "$file"
}

cmd_check_agent() {
  local file=${1:-} errors
  [[ -f $file ]] || die "usage : pp.sh check-agent CHEMIN/agents/NOM.md"
  errors=$(agent_structure_errors "$file")
  [[ $errors == "en-tête illisible"* ]] || errors+=$'\n'$(agent_style_errors "$file")
  errors=$(grep . <<<"$errors")
  [[ -z $errors ]] || die "$(sed "s|^|refusé : $file : |" <<<"$errors")"
  printf 'conforme : %s\n' "$file"
}

# Eval suites: evals/<skill>/<case>/case.yaml, written in JSON (a subset of YAML) so that jq
# checks them with no other dependency. A case is positive when a tool_used Skill grader naming
# the skill must fire, negative when it must not (min: 0, max: 0, arm: both).
EVAL_CASE_KIND='def skill_grader($skill): .type == "tool_used" and .tool == "Skill" and ((.input_match // "") | contains($skill));
  if any(.graders[]?; skill_grader($skill) and .max == 0) then "négatif"
  elif any(.graders[]?; skill_grader($skill) and ((.max // 1) > 0) and ((.min // 1) >= 1)) then "positif"
  else "aucun" end'
EVAL_CASE_RULES='def skill_grader($skill): .type == "tool_used" and .tool == "Skill" and ((.input_match // "") | contains($skill));
  def result_grader: (.type == "regex" and ((.target // "last_message") | type == "object" or (IN("trace", "mock_calls") | not)))
    or .type == "file_exists" or .type == "baseline"
    or (.type == "llm" and ((.focus // "last_message") | type == "object" or (IN("trace", "mock_calls") | not)));
  (if .schema_version != "1.0" then "schema_version \"1.0\" exigé" else empty end),
  (if (.name // "" | startswith($skill + "-")) | not then "nom sans le préfixe \($skill)-" else empty end),
  (if (.runs | type) != "number" or .runs < 3 then "trois exécutions au moins, déclarées par runs" else empty end),
  (if (.execution.prompt // "" | length) == 0 then "execution.prompt absent" else empty end),
  (if ([.graders[]? | select(result_grader)] | length) == 0
   then "aucun correcteur de résultat (regex, file_exists, llm ou baseline sur le résultat)" else empty end),
  (if any(.graders[]?; skill_grader($skill) and .max == 0)
      and (any(.graders[]?; skill_grader($skill) and .max == 0 and .min == 0 and .arm == "both") | not)
   then "cas négatif sans min: 0, max: 0 et arm: both" else empty end)'
COST_LOW=0.13 COST_HIGH=0.23 COST_MEASURED=2026-10-19

# eval_cases <plugin> <skill>: the case files of the suite, one per line.
eval_cases() {
  find "$1/evals/$2" -mindepth 2 -maxdepth 2 -name case.yaml 2>/dev/null | sort
}

# suite_errors <plugin> <skill>: one refusal per broken rule; empty when the suite conforms.
suite_errors() {
  local plugin=$1 skill=$2 file rel kind positives=0 negatives=0 problem
  local -a files
  mapfile -t files < <(eval_cases "$plugin" "$skill")
  if ((${#files[@]} == 0)); then
    echo "refusé : aucun cas dans evals/$skill/."
    return
  fi
  for file in "${files[@]}"; do
    rel=${file#"$plugin"/}
    if ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
      echo "refusé : $rel : écrire case.yaml en JSON (sous-ensemble du YAML), pour qu'il se vérifie sans dépendance."
      continue
    fi
    while IFS= read -r problem; do
      [[ -z $problem ]] || echo "refusé : $rel : $problem."
    done < <(jq -r --arg skill "$skill" "$EVAL_CASE_RULES" "$file")
    kind=$(jq -r --arg skill "$skill" "$EVAL_CASE_KIND" "$file")
    [[ $kind == positif ]] && positives=$((positives + 1))
    [[ $kind == négatif ]] && negatives=$((negatives + 1))
  done
  ((positives > 0)) || echo "refusé : evals/$skill/ : aucun cas positif (tool_used Skill qui doit déclencher $skill)."
  ((negatives > 0)) || echo "refusé : evals/$skill/ : aucun cas négatif (tool_used Skill, min: 0, max: 0, arm: both)."
}

cmd_check_evals() {
  local plugin=${1:-} skill=${2:-} errors files count positives negatives
  [[ -n $plugin && -n $skill ]] || die "usage : pp.sh check-evals PLUGIN SKILL"
  need jq
  errors=$(suite_errors "$plugin" "$skill")
  [[ -z $errors ]] || die "$errors"
  files=$(eval_cases "$plugin" "$skill")
  count=$(grep -c . <<<"$files")
  positives=0 negatives=0
  while IFS= read -r file; do
    case $(jq -r --arg skill "$skill" "$EVAL_CASE_KIND" "$file") in
      positif) positives=$((positives + 1)) ;;
      négatif) negatives=$((negatives + 1)) ;;
    esac
  done <<<"$files"
  printf 'conforme : %d cas (%d positif%s, %d négatif%s), 3 exécutions par cas au moins\n' \
    "$count" "$positives" "$( ((positives > 1)) && echo s)" "$negatives" "$( ((negatives > 1)) && echo s)"
}

# usd <amount>: an amount with two decimals and a decimal comma, as the announcement prints it.
usd() { LC_ALL=C awk -v n="$1" 'BEGIN { s = sprintf("%.2f", n); sub(/\./, ",", s); print s }'; }

# eval_plan <plugin> <skill> <cap> <keep: --keep-temp or ""> <arms: 1 or 2>: checks, then sets
# EVAL_COMMAND (an array) and prints the announcement. Exits 1 on a non-conforming suite, 2 when
# a case is blocked.
eval_plan() {
  local plugin=$1 skill=$2 cap=$3 keep=${4:-} arms=${5:-2} errors files runs count sessions low high
  local -a bash_cases=() runs_list=()
  need jq
  [[ $cap =~ ^[0-9]+([.,][0-9]+)?$ ]] && LC_ALL=C awk -v c="${cap/,/.}" 'BEGIN { exit !(c > 0) }' \
    || die "refusé : plafond « $cap » invalide ; un montant positif en USD est attendu."
  cap=${cap/,/.}
  errors=$(suite_errors "$plugin" "$skill")
  [[ -z $errors ]] || die "$errors"
  files=$(eval_cases "$plugin" "$skill")
  count=$(grep -c . <<<"$files")
  while IFS= read -r file; do
    runs_list+=("$(jq -r '.runs' "$file")")
    jq -e '(.execution.allowed_tools // []) | any(startswith("Bash"))' "$file" >/dev/null && bash_cases+=("$(jq -r '.name' "$file")")
  done <<<"$files"
  if ((${#bash_cases[@]})); then
    local missing
    for missing in bwrap socat; do
      command -v "$missing" >/dev/null 2>&1 || die "bloqué : $missing absent ($(join ', ' "${bash_cases[@]}") exige$( ((${#bash_cases[@]} > 1)) && echo nt) Bash) ; le bac à sable de claude plugin eval en a besoin." 2
    done
  fi
  need claude
  runs=0
  for count_runs in "${runs_list[@]}"; do runs=$((runs + count_runs)); done
  sessions=$((runs * arms))
  low=$(LC_ALL=C awk -v s="$sessions" -v c="$COST_LOW" 'BEGIN { print s * c }')
  high=$(LC_ALL=C awk -v s="$sessions" -v c="$COST_HIGH" 'BEGIN { print s * c }')
  if [[ $(printf '%s\n' "${runs_list[@]}" | sort -u | grep -c .) == 1 ]]; then
    printf 'sessions : %d (%d cas × %d exécutions × %d bras)\n' "$sessions" "$count" "${runs_list[0]}" "$arms"
  else
    printf 'sessions : %d (%d exécutions × %d bras)\n' "$sessions" "$runs" "$arms"
  fi
  printf 'coût estimé : %s à %s USD (%s à %s USD par session, mesuré le %s)\n' \
    "$(usd "$low")" "$(usd "$high")" "$(usd "$COST_LOW")" "$(usd "$COST_HIGH")" "$COST_MEASURED"
  printf 'plafond : %s USD\n' "${cap/./,}"
  if LC_ALL=C awk -v h="$high" -v c="$cap" 'BEGIN { exit !(h > c) }'; then
    printf "avertissement : l'estimation haute, %s USD, va au-delà du plafond ; le passage peut s'arrêter avant la fin (exit 2, résultats partiels).\n" "$(usd "$high")"
  fi
  local account
  account=$(claude auth status --json 2>/dev/null | jq -r '"\(.email // "inconnu") (\(.subscriptionType // "?"))"' 2>/dev/null)
  printf 'compte qui paie : %s, annoncé par claude auth status ; seul /api/oauth/profile dit le titulaire réel\n' "${account:-inconnu}"
  EVAL_OUTPUT="$plugin/evals/results/$skill-$(date +%Y%m%dT%H%M%S)"
  EVAL_COMMAND=(claude plugin eval "$plugin" --case "$skill-*" --no-publish --max-cost-usd "$cap")
  ((arms == 1)) && EVAL_COMMAND+=(--ablation none)
  ((${#bash_cases[@]})) && EVAL_COMMAND+=(--allow-tools Bash)
  [[ $keep == --keep-temp ]] && EVAL_COMMAND+=(--keep-temp)
  EVAL_COMMAND+=(--output-dir "$EVAL_OUTPUT")
  local shown
  shown=$(printf '%q ' "${EVAL_COMMAND[@]}")
  printf 'commande : %s\n' "${shown% }" | sed "s/ --case $skill-\\\\\\* / --case '$skill-*' /"
  printf 'accord : seul un « oui » lance ce passage.\n'
}

# eval_options <args...>: --max-cost, --keep-temp and --one-arm into CAP, KEEP and ARMS;
# --quote into QUOTE.
eval_options() {
  CAP=3 KEEP="" ARMS=2 QUOTE="" QUOTED=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --one-arm) ARMS=1; shift ;;
      --max-cost) CAP=${2:-}; shift 2 ;;
      --keep-temp) KEEP=--keep-temp; shift ;;
      --quote) QUOTE=${2:-}; QUOTED=1; shift 2 ;;
      *) shift ;;
    esac
  done
}

cmd_eval_plan() {
  local plugin=${1:-} skill=${2:-}
  [[ -n $plugin && -n $skill ]] || die "usage : pp.sh eval-plan PLUGIN SKILL [--max-cost USD] [--keep-temp]"
  shift 2
  eval_options "$@"
  eval_plan "$plugin" "$skill" "$CAP" "$KEEP" "$ARMS"
}

cmd_eval_run() {
  local plugin=${1:-} skill=${2:-} normalized rc
  [[ -n $plugin && -n $skill ]] || die "usage : pp.sh eval-run PLUGIN SKILL --quote MESSAGE [--max-cost USD] [--keep-temp]"
  shift 2
  eval_options "$@"
  normalized=$(tr '[:upper:]' '[:lower:]' <<<"$QUOTE" | sed -E 's/^ +//; s/[ .!]+$//')
  [[ $QUOTED == 1 && $normalized == oui ]] || die "refusé : « $QUOTE » n'est pas un « oui » ; rien n'est lancé."
  eval_plan "$plugin" "$skill" "$CAP" "$KEEP" "$ARMS" || exit $?
  local log
  log=$(mktemp)
  "${EVAL_COMMAND[@]}" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  printf 'claude plugin eval : exit %d\n' "$rc"
  # Outside a terminal, a directory never trusted is refused before anything loads. Trusting it
  # is Soon's gesture, free with a case filter that matches nothing; --trust-plugin is never used.
  if grep -q 'is not a trusted plugin directory' "$log"; then
    rm -f "$log"
    die "bloqué : $plugin n'est pas un dossier de confiance pour claude plugin eval. À lancer une fois dans un terminal, sans coût : cd $(printf '%q' "$plugin") && claude plugin eval . --case 'aucun-*' --no-publish --max-cost-usd 0.01 --ablation none --runs 1 — puis répondre y." 2
  fi
  rm -f "$log"
  [[ -f $EVAL_OUTPUT/aggregate-result.json ]] || die "échec : aucun résultat écrit dans $EVAL_OUTPUT."
  cmd_eval_verdict "$plugin" "$skill" "$EVAL_OUTPUT/aggregate-result.json"
}

# The verdict of a pass: a positive case must score 1.00 with a positive gap over the baseline,
# and is refused when the baseline already passes it; a negative case must score 1.00.
cmd_eval_verdict() {
  local plugin=${1:-} skill=${2:-} result=${3:-} name score delta error kind case_file failing=0 blocked=0
  [[ -n $plugin && -n $skill && -f $result ]] || die "usage : pp.sh eval-verdict PLUGIN SKILL aggregate-result.json"
  jq -e '.cases | type == "array"' "$result" >/dev/null 2>&1 || die "résultat illisible : $result"
  if jq -e '.partial == true' "$result" >/dev/null; then
    printf 'partiel : %s ; résultats incomplets, à ne pas comparer\n' "$(jq -r '.partialReason // "raison inconnue"' "$result")"
    blocked=1
  fi
  while IFS=$'\t' read -r name score delta error; do
    kind=aucun
    while IFS= read -r case_file; do
      jq -e --arg name "$name" '.name == $name' "$case_file" >/dev/null 2>&1 || continue
      kind=$(jq -r --arg skill "$skill" "$EVAL_CASE_KIND" "$case_file")
    done < <(eval_cases "$plugin" "$skill")
    if [[ $error =~ sandbox|bubblewrap|bwrap|socat ]]; then
      printf 'bloqué : %s : %s\n' "$name" "$error"
      blocked=1
      continue
    fi
    local shown_delta="—" without=""
    if [[ $delta != null ]]; then
      shown_delta=$(LC_ALL=C awk -v d="$delta" 'BEGIN { printf "%+.2f", d }')
      without=$(LC_ALL=C awk -v s="$score" -v d="$delta" 'BEGIN { printf "%.2f", s - d }')
    fi
    score=$(LC_ALL=C awk -v s="$score" 'BEGIN { printf "%.2f", s }')
    if [[ $kind == positif && -n $without ]] && LC_ALL=C awk -v w="$without" 'BEGIN { exit !(w >= 1) }'; then
      printf 'refusé : le témoin réussit %s (WITH %s, W/OUT %s) : le cas ne prouve rien, à réécrire\n' "$name" "$score" "$without"
      failing=1
    elif LC_ALL=C awk -v s="$score" 'BEGIN { exit !(s < 1) }'; then
      printf 'rouge : %s : WITH %s, Δ %s\n' "$name" "$score" "$shown_delta"
      failing=1
    elif [[ $kind == positif ]] && { [[ -z $without ]] || LC_ALL=C awk -v d="$delta" 'BEGIN { exit !(d <= 0) }'; }; then
      printf 'non prouvé : %s : WITH %s, Δ %s : aucun écart positif avec le témoin\n' "$name" "$score" "$shown_delta"
      failing=1
    else
      printf 'ok : %s (%s) : WITH %s, Δ %s\n' "$name" "$kind" "$score" "$shown_delta"
    fi
  done < <(jq -r '.cases[] | [.name, (.aggregates.score // 0), (.aggregates.delta // "null"),
                  ([(.arms.with // [])[], (.arms.without // [])[] | .error // empty] | first // "")] | @tsv' "$result")
  printf 'coût : %s USD\n' "$(usd "$(jq -r '.costUsd // 0' "$result")")"
  if ((blocked)); then printf 'verdict : bloqué\n'; exit 2; fi
  if ((failing)); then printf 'verdict : rouge\n'; exit 1; fi
  printf 'verdict : vert\n'
}

# Hooks: tool events need a matcher; Stop and SubagentStop take none; only PreToolUse and
# UserPromptSubmit can block, so only they may be fail-closed.
HOOK_EVENTS=" PreToolUse PostToolUse UserPromptSubmit Stop SubagentStop SessionStart SessionEnd Notification PreCompact "
SCOPE_WARNING="avertissement : installé pour le compte, ce hook s'appliquera à toutes les sessions, dans tous les projets ; il doit rester inerte hors de son contexte."

# hook_script <name> <event> <matcher> <mode>: the skeleton, whose input contract is already
# written and whose rule is not.
hook_script() {
  local name=$1 event=$2 matcher=$3 mode=$4
  printf '#!/usr/bin/env bash\n'
  printf '# %s — %s hook%s.\n' "$name" "$event" "${matcher:+ for $matcher}"
  printf '# TODO: what it checks, and the context outside of which it stays silent. Installed for the\n'
  printf '# account, it runs in every session; it assumes no order among the hooks of an event.\n'
  if [[ $mode == fail-closed ]]; then
    printf '# Fail-closed: exit 2 with the reason on stderr blocks; an internal error blocks too (jq\n'
    printf '# missing, unreadable input); hooks.json sets "onFailure": "block".\n\n'
    printf 'command -v jq >/dev/null 2>&1 || { echo "%s : jq introuvable ; blocage par précaution." >&2; exit 2; }\n' "$name"
    printf "IFS= read -r -d '' input || true\n"
    printf "jq -e 'type == \"object\"' >/dev/null 2>&1 <<<\"\$input\" || { echo \"%s : entrée illisible ; blocage par précaution.\" >&2; exit 2; }\n" "$name"
  else
    if [[ $event == Stop || $event == SubagentStop ]]; then
      printf '# Fail-open: never fails, every problem ends silently with exit 0 (onFailure has no effect on Stop).\n\n'
    else
      printf '# Fail-open: it always exits 0; hooks.json sets "onFailure": "continue".\n\n'
    fi
    printf 'command -v jq >/dev/null 2>&1 || exit 0\n'
    printf "IFS= read -r -d '' input || true\n"
    printf "jq -e 'type == \"object\"' >/dev/null 2>&1 <<<\"\$input\" || exit 0\n"
    if [[ $event == Stop || $event == SubagentStop ]]; then
      printf "[[ \$(jq -r '.stop_hook_active // false' <<<\"\$input\") == false ]] || exit 0\n"
    fi
  fi
  printf '\n# RULE: the rule is not written yet.\nexit 0\n'
}

# hook_test <name> <mode>: the simulated-input test, its contract cases green on the skeleton,
# and a placeholder that fails until the rule's own cases replace it.
hook_test() {
  local name=$1 mode=$2
  printf '#!/usr/bin/env bash\n'
  printf '# %s: simulated inputs, no session.\n' "$name"
  printf '# shellcheck source=../lib.sh\nsource "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"\n'
  printf 'SUITE=test_%s\nHOOK="$PLUGIN_ROOT/hooks/scripts/%s.sh"\n\n' "${name//-/_}" "$name"
  printf 'echo "# contrat du squelette"\n'
  if [[ $mode == fail-closed ]]; then
    printf "run_hook \"\$HOOK\" 'pas du json'\nexpect_blocked \"squelette : entrée illisible bloquée\"\n"
    printf "no_jq=\$(path_without jq)\nrun_hook \"\$HOOK\" '{}' PATH=\"\$no_jq\"\nrm -rf \"\$no_jq\"\nexpect_blocked \"squelette : jq absent bloqué\"\n\n"
  else
    printf "run_hook \"\$HOOK\" 'pas du json'\nexpect_status \"squelette : entrée illisible, exit 0\" 0\n"
    printf "no_jq=\$(path_without jq)\nrun_hook \"\$HOOK\" '{}' PATH=\"\$no_jq\"\nrm -rf \"\$no_jq\"\nexpect_status \"squelette : jq absent, exit 0\" 0\n\n"
  fi
  printf 'echo "# règle"\n'
  printf '# Replace the rule_placeholder call by the rule'"'"'s simulated inputs: what it blocks or reports,\n'
  printf '# what it lets through, and an input outside its context, where it stays silent.\n'
  printf 'rule_placeholder() { fail "règle de %s : à écrire" "remplacer rule_placeholder par les entrées simulées de la règle"; }\n' "$name"
  printf 'rule_placeholder\n\nfinish\n'
}

cmd_add_hook() {
  local plugin=${1:-} name="" event="" matcher="" mode="" timeout=10 dry=0
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name=${2:-}; shift 2 ;;
      --event) event=${2:-}; shift 2 ;;
      --matcher) matcher=${2:-}; shift 2 ;;
      --mode) mode=${2:-}; shift 2 ;;
      --timeout) timeout=${2:-}; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) shift ;;
    esac
  done
  [[ -n $plugin && -n $name && -n $event && -n $mode ]] \
    || die "usage : pp.sh add-hook PLUGIN --name NOM --event ÉVÉNEMENT [--matcher FILTRE] --mode fail-open|fail-closed [--timeout S] [--dry-run]"
  need jq
  [[ -f $plugin/.claude-plugin/plugin.json ]] || die "refusé : $plugin n'est pas un plugin du modèle (.claude-plugin/plugin.json absent)."
  [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "refusé : « $name » n'est pas en kebab-case."
  [[ $HOOK_EVENTS == *" $event "* ]] || die "refusé : événement inconnu « $event » ; connus :$HOOK_EVENTS."
  [[ $mode == fail-open || $mode == fail-closed ]] || die "refusé : mode « $mode » inconnu ; fail-open ou fail-closed."
  [[ $timeout =~ ^[0-9]+$ ]] || die "refusé : timeout « $timeout » invalide, en secondes."
  case $event in
    PreToolUse | PostToolUse) [[ -n $matcher ]] || die "refusé : $event exige un filtre (--matcher), la liste exacte des outils visés." ;;
    Stop | SubagentStop | UserPromptSubmit) [[ -z $matcher ]] || die "refusé : $event n'a pas de filtre." ;;
  esac
  if [[ $mode == fail-closed ]]; then
    case $event in
      PreToolUse | UserPromptSubmit) ;;
      PostToolUse) die "refusé : PostToolUse ne peut pas bloquer (l'outil a déjà agi) ; mode fail-open." ;;
      *) die "refusé : $event ne bloque pas une action, et onFailure y est sans effet sur Stop ; mode fail-open." ;;
    esac
  fi
  local script="hooks/scripts/$name.sh" test="tests/hooks/test_${name//-/_}.sh"
  [[ ! -e $plugin/$script && ! -e $plugin/$test ]] || die "refusé : le hook $name existe déjà ($script)."
  if [[ -f $plugin/hooks/hooks.json ]] && grep -qF "hooks/scripts/$name.sh" "$plugin/hooks/hooks.json"; then
    die "refusé : hooks.json câble déjà $name."
  fi

  printf '%s\n' "$SCOPE_WARNING"
  if ((dry)); then
    printf 'écrirait : %s, %s, hooks/hooks.json (%s%s, %s, timeout %s s), docs/INSTALLATION.md\n' \
      "$script" "$test" "$event" "${matcher:+ [$matcher]}" "$mode" "$timeout"
    return 0
  fi
  mkdir -p "$plugin/hooks/scripts" "$plugin/tests/hooks"
  hook_script "$name" "$event" "$matcher" "$mode" >"$plugin/$script"
  hook_test "$name" "$mode" >"$plugin/$test"
  wire_hook "$plugin" "$script" "$event" "$matcher" "$mode" "$timeout"
  note_hook "$plugin" "$name" "$event" "$matcher" "$mode"
  printf 'écrit : %s, %s, hooks/hooks.json, docs/INSTALLATION.md\n' "$script" "$test"
}

# wire_hook <plugin> <script path> <event> <matcher> <mode> <timeout>: the exec-form entry of
# hooks/hooks.json, onFailure from the mode, none on Stop.
wire_hook() {
  local plugin=$1 script=$2 event=$3 matcher=$4 mode=$5 timeout=$6 hooks_json="$1/hooks/hooks.json" current
  mkdir -p "$plugin/hooks"
  current=$(cat "$hooks_json" 2>/dev/null || echo '{"hooks": {}}')
  jq --arg event "$event" --arg matcher "$matcher" --arg path "\${CLAUDE_PLUGIN_ROOT}/$script" \
    --argjson timeout "$timeout" --arg failure "$([[ $mode == fail-closed ]] && echo block || echo continue)" '
    ({type: "command", command: "bash", args: [$path], timeout: $timeout}
      + (if $event == "Stop" or $event == "SubagentStop" then {} else {onFailure: $failure} end)) as $hook
    | .hooks[$event] = ((.hooks[$event] // []) + [(if $matcher == "" then {} else {matcher: $matcher} end) + {hooks: [$hook]}])' \
    <<<"$current" >"$hooks_json.tmp" && mv "$hooks_json.tmp" "$hooks_json"
}

# note_hook <plugin> <name> <event> <matcher> <mode>: the hook's line in docs/INSTALLATION.md.
note_hook() {
  local installation="$1/docs/INSTALLATION.md"
  if ! grep -q '^## Portée des hooks$' "$installation" 2>/dev/null; then
    printf '\n## Portée des hooks\n\nInstallé pour le compte, chaque hook de ce plugin s'"'"'applique à toutes les sessions, dans tous les projets ; chacun reste inerte hors de son contexte.\n\n' >>"$installation"
  fi
  printf -- '- `%s` — %s%s, %s.\n' "$2" "$3" "${4:+ ($4)}" "$5" >>"$installation"
}

# Agents: tools declared one by one and known, never Agent, a reviewer that cannot write; an agent
# with a write tool or Bash is held to its folders and its allowlist by agent-scope-guard.
AGENT_MODELS=" sonnet opus haiku fable inherit "

# agent_test <plugin name> <agent> <tools> <model> <writes json> <bash json> <scoped>: the test
# that fails while the agent is absent.
agent_test() {
  printf '#!/usr/bin/env bash\n'
  printf '# agents/%s.md: present, strict header, tools %s, model %s.\n' "$2" "$3" "$4"
  printf '# shellcheck source=../lib.sh\nsource "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"\n'
  printf '# shellcheck source=../headers.sh\nsource "$(dirname "${BASH_SOURCE[0]}")/../headers.sh"\n'
  printf 'SUITE=test_agent_%s\nFILE="$PLUGIN_ROOT/agents/%s.md"\n\n' "${2//-/_}" "$2"
  printf 'if [[ ! -f $FILE ]]; then\n  fail "agents/%s.md présent" "absent"\n  finish\n  exit\nfi\n' "$2"
  printf 'pass "agents/%s.md présent"\n' "$2"
  printf 'errors=$(agent_structure_errors "$FILE")\n'
  printf '[[ -z $errors ]] && pass "en-tête strict" || fail "en-tête strict" "$errors"\n'
  printf 'read_frontmatter "$FILE"\n'
  printf "tools=\$(tr ',' '\\\\n' <<<\"\${FM[tools]-}\" | sed 's/ //g' | sort | paste -sd, -)\n"
  printf '[[ $tools == "%s" ]] && pass "outils : %s" || fail "outils : %s" "$tools"\n' \
    "$(tr ',' '\n' <<<"$3" | sed 's/ //g' | sort | paste -sd, -)" "$3" "$3"
  printf '[[ ${FM[model]-} == %s ]] && pass "modèle : %s" || fail "modèle : %s" "${FM[model]-absent}"\n' "$4" "$4" "$4"
  if [[ $7 == 1 ]]; then
    printf "jq -e --arg a %q '.[\$a] == {write: %s, bash: %s}' \"\$PLUGIN_ROOT/hooks/agent-scope.json\" >/dev/null 2>&1 \\\\\n" \
      "$1:$2" "$5" "$6"
    printf '  && pass "portée déclarée au garde" || fail "portée déclarée au garde"\n'
  fi
  printf '\nfinish\n'
}

cmd_add_agent() {
  local plugin=${1:-} name="" tool_list="" model="" writes="" allow="" test_only=0 tool
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name=${2:-}; shift 2 ;;
      --tools) tool_list=${2:-}; shift 2 ;;
      --model) model=${2:-}; shift 2 ;;
      --writes) writes=${2:-}; shift 2 ;;
      --bash) allow=${2:-}; shift 2 ;;
      --test-only) test_only=1; shift ;;
      *) shift ;;
    esac
  done
  [[ -n $plugin && -n $name && -n $tool_list && -n $model ]] \
    || die "usage : pp.sh add-agent PLUGIN --name NOM --tools \"Read, Grep\" --model MODÈLE [--writes \"docs/,test/\"] [--bash \"git diff,git log\"] [--test-only]"
  need jq
  [[ -f $plugin/.claude-plugin/plugin.json ]] || die "refusé : $plugin n'est pas un plugin du modèle (.claude-plugin/plugin.json absent)."
  [[ $name =~ ^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$ && $name != *--* ]] \
    || die "refusé : nom « $name » : 3 à 50 caractères en kebab-case, commençant et finissant par une lettre ou un chiffre."
  local -a list
  local writer=0 shell=0
  IFS=',' read -ra list <<<"$tool_list"
  for tool in "${list[@]}"; do
    tool=${tool// /}
    [[ $tool != Agent ]] || die "refusé : l'outil Agent est interdit, un agent du plugin ne lance pas d'agent."
    [[ $KNOWN_TOOLS == *" $tool "* ]] || die "refusé : outil inconnu : $tool."
    if [[ $tool =~ ^(Write|Edit|NotebookEdit)$ ]]; then
      [[ $name != *review* ]] || die "refusé : un relecteur n'a ni Write ni Edit ($tool)."
      writer=1
    fi
    [[ $tool != Bash ]] || shell=1
  done
  [[ $AGENT_MODELS == *" $model "* || $model == claude-* ]] || die "refusé : model « $model » inconnu ; connus :$AGENT_MODELS, ou un identifiant claude-…"
  ((writer == 0)) || [[ -n $writes ]] || die "refusé : un agent qui écrit déclare ses dossiers d'écriture (--writes \"docs/\")."
  ((shell == 0)) || [[ -n $allow ]] || die "refusé : un agent qui a Bash déclare sa liste blanche (--bash \"git diff,git log\")."
  ((writer == 1)) || [[ -z $writes ]] || die "refusé : --writes sans outil d'écriture dans --tools."
  [[ /${writes//,//,/}/ != */../* && ,$writes != *,/* ]] || die "refusé : dossier d'écriture qui remonte (..) ou absolu : $writes."
  local file="agents/$name.md" test="tests/static/test_agent_${name//-/_}.sh"
  [[ ! -e $plugin/$file ]] || die "refusé : l'agent $name existe déjà ($file)."
  ((test_only == 0)) || [[ ! -e $plugin/$test ]] || die "refusé : le test $test existe déjà."

  local plugin_name writes_json bash_json scoped=0
  plugin_name=$(jq -r '.name' "$plugin/.claude-plugin/plugin.json")
  writes_json=$(tr ',' '\n' <<<"$writes" | sed 's/^ *//; s/ *$//' | grep . | jq -Rsc 'split("\n") | map(select(length > 0))')
  bash_json=$(tr ',' '\n' <<<"$allow" | sed 's/^ *//; s/ *$//' | grep . | jq -Rsc 'split("\n") | map(select(length > 0))')
  ((writer == 0 && shell == 0)) || scoped=1
  if [[ ! -e $plugin/$test ]]; then
    mkdir -p "$plugin/tests/static"
    agent_test "$plugin_name" "$name" "$tool_list" "$model" "$writes_json" "$bash_json" "$scoped" >"$plugin/$test"
  fi
  if ((test_only)); then
    printf 'écrit : %s (le test de l'"'"'agent, rouge tant que %s manque)\n' "$test" "$file"
    return 0
  fi

  local guard="hooks/scripts/agent-scope-guard.sh"
  if ((scoped)) && [[ ! -e $plugin/$guard ]]; then
    printf '%s\n' "$SCOPE_WARNING"
    mkdir -p "$plugin/hooks/scripts" "$plugin/tests/hooks"
    sed "s/__PLUGIN__/$plugin_name/" "$PP_ROOT/scripts/scaffold/agent-scope/agent-scope-guard.sh" >"$plugin/$guard"
    cp "$PP_ROOT/scripts/scaffold/agent-scope/test_agent_scope_guard.sh" "$plugin/tests/hooks/"
    wire_hook "$plugin" "$guard" PreToolUse "Edit|Write|NotebookEdit|Bash|Monitor" fail-closed 10
    note_hook "$plugin" agent-scope-guard PreToolUse "Edit|Write|NotebookEdit|Bash|Monitor" fail-closed
  fi
  if ((scoped)); then
    local scope_file="$plugin/hooks/agent-scope.json"
    jq --arg agent "$plugin_name:$name" --argjson write "$writes_json" --argjson bash "$bash_json" \
      '.[$agent] = {write: $write, bash: $bash}' <<<"$(cat "$scope_file" 2>/dev/null || echo '{}')" >"$scope_file.tmp" \
      && mv "$scope_file.tmp" "$scope_file"
  fi
  mkdir -p "$plugin/agents"
  {
    printf -- '---\nname: %s\ndescription: "Use this agent when TODO; not for TODO."\ntools: %s\nmodel: %s\n---\n\n' "$name" "$tool_list" "$model"
    printf '## Responsibilities\n\nTODO: the one bounded task this agent does for the main session.\n\n'
    printf '## Approach\n\nTODO: the steps, in order.'
    if ((scoped)); then
      printf ' Scope, enforced by the agent-scope-guard hook: writes only under %s; Bash only %s.' \
        "$(jq -r 'if length == 0 then "nothing" else map("`\(.)`") | join(", ") end' <<<"$writes_json")" \
        "$(jq -r 'if length == 0 then "nothing" else map("`\(.)`") | join(", ") end' <<<"$bash_json")"
    fi
    printf '\n\n## Output format\n\nEnd with this report, and nothing after it:\n\n'
    printf 'STATUS: done | blocked | failed\nFILES_CHANGED: <paths, or none>\nCOMMANDS_RUN: <command → exit code, one per line, or none>\nOPEN_QUESTIONS: <questions for the main session, or none>\n'
  } >"$plugin/$file"
  printf 'écrit : %s%s\n' "$file" "$( ((scoped)) && echo ", hooks/agent-scope.json")"
}

# MCP: an existing server declared in .mcp.json, never its code — local through a bash launcher of
# scripts/, remote in HTTPS or WSS — with the user's values as ${VAR}, by the rules of tests/mcp.sh.

# mcp_test <server> <entry>: the test that fails while .mcp.json does not declare the server.
mcp_test() {
  local variables
  variables=$(mcp_variables "$2" | paste -sd' ' -)
  printf '#!/usr/bin/env bash\n'
  printf '# .mcp.json: the %s server, declared as pp.sh add-mcp wrote it; its variables in the README.\n' "$1"
  printf '# shellcheck source=../lib.sh\nsource "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"\n'
  printf 'SUITE=test_mcp_%s\nMCP="$PLUGIN_ROOT/.mcp.json"\n\n' "${1//-/_}"
  printf "if ! jq -e --arg s %s '.mcpServers[\$s]' \"\$MCP\" >/dev/null 2>&1; then\n" "$1"
  printf '  fail "serveur %s déclaré" ".mcp.json absent, ou sans le serveur %s"\n  finish\n  exit\nfi\n' "$1" "$1"
  printf 'pass "serveur %s déclaré"\n' "$1"
  printf "want=\$(cat <<'JSON'\n%s\nJSON\n)\n" "$2"
  printf "jq -e --arg s %s --argjson want \"\$want\" '.mcpServers[\$s] == \$want' \"\$MCP\" >/dev/null \\\\\n" "$1"
  printf '  && pass "déclaration de %s" || fail "déclaration de %s" "$(jq -c --arg s %s '"'"'.mcpServers[$s]'"'"' "$MCP")"\n' "$1" "$1" "$1"
  if [[ -n $variables ]]; then
    printf 'for var in %s; do\n' "$variables"
    printf '  grep -qF "\\`$var\\`" "$PLUGIN_ROOT/README.md" && pass "README : $var documentée" || fail "README : $var documentée"\ndone\n'
  fi
  printf '\nfinish\n'
}

# readme_mcp <plugin>: the « Serveurs MCP » section of README.md, rewritten from .mcp.json, before
# « ## Tests », or at the end.
readme_mcp() {
  local plugin=$1 readme="$1/README.md" section server entry where variables
  section=$(mktemp)
  {
    cat <<'TEXT'
## Serveurs MCP

Déclarés dans `.mcp.json`, sans rien installer : chaque valeur vient de l'environnement de l'utilisateur, en `${VAR}`. Un skill qui dépend d'un serveur a besoin d'une doublure dans `evals/mocks/<serveur>/` pour être évalué ; sans elle, le serveur n'est pas démarré pendant une évaluation.

TEXT
    while IFS= read -r server; do
      entry=$(jq -c --arg s "$server" '.mcpServers[$s]' "$plugin/.mcp.json")
      if jq -e 'has("url")' <<<"$entry" >/dev/null; then
        where="distant, \`$(jq -r '.url' <<<"$entry")\`"
      else
        where="local, lancé par \`$(jq -r '.args[0] | ltrimstr("${CLAUDE_PLUGIN_ROOT}/")' <<<"$entry")\`"
      fi
      variables=$(mcp_variables "$entry" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
      printf -- "- \`%s\` — %s ; variables : %s ; doublure d'évaluation : \`evals/mocks/%s/\`.\n" \
        "$server" "$where" "${variables:-aucune}" "$server"
    done < <(jq -r '.mcpServers | keys_unsorted[]' "$plugin/.mcp.json")
  } >"$section"
  touch "$readme"
  awk -v section="$section" '
    function emit(  line) { while ((getline line < section) > 0) print line; close(section); print ""; done = 1 }
    /^## Serveurs MCP$/ { skip = 1; next }
    skip && /^## / { skip = 0 }
    skip { next }
    /^## Tests$/ && !done { emit() }
    { print }
    END { if (!done) { print ""; emit() } }' "$readme" >"$readme.tmp" && mv "$readme.tmp" "$readme"
  rm -f "$section"
}

cmd_add_mcp() {
  local plugin=${1:-} name="" launcher="" url="" args="" envs="" test_only=0 item type entry error variables
  local -a headers=() names=()
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name=${2:-}; shift 2 ;;
      --launcher) launcher=${2:-}; shift 2 ;;
      --url) url=${2:-}; shift 2 ;;
      --args) args=${2:-}; shift 2 ;;
      --env) envs=${2:-}; shift 2 ;;
      --header) headers+=("${2:-}"); shift 2 ;;
      --test-only) test_only=1; shift ;;
      *) shift ;;
    esac
  done
  [[ -n $plugin && -n $name && -n $launcher$url && (-z $launcher || -z $url) ]] \
    || die "usage : pp.sh add-mcp PLUGIN --name NOM (--launcher scripts/NOM.sh [--args A,…] [--env VAR,…] | --url https://…|wss://… [--header 'Nom=valeur']…) [--test-only]"
  need jq
  [[ -f $plugin/.claude-plugin/plugin.json ]] || die "refusé : $plugin n'est pas un plugin du modèle (.claude-plugin/plugin.json absent)."
  [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "refusé : « $name » n'est pas en kebab-case."
  if [[ -e $plugin/.mcp.json ]]; then
    jq -e '.mcpServers | type == "object"' "$plugin/.mcp.json" >/dev/null 2>&1 || die "refusé : $plugin/.mcp.json illisible, sans enveloppe « mcpServers »."
    jq -e --arg s "$name" '.mcpServers | has($s)' "$plugin/.mcp.json" >/dev/null && die "refusé : le serveur $name est déjà déclaré dans .mcp.json."
  fi
  if [[ -n $launcher ]]; then
    ((${#headers[@]} == 0)) || die "refusé : --header ne vaut que pour un serveur distant (--url)."
    launcher=${launcher#'${CLAUDE_PLUGIN_ROOT}/'}
    [[ $launcher =~ ^scripts/[A-Za-z0-9_-][A-Za-z0-9_.-]*\.sh$ ]] \
      || die "refusé : lanceur « $launcher » : un script bash du plugin, scripts/<nom>.sh, que la déclaration lance par bash depuis \${CLAUDE_PLUGIN_ROOT} ; le code d'un serveur n'est pas écrit ici."
    [[ -f $plugin/$launcher ]] || die "refusé : lanceur absent : $launcher n'existe pas dans $plugin."
    launcher="\${CLAUDE_PLUGIN_ROOT}/$launcher"
    [[ -z $envs ]] || IFS=',' read -ra names <<<"$envs"
    for item in ${names[@]+"${names[@]}"}; do
      [[ $item =~ ^[A-Z_][A-Z0-9_]*$ ]] \
        || die "refusé : variable « $item » : un nom en majuscules, chiffres et _, dont la valeur vient de l'environnement de l'utilisateur, en \${NOM}."
    done
    entry=$(jq -nc --arg launcher "$launcher" --arg args "$args" --arg envs "$envs" '
      {command: "bash", args: ([$launcher] + ($args | split(",") | map(select(length > 0))))}
      + (if $envs == "" then {} else {env: ($envs | split(",") | map({key: ., value: "${\(.)}"}) | from_entries)} end)')
  else
    [[ -z $envs && -z $args ]] || die "refusé : --env et --args ne valent que pour un serveur local (--launcher) ; un serveur distant reçoit ses valeurs par --header."
    case $url in
      https://*) type=http ;;
      wss://*) type=ws ;;
      *) die "refusé : adresse « $url » : un serveur distant en HTTPS ou WSS seulement." ;;
    esac
    for item in ${headers[@]+"${headers[@]}"}; do
      [[ $item =~ ^[A-Za-z0-9-]+=.+$ ]] || die "refusé : en-tête « $item » : Nom=valeur attendu."
    done
    entry=$(jq -nc --arg type "$type" --arg url "$url" '{type: $type, url: $url}
      + (if ($ARGS.positional | length) == 0 then {}
         else {headers: ($ARGS.positional | map(capture("^(?<key>[^=]+)=(?<value>.*)$")) | from_entries)} end)' \
      --args ${headers[@]+"${headers[@]}"})
  fi
  for error in "$(mcp_variable_error "$entry")" "$(mcp_secret_error "$entry")" "$(mcp_install_error "$entry" "$plugin")"; do
    [[ -z $error ]] || die "refusé : $error ; rien n'a été écrit."
  done

  local test="tests/static/test_mcp_${name//-/_}.sh"
  ((test_only == 0)) || [[ ! -e $plugin/$test ]] || die "refusé : le test $test existe déjà."
  if [[ ! -e $plugin/$test ]]; then
    mkdir -p "$plugin/tests/static"
    mcp_test "$name" "$entry" >"$plugin/$test"
  fi
  if ((test_only)); then
    printf "écrit : %s (le test du serveur, rouge tant que .mcp.json ne le déclare pas)\n" "$test"
    return 0
  fi
  jq --arg s "$name" --argjson entry "$entry" '.mcpServers[$s] = $entry' \
    <<<"$(cat "$plugin/.mcp.json" 2>/dev/null || echo '{"mcpServers": {}}')" >"$plugin/.mcp.json.tmp" \
    && mv "$plugin/.mcp.json.tmp" "$plugin/.mcp.json"
  readme_mcp "$plugin"
  variables=$(mcp_variables "$entry" | paste -sd, - | sed 's/,/, /g')
  printf 'écrit : .mcp.json (serveur %s), README.md (section « Serveurs MCP »)\n' "$name"
  printf "variables à définir par l'utilisateur : %s\n" "${variables:-aucune}"
  printf "rappel : un skill qui dépend du serveur %s a besoin d'une doublure dans evals/mocks/%s/ pour être évalué ; sans elle, le serveur n'est pas démarré pendant une évaluation.\n" "$name" "$name"
}

# Out of scope (PRD, « Hors périmètre ») : each refusal names its reason and what would reopen it.
cmd_out_of_scope() {
  local cli="rouvert au premier plugin qui a besoin d'un système sans ligne de commande, ou d'un channel"
  case ${1:-} in
    mcp-code) die "refusé : écrire le code d'un serveur MCP est hors périmètre ; plugin-plugin déclare un serveur existant (add-mcp), il n'en écrit pas ; $cli." ;;
    channel) die "refusé : un channel est hors périmètre ; il exige le code d'un serveur MCP écrit pour le plugin ; $cli." ;;
    lsp) die "refusé : la déclaration d'un serveur de langage est hors périmètre de la v0.1 ; rouvert en v0.2, où elle est prévue." ;;
    output-style) die "refusé : un style de sortie est hors périmètre ; aucun plugin du modèle n'en a l'usage, et le plugin reste petit ; rouvert par une révision du PRD." ;;
    command) die "refusé : une commande classique (commands/) est une forme ancienne, exclue par le PRD ; rouvert : jamais, un skill la remplace et s'invoque déjà par /<plugin>:<skill>." ;;
    plugin-option) die "refusé : une option de plugin est hors périmètre ; compte, marketplace et langue des messages restent écrits en dur ; rouvert par une révision du PRD, le jour où un plugin doit se régler par utilisateur." ;;
    plugin-dependency) die "refusé : une dépendance entre plugins est hors périmètre ; un plugin du modèle s'installe et fonctionne seul ; rouvert par une révision du PRD, quand un plugin ne peut pas fonctionner sans un autre plugin." ;;
    *) die "usage : pp.sh out-of-scope mcp-code | channel | lsp | output-style | command | plugin-option | plugin-dependency" ;;
  esac
}

cmd_status() {
  [[ $# == 1 && -f $1 ]] || die "usage : pp.sh status DOCUMENT"
  local status
  status=$(doc_status "$1")
  [[ -n $status ]] || die "aucun statut dans $1"
  printf '%s\n' "$status"
}

case ${1:-} in
  reaudit) shift; cmd_reaudit "$@" ;;
  snapshot) shift; cmd_snapshot "$@" ;;
  diff-snapshots) shift; cmd_diff_snapshots "$@" ;;
  init-state) shift; cmd_init_state "$@" ;;
  check-name) shift; cmd_check_name "$@" ;;
  delegate) shift; cmd_delegate "$@" ;;
  approve) shift; cmd_approve "$@" ;;
  status) shift; cmd_status "$@" ;;
  create) shift; cmd_create "$@" ;;
  checkpoint) shift; cmd_checkpoint "$@" ;;
  resume) shift; cmd_resume "$@" ;;
  check-skill) shift; cmd_check_skill "$@" ;;
  check-agent) shift; cmd_check_agent "$@" ;;
  check-evals) shift; cmd_check_evals "$@" ;;
  eval-plan) shift; cmd_eval_plan "$@" ;;
  eval-run) shift; cmd_eval_run "$@" ;;
  eval-verdict) shift; cmd_eval_verdict "$@" ;;
  add-hook) shift; cmd_add_hook "$@" ;;
  add-agent) shift; cmd_add_agent "$@" ;;
  add-mcp) shift; cmd_add_mcp "$@" ;;
  out-of-scope) shift; cmd_out_of_scope "$@" ;;
  *) die "usage : pp.sh reaudit | snapshot | diff-snapshots | init-state | check-name | delegate | approve | status | create | checkpoint | resume | check-skill | check-agent | check-evals | eval-plan | eval-run | eval-verdict | add-hook | add-agent | add-mcp | out-of-scope" ;;
esac
