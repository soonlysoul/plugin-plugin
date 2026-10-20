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
#   check PLUGIN
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
#   release PLUGIN [--bump patch|minor|major]
#   release-write PLUGIN --version X.Y.Z [--date YYYY-MM-DD]
#   marketplace-entry MARKETPLACE-CLONE --name N --description TEXT
#   publish PLUGIN [--bump patch|minor|major] [--run N]
#   mount PLUGIN --host HOST-REPO [--path PATH] [--run]
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
# shellcheck source=lib/check.sh
source "$PP_ROOT/scripts/lib/check.sh"
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

# check <plugin>: its gaps to the model, one per line, without changing a file.
cmd_check() {
  [[ $# == 1 ]] || die "usage : pp.sh check PLUGIN"
  need jq
  [[ -f $1/.claude-plugin/plugin.json ]] || die "refusé : $1 n'est pas un plugin (.claude-plugin/plugin.json absent) ; rien à vérifier."
  local gaps count
  gaps=$(check_gaps "$1")
  count=$(grep -c . <<<"$gaps")
  printf 'check : %s (%s)\n' "$(jq -r '.name // "?" | tostring' "$1/.claude-plugin/plugin.json" 2>/dev/null)" "$1"
  if ((count == 0)); then
    printf 'écarts : 0 — au modèle de plugin-flutter\n'
  else
    printf 'écarts : %d\n' "$count"
    sed 's/^/- /' <<<"$gaps"
  fi
  printf 'aucun fichier modifié.\n'
  ((count == 0)) || exit 1
}

# require_model <plugin>: the add-* commands write only into a plugin at the model; out of it, its
# own suite would not cover what they add.
require_model() {
  local gaps
  gaps=$(check_gaps "$1")
  [[ -z $gaps ]] || die "refusé : $1 n'est pas au modèle (écarts : $(grep -c . <<<"$gaps"), dont « $(head -n 1 <<<"$gaps") ») ; pp.sh check $1 les liste. plugin-plugin n'y ajoute rien tant qu'il n'est pas au modèle."
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
    publication_in_progress "$dir"
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
  publication_in_progress "$dir"
}

# publication_in_progress <dir>: one line when pp.sh publish left a plan there, with the command
# that resumes it from what is really done.
publication_in_progress() {
  local plan="$1/.plugin-plugin/publication.json" dir
  [[ -f $plan ]] || return 0
  dir=$(cd "$1" && pwd -P)
  printf 'publication en cours : %s ; reprise : bash %s publish %s\n' \
    "$(jq -r '"\(.name) \(.version) (étiquette \(.tag))"' "$plan" 2>/dev/null)" "$(shell_word "$PP_ROOT/scripts/pp.sh")" "$(shell_word "$dir")"
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
  local -a bash_cases=() bash_grants=() runs_list=()
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
    if jq -e '(.execution.allowed_tools // []) | any(startswith("Bash"))' "$file" >/dev/null; then
      bash_cases+=("$(jq -r '.name' "$file")")
      mapfile -t -O "${#bash_grants[@]}" bash_grants < <(jq -r '.execution.allowed_tools[] | select(startswith("Bash"))' "$file")
    fi
  done <<<"$files"
  # The operator grant is what the cases declare: Bash(pattern:*) stays narrow, unless a case wants all of Bash.
  if printf '%s\n' ${bash_grants[@]+"${bash_grants[@]}"} | grep -qx Bash; then bash_grants=(Bash)
  else mapfile -t bash_grants < <(printf '%s\n' ${bash_grants[@]+"${bash_grants[@]}"} | grep . | sort -u); fi
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
  ((${#bash_cases[@]})) && EVAL_COMMAND+=(--allow-tools "${bash_grants[@]}")
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
# and a placeholder that fails until the rule's own cases replace it. It calls only what every
# harness of the model has (pass, fail, run_hook, expect_status, expect_blocked, finish): jq is
# taken away by an empty PATH, the skeleton calling nothing before it.
hook_test() {
  local name=$1 mode=$2
  printf '#!/usr/bin/env bash\n'
  printf '# %s: simulated inputs, no session.\n' "$name"
  printf '# shellcheck source=../lib.sh\nsource "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"\n'
  printf 'SUITE=test_%s\nHOOK="$PLUGIN_ROOT/hooks/scripts/%s.sh"\n\n' "${name//-/_}" "$name"
  printf 'echo "# contrat du squelette"\n'
  if [[ $mode == fail-closed ]]; then
    printf "run_hook \"\$HOOK\" 'pas du json'\nexpect_blocked \"squelette : entrée illisible bloquée\"\n"
    printf "no_jq=\$(mktemp -d)\nrun_hook \"\$HOOK\" '{}' PATH=\"\$no_jq\"\nrm -rf \"\$no_jq\"\nexpect_blocked \"squelette : jq absent bloqué\"\n\n"
  else
    printf "run_hook \"\$HOOK\" 'pas du json'\nexpect_status \"squelette : entrée illisible, exit 0\" 0\n"
    printf "no_jq=\$(mktemp -d)\nrun_hook \"\$HOOK\" '{}' PATH=\"\$no_jq\"\nrm -rf \"\$no_jq\"\nexpect_status \"squelette : jq absent, exit 0\" 0\n\n"
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
  require_model "$plugin"
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
    <<<"$current" | json_layout "$hooks_json" >"$hooks_json.tmp" && mv "$hooks_json.tmp" "$hooks_json"
}

# json_layout [file]: jq's output with each array of strings on one line, as the model writes
# them ("args": ["${CLAUDE_PLUGIN_ROOT}/…"]), unless the file being rewritten spreads them over
# several lines: an addition leaves the existing lines as they were.
json_layout() {
  if [[ -f ${1:-} ]] && awk 'prev ~ /\[$/ && /^[[:space:]]*"/ { found = 1 } { prev = $0 } END { exit !found }' "$1"; then
    cat
    return
  fi
  awk '
    function flush(  i) { if (open != "") print open; for (i = 1; i <= n; i++) print item[i]; open = ""; n = 0 }
    open != "" && /^[[:space:]]*"([^"\\]|\\.)*",?$/ { item[++n] = $0; next }
    open != "" && n > 0 && /^[[:space:]]*\],?$/ {
      line = open
      for (i = 1; i <= n; i++) { v = item[i]; sub(/^[[:space:]]+/, "", v); line = line (i > 1 ? " " : "") v }
      closing = $0; sub(/^[[:space:]]+/, "", closing)
      print line closing; open = ""; n = 0; next
    }
    open != "" { flush() }
    /\[$/ { open = $0; next }
    { print }
    END { flush() }'
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
  require_model "$plugin"
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
  # A scope guard of the plugin's own (plugin-flutter's) knows its agents by name and would block
  # this one: declaring its scope there means editing the plugin's content.
  local own_guard
  if ((scoped)); then
    own_guard=$(grep -l 'agent_type' "$plugin"/hooks/scripts/*.sh 2>/dev/null | while IFS= read -r f; do
      grep -q 'agent-scope\.json' "$f" || printf '%s\n' "${f#"$plugin"/}"
    done | head -n 1)
    [[ -z $own_guard ]] || die "refusé : le garde de portée de ce plugin ($own_guard) ne lit pas hooks/agent-scope.json ; donner une portée à $name toucherait à son contenu. Un agent en lecture seule (Read, Grep, Glob) s'ajoute sans garde."
  fi
  local helper=""
  if [[ ! -e $plugin/$test ]]; then
    mkdir -p "$plugin/tests/static"
    agent_test "$plugin_name" "$name" "$tool_list" "$model" "$writes_json" "$bash_json" "$scoped" >"$plugin/$test"
    # The test reads headers with plugin-plugin's strict parser, absent from a harness it did not write.
    if [[ ! -f $plugin/tests/headers.sh ]]; then
      cp "$PP_ROOT/tests/headers.sh" "$plugin/tests/headers.sh"
      helper=", tests/headers.sh (aide de test absente)"
    fi
  fi
  if ((test_only)); then
    printf 'écrit : %s%s (le test de l'"'"'agent, rouge tant que %s manque)\n' "$test" "$helper" "$file"
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
      '.[$agent] = {write: $write, bash: $bash}' <<<"$(cat "$scope_file" 2>/dev/null || echo '{}')" | json_layout "$scope_file" >"$scope_file.tmp" \
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
  printf 'écrit : %s%s%s\n' "$file" "$( ((scoped)) && echo ", hooks/agent-scope.json")" "$helper"
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
  require_model "$plugin"
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
    <<<"$(cat "$plugin/.mcp.json" 2>/dev/null || echo '{"mcpServers": {}}')" | json_layout "$plugin/.mcp.json" >"$plugin/.mcp.json.tmp" \
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

# Release. The rehearsal checks, computes, drafts and announces every gesture, and sends nothing:
# the version, the CHANGELOG entry, the suite and the tag are tried on a throwaway clone, GitHub is
# only read, and the plugin's own folder is left as it was.
SEMVER='^[0-9]+\.[0-9]+\.[0-9]+$'
MAX_ALWAYS_ON_TOKENS=1000

# shell_word <arg>: the argument as it is typed in an announced command.
shell_word() {
  if [[ $1 =~ ^[A-Za-z0-9_./:@%+=,-]+$ ]]; then printf '%s' "$1"
  elif [[ $1 != *[\"\$\`\\!]* ]]; then printf '"%s"' "$1"
  else printf "'%s'" "${1//\'/\'\\\'\'}"; fi
}

# last_release <dir> <name>: "version<TAB>tag" of the newest {name}--vX.Y.Z tag, or of a former
# vX.Y.Z one, which is read and never touched; nothing before a first publication.
last_release() {
  git -C "$1" tag -l | sed -nE "s/^($2--v|v)([0-9]+\.[0-9]+\.[0-9]+)$/\2\t&/p" | sort -t$'\t' -k1,1V | tail -n 1
}

# components_at <dir> <rev>: the components of the plugin at that commit, one "kind name" per line.
components_at() {
  {
    git -C "$1" ls-tree -r --name-only "$2" -- skills agents 2>/dev/null |
      sed -nE 's|^skills/([^/]+)/SKILL\.md$|skill \1|p; s|^agents/([^/]+)\.md$|agent \1|p'
    git -C "$1" show "$2:hooks/hooks.json" 2>/dev/null |
      jq -r '.hooks[]?[]?.hooks[]? | (.args[0] // .command // empty) | split("/") | last | sub("\\.sh$"; "") | "hook \(.)"' 2>/dev/null
    git -C "$1" show "$2:.mcp.json" 2>/dev/null | jq -r '(.mcpServers // {}) | keys[] | "serveur MCP \(.)"' 2>/dev/null
  } | sort -u
}

# change_nature <dir> <tag or "">: NATURE (first, major, minor, patch or none), NATURE_TEXT, and the
# components ADDED and REMOVED since the tag. A removed component breaks what used it.
change_nature() {
  local dir=$1 tag=$2 before="" after list
  [[ -z $tag ]] || before=$(components_at "$dir" "$tag")
  after=$(components_at "$dir" HEAD)
  REMOVED=$(comm -23 <(grep . <<<"$before") <(grep . <<<"$after"))
  ADDED=$(comm -13 <(grep . <<<"$before") <(grep . <<<"$after"))
  if [[ -z $tag ]]; then
    NATURE=first NATURE_TEXT="première publication"
  elif [[ -n $REMOVED ]]; then
    list=$(paste -sd, - <<<"$REMOVED" | sed 's/,/, /g')
    NATURE=major NATURE_TEXT="majeure : $( (($(grep -c . <<<"$REMOVED") > 1)) && echo "composants retirés" || echo "composant retiré") : $list"
  elif [[ -n $ADDED ]]; then
    list=$(paste -sd, - <<<"$ADDED" | sed 's/,/, /g')
    NATURE=minor NATURE_TEXT="mineure : $( (($(grep -c . <<<"$ADDED") > 1)) && echo "composants ajoutés" || echo "composant ajouté") : $list"
  elif ! git -C "$dir" diff --quiet "$tag" HEAD -- . ':(exclude).plugin-plugin'; then
    NATURE=patch NATURE_TEXT="correctif : aucun composant ajouté ni retiré"
  else
    NATURE=none NATURE_TEXT="aucun changement"
  fi
}

bump_rank() { case $1 in patch) echo 1 ;; minor) echo 2 ;; major) echo 3 ;; esac; }
bump_word() { case $1 in patch) echo correctif ;; minor) echo mineure ;; major) echo majeure ;; esac; }
# bump <version> <patch|minor|major>
bump() {
  local major minor patch
  IFS=. read -r major minor patch <<<"$1"
  case $2 in
    major) printf '%d.0.0' $((major + 1)) ;;
    minor) printf '%d.%d.0' "$major" $((minor + 1)) ;;
    patch) printf '%d.%d.%d' "$major" "$minor" $((patch + 1)) ;;
  esac
}

# plugin_cost <dir> <name>: COST_TOTAL (always-on tokens), COST_ROWS ("component<TAB>always-on<TAB>
# on-invoke" per skill or agent) and COST_SUMMARY, as claude plugin details reports them.
plugin_cost() {
  local output
  output=$(claude --plugin-dir "$1" plugin details "$2" 2>&1) || return 1
  COST_TOTAL=$(sed -n 's/.*Always-on:[[:space:]]*~\([0-9.]*k\{0,1\}\) tok.*/\1/p' <<<"$output" | head -n 1)
  COST_TOTAL=$(awk -v t="$COST_TOTAL" 'BEGIN { if (t == "") exit; n = t + 0; if (t ~ /k$/) n *= 1000; printf "%d", n }')
  [[ -n $COST_TOTAL ]] || return 1
  COST_ROWS=$(awk '/^Per-component/ { table = 1; next } table && $1 == "component" { rows = 1; next }
    rows && NF == 0 { exit } rows && NF >= 3 { print $1 "\t" $2 "\t" $3 }' <<<"$output")
  COST_SUMMARY="~$COST_TOTAL tokens"
  [[ -z $COST_ROWS ]] || COST_SUMMARY+=" — $(awk -F'\t' '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $1, $2 }' <<<"$COST_ROWS")"
}

# changelog_section <file> <version>: the lines of the section ## [version], trailing blank lines dropped.
changelog_section() {
  awk -v heading="## [$2] — " 'index($0, heading) == 1 { on = 1; print; next } on && /^## \[/ { exit } on { print }' "$1" |
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

# changelog_write <file> <version> <date> <cost line> <tag or "">: the section ## [version] — date.
# An « en cours » section at the top is dated and keeps its entries; otherwise a section is drafted
# from the components added and removed since the tag, or from its commits. Already dated: unchanged.
changelog_write() {
  local file=$1 version=$2 date=$3 cost=$4 tag=$5 i first=-1 end en_cours='^## \[[^]]*\] — en cours$'
  local -a lines section out
  mapfile -t lines <"$file"
  for i in "${!lines[@]}"; do
    [[ ${lines[i]} == "## [$version] — "[0-9]* ]] && return 0
    [[ $first == -1 && ${lines[i]} == "## ["* ]] && first=$i
  done
  if ((first >= 0)) && [[ ${lines[first]} =~ $en_cours ]]; then
    end=${#lines[@]}
    for ((i = first + 1; i < ${#lines[@]}; i++)); do [[ ${lines[i]} == "## ["* ]] && { end=$i; break; }; done
    section=("## [$version] — $date")
    for ((i = first + 1; i < end; i++)); do [[ ${lines[i]} == "Coût en contexte permanent : "* ]] || section+=("${lines[i]}"); done
    while ((${#section[@]} > 1)) && [[ -z ${section[-1]} ]]; do unset 'section[-1]'; done
    section+=("" "$cost")
    ((end == ${#lines[@]})) || section+=("")
    out=("${lines[@]:0:first}" "${section[@]}" "${lines[@]:end}")
  else
    section=("## [$version] — $date")
    if [[ -n $ADDED ]]; then section+=("" "### Ajouté" ""); mapfile -t -O "${#section[@]}" section < <(component_items <<<"$ADDED"); fi
    if [[ -n $REMOVED ]]; then section+=("" "### Retiré" ""); mapfile -t -O "${#section[@]}" section < <(component_items <<<"$REMOVED"); fi
    if [[ -z $ADDED$REMOVED ]]; then
      section+=("" "### Modifié" "")
      mapfile -t -O "${#section[@]}" section < <(git -C "$(dirname "$file")" log --format='- %s' "${tag:+$tag..}HEAD" -- . ':(exclude).plugin-plugin')
    fi
    section+=("" "$cost")
    if ((first >= 0)); then out=("${lines[@]:0:first}" "${section[@]}" "" "${lines[@]:first}")
    else out=("${lines[@]}" "" "${section[@]}"); fi
  fi
  printf '%s\n' "${out[@]}" >"$file"
}

component_items() {
  sed -E 's/^skill (.*)$/- Skill `\1`./; s/^agent (.*)$/- Agent `\1`./; s/^hook (.*)$/- Hook `\1`./; s/^serveur MCP (.*)$/- Serveur MCP `\1`./'
}

# The local gesture that writes a release: the version line of plugin.json and the CHANGELOG entry,
# with the context cost of the version. The rehearsal runs it on its throwaway clone.
cmd_release_write() {
  local dir=${1:-} version="" date name last="" last_version tag="" json
  date=$(date +%F)
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --version) version=${2:-}; shift 2 ;;
      --date) date=${2:-}; shift 2 ;;
      *) die "usage : pp.sh release-write DOSSIER --version X.Y.Z [--date AAAA-MM-JJ]" ;;
    esac
  done
  [[ -n $dir && $version =~ $SEMVER ]] || die "usage : pp.sh release-write DOSSIER --version X.Y.Z [--date AAAA-MM-JJ]"
  need jq
  [[ -f $dir/.claude-plugin/plugin.json && -f $dir/CHANGELOG.md ]] \
    || die "refusé : $dir n'a pas .claude-plugin/plugin.json et CHANGELOG.md."
  name=$(jq -r '.name // empty' "$dir/.claude-plugin/plugin.json" 2>/dev/null)
  jq -e 'has("version")' "$dir/.claude-plugin/plugin.json" >/dev/null 2>&1 && [[ -n $name ]] \
    || die "refusé : nom ou version illisible dans $dir/.claude-plugin/plugin.json."
  last=$(last_release "$dir" "$name")
  if [[ -n $last ]]; then
    last_version=${last%%$'\t'*} tag=${last#*$'\t'}
    version_lt "$last_version" "$version" \
      || die "refusé : $version n'est pas plus récente que la dernière version publiée, $last_version ($tag)."
  fi
  need claude
  plugin_cost "$dir" "$name" || die "échec : coût en contexte illisible (claude --plugin-dir $dir plugin details $name)."
  change_nature "$dir" "$tag"
  json=$(sed -E '0,/"version"[[:space:]]*:[[:space:]]*"[^"]*"/s//"version": "'"$version"'"/' "$dir/.claude-plugin/plugin.json")
  jq -e --arg v "$version" '.version == $v' <<<"$json" >/dev/null 2>&1 || die "échec : version non écrite dans plugin.json."
  [[ $json == "$(<"$dir/.claude-plugin/plugin.json")" ]] || printf '%s\n' "$json" >"$dir/.claude-plugin/plugin.json"
  changelog_write "$dir/CHANGELOG.md" "$version" "$date" "Coût en contexte permanent : $COST_SUMMARY." "$tag"
  printf 'écrit : .claude-plugin/plugin.json (version %s), CHANGELOG.md (%s)\n' "$version" "$(head -n 1 < <(changelog_section "$dir/CHANGELOG.md" "$version"))"
}

# The local gesture that adds a plugin to a copy of the marketplace soon, in the form of its entries.
cmd_marketplace_entry() {
  local dir=${1:-} name="" description="" file error
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name=${2:-}; shift 2 ;;
      --description) description=${2:-}; shift 2 ;;
      *) die "usage : pp.sh marketplace-entry DOSSIER --name NOM --description TEXTE" ;;
    esac
  done
  [[ -n $dir && -n $name && -n $description ]] || die "usage : pp.sh marketplace-entry DOSSIER --name NOM --description TEXTE"
  need jq
  file="$dir/.claude-plugin/marketplace.json"
  jq -e '.plugins | type == "array"' "$file" >/dev/null 2>&1 || die "refusé : $file illisible, ou sans liste plugins."
  error=$(name_error "$name")
  [[ -z $error ]] || die "$error"
  jq -e --arg n "$name" 'any(.plugins[]; .name == $n)' "$file" >/dev/null && die "refusé : $name est déjà dans $file."
  jq --arg n "$name" --arg d "$description" --arg repo "$OWNER/$name" \
    '.plugins += [{name: $n, source: {source: "github", repo: $repo}, description: $d}]' "$file" >"$file.tmp" \
    && mv "$file.tmp" "$file"
  printf 'écrit : %s (entrée %s, source github %s/%s)\n' "$file" "$name" "$OWNER" "$name"
}

# add_gesture <key> <local|GitHub> <label> <command>: one gesture of the release, in order.
add_gesture() { G_KEY+=("$1"); G_WHERE+=("$2"); G_LABEL+=("$3"); G_CMD+=("$4"); }

# print_install <listed: 0 or 1> <name>: the commands Soon runs on each device, after the release.
print_install() {
  if (($1)); then
    printf 'après le push, sur chaque appareil, puis redémarrer Claude Code :\n'
    printf '  claude plugin marketplace update %s\n  claude plugin update %s@%s\n' "$MARKETPLACE" "$2" "$MARKETPLACE"
  else
    printf 'après la fusion de la PR par Soon, sur chaque appareil (sans la marketplace : claude plugin marketplace add %s) :\n' "$MARKETPLACE_REPO"
    printf '  claude plugin marketplace update %s\n  claude plugin install %s@%s\n' "$MARKETPLACE" "$2" "$MARKETPLACE"
  fi
}

cmd_release() {
  local dir=${1:-} bump_to="" plan_out="" usage="usage : pp.sh release DOSSIER [--bump patch|minor|major]"
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --bump) bump_to=${2:-}; shift 2 ;;
      --plan-out) plan_out=${2:-}; shift 2 ;;
      *) die "$usage" ;;
    esac
  done
  [[ -n $dir ]] || die "$usage"
  [[ -z $bump_to || $bump_to =~ ^(patch|minor|major)$ ]] || die "refusé : --bump « $bump_to » inconnu ; patch, minor ou major."
  need jq
  need git
  [[ -f $dir/.claude-plugin/plugin.json ]] || die "refusé : $dir n'est pas un plugin du modèle (.claude-plugin/plugin.json absent)."
  dir=$(cd "$dir" && pwd -P)
  local manifest="$dir/.claude-plugin/plugin.json" name description current error top branch dirty origin
  name=$(jq -r '.name // empty' "$manifest" 2>/dev/null)
  description=$(jq -r '.description // empty' "$manifest" 2>/dev/null)
  current=$(jq -r '.version // empty' "$manifest" 2>/dev/null)
  [[ -n $name ]] || die "refusé : nom illisible dans .claude-plugin/plugin.json."
  error=$(name_error "$name")
  [[ -z $error ]] || die "$error"
  [[ $current =~ $SEMVER ]] || die "refusé : version « $current » de plugin.json hors SemVer."
  [[ -f $dir/tests/run-all.sh ]] || die "refusé : $dir n'a pas de suite tests/run-all.sh."

  # Local state: its own repository, main, a clean tree, an origin that is the plugin's repository.
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  [[ $top == "$dir" ]] || die "refusé : $dir n'est pas la racine de son dépôt git${top:+ (dépôt englobant : $top)} ; claude plugin tag étiquetterait le dépôt englobant."
  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "détachée")
  [[ $branch == main ]] || die "refusé : on publie depuis main ; branche courante : $branch."
  dirty=$(git -C "$dir" --no-optional-locks status --porcelain --untracked-files=all | cut -c4- | sed 's/^.* -> //')
  [[ -z $dirty ]] || die "refusé : changements non enregistrés : $(head -n 5 <<<"$dirty" | paste -sd, - | sed 's/,/, /g')$( (($(grep -c . <<<"$dirty") > 5)) && echo ", …") ; les commiter d'abord. Rien n'a été envoyé."
  local expected="https://github.com/$OWNER/$name.git"
  origin=$(git -C "$dir" config --get remote.origin.url 2>/dev/null)
  case $origin in
    "" | "$expected" | "https://github.com/$OWNER/$name" | "git@github.com:$OWNER/$name.git") ;;
    *) die "refusé : origin pointe vers $origin, et non vers $expected." ;;
  esac

  # GitHub, read only: the marketplace soon and the plugin's repository.
  need gh
  local market listed=0 repo_exists=0 output
  market=$(gh api "repos/$MARKETPLACE_REPO/contents/.claude-plugin/marketplace.json" -H "Accept: application/vnd.github.raw+json" 2>/dev/null)
  jq -e '.plugins | type == "array"' <<<"$market" >/dev/null 2>&1 \
    || die "bloqué : GitHub illisible (gh api repos/$MARKETPLACE_REPO/contents/.claude-plugin/marketplace.json) ; rien n'a été envoyé." 2
  jq -e --arg n "$name" 'any(.plugins[]; .name == $n)' <<<"$market" >/dev/null && listed=1
  if output=$(gh api "repos/$OWNER/$name" 2>&1); then
    repo_exists=1
  elif [[ $output != *"HTTP 404"* ]]; then
    die "bloqué : GitHub illisible (gh api repos/$OWNER/$name) : ${output:0:200} ; rien n'a été envoyé." 2
  fi

  # The version, by the nature of the change since the last release.
  local last last_version tag_from="" version nature_line=""
  last=$(last_release "$dir" "$name")
  if [[ -z $last ]]; then
    [[ -z $bump_to ]] || die "refusé : première publication : la version est celle de plugin.json, $current ; --bump ne s'applique qu'après une publication."
    version=$current
    nature_line="version : $current (première publication, version de plugin.json)"
  else
    last_version=${last%%$'\t'*} tag_from=${last#*$'\t'}
    change_nature "$dir" "$tag_from"
    [[ $NATURE != none ]] || die "refusé : rien à publier depuis $tag_from ; aucun changement depuis cette étiquette."
    version=$(bump "$last_version" "$NATURE")
    if [[ -n $bump_to ]]; then
      (($(bump_rank "$bump_to") >= $(bump_rank "$NATURE"))) \
        || die "refusé : --bump $bump_to est plus faible que la nature du changement ($NATURE_TEXT)."
      if [[ $bump_to != "$NATURE" ]]; then
        version=$(bump "$last_version" "$bump_to")
        nature_line="version : $last_version → $version ($(bump_word "$bump_to"), imposée par --bump ; la nature du changement donne $NATURE_TEXT ; depuis $tag_from)"
      fi
    fi
    [[ -n $nature_line ]] || nature_line="version : $last_version → $version ($NATURE_TEXT ; depuis $tag_from)"
  fi
  local tag="$name--v$version"
  git -C "$dir" rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "refusé : l'étiquette $tag existe déjà ; rien n'a été envoyé."

  printf 'répétition de publication : %s — rien n'"'"'est envoyé\n' "$name"
  printf 'dépôt : %s, branche main, arbre propre\n' "$dir"
  printf 'marketplace %s (GitHub) : %s\n' "$MARKETPLACE" "$( ((listed)) && echo "$name présent, aucune PR" || echo "$name absent, PR d'ajout")"
  printf 'dépôt %s/%s (GitHub) : %s\n' "$OWNER" "$name" "$( ((repo_exists)) && echo présent || echo "absent, à créer")"
  printf '%s\n' "$nature_line"

  # Everything else on a throwaway clone of HEAD: strict validation, cost, the written version,
  # the suite, the tag.
  need claude
  RELEASE_TMP=$(mktemp -d)
  trap 'rm -rf "$RELEASE_TMP"' EXIT
  local clone="$RELEASE_TMP/$name" target results=() failures=""
  git clone -q "$dir" "$clone" 2>/dev/null || die "échec : copie jetable impossible (git clone $dir)."
  for target in . .claude-plugin/plugin.json skills agents; do
    [[ -e $clone/$target ]] || continue
    if output=$(cd "$clone" && claude plugin validate "$target" --strict 2>&1); then
      results+=("ok $target")
    else
      results+=("ÉCHEC $target")
      failures+=" $target : $(grep -E '❯' <<<"$output" | head -n 2 | sed 's/^ *❯ *//' | paste -sd';' -) ;"
    fi
  done
  printf 'validation stricte : %s\n' "$(join ', ' "${results[@]}")"
  [[ -z $failures ]] || die "refusé : la validation stricte n'est pas verte :${failures% ;} ; rien n'a été envoyé."

  plugin_cost "$clone" "$name" || die "échec : coût en contexte illisible (claude --plugin-dir . plugin details $name)."
  printf 'coût en contexte : ~%d tokens permanents (seuil %d)\n' "$COST_TOTAL" "$MAX_ALWAYS_ON_TOKENS"
  [[ -z $COST_ROWS ]] || awk -F'\t' '{ printf "  - %s : %s permanent, %s à l'"'"'appel\n", $1, $2, $3 }' <<<"$COST_ROWS"
  ((COST_TOTAL <= MAX_ALWAYS_ON_TOKENS)) \
    || printf 'alerte : coût permanent ~%d tokens, au-delà du seuil de %d\n' "$COST_TOTAL" "$MAX_ALWAYS_ON_TOKENS"

  local wrote=0
  output=$( (cmd_release_write "$clone" --version "$version") 2>&1) || die "échec : release-write sur la copie jetable : $output"
  if [[ -n $(git -C "$clone" status --porcelain) ]]; then
    wrote=1
    git -C "$clone" -c user.name=plugin-plugin -c user.email=release@example.invalid commit -qm "chore(release): $name $version" \
      -- .claude-plugin/plugin.json CHANGELOG.md || die "échec : commit de version sur la copie jetable."
  fi
  printf 'entrée du CHANGELOG :\n'
  changelog_section "$clone/CHANGELOG.md" "$version" | sed -E 's/^(.)/  \1/'

  local log rc summary
  log=$(cd "$clone" && bash tests/run-all.sh 2>&1)
  rc=$?
  summary=$(grep -E '^(réussies|échouées|sautées|bloquées) : ' <<<"$log" | paste -sd, - | sed 's/,/, /g')
  printf 'suite du plugin : exit %d (%s)\n' "$rc" "${summary:-bilan illisible}"
  if ((rc != 0)); then
    grep -E '^  - ' <<<"$log" | head -n 5
    die "refusé : la suite du plugin n'est pas verte (exit $rc) ; rien n'a été envoyé."
  fi

  output=$(claude plugin tag --dry-run "$clone" 2>&1) \
    || die "refusé : claude plugin tag --dry-run refuse l'étiquette : $(grep -m 1 '✘' <<<"$output" || head -n 1 <<<"$output")"
  grep -qF "would create tag $tag" <<<"$output" || die "échec : claude plugin tag --dry-run n'annonce pas $tag : $(head -n 3 <<<"$output" | paste -sd' ' -)"
  printf 'étiquette : %s, vérifiée par claude plugin tag --dry-run (exit 0)\n' "$tag"

  if ((!listed)); then
    mkdir -p "$RELEASE_TMP/market/.claude-plugin"
    printf '%s\n' "$market" >"$RELEASE_TMP/market/.claude-plugin/marketplace.json"
    output=$( (cmd_marketplace_entry "$RELEASE_TMP/market" --name "$name" --description "$description") 2>&1) \
      || die "refusé : entrée de marketplace impossible : $output"
    output=$(cd "$RELEASE_TMP/market" && claude plugin validate . --strict 2>&1) \
      || die "refusé : la marketplace modifiée ne passe pas la validation stricte : $(grep -E '❯' <<<"$output" | head -n 2 | paste -sd';' -)"
    printf 'marketplace modifiée : validation stricte ok\n'
  fi

  # The gestures, in order; none is run here.
  G_KEY=() G_WHERE=() G_LABEL=() G_CMD=()
  local d pp work_dir work branch_name="add-$name" body
  d=$(shell_word "$dir")
  pp="bash $(shell_word "$PP_ROOT/scripts/pp.sh")"
  work_dir="${TMPDIR:-/tmp}/plugin-plugin-release/$name/claude-plugins"
  work=$(shell_word "$work_dir")
  if ((wrote)); then
    add_gesture write local "écrire la version et le CHANGELOG" "$pp release-write $d --version $version"
    add_gesture commit local "commit de version" "git -C $d commit -m $(shell_word "chore(release): $name $version") -- .claude-plugin/plugin.json CHANGELOG.md"
  fi
  add_gesture tag local "étiquette" "claude plugin tag $d"
  ((repo_exists)) || add_gesture repo GitHub "création du dépôt" "gh repo create $OWNER/$name --public --description $(shell_word "$description")"
  [[ -n $origin ]] || add_gesture origin local "remote origin" "git -C $d remote add origin $expected"
  add_gesture push-main GitHub "push de main" "git -C $d push origin main"
  add_gesture push-tag GitHub "push de l'étiquette" "git -C $d push origin refs/tags/$tag"
  if ((!listed)); then
    body="$name $version, source github $OWNER/$name, étiquette $tag. Suite : $summary ; validation stricte : ok. Coût en contexte permanent : $COST_SUMMARY."
    add_gesture clone local "copie de la marketplace" "gh repo clone $MARKETPLACE_REPO $work"
    add_gesture branch local "branche de marketplace" "git -C $work switch -c $branch_name"
    add_gesture entry local "entrée de marketplace" "$pp marketplace-entry $work --name $name --description $(shell_word "$description")"
    add_gesture market-commit local "commit de marketplace" "git -C $work commit -am $(shell_word "feat: ajouter $name à la marketplace $MARKETPLACE")"
    add_gesture push-branch GitHub "push de la branche" "git -C $work push origin $branch_name"
    add_gesture pr GitHub "PR de marketplace" "gh pr create --repo $MARKETPLACE_REPO --base main --head $branch_name --title $(shell_word "Ajouter $name $version") --body $(shell_word "$body")"
  fi
  printf "gestes, dans l'ordre — aucun n'est exécuté :\n"
  local i
  for i in "${!G_KEY[@]}"; do printf '  %d. [%s] %s : %s\n' $((i + 1)) "${G_WHERE[i]}" "${G_LABEL[i]}" "${G_CMD[i]}"; done
  print_install "$listed" "$name"
  printf 'répétition terminée : %d gestes listés, aucun exécuté\n' "${#G_KEY[@]}"
  # pp.sh publish freezes what the rehearsal proved: the version, the tag and these gestures.
  if [[ -n $plan_out ]]; then
    for i in "${!G_KEY[@]}"; do
      jq -nc --arg key "${G_KEY[i]}" --arg where "${G_WHERE[i]}" --arg label "${G_LABEL[i]}" --arg command "${G_CMD[i]}" \
        '{key: $key, where: $where, label: $label, command: $command}'
    done | jq -s --arg name "$name" --arg version "$version" --arg tag "$tag" --arg dir "$dir" --arg work "$work_dir" \
      --arg branch "$branch_name" --argjson listed "$listed" --arg frozen "$(date +%FT%T%:z)" \
      '{name: $name, version: $version, tag: $tag, dir: $dir, listed: ($listed == 1), work: $work, branch: $branch,
        frozen: $frozen, gestures: .}' >"$plan_out" || die "échec : plan de publication non écrit ($plan_out)."
  fi
}

# Publication. pp.sh publish freezes the gestures a green rehearsal proved, then announces them one
# step at a time — the local gestures up to and including one GitHub gesture — with their exact
# commands. A step runs only through the command announced, after the « oui » consent-capture
# writes to consents.log (scripts/lib/consent.sh); gesture-guard lets that command through once.
# What is done is read from the repositories themselves, so a resumption redoes nothing; each
# gesture is written to .plugin-plugin/gestures.log: date, tag, gesture, label, outcome, exit code,
# command, consent used, and for a failure the command that resumes. git ignores these files.
STATE_FILES=(publication.json pending consents.log gestures.log)

# state_ignored <dir>: refuses unless git ignores the state of a publication in <dir>.
state_ignored() {
  local file
  local -a missing=()
  for file in "${STATE_FILES[@]}"; do
    git -C "$1" check-ignore -q ".plugin-plugin/$file" 2>/dev/null || missing+=(".plugin-plugin/$file")
  done
  ((${#missing[@]} == 0)) || die "refusé : $(join ', ' "${missing[@]}") $( ((${#missing[@]} > 1)) && echo "ne sont pas ignorés" || echo "n'est pas ignoré") par git ; écrits pendant la publication, ils saliraient l'arbre que claude plugin tag exige propre. Les ajouter au .gitignore, puis commiter."
}

# load_plan <file>: P_NAME, P_VERSION, P_TAG, P_DIR, P_LISTED, P_WORK, P_BRANCH, and the gestures.
load_plan() {
  local field count
  jq -e '.gestures | type == "array" and length > 0' "$1" >/dev/null 2>&1 || die "refusé : plan de publication illisible : $1."
  for field in name version tag dir work branch; do
    printf -v "P_${field^^}" '%s' "$(jq -r --arg f "$field" '.[$f] // ""' "$1")"
  done
  P_LISTED=$(jq -r 'if .listed then 1 else 0 end' "$1")
  mapfile -t G_KEY < <(jq -r '.gestures[].key' "$1")
  mapfile -t G_WHERE < <(jq -r '.gestures[].where' "$1")
  mapfile -t G_LABEL < <(jq -r '.gestures[].label' "$1")
  mapfile -t G_CMD < <(jq -r '.gestures[].command' "$1")
  count=$(jq '.gestures | length' "$1")
  [[ ${#G_CMD[@]} == "$count" && ${#G_LABEL[@]} == "$count" ]] || die "refusé : plan de publication illisible : $1."
}

has_entry() { jq -e --arg n "$P_NAME" 'any(.plugins[]?; .name == $n)' >/dev/null 2>&1; }

# market_branch_pushed: true when the marketplace branch of the release is on GitHub; read once
# per scan. Once it is, the copy of the marketplace no longer matters.
market_branch_pushed() {
  if [[ -z ${MARKET_PUSHED:-} ]]; then
    MARKET_PUSHED=0
    [[ -n $(git ls-remote "https://github.com/$MARKETPLACE_REPO.git" "refs/heads/$P_BRANCH" 2>/dev/null) ]] && MARKET_PUSHED=1
  fi
  ((MARKET_PUSHED))
}

# gesture_done <index>: true when the effect of the gesture is already there, read from the
# plugin, its copy of the marketplace and GitHub.
gesture_done() {
  local d=$P_DIR w=$P_WORK heading="^## \[${P_VERSION//./\\.}\] — [0-9]" sha count
  case ${G_KEY[$1]} in
    write) [[ $(jq -r '.version' "$d/.claude-plugin/plugin.json" 2>/dev/null) == "$P_VERSION" ]] && grep -qE "$heading" "$d/CHANGELOG.md" ;;
    commit)
      [[ $(git -C "$d" show HEAD:.claude-plugin/plugin.json 2>/dev/null | jq -r '.version' 2>/dev/null) == "$P_VERSION" ]] \
        && git -C "$d" show HEAD:CHANGELOG.md 2>/dev/null | grep -qE "$heading"
      ;;
    tag) git -C "$d" rev-parse -q --verify "refs/tags/$P_TAG" >/dev/null ;;
    repo) gh api "repos/$OWNER/$P_NAME" >/dev/null 2>&1 ;;
    origin)
      case $(git -C "$d" config --get remote.origin.url 2>/dev/null) in
        "https://github.com/$OWNER/$P_NAME.git" | "https://github.com/$OWNER/$P_NAME" | "git@github.com:$OWNER/$P_NAME.git") return 0 ;;
        *) return 1 ;;
      esac
      ;;
    push-main)
      sha=$(git -C "$d" ls-remote origin refs/heads/main 2>/dev/null | cut -f1)
      [[ -n $sha && $sha == "$(git -C "$d" rev-parse -q --verify "refs/tags/$P_TAG^{commit}")" ]]
      ;;
    push-tag) [[ -n $(git -C "$d" ls-remote origin "refs/tags/$P_TAG" 2>/dev/null) ]] ;;
    clone) market_branch_pushed || { [[ -d $w/.git && $(git -C "$w" config --get remote.origin.url 2>/dev/null) == *"$MARKETPLACE_REPO"* ]]; } ;;
    branch) market_branch_pushed || git -C "$w" rev-parse -q --verify "refs/heads/$P_BRANCH" >/dev/null 2>&1 ;;
    entry)
      market_branch_pushed || git -C "$w" show "$P_BRANCH:.claude-plugin/marketplace.json" 2>/dev/null | has_entry \
        || { [[ $(git -C "$w" symbolic-ref --short HEAD 2>/dev/null) == "$P_BRANCH" ]] && has_entry <"$w/.claude-plugin/marketplace.json"; }
      ;;
    market-commit) market_branch_pushed || git -C "$w" show "$P_BRANCH:.claude-plugin/marketplace.json" 2>/dev/null | has_entry ;;
    push-branch) market_branch_pushed ;;
    pr)
      count=$(gh pr list --repo "$MARKETPLACE_REPO" --head "$P_BRANCH" --state all --json number 2>/dev/null | jq 'length' 2>/dev/null)
      ((${count:-0} > 0))
      ;;
    *) return 1 ;;
  esac
}

