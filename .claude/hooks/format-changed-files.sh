#!/usr/bin/env bash
# Formate le fichier qui vient d'être écrit, avec l'outil déclaré par le projet.
#
# PostToolUse / matcher Write|Edit. Ne bloque jamais : un formateur absent est
# une information, pas une faute. Sortie sur stderr avec exit 0 — Claude la voit
# sans que l'écriture soit annulée.
#
# Formater ici évite qu'un diff de revue soit pollué par des retouches de style,
# et que la CI recale une branche pour une virgule.
#
# Gabarit posé par scripts/init-projet.sh. Ajouter l'outil de ce projet au
# « case » ci-dessous est le geste attendu.
set -uo pipefail

entree=$(cat)
chemin=$(printf '%s' "$entree" | jq -r '.tool_input.file_path // ""')
[ -n "$chemin" ] && [ -f "$chemin" ] || exit 0

# Un fichier hors du dépôt n'est pas formaté : le projet ne décide pas du style
# des autres.
racine="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
case "$chemin" in
  "$racine"/*) ;;
  *) exit 0 ;;
esac

signaler() { printf 'format-changed-files.sh : %s\n' "$1" >&2; }

case "$chemin" in
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.json | *.css | *.md)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write "$chemin" >/dev/null 2>&1 || signaler "prettier a échoué sur $chemin"
    elif [ -x "$racine/node_modules/.bin/prettier" ]; then
      "$racine/node_modules/.bin/prettier" --write "$chemin" >/dev/null 2>&1 \
        || signaler "prettier a échoué sur $chemin"
    fi
    ;;

  *.dart)
    command -v dart >/dev/null 2>&1 \
      && { dart format "$chemin" >/dev/null 2>&1 || signaler "dart format a échoué sur $chemin"; }
    ;;

  *.rs)
    command -v rustfmt >/dev/null 2>&1 \
      && { rustfmt --edition 2021 "$chemin" >/dev/null 2>&1 || signaler "rustfmt a échoué sur $chemin"; }
    ;;

  *.nix)
    command -v nixfmt >/dev/null 2>&1 \
      && { nixfmt "$chemin" >/dev/null 2>&1 || signaler "nixfmt a échoué sur $chemin"; }
    ;;

  *.sh)
    # Pas de formateur : shellcheck signale ce qui compte vraiment dans un script.
    if command -v shellcheck >/dev/null 2>&1; then
      shellcheck -S warning "$chemin" >/dev/null 2>&1 \
        || signaler "shellcheck signale des avertissements sur $chemin"
    fi
    # Un hook non exécutable ne s'exécute pas — le cas est silencieux et coûteux.
    case "$chemin" in
      */.claude/hooks/*) [ -x "$chemin" ] || chmod +x "$chemin" ;;
    esac
    ;;
esac

exit 0
