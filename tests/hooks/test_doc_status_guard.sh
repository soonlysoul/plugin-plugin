#!/usr/bin/env bash
# doc-status-guard (PostToolUse, Edit|Write, fail-open): a framing document that was approved
# and then modified goes back to review; a draft or a document under review keeps its status;
# outside a managed project (no .plugin-plugin/ beside docs/) the hook is silent.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_doc_status_guard
HOOK="$PLUGIN_ROOT/hooks/scripts/doc-status-guard.sh"
PP="$PLUGIN_ROOT/scripts/pp.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ ! -f $HOOK ]]; then
  fail "hooks/scripts/doc-status-guard.sh présent" "absent : $HOOK"
  finish
  exit
fi

# post_input <file> [tool]: PostToolUse input for a write to <file>.
post_input() {
  jq -nc --arg f "$1" --arg t "${2:-Edit}" --arg d "$work" \
    '{session_id: "test", cwd: $d, hook_event_name: "PostToolUse", permission_mode: "default",
      tool_name: $t, tool_input: {file_path: $f}, tool_response: {success: true}, tool_use_id: "toolu_test"}'
}
# new_project <name> <status line>: a managed project with docs/PRD.md under that status.
new_project() {
  local root="$work/$1"
  mkdir -p "$root/docs" "$root/.plugin-plugin"
  printf '# PRD — essai\n\n%s\n\n## Problème\n\nTexte.\n' "$2" >"$root/docs/PRD.md"
  printf '%s' "$root"
}
status_line() { grep -m 1 '^\*\*Statut : ' "$1"; }
sum() { sha256sum "$1" | cut -d' ' -f1; }

echo "# document approuvé, puis modifié"
root=$(new_project approved '**Statut : BROUILLON**')
bash "$PP" approve "$root/docs/PRD.md" --quote "je valide" >/dev/null 2>&1
status_line "$root/docs/PRD.md" | grep -q 'APPROUVÉ' && pass "mise en place : PRD approuvé par pp.sh approve" \
  || fail "mise en place : PRD approuvé par pp.sh approve" "$(status_line "$root/docs/PRD.md")"
run_hook "$HOOK" "$(post_input "$root/docs/PRD.md" Write)"
expect_status "écriture de l'approbation elle-même : exit 0" 0
status_line "$root/docs/PRD.md" | grep -q 'APPROUVÉ' && pass "écriture de l'approbation : le statut reste approuvé" \
  || fail "écriture de l'approbation : le statut reste approuvé" "$(status_line "$root/docs/PRD.md")"
printf '\nUne phrase ajoutée après l approbation.\n' >>"$root/docs/PRD.md"
run_hook "$HOOK" "$(post_input "$root/docs/PRD.md")"
expect_status "approuvé puis modifié : exit 0 (PostToolUse ne bloque pas)" 0
status_line "$root/docs/PRD.md" | grep -q '^\*\*Statut : REVUE\*\*' && pass "approuvé puis modifié : repasse en revue" \
  || fail "approuvé puis modifié : repasse en revue" "$(status_line "$root/docs/PRD.md")"
status_line "$root/docs/PRD.md" | grep -q 'approuvé le [0-9-]*' && pass "la ligne de statut garde la date de l'approbation perdue" \
  || fail "la ligne de statut garde la date de l'approbation perdue" "$(status_line "$root/docs/PRD.md")"
grep -q 'Une phrase ajoutée' "$root/docs/PRD.md" && pass "le contenu modifié est conservé" || fail "le contenu modifié est conservé"
jq -e '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | test("REVUE"))' \
  <<<"$HOOK_STDOUT" >/dev/null 2>&1 && pass "Claude est prévenu par additionalContext" \
  || fail "Claude est prévenu par additionalContext" "stdout : ${HOOK_STDOUT:0:300}"

echo "# approbation écrite à la main, sans le journal"
root=$(new_project forged '**Statut : APPROUVÉ** le 2026-10-19 (« je valide »).')
run_hook "$HOOK" "$(post_input "$root/docs/PRD.md")"
status_line "$root/docs/PRD.md" | grep -q '^\*\*Statut : REVUE\*\*' && pass "approuvé sans trace au journal : repasse en revue" \
  || fail "approuvé sans trace au journal : repasse en revue" "$(status_line "$root/docs/PRD.md")"

echo "# brouillon et revue gardent leur statut"
for status in BROUILLON REVUE; do
  root=$(new_project "kept-$status" "**Statut : $status**")
  printf '\nAjout.\n' >>"$root/docs/PRD.md"
  before=$(sum "$root/docs/PRD.md")
  run_hook "$HOOK" "$(post_input "$root/docs/PRD.md")"
  expect_silent_allow "$status modifié : silencieux"
  [[ $(sum "$root/docs/PRD.md") == "$before" ]] && pass "$status modifié : fichier intact" || fail "$status modifié : fichier intact"
done

echo "# hors de son contexte, le hook est inerte"
root="$work/unmanaged"
mkdir -p "$root/docs"
printf '# PRD\n\n**Statut : APPROUVÉ** le 2026-10-19 (« je valide »).\n\nTexte.\n' >"$root/docs/PRD.md"
before=$(sum "$root/docs/PRD.md")
run_hook "$HOOK" "$(post_input "$root/docs/PRD.md")"
expect_silent_allow "projet non géré (pas de .plugin-plugin/) : silencieux"
[[ $(sum "$root/docs/PRD.md") == "$before" ]] && pass "projet non géré : fichier intact" || fail "projet non géré : fichier intact"
root=$(new_project outside '**Statut : BROUILLON**')
printf '# README\n\n**Statut : APPROUVÉ** le 2026-10-19 (« je valide »).\n' >"$root/README.md"
before=$(sum "$root/README.md")
run_hook "$HOOK" "$(post_input "$root/README.md")"
expect_silent_allow "fichier hors de docs/ : silencieux"
[[ $(sum "$root/README.md") == "$before" ]] && pass "fichier hors de docs/ : intact" || fail "fichier hors de docs/ : intact"
run_hook "$HOOK" "$(post_input "$root/docs/PRD.md" Bash)"
expect_silent_allow "outil autre qu'Edit ou Write : silencieux"

echo "# fail-open"
run_hook "$HOOK" 'pas du json'
expect_status "entrée illisible : exit 0" 0
no_jq=$(path_without jq)
run_hook "$HOOK" "$(post_input "$root/docs/PRD.md")" PATH="$no_jq"
expect_status "jq absent : exit 0" 0
rm -rf "$no_jq"

finish
