#!/usr/bin/env bash
# scripts/pp.sh reaudit, snapshot and diff-snapshots, against a claude stub: what to re-verify
# after a Claude Code update, which formats changed, which facts strict validation contradicts.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_reaudit
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A claude stub. STUB_VERSION: what --version prints. STUB_VALIDATE_EXIT: exit code of
# plugin validate. STUB_INIT_VARIANT=1: plugin init writes one agent file differently.
# Each call is logged with HOME and CLAUDE_CONFIG_DIR to STUB_LOG.
mkdir "$work/stub"
cat >"$work/stub/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\tHOME=%s\tCLAUDE_CONFIG_DIR=%s\n' "$*" "$HOME" "${CLAUDE_CONFIG_DIR:-}" >>"${STUB_LOG:-/dev/null}"
case " $* " in
  " --version ") echo "${STUB_VERSION:-2.1.296} (Claude Code)" ;;
  *" plugin validate "*) exit "${STUB_VALIDATE_EXIT:-0}" ;;
  *" plugin init "*)
    root="$CLAUDE_CONFIG_DIR/skills/$3"
    mkdir -p "$root/.claude-plugin" "$root/agents"
    echo '{"name": "probe"}' >"$root/.claude-plugin/plugin.json"
    if [[ ${STUB_INIT_VARIANT:-0} == 1 ]]; then echo 'tools: Read' >"$root/agents/example.md"
    else echo 'tools: [Read]' >"$root/agents/example.md"; fi
    ;;
  *) echo "claude stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
EOF
chmod +x "$work/stub/claude"
STUBPATH="$work/stub:$PATH"

# A fact base and a snapshot store for the cases below.
mkdir -p "$work/base/probes/agrees/.claude-plugin" "$work/base/snapshots"
echo '{}' >"$work/base/probes/agrees/.claude-plugin/plugin.json"
cat >"$work/base/facts.json" <<'EOF'
[
  {"id": "old-one", "statement": "Premier fait.", "claude_version": "2.1.296", "date": "2026-10-19",
   "source": "essai", "recheck": "commande un", "status": "confirmé"},
  {"id": "old-two", "statement": "Deuxième fait.", "claude_version": "2.1.296", "date": "2026-10-19",
   "source": "essai", "recheck": "commande deux", "status": "infirmé"},
  {"id": "new-one", "statement": "Fait récent.", "claude_version": "2.1.297", "date": "2026-10-20",
   "source": "essai", "recheck": "commande trois", "status": "confirmé"},
  {"id": "unverified", "statement": "Fait jamais mesuré.", "claude_version": null, "date": "2026-10-19",
   "source": "essai", "recheck": "commande quatre", "status": "à vérifier"},
  {"id": "probed", "statement": "Un manifeste vide échoue.", "claude_version": "2.1.296", "date": "2026-10-19",
   "source": "essai", "recheck": "claude plugin validate", "status": "confirmé",
   "probe": {"example": "agrees", "target": ".claude-plugin/plugin.json", "expect": "fail"}}
]
EOF
jq '[.[] | select(.id != "new-one")]' "$work/base/facts.json" >"$work/base/facts-296.json"

# run_pp <args...> -- [env assignments...]: sets PP_STATUS and PP_OUTPUT (stdout and stderr).
run_pp() {
  local -a args=()
  while [[ $# -gt 0 && $1 != -- ]]; do args+=("$1"); shift; done
  [[ ${1:-} == -- ]] && shift
  PP_OUTPUT=$(env "$@" "$BASH" "$PP" "${args[@]}" 2>&1)
  PP_STATUS=$?
}
expect_status() {
  if [[ $PP_STATUS == "$2" ]]; then pass "$1"; else fail "$1" "attendu exit $2, obtenu $PP_STATUS ; sortie : $(head -c 400 <<<"$PP_OUTPUT" | tr '\n' '|')"; fi
}
expect_output() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then pass "$1"; else fail "$1" "motif absent : $2 ; sortie : $(head -c 400 <<<"$PP_OUTPUT" | tr '\n' '|')"; fi
}
refuse_output() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then fail "$1" "motif présent : $2"; else pass "$1"; fi
}

if [[ ! -f $PP ]]; then
  fail "scripts/pp.sh présent" "absent : $PP"
  finish
  exit
fi

echo "# snapshot"
log="$work/init.log"
run_pp snapshot --out "$work/base/snapshots/2.1.296.json" -- PATH="$STUBPATH" STUB_LOG="$log"
expect_status "snapshot : exit 0" 0
jq -e 'type == "object" and has(".claude-plugin/plugin.json") and has("agents/example.md")' \
  "$work/base/snapshots/2.1.296.json" >/dev/null 2>&1 && pass "snapshot : chemins relatifs et contenus en JSON" \
  || fail "snapshot : chemins relatifs et contenus en JSON" "$(head -c 300 "$work/base/snapshots/2.1.296.json" 2>&1)"
init_line=$(grep -F 'plugin init' "$log" 2>/dev/null)
[[ $init_line == *"--with skills agents hooks mcp lsp output-style channel"* ]] \
  && pass "snapshot : plugin init demande tous les composants" || fail "snapshot : plugin init demande tous les composants" "$init_line"
