#!/usr/bin/env bash
# Rappelle, en fin de tour, que du code a changé sans que les tests aient tourné.
#
# Stop hook. Les instructions d'agence sont explicites : « ne jamais annoncer
# terminé sans avoir exécuté les tests et montré leur sortie ». Ce hook ne peut
# pas vérifier ce qui a été *montré* ; il vérifie ce qui a *changé*, et le
# signale.
#
# Ne bloque pas. Un hook Stop qui bloque enferme la session dans une boucle dont
# elle ne peut pas sortir seule — le remède serait pire que le mal.
#
# Gabarit posé par scripts/init-projet.sh. Les extensions surveillées et les
# commandes proposées en fin de fichier sont à ajuster à ce projet.
set -uo pipefail

racine="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$racine" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Fichiers de code modifiés et non commités, tests exclus.
modifies=$(git status --porcelain 2>/dev/null \
  | awk '{ print $NF }' \
  | grep -Ev '(^|/)(test|tests|__tests__)/|\.(test|spec)\.[a-z]+$' \
  | grep -E '\.(ts|tsx|js|jsx|mjs|dart|rs)$' || true)

[ -n "$modifies" ] || exit 0

nombre=$(printf '%s\n' "$modifies" | grep -c . || true)

{
  printf '\n── verify-tests.sh ─────────────────────────────────────────────\n'
  printf '%s fichier(s) de code modifié(s) et non commité(s) :\n\n' "$nombre"
  printf '%s\n' "$modifies" | sed 's/^/  /'
  printf '\nLes tests ont-ils été exécutés et leur sortie montrée ?\n'
  printf 'Sinon, ne pas conclure — lancer la commande du projet :\n\n'
  [ -f package.json ]           && printf '  pnpm test\n'
  [ -f pubspec.yaml ]           && printf '  flutter test\n'
  [ -f Cargo.toml ]             && printf '  cargo test\n'
  [ -f package.json ] || [ -f pubspec.yaml ] || [ -f Cargo.toml ] \
    || printf '  (aucun harnais de test dans ce dépôt pour le moment)\n'
  printf '────────────────────────────────────────────────────────────────\n'
} >&2

exit 0
