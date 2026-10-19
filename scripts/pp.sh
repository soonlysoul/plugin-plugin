#!/usr/bin/env bash
# plugin-plugin's deterministic tool: what a skill must not leave to judgment. No session,
# no quota; `claude` is called only for local subcommands (--version, plugin validate,
# plugin init in a throwaway home).
# Usage: pp.sh <command> [options]
#   reaudit [--facts FILE] [--snapshots DIR] [--probes DIR]
#   snapshot --out FILE
#   diff-snapshots OLD.json NEW.json
# Exit codes: 0 done, 1 bad usage or unreadable input, 2 a prerequisite is missing.
set -uo pipefail

PP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FACTS_DIR="$PP_ROOT/scripts/facts"
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

case ${1:-} in
  reaudit) shift; cmd_reaudit "$@" ;;
  snapshot) shift; cmd_snapshot "$@" ;;
  diff-snapshots) shift; cmd_diff_snapshots "$@" ;;
  *) die "usage : pp.sh reaudit | snapshot --out FICHIER | diff-snapshots ANCIEN.json NOUVEAU.json" ;;
esac
