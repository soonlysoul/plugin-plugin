#!/usr/bin/env bash
# Refuse les commandes irréversibles.
#
# Gabarit posé par scripts/init-projet.sh. Ce fichier appartient désormais au
# dépôt qui le porte : l'adapter à ce projet est prévu, pas toléré. Y ajouter un
# motif est un geste ordinaire ; en retirer un se justifie dans le commit.
#
# PreToolUse / matcher Bash. Reçoit le JSON de l'appel sur stdin.
# Sortie : exit 0 laisse passer, exit 2 refuse et renvoie stderr à Claude.
#
# Ce hook est la dernière barrière, pas la seule : `permissions.deny` de
# settings.json couvre les mêmes cas par motif. Un motif se contourne par une
# variante d'écriture, une expression régulière un peu moins. Les deux ensemble
# valent mieux que l'une des deux.
#
# Testable sans Claude :
#   echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | ./block-dangerous-commands.sh
set -uo pipefail

entree=$(cat)
outil=$(printf '%s' "$entree" | jq -r '.tool_name // ""')
[ "$outil" = "Bash" ] || exit 0

commande_brute=$(printf '%s' "$entree" | jq -r '.tool_input.command // ""')
[ -n "$commande_brute" ] || exit 0

# Le contenu d'un heredoc est une DONNÉE, pas une commande : un message de commit
# qui parle de « sudo » n'exécute pas sudo, et un test qui contient « rm -rf / »
# ne supprime rien. Sans ce filtre, écrire de la documentation sur les commandes
# dangereuses devient impossible — le garde bloquerait sa propre description.
#
# La ligne qui OUVRE le heredoc est conservée : c'est bien une commande.
commande=$(printf '%s\n' "$commande_brute" | awk '
  BEGIN { dans_heredoc = 0; marqueur = "" }
  {
    if (dans_heredoc) {
      ligne = $0
      sub(/^[[:space:]]+/, "", ligne)
      if (ligne == marqueur) { dans_heredoc = 0 }
      next
    }
    if (match($0, /<<-?[[:space:]]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)) {
      m = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[[:space:]]*/, "", m)
      gsub(/['"'"'"]/, "", m)
      marqueur = m
      dans_heredoc = 1
    }
    print
  }
')
[ -n "$commande" ] || exit 0

refuser() {
  printf 'BLOQUÉ par block-dangerous-commands.sh : %s\n\n' "$1" >&2
  printf 'Commande : %s\n\n' "$commande" >&2
  printf 'Cette opération est irréversible.\n' >&2
  printf 'Si elle est réellement nécessaire, elle doit être proposée à\n' >&2
  printf "l'utilisateur et exécutée par lui, jamais par la session.\n" >&2
  exit 2
}

# Chaque règle lit la commande par une chaîne ici (<<<), jamais par un tube :
# `grep -q` sort à la première correspondance, et `printf`, qui écrivait encore
# une commande plus longue qu'un tube, mourait de SIGPIPE ; sous `pipefail`, le
# test rendait 141, donc faux — un geste en première ligne d'une longue commande
# passait.

# ─── rm -rf destructeur ───────────────────────────────────────────────────────
# Vise tout chemin ABSOLU ou partant du home : racine, ~, $HOME, /home, /nix,
# /etc, /var, /usr. Un chemin relatif (./build, node_modules) passe — c'est la
# forme d'un nettoyage légitime dans un espace de travail.
#
# Volontairement conservateur : « rm -rf /home/x/projet/build » est refusé alors
# qu'il peut être anodin. La même intention s'écrit en relatif, et le coût d'un
# refus injustifié est sans commune mesure avec celui d'un effacement.
_rmrf='rm[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*f|-[[:alnum:]]*f[[:alnum:]]*[rR]|--recursive[[:space:]]+--force)[[:space:]]+'
if grep -Eq "${_rmrf}(~|\\\$HOME|/home/|/nix|/etc|/var|/usr|/opt|/srv)" <<<"$commande"; then
  refuser "suppression récursive dans le home ou dans une arborescence système"
