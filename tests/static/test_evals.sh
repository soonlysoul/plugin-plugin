#!/usr/bin/env bash
# Eval suites, checked without running them (check-evals), announced before any launch
# (eval-plan), launched only on a literal « oui » (eval-run), and judged (eval-verdict): a
# positive case the baseline passes is refused; a case that needs Bash without bwrap is blocked.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_evals
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A claude stub: auth status names the account; plugin eval writes STUB_RESULT (a JSON file)
# as aggregate-result.json in --output-dir. Every call is logged to STUB_LOG.
mkdir "$work/stub" "$work/sandbox"
cat >"$work/stub/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STUB_LOG:-/dev/null}"
case " $* " in
  " auth status "*) echo '{"loggedIn": true, "authMethod": "claude.ai", "email": "compte@example.invalid", "subscriptionType": "pro"}' ;;
  *" plugin eval "*)
    if [[ ${STUB_UNTRUSTED:-0} == 1 ]]; then
      echo "Error: $4 is not a trusted plugin directory, and this run cannot stop to ask you about it (no interactive terminal, or --json / CI)." >&2
      exit 1
    fi
    out=""
    while [[ $# -gt 0 ]]; do [[ $1 == --output-dir ]] && out=$2; shift; done
    mkdir -p "$out" && cp "${STUB_RESULT:?}" "$out/aggregate-result.json" ;;
  *) echo "claude stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
EOF
chmod +x "$work/stub/claude"
for tool in bwrap socat; do printf '#!/usr/bin/env bash\n' >"$work/sandbox/$tool"; chmod +x "$work/sandbox/$tool"; done
NOSANDBOX=$(path_without bwrap socat)
STUBPATH="$work/stub:$NOSANDBOX"

MATCH='\"skill\"\\s*:\\s*\"(?:[\\w-]+:)?demo\"'
POSITIVE='{"schema_version": "1.0", "name": "demo-positive", "runs": 3,
  "execution": {"prompt": "Fais la chose.", "allowed_tools": ["Skill", "Read"]},
  "graders": [{"name": "skill-fired", "type": "tool_used", "tool": "Skill", "input_match": "'$MATCH'"},
              {"name": "result", "type": "regex", "target": "last_message", "pattern": "fait"}]}'
NEGATIVE='{"schema_version": "1.0", "name": "demo-negative", "runs": 3,
  "execution": {"prompt": "Autre chose.", "allowed_tools": ["Skill", "Read"]},
  "graders": [{"name": "skill-not-fired", "type": "tool_used", "tool": "Skill", "input_match": "'$MATCH'", "min": 0, "max": 0, "arm": "both"},
              {"name": "result", "type": "regex", "pattern": "fait", "match": "not_contains"}]}'