[[ -n $init_line && $init_line != *"HOME=$HOME"$'\t'* && $init_line != *"CLAUDE_CONFIG_DIR=$HOME/.claude" ]] \
  && pass "snapshot : HOME et CLAUDE_CONFIG_DIR jetables, jamais ~/.claude" || fail "snapshot : HOME et CLAUDE_CONFIG_DIR jetables, jamais ~/.claude" "$init_line"
[[ $init_line == *"--author-email sonde@example.invalid"* ]] \
  && pass "snapshot : aucun e-mail réel" || fail "snapshot : aucun e-mail réel" "$init_line"

echo "# diff-snapshots"
run_pp snapshot --out "$work/variant.json" -- PATH="$STUBPATH" STUB_INIT_VARIANT=1
run_pp diff-snapshots "$work/base/snapshots/2.1.296.json" "$work/variant.json" -- PATH="$STUBPATH"
expect_status "deux instantanés qui diffèrent d'un fichier : exit 0" 0
expect_output "le fichier changé est listé" '^  - agents/example\.md \(modifié\)$'
refuse_output "le fichier inchangé ne l'est pas" 'plugin\.json'
run_pp diff-snapshots "$work/base/snapshots/2.1.296.json" "$work/base/snapshots/2.1.296.json" -- PATH="$STUBPATH"
expect_output "deux instantanés identiques : aucun format changé" '^formats changés : 0$'

echo "# version inchangée"
: >"$log"
run_pp reaudit --facts "$work/base/facts-296.json" --snapshots "$work/base/snapshots" --probes "$work/base/probes" \
  -- PATH="$STUBPATH" STUB_VERSION=2.1.296 STUB_VALIDATE_EXIT=1 STUB_LOG="$log"
expect_status "version inchangée : exit 0" 0
expect_output "version inchangée : le message dit rien à revérifier" '^rien à revérifier depuis la version 2\.1\.296$'
expect_output "version inchangée : liste des faits vide" '^faits à revérifier : 0$'
expect_output "version inchangée : liste des formats vide" '^formats changés : 0$'
refuse_output "version inchangée : aucun fait listé" '^  - (old|probed)'
grep -qF 'plugin init' "$log" && fail "version inchangée : aucun instantané produit" "$(grep -F 'plugin init' "$log")" \
  || pass "version inchangée : aucun instantané produit"
expect_output "le fait à vérifier est compté à part" '^à vérifier, jamais tranchés : 1$'

echo "# version plus récente"
run_pp reaudit --facts "$work/base/facts.json" --snapshots "$work/base/snapshots" --probes "$work/base/probes" \
  -- PATH="$STUBPATH" STUB_VERSION=2.1.297 STUB_VALIDATE_EXIT=1 STUB_INIT_VARIANT=1
expect_status "version plus récente : exit 0" 0
expect_output "les faits mesurés sur 2.1.296 sont comptés" '^faits à revérifier : 3$'
for id in old-one old-two probed; do
  expect_output "fait $id listé, avec sa façon de revérifier" "^  - $id \\(2\\.1\\.296, [a-zé ]+\\) : .+ — revérifier : "
done
refuse_output "le fait mesuré sur 2.1.297 n'est pas listé" '^  - new-one'
refuse_output "le fait jamais mesuré n'est pas listé" '^  - unverified'
expect_output "le format changé depuis l'instantané 2.1.296 est listé" '^formats changés : 1 \(instantané 2\.1\.296 → 2\.1\.297\)$'
expect_output "le format changé est nommé" '^  - agents/example\.md \(modifié\)$'

echo "# la validation stricte l'emporte"
run_pp reaudit --facts "$work/base/facts-296.json" --snapshots "$work/base/snapshots" --probes "$work/base/probes" \
  -- PATH="$STUBPATH" STUB_VERSION=2.1.296 STUB_VALIDATE_EXIT=1
expect_output "sonde conforme : rien à corriger" '^faits à corriger \(la validation stricte l.emporte\) : 0$'
run_pp reaudit --facts "$work/base/facts-296.json" --snapshots "$work/base/snapshots" --probes "$work/base/probes" \
  -- PATH="$STUBPATH" STUB_VERSION=2.1.296 STUB_VALIDATE_EXIT=0
expect_output "sonde contredite : le fait est compté à corriger" '^faits à corriger \(la validation stricte l.emporte\) : 1$'
expect_output "sonde contredite : le fait est nommé avec le verdict du validateur" \
  '^  - probed : la validation stricte réussit sur agrees/\.claude-plugin/plugin\.json, le fait attend un échec$'
expect_output "sonde contredite : les listes de la version restent vides" '^rien à revérifier depuis la version 2\.1\.296$'

echo "# prérequis"
no_claude=$(path_without claude)
run_pp reaudit --facts "$work/base/facts-296.json" --snapshots "$work/base/snapshots" --probes "$work/base/probes" -- PATH="$no_claude"
expect_status "claude absent : exit 2" 2
expect_output "claude absent : bloqué, la cause est dite" 'bloqué : claude introuvable'
rm -rf "$no_claude"
run_pp reaudit --facts "$work/nope.json" -- PATH="$STUBPATH"
expect_status "base illisible : exit 1" 1

echo "# base réelle"
run_pp reaudit -- PATH="$STUBPATH" STUB_VERSION=2.1.296 STUB_VALIDATE_EXIT=1
expect_output "base réelle sur 2.1.296 : rien à revérifier" '^rien à revérifier depuis la version 2\.1\.296$'
expect_output "base réelle : un instantané de 2.1.296 est versionné" '^formats changés : 0$'

finish
