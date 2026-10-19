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
# Exit codes: 0 done, 1 refused, bad usage or unreadable input, 2 a prerequisite is missing.
set -uo pipefail

PP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FACTS_DIR="$PP_ROOT/scripts/facts"
# shellcheck source=lib/doc-status.sh
source "$PP_ROOT/scripts/lib/doc-status.sh"
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
  cp "$PP_ROOT/tests/lib.sh" "$PP_ROOT/tests/run-all.sh" "$dir/tests/"
  cp "$PP_ROOT/tests/static/test_paths.sh" "$PP_ROOT/tests/static/test_run_all.sh" "$dir/tests/static/"
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
  *) die "usage : pp.sh reaudit | snapshot | diff-snapshots | init-state | check-name | delegate | approve | status | create" ;;
esac