fi
# La racine seule, ou « / » suivi d'un joker.
if grep -Eq "${_rmrf}/([[:space:]]|\*|$)" <<<"$commande"; then
  refuser "suppression récursive de la racine"
fi

# ─── sudo non déclaré ─────────────────────────────────────────────────────────
# Les instructions d'agence : toute commande sudo est PROPOSÉE, jamais exécutée.
if grep -Eq '(^|[;&|[:space:]])sudo([[:space:]]|$)' <<<"$commande"; then
  refuser "sudo — à proposer à l'utilisateur, jamais à exécuter"
fi

# ─── force push ───────────────────────────────────────────────────────────────
if grep -Eq 'git[[:space:]]+push[^|;&]*(--force([[:space:]]|$|=)|[[:space:]]-f([[:space:]]|$))' <<<"$commande"; then
  refuser "git push --force — réécrit l'historique distant"
fi

# ─── Historique Git réécrit ou travail détruit ────────────────────────────────
if grep -Eq 'git[[:space:]]+(reset[[:space:]]+--hard[[:space:]]+(origin|upstream)/|clean[[:space:]]+-[[:alnum:]]*[xX]|filter-branch|filter-repo)' <<<"$commande"; then
  refuser "destruction de travail local ou réécriture d'historique"
fi

# ─── Base de données ──────────────────────────────────────────────────────────
if grep -Eiq 'DROP[[:space:]]+(DATABASE|SCHEMA|TABLE)|TRUNCATE[[:space:]]+TABLE|DELETE[[:space:]]+FROM[^;]*(WHERE[[:space:]]+1[[:space:]]*=[[:space:]]*1|;|$)' <<<"$commande"; then
  refuser "opération destructrice sur la base de données"
fi

# ─── Production ───────────────────────────────────────────────────────────────
# Le déploiement production relève d'une procédure dédiée, jamais d'une
# session. Le mot « production » suffit à exiger le passage par un humain.
if grep -Eiq '(deploy|apply|promote|release)[^|;&]*\b(prod|production)\b|\b(prod|production)\b[^|;&]*(deploy|apply|promote)' <<<"$commande"; then
  refuser "déploiement production — procédure dédiée obligatoire"
fi

# ─── Destruction d'infrastructure ─────────────────────────────────────────────
if grep -Eq 'terraform[[:space:]]+destroy|pulumi[[:space:]]+destroy|kubectl[[:space:]]+delete[[:space:]]+(namespace|node|pv)|docker[[:space:]]+(system[[:space:]]+prune|volume[[:space:]]+rm)|nixos-rebuild' <<<"$commande"; then
  refuser "destruction d'infrastructure ou reconstruction système"
fi

# ─── Clés SSH ─────────────────────────────────────────────────────────────────
if grep -Eq 'ssh-keygen|ssh-add[[:space:]]+-[dD]|(rm|mv|chmod|>)[^|;&]*\.ssh/' <<<"$commande"; then
  refuser "modification des clés SSH"
fi

# ─── Exfiltration de secrets ──────────────────────────────────────────────────
# Un secret lu puis envoyé sur le réseau, ou affiché dans une sortie conservée.
if grep -Eq '(cat|less|head|tail|xxd|base64)[^|;&]*(\.env|\.ssh/|credentials|\.pem|\.key|token|secret)' <<<"$commande" \
   && grep -Eq '\|[[:space:]]*(curl|wget|nc|ncat|socat|ssh|mail)' <<<"$commande"; then
  refuser "lecture d'un secret redirigée vers le réseau"
fi

# ─── Installation impérative (instructions NixOS de l'agence) ─────────────────
if grep -Eq '(npm|pnpm|yarn)[[:space:]]+(install|i|add)[[:space:]]+(-g|--global)|pip[[:space:]]+install|curl[^|;&]*\|[[:space:]]*(ba)?sh|wget[^|;&]*\|[[:space:]]*(ba)?sh' <<<"$commande"; then
  refuser "installation impérative — tout passe par Nix sur cette machine"
fi

exit 0