# gesture_ready <index>: why the gesture must not run in the present state; nothing when it may.
gesture_ready() {
  local branch
  case ${G_KEY[$1]} in
    entry | market-commit | push-branch)
      branch=$(git -C "$P_WORK" symbolic-ref --short HEAD 2>/dev/null)
      [[ $branch == "$P_BRANCH" ]] \
        || echo "la copie de la marketplace ($P_WORK) est sur ${branch:-une tête détachée}, pas sur $P_BRANCH ; jamais sur main : la marketplace ne change que par une branche et une PR"
      ;;
    push-main)
      branch=$(git -C "$P_DIR" symbolic-ref --short HEAD 2>/dev/null)
      if [[ $branch != main ]]; then echo "le plugin est sur ${branch:-une tête détachée}, pas sur main"
      elif [[ $(git -C "$P_DIR" rev-parse main) != "$(git -C "$P_DIR" rev-parse -q --verify "refs/tags/$P_TAG^{commit}")" ]]; then
        echo "main a bougé depuis l'étiquette $P_TAG : seul l'état étiqueté se publie"
      fi
      ;;
  esac
}

# The submodule of a mount: M_HOST, M_PATH, M_URL and M_SHA, the commit of the tag.
mount_done() {
  case ${G_KEY[$1]} in
    submodule) [[ $(git -C "$M_HOST" config -f .gitmodules --get "submodule.$M_PATH.url" 2>/dev/null) == "$M_URL" && -e $M_HOST/$M_PATH/.git ]] ;;
    pin) [[ $(git -C "$M_HOST/$M_PATH" rev-parse HEAD 2>/dev/null) == "$M_SHA" ]] ;;
    stage) [[ $(git -C "$M_HOST" ls-files -s -- "$M_PATH" 2>/dev/null | awk '{ print $2 }') == "$M_SHA" ]] ;;
    host-commit) [[ $(git -C "$M_HOST" ls-tree HEAD -- "$M_PATH" 2>/dev/null | awk '{ print $3 }') == "$M_SHA" ]] ;;
    *) return 1 ;;
  esac
}
mount_ready() { :; }