# suite <plugin> <case json>...: evals/demo/<name>/case.yaml for each case.
suite() {
  local plugin="$work/$1" json name
  shift
  mkdir -p "$plugin/evals/demo"
  for json in "$@"; do
    name=$(jq -r '.name // "sans-nom"' <<<"$json" 2>/dev/null || echo brut)
    mkdir -p "$plugin/evals/demo/$name"
    printf '%s\n' "$json" >"$plugin/evals/demo/$name/case.yaml"
  done
  printf '%s' "$plugin"
}
run_pp() {
  local -a args=()
  while [[ $# -gt 0 && $1 != -- ]]; do args+=("$1"); shift; done
  [[ ${1:-} == -- ]] && shift
  PP_OUTPUT=$(env "$@" "$BASH" "$PP" "${args[@]}" 2>&1)
  PP_STATUS=$?
}
expect_pp() {
  if [[ $PP_STATUS == "$2" ]]; then pass "$1"; else fail "$1" "attendu exit $2, obtenu $PP_STATUS ; sortie : $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 400)"; fi
}
expect_output() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then pass "$1"; else fail "$1" "motif absent : $2 ; sortie : $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 400)"; fi
}
refuse_output() {
  if grep -qE -- "$2" <<<"$PP_OUTPUT"; then fail "$1" "motif présent : $2"; else pass "$1"; fi
}
with() { jq -c "$2" <<<"$1"; }

echo "# check-evals : une suite valide"
good=$(suite good "$POSITIVE" "$NEGATIVE")
run_pp check-evals "$good" demo
expect_pp "suite au modèle : exit 0" 0
expect_output "le bilan compte cas positifs et négatifs" '^conforme : 2 cas \(1 positif, 1 négatif\), 3 exécutions par cas au moins$'

echo "# check-evals : chaque règle manquante est nommée"
# refused <label> <pattern> <case json>...
refused() {
  local label=$1 pattern=$2 plugin
  shift 2
  plugin=$(suite "case-$RANDOM$RANDOM" "$@")
  run_pp check-evals "$plugin" demo
  if [[ $PP_STATUS == 1 ]] && grep -qE -- "$pattern" <<<"$PP_OUTPUT"; then pass "$label : refusé, règle nommée"
  else fail "$label : refusé, règle nommée" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"; fi
}
refused "schema_version absent" 'schema_version' "$(with "$POSITIVE" 'del(.schema_version)')" "$NEGATIVE"
refused "schema_version 1.1" 'schema_version "1\.0"' "$(with "$POSITIVE" '.schema_version = "1.1"')" "$NEGATIVE"
refused "aucun cas négatif" 'aucun cas négatif' "$POSITIVE"
refused "aucun cas positif" 'aucun cas positif' "$NEGATIVE"
refused "aucun correcteur de résultat" 'correcteur de résultat' "$(with "$POSITIVE" '.graders |= map(select(.type == "tool_used"))')" "$NEGATIVE"
refused "regex sur la trace seulement" 'correcteur de résultat' "$(with "$POSITIVE" '.graders[1].target = "trace"')" "$NEGATIVE"
refused "deux exécutions" 'trois exécutions' "$(with "$POSITIVE" '.runs = 2')" "$NEGATIVE"
refused "exécutions non déclarées" 'trois exécutions' "$(with "$POSITIVE" 'del(.runs)')" "$NEGATIVE"
refused "nom sans le préfixe du skill" 'préfixe demo-' "$(with "$POSITIVE" '.name = "positive"')" "$NEGATIVE"
refused "négatif sans arm: both" 'arm: both' "$POSITIVE" "$(with "$NEGATIVE" 'del(.graders[0].arm)')"
refused "prompt absent" 'prompt' "$(with "$POSITIVE" 'del(.execution.prompt)')" "$NEGATIVE"
plugin=$(suite yaml "$NEGATIVE")
mkdir -p "$plugin/evals/demo/demo-positive"
printf 'schema_version: "1.0"\nname: demo-positive\n' >"$plugin/evals/demo/demo-positive/case.yaml"
run_pp check-evals "$plugin" demo
[[ $PP_STATUS == 1 && $PP_OUTPUT == *JSON* ]] && pass "case.yaml hors JSON : refusé, règle nommée" \
  || fail "case.yaml hors JSON : refusé, règle nommée" "exit $PP_STATUS ; ${PP_OUTPUT:0:300}"
run_pp check-evals "$work/nothing" demo
expect_pp "suite absente : refusé" 1

echo "# check-evals : les suites de plugin-plugin"
for skill in reaudit frame create resume check release; do
  run_pp check-evals "$PLUGIN_ROOT" "$skill"
  expect_pp "evals/$skill conforme" 0
done

echo "# eval-plan : l'annonce avant tout lancement"
log="$work/claude.log"
run_pp eval-plan "$good" demo -- PATH="$STUBPATH" STUB_LOG="$log"
expect_pp "eval-plan : exit 0" 0
expect_output "nombre de sessions" '^sessions : 12 \(2 cas × 3 exécutions × 2 bras\)$'
expect_output "fourchette de coût" '^coût estimé : 1,56 à 2,76 USD \(0,13 à 0,23 USD par session, mesuré le 2026-10-19\)$'
expect_output "plafond par défaut" '^plafond : 3 USD$'
expect_output "compte qui paie" '^compte qui paie : compte@example\.invalid \(pro\), annoncé par claude auth status'
expect_output "commande exacte, rapport local, plafonnée" "^commande : claude plugin eval .+ --case 'demo-\\*' --no-publish --max-cost-usd 3 --output-dir .+$"
refuse_output "jamais --trust-plugin" 'trust-plugin'
refuse_output "aucun outil accordé sans besoin" 'allow-tools'
grep -qF 'plugin eval' "$log" 2>/dev/null && fail "eval-plan ne lance rien" "$(cat "$log")" || pass "eval-plan ne lance rien"
run_pp eval-plan "$good" demo --max-cost 5 -- PATH="$STUBPATH"
expect_output "plafond modifiable" '^plafond : 5 USD$'
expect_output "plafond modifiable : dans la commande" '--max-cost-usd 5 '
run_pp eval-plan "$good" demo --max-cost 1 -- PATH="$STUBPATH"
expect_output "estimation au-delà du plafond : avertie" 'au-delà du plafond'
for cap in 0 abc -2; do
  run_pp eval-plan "$good" demo --max-cost "$cap" -- PATH="$STUBPATH"
  expect_pp "plafond « $cap » : refusé" 1
done
run_pp eval-plan "$(suite bad-plan "$POSITIVE")" demo -- PATH="$STUBPATH"
expect_pp "suite non conforme : rien n'est annoncé" 1

run_pp eval-plan "$good" demo --one-arm -- PATH="$STUBPATH"
expect_output "un seul bras : sessions divisées par deux" '^sessions : 6 \(2 cas × 3 exécutions × 1 bras\)$'
expect_output "un seul bras : --ablation none dans la commande" ' --ablation none '

echo "# eval-plan : Bash sans bwrap"
bash_case=$(with "$POSITIVE" '.name = "demo-shell" | .execution.allowed_tools += ["Bash"]')
shell=$(suite shell "$bash_case" "$NEGATIVE")
run_pp eval-plan "$shell" demo -- PATH="$STUBPATH"
expect_pp "Bash sans bwrap ni socat : exit 2" 2
expect_output "Bash sans bwrap : bloqué, cas nommé" '^bloqué : bwrap absent \(demo-shell exige Bash\)'
run_pp eval-plan "$shell" demo -- PATH="$work/stub:$work/sandbox:$NOSANDBOX"
expect_pp "Bash avec bwrap et socat : exit 0" 0
expect_output "Bash accordé par la commande, et lui seul" '--allow-tools Bash '
narrow_case=$(with "$POSITIVE" '.name = "demo-narrow" | .execution.allowed_tools += ["Bash(bash:*)"]')
narrow=$(suite narrow "$narrow_case" "$NEGATIVE")
run_pp eval-plan "$narrow" demo -- PATH="$work/stub:$work/sandbox:$NOSANDBOX"
expect_pp "Bash restreint par un motif : exit 0" 0
expect_output "le motif du cas est accordé tel quel" '--allow-tools [^ ]*bash:[^ ]* '
refuse_output "un cas restreint n'accorde jamais Bash entier" '--allow-tools Bash '

echo "# eval-run : rien ne part sans « oui »"
cat >"$work/green.json" <<'EOF'
{"schemaVersion": 1, "partial": false, "costUsd": 2.1, "claudeVersion": "2.1.296",
 "cases": [{"name": "demo-positive", "aggregates": {"score": 1.0, "delta": 0.67}, "arms": {"with": [{"error": null}], "without": [{"error": null}]}},
           {"name": "demo-negative", "aggregates": {"score": 1.0, "delta": 0.0}, "arms": {"with": [{"error": null}], "without": [{"error": null}]}}]}
EOF
for answer in "ok" "oui mais vite" "" "d'accord"; do
  : >"$log"
  run_pp eval-run "$good" demo --quote "$answer" -- PATH="$STUBPATH" STUB_LOG="$log" STUB_RESULT="$work/green.json"
  [[ $PP_STATUS == 1 && $PP_OUTPUT == *refusé* ]] && pass "« $answer » : refusé" || fail "« $answer » : refusé" "exit $PP_STATUS ; ${PP_OUTPUT:0:200}"
  grep -qF 'plugin eval' "$log" && fail "« $answer » : rien n'est lancé" || pass "« $answer » : rien n'est lancé"
done
: >"$log"
run_pp eval-run "$good" demo --quote "Oui" -- PATH="$STUBPATH" STUB_LOG="$log" STUB_RESULT="$work/green.json"
expect_pp "« Oui » : lancé, verdict vert, exit 0" 0
line=$(grep -F 'plugin eval' "$log")
[[ $line == *"--no-publish"* && $line == *"--max-cost-usd 3"* && $line != *"trust-plugin"* && $line == *"--case demo-*"* ]] \
  && pass "la commande lancée est celle annoncée" || fail "la commande lancée est celle annoncée" "$line"
expect_output "le verdict suit le lancement" '^verdict : vert'

run_pp eval-run "$good" demo --quote "oui" -- PATH="$STUBPATH" STUB_UNTRUSTED=1 STUB_RESULT="$work/green.json"
expect_pp "dossier non approuvé : exit 2" 2
expect_output "dossier non approuvé : bloqué, et la commande gratuite qui l'approuve" "^bloqué : .+ n'est pas un dossier de confiance.+--case 'aucun-\\*'.+--max-cost-usd 0\\.01"

echo "# eval-verdict"
# verdict <label> <exit> <pattern> <jq filter on green.json>
verdict() {
  jq "$4" "$work/green.json" >"$work/result.json"
  run_pp eval-verdict "$good" demo "$work/result.json"
  if [[ $PP_STATUS == "$2" ]] && grep -qE -- "$3" <<<"$PP_OUTPUT"; then pass "$1"
  else fail "$1" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 300)"; fi
}
verdict "positif Δ > 0, tout à 1 : vert" 0 '^verdict : vert' '.'
verdict "positif réussi par le témoin : refusé" 1 '^refusé : le témoin réussit demo-positive \(WITH 1\.00, W/OUT 1\.00\)' '.cases[0].aggregates.delta = 0'
verdict "positif sous le seuil : rouge" 1 '^rouge : demo-positive : WITH 0\.33' '.cases[0].aggregates = {score: 0.33, delta: 0.33}'
verdict "négatif sans écart : accepté" 0 '^verdict : vert' '.cases[1].aggregates.delta = 0'
verdict "sans bras témoin : jugé sur le score seul" 1 '^rouge : demo-positive : WITH 0\.00, Δ —' '.cases[0].aggregates = {score: 0}'
verdict "bac à sable absent : bloqué" 2 '^bloqué : demo-positive : sandbox' '.cases[0].arms.with[0].error = "sandbox unavailable: bubblewrap not found"'
verdict "passage partiel : dit" 2 '^partiel : cost_ceiling' '.partial = true | .partialReason = "cost_ceiling"'

rm -rf "$NOSANDBOX"
finish