# log_gesture <number> <outcome> <exit code> <consent> [resume command]
log_gesture() {
  printf '%s\t%s\t%s %d\t%s\t%s\texit %s\t%s\taccord %s%s\n' "$(date +%FT%T%:z)" "$P_TAG" "$JOURNAL_KIND" "$1" "${G_LABEL[$1 - 1]}" \
    "$2" "$3" "${G_CMD[$1 - 1]}" "${4:--}" "${5:+	reprise : $5}" >>"$STATE/gestures.log"
}
journaled() {
  awk -F'\t' -v tag="$P_TAG" -v gesture="$JOURNAL_KIND $1" '$2 == tag && $3 == gesture && ($5 == "fait" || $5 == "déjà fait") { found = 1 }
    END { exit !found }' "$STATE/gestures.log" 2>/dev/null
}
show_gesture() { printf '%s : %d. [%s] %s : %s%s\n' "$1" $(($2 + 1)) "${G_WHERE[$2]}" "${G_LABEL[$2]}" "${G_CMD[$2]}" "${3:-}"; }

# scan_steps: NEXT, the number of the first gesture not done. A gesture found done that the
# journal does not hold as done — its answer lost in a cut — is journaled « déjà fait ».
scan_steps() {
  local i
  MARKET_PUSHED=""
  for ((i = 0; i < ${#G_KEY[@]}; i++)); do
    "$DONE_FN" "$i" || break
    journaled $((i + 1)) && continue
    log_gesture $((i + 1)) "déjà fait" - ""
    show_gesture "déjà fait" "$i"
  done
  NEXT=$((i + 1))
}

# step_end <index>: the last gesture of the step starting there, the first GitHub gesture on.
step_end() {
  local i
  for ((i = $1; i < ${#G_KEY[@]} - 1; i++)); do [[ ${G_WHERE[i]} == GitHub ]] && break; done
  printf '%d' "$i"
}
step_sha() {
  local i
  for ((i = $1; i <= $2; i++)); do printf '%s\n' "${G_CMD[i]}"; done | sha256sum | cut -d' ' -f1
}
done_summary() {
  case $1 in
    0) printf 'fait : aucun geste\n' ;;
    1) printf 'fait : geste 1\n' ;;
    *) printf 'fait : gestes 1 à %d\n' "$1" ;;
  esac
}

# announce <first index> <last index> <id> <command to type>: prints the step and writes the
# announcement that consent-capture answers and gesture-guard consumes.
announce() {
  local first=$1 last=$2 i github=0
  for ((i = first; i <= last; i++)); do [[ ${G_WHERE[i]} == GitHub ]] && github=$((github + 1)); done
  printf 'prochaine étape — gestes %d à %d, dont %d vers GitHub :\n' $((first + 1)) $((last + 1)) "$github"
  for ((i = first; i <= last; i++)); do printf '  %d. [%s] %s : %s\n' $((i + 1)) "${G_WHERE[i]}" "${G_LABEL[i]}" "${G_CMD[i]}"; done
  printf '%s\t%s\t%s\t%s\n' "$(date +%s%N)" "$3" "$(step_sha "$first" "$last")" "$4" >"$STATE/pending" \
    || die "échec : annonce non écrite ($STATE/pending)."
  printf 'commande : %s\n' "$4"
  printf 'accord : seul un « oui » tapé lance cette étape ; toute autre réponse la retire.\n'
  [[ $PWD == "$P_DIR" || $PWD == "$P_DIR"/* ]] \
    || printf "session : l'accord ne se capte que dans une session Claude Code ouverte dans %s.\n" "$P_DIR"
}

# consent_for <id> <sha>: the date of the announcement when the last answer recorded for this step
# is a « oui » to these very commands, not used yet; nothing otherwise.
consent_for() {
  local date
  date=$(awk -F'\t' -v id="$1" -v sha="$2" '$3 == id { last = ($2 == "accord" && $5 == sha) ? $4 : "" } END { print last }' \
    "$STATE/consents.log" 2>/dev/null)
  [[ -n $date ]] || return 0
  awk -F'\t' -v used="accord $date" '$8 == used { found = 1 } END { exit !found }' "$STATE/gestures.log" 2>/dev/null && return 0
  printf '%s' "$date"
}

# step_report <index of the gesture that stopped> <resume command>
step_report() {
  done_summary "$1"
  printf 'reste : gestes %d à %d\n' $(($1 + 1)) "${#G_KEY[@]}"
  printf 'reprise : %s\n' "$2"
  printf "la reprise annonce de nouveau l'étape du geste %d ; aucun geste fait n'est refait.\n" $(($1 + 1))
}

# run_step <first index> <last index> <consent> <resume command>: runs the gestures of a step; a
# gesture found done is not run again. On a refusal or a failure, exits 1 after the report.
run_step() {
  local first=$1 last=$2 consent=$3 resume=$4 i n reason out rc
  for ((i = first; i <= last; i++)); do
    n=$((i + 1))
    if ((i > first)) && "$DONE_FN" "$i"; then
      log_gesture "$n" "déjà fait" - "$consent"
      show_gesture "déjà fait" "$i"
      continue
    fi
    reason=$("$READY_FN" "$i")
    if [[ -n $reason ]]; then
      log_gesture "$n" refusé - "$consent" "$resume"
      printf 'refusé : %d. [%s] %s : %s\n' "$n" "${G_WHERE[i]}" "${G_LABEL[i]}" "$reason"
      step_report "$i" "$resume"
      exit 1
    fi
    out=$(cd "$P_DIR" && bash -c "${G_CMD[i]}" 2>&1)
    rc=$?
    if ((rc != 0)); then
      log_gesture "$n" échoué "$rc" "$consent" "$resume"
      show_gesture échoué "$i" " → exit $rc"
      grep . <<<"$out" | tail -n 3 | sed 's/^/  /'
      step_report "$i" "$resume"
      exit 1
    fi
    log_gesture "$n" fait 0 "$consent"
    show_gesture fait "$i" " → exit 0"
    [[ ${G_WHERE[i]} != GitHub ]] || grep . <<<"$out" | tail -n 1 | sed 's/^/  /'
  done
}

cmd_publish() {
  local dir=${1:-} run="" bump="" usage="usage : pp.sh publish DOSSIER [--bump patch|minor|major] [--run N]"
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --run) run=${2:-}; shift 2 ;;
      --bump) bump=${2:-}; shift 2 ;;
      *) die "$usage" ;;
    esac
  done
  [[ -n $dir && $run =~ ^[0-9]*$ ]] || die "$usage"
  need jq
  need git
  need gh
  [[ -f $dir/.claude-plugin/plugin.json ]] || die "refusé : $dir n'est pas un plugin du modèle (.claude-plugin/plugin.json absent)."
  dir=$(cd "$dir" && pwd -P)
  [[ $(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) == "$dir" ]] || die "refusé : $dir n'est pas la racine de son dépôt git."
  state_ignored "$dir"
  STATE="$dir/.plugin-plugin" PLAN="$dir/.plugin-plugin/publication.json" JOURNAL_KIND=geste DONE_FN=gesture_done READY_FN=gesture_ready
  if [[ ! -f $PLAN ]]; then
    [[ -z $run ]] || die "refusé : aucune publication en cours dans $dir ; l'annoncer d'abord (pp.sh publish $dir)."
    local tmp output rc
    tmp=$(mktemp)
    output=$( (cmd_release "$dir" --plan-out "$tmp" ${bump:+--bump "$bump"}) 2>&1)
    rc=$?
    if ((rc != 0)); then
      rm -f "$tmp"
      printf '%s\n' "$output"
      exit "$rc"
    fi
    { mkdir -p "$STATE" && mv "$tmp" "$PLAN"; } || die "échec : plan de publication non écrit ($PLAN)."
    grep -E '^(version|coût en contexte|alerte) : ' <<<"$output"
    printf 'répétition : verte sur une copie jetable (validation stricte, suite, étiquette) ; plan figé dans .plugin-plugin/publication.json\n'
  elif [[ -n $bump ]]; then
    die "refusé : une publication est en cours ($PLAN) ; --bump ne vaut que pour son annonce."
  fi
  load_plan "$PLAN"
  [[ $P_DIR == "$dir" ]] || die "refusé : le plan $PLAN vise $P_DIR, pas $dir."
  printf 'publication : %s %s (étiquette %s)\n' "$P_NAME" "$P_VERSION" "$P_TAG"
  local typed first last consent
  typed="bash $(shell_word "$PP_ROOT/scripts/pp.sh") publish $(shell_word "$dir")"
  scan_steps
  if [[ -n $run ]]; then
    ((NEXT <= ${#G_KEY[@]})) || die "refusé : la publication est terminée ; rien à lancer."
    ((run >= NEXT)) || die "refusé : le geste $run est fait ; prochain geste : $NEXT."
    ((run == NEXT)) || die "refusé : le geste $run n'est pas le prochain ; prochain geste : $NEXT."
    first=$((NEXT - 1))
    last=$(step_end "$first")
    consent=$(consent_for "publish $P_TAG $NEXT" "$(step_sha "$first" "$last")")
    [[ -n $consent ]] || die "refusé : aucun « oui » capté pour l'étape du geste $NEXT ; l'annoncer (pp.sh publish $dir), puis attendre la réponse de Soon."
    rm -f "$STATE/pending"
    run_step "$first" "$last" "$consent" "$typed"
    scan_steps
  fi
  if ((NEXT > ${#G_KEY[@]})); then
    rm -f "$STATE/pending" "$PLAN"
    printf 'publication terminée : %s %s, %d gestes faits\n' "$P_NAME" "$P_VERSION" "${#G_KEY[@]}"
    print_install "$P_LISTED" "$P_NAME"
    return 0
  fi
  done_summary $((NEXT - 1))
  first=$((NEXT - 1))
  announce "$first" "$(step_end "$first")" "publish $P_TAG $NEXT" "$typed --run $NEXT"
}

# Mount a published plugin as a submodule of a host repository, pinned on its last tag: four local
# gestures, one step, announced and run on a « oui » like a step of a publication. The host is
# committed, never pushed.
cmd_mount() {
  local dir=${1:-} host="" path="" path_given=0 run=0 usage="usage : pp.sh mount DOSSIER --host DÉPÔT-HÔTE [--path CHEMIN] [--run]"
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --host) host=${2:-}; shift 2 ;;
      --path) path=${2:-}; path_given=1; shift 2 ;;
      --run) run=1; shift ;;
      *) die "$usage" ;;
    esac
  done
  [[ -n $dir && -n $host ]] || die "$usage"
  need jq
  need git
  [[ -f $dir/.claude-plugin/plugin.json ]] || die "refusé : $dir n'est pas un plugin du modèle (.claude-plugin/plugin.json absent)."
  dir=$(cd "$dir" && pwd -P)
  local name last version tag
  name=$(jq -r '.name // empty' "$dir/.claude-plugin/plugin.json" 2>/dev/null)
  [[ -n $name ]] || die "refusé : nom illisible dans .claude-plugin/plugin.json."
  last=$(last_release "$dir" "$name")
  [[ -n $last ]] || die "refusé : $name n'a aucune étiquette de publication ; le publier d'abord (pp.sh publish $dir)."
  version=${last%%$'\t'*} tag=${last#*$'\t'}
  M_URL="https://github.com/$OWNER/$name.git"
  [[ -n $(git ls-remote "$M_URL" "refs/tags/$tag" 2>/dev/null) ]] || die "refusé : l'étiquette $tag est absente de $M_URL ; finir la publication d'abord."
  [[ -d $host ]] || die "refusé : le dépôt hôte $host n'existe pas."
  M_HOST=$(cd "$host" && pwd -P)
  [[ $(git -C "$M_HOST" rev-parse --show-toplevel 2>/dev/null) == "$M_HOST" ]] || die "refusé : $M_HOST n'est pas la racine d'un dépôt git."
  M_PATH=${path:-$name}
  [[ $M_PATH != /* && /$M_PATH/ != */../* ]] || die "refusé : chemin « $M_PATH » : un chemin relatif, dans le dépôt hôte, est attendu."
  M_SHA=$(git -C "$dir" rev-parse "refs/tags/$tag^{commit}")
  if [[ -e $M_HOST/$M_PATH && $(git -C "$M_HOST" config -f .gitmodules --get "submodule.$M_PATH.url" 2>/dev/null) != "$M_URL" ]]; then
    die "refusé : $M_HOST/$M_PATH existe déjà, et n'est pas un sous-module de $M_URL."
  fi
  state_ignored "$dir"
  STATE="$dir/.plugin-plugin" P_DIR=$dir P_TAG=$tag JOURNAL_KIND="montage $M_HOST/$M_PATH" DONE_FN=mount_done READY_FN=mount_ready
  mkdir -p "$STATE"
  local h p
  h=$(shell_word "$M_HOST") p=$(shell_word "$M_PATH")
  G_KEY=() G_WHERE=() G_LABEL=() G_CMD=()
  add_gesture submodule local "sous-module" "git -C $h submodule add $M_URL $p"
  add_gesture pin local "épinglage" "git -C $(shell_word "$M_HOST/$M_PATH") checkout -q refs/tags/$tag"
  add_gesture stage local "index de l'hôte" "git -C $h add $p"
  add_gesture host-commit local "commit de l'hôte" "git -C $h commit -m $(shell_word "chore: monter $name $version en sous-module, épinglé sur $tag") -- .gitmodules $p"
  local id="mount $tag $M_HOST/$M_PATH" typed first last=$((${#G_KEY[@]} - 1)) consent
  typed="bash $(shell_word "$PP_ROOT/scripts/pp.sh") mount $(shell_word "$dir") --host $h"
  ((path_given)) && typed+=" --path $p"
  printf 'montage : %s %s (étiquette %s) dans %s/%s\n' "$name" "$version" "$tag" "$M_HOST" "$M_PATH"
  scan_steps
  ((NEXT <= ${#G_KEY[@]})) || die "refusé : $name est déjà monté dans $M_HOST/$M_PATH, sur $tag."
  first=$((NEXT - 1))
  if ((run)); then
    consent=$(consent_for "$id" "$(step_sha "$first" "$last")")
    [[ -n $consent ]] || die "refusé : aucun « oui » capté pour le montage ; l'annoncer (pp.sh mount sans --run), puis attendre la réponse de Soon."
    rm -f "$STATE/pending"
    run_step "$first" "$last" "$consent" "$typed"
    printf "montage terminé : %s épinglé sur %s dans %s/%s ; le dépôt hôte est commité, pas poussé.\n" "$name" "$tag" "$M_HOST" "$M_PATH"
    return 0
  fi
  done_summary "$first"
  announce "$first" "$last" "$id" "$typed --run"
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
  check) shift; cmd_check "$@" ;;
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
  release) shift; cmd_release "$@" ;;
  release-write) shift; cmd_release_write "$@" ;;
  marketplace-entry) shift; cmd_marketplace_entry "$@" ;;
  publish) shift; cmd_publish "$@" ;;
  mount) shift; cmd_mount "$@" ;;
  *) die "usage : pp.sh reaudit | snapshot | diff-snapshots | init-state | check-name | check | delegate | approve | status | create | checkpoint | resume | check-skill | check-agent | check-evals | eval-plan | eval-run | eval-verdict | add-hook | add-agent | add-mcp | out-of-scope | release | release-write | marketplace-entry | publish | mount" ;;
esac
