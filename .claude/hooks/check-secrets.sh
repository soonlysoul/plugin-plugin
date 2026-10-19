#!/usr/bin/env bash
# Refuse l'écriture d'un secret dans le dépôt.
#
# PreToolUse / matcher Write|Edit. Aucun secret dans Git, aucun token dans
# CLAUDE.md ni dans .mcp.json — ces deux fichiers-là sont systématiquement
# committés et relus, ce qui en fait le pire endroit possible pour une clé.
#
# Gabarit posé par scripts/init-projet.sh. Ce fichier appartient désormais au
# dépôt qui le porte.
#
# Testable sans Claude :
#   echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x.ts","content":"const k = \"sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\""}}' \
#     | ./check-secrets.sh
set -uo pipefail

entree=$(cat)
outil=$(printf '%s' "$entree" | jq -r '.tool_name // ""')
case "$outil" in
  Write | Edit | MultiEdit) ;;
  *) exit 0 ;;
esac

chemin=$(printf '%s' "$entree" | jq -r '.tool_input.file_path // ""')

# Contenu écrit, quelle que soit la forme de l'outil.
contenu=$(printf '%s' "$entree" | jq -r '
  [ .tool_input.content?,
    .tool_input.new_string?,
    (.tool_input.edits? // [] | .[].new_string?)
  ] | map(select(. != null)) | join("\n")
')
[ -n "$contenu" ] || exit 0

refuser() {
  printf 'BLOQUÉ par check-secrets.sh : %s\n\n' "$1" >&2
  printf 'Fichier : %s\n\n' "${chemin:-inconnu}" >&2
  printf 'Un secret ne doit jamais entrer dans Git.\n' >&2
  printf "Utiliser le secret broker, une variable d'environnement éphémère,\n" >&2
  printf 'ou un fichier hors dépôt référencé par son chemin.\n' >&2
  exit 2
}

# ─── Ce qui est manifestement factice ─────────────────────────────────────────
# Sans exception, il devient impossible d'écrire un test de détection de secrets
# ou de documenter un format de jeton : le garde bloquerait sa propre
# description. Mais l'exception doit être ÉTROITE — la première version acceptait
# qu'un fragment quelconque disculpe le jeton entier, ce qui suffisait à la
# contourner en collant « EXAMPLE » derrière un vrai jeton.
#
# Deux critères seulement, tous deux ancrés sur la TOTALITÉ du corps :
#
#   1. le corps n'est qu'une répétition d'un même caractère ;
#   2. le jeton est un exemple publié par le fournisseur lui-même.
#
# Pas de rétro-référence : grep -E ne la garantit pas (ugrep la refuse). Les
# répétitions sont donc énumérées.
_repetitions=""
for _c in {A..Z} {a..z} {0..9}; do _repetitions="${_repetitions}${_c}+|"; done
CORPS_REPETE="^(${_repetitions%|})$"
unset _repetitions _c

# Exemples que les fournisseurs publient eux-mêmes dans leur documentation.
EXEMPLES_PUBLIES='^(AKIAIOSFODNN7EXAMPLE|ASIAIOSFODNN7EXAMPLE|AKIAI44QH8DHBEXAMPLE)$'

# Préfixes connus, retirés avant l'analyse : c'est le CORPS qui doit être
# factice, pas la ligne qui le contient.
PREFIXES='^(sk-ant-|gh[pousr]_|github_pat_|xox[abposr]-|AKIA|ASIA)([a-z0-9]{1,8}-)?'

# Rend 0 si AU MOINS UNE occurrence du motif ne ressemble pas à une valeur
# factice. Une occurrence réelle suffit à refuser, quel que soit le reste.
#
# Le résultat de `grep -Eo` est capturé AVANT d'être filtré. Enchaîner les deux
# dans un pipe faisait tuer le producteur par SIGPIPE dès la première
# correspondance du consommateur `-q` ; sous `pipefail`, le pipeline rendait
# alors 141, donc « pas de refus » — et un vrai jeton passait, à condition
# d'être suivi d'assez de contenu pour remplir le tampon de tube.
vraisemblable() {
  occurrences=$(printf '%s' "$contenu" | grep -Eo "$1") || return 1
  while IFS= read -r occurrence; do
    [ -n "$occurrence" ] || continue
    printf '%s' "$occurrence" | grep -Eq "$EXEMPLES_PUBLIES" && continue
    corps=$(printf '%s' "$occurrence" | sed -E "s/$PREFIXES//")
    printf '%s' "$corps" | grep -Eq "$CORPS_REPETE" && continue
    return 0
  done <<EOF
$occurrences
EOF
  return 1
}

# ─── Jetons reconnaissables à leur préfixe ────────────────────────────────────
if vraisemblable 'sk-ant-[A-Za-z0-9_-]{20,}'; then
  refuser "clé API Anthropic"
fi
if vraisemblable 'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}'; then
  refuser "token GitHub"
fi
if vraisemblable 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}'; then
  refuser "identifiant AWS"
fi
if vraisemblable 'xox[abposr]-[A-Za-z0-9-]{10,}'; then
  refuser "token Slack"
fi

# ─── Clés privées ─────────────────────────────────────────────────────────────
# L'en-tête seul n'est pas une clé : il figure dans toute documentation qui
# explique le format. C'est le CORPS qui fuit.
#
# Le corps est extrait ENTRE les délimiteurs, puis recollé. Chercher un bloc
# base64 « quelque part dans le fichier » se contournait en repliant la clé sur
# des lignes plus courtes, et refusait à tort une documentation qui montrait un
# en-tête à côté d'un hash sans rapport.
# Seules les lignes ENTIÈREMENT base64 sont accumulées. Sans cette restriction,
# une clé sans marqueur de fin faisait avaler le reste du fichier — et une
# documentation montrant un en-tête à côté d'une phrase contenant un hash était
# refusée à tort.
corps_pem=$(printf '%s' "$contenu" \
  | awk '/-----BEGIN [A-Z ]*PRIVATE KEY-----/ { dedans = 1; next }
         /-----END [A-Z ]*PRIVATE KEY-----/    { dedans = 0; next }
         dedans && /^[A-Za-z0-9+\/=]+$/' \
  | tr -cd 'A-Za-z0-9+/=')
if [ "${#corps_pem}" -ge 64 ]; then
  refuser "clé privée"
fi

# ─── Affectation d'un secret à une valeur littérale ───────────────────────────
# Ne se déclenche que sur une vraie valeur : les placeholders, les lectures
# d'environnement et les chaînes vides passent — sinon .env.example, les tests
# et la documentation deviendraient inécrivables.
if printf '%s' "$contenu" | grep -Eiq '(api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|password|passwd|client[_-]?secret|private[_-]?key)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{12,}["'"'"']'; then
  if ! printf '%s' "$contenu" | grep -Eiq '(api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|password|passwd|client[_-]?secret|private[_-]?key)[[:space:]]*[:=][[:space:]]*["'"'"'](\$\{?[A-Z_]+\}?|<[^>]+>|x{3,}|\.{3,}|change[_-]?me|your[_-]?|example|placeholder|dummy|fake|test[_-]?only|TODO|REMPLACER)'; then
    refuser "affectation d'un secret à une valeur littérale"
  fi
fi

# ─── Fichiers où un secret ne doit jamais figurer, même en exemple ────────────
#
# LE GUILLEMET APRÈS LA CLÉ N'EST PAS FACULTATIF DANS LA VRAIE VIE. La version
# d'origine exigeait « api_key: » collé à son séparateur, et refusait une valeur
# commençant par un guillemet. Or .mcp.json EST du JSON : la clé s'y écrit
# toujours « "API_KEY": "…" ». Les deux guillemets faisaient échouer le motif à
# tous les coups — la garde qui vise nommément ce fichier ne pouvait pas s'y
# déclencher une seule fois. Mesuré le 2026-08-17, sur le cas réel qui l'a
# motivée : un serveur MCP portant sa clé d'API dans « env ».
#
# Le guillemet est donc optionnel des DEUX côtés du séparateur, et c'est le
# premier caractère de la VALEUR, guillemet consommé, qui décide :
#   "API_KEY":"21st_sk_x"   → « 2 » : refusé
#   "API_KEY":"${MA_CLE}"   → « $ » : lecture d'environnement, accepté
#   "API_KEY":"<votre clé>" → « < » : gabarit à remplir, accepté
#   "API_KEY":""            → « " » : vide, accepté
case "$chemin" in
  *CLAUDE.md | *.mcp.json | *manifest.yaml | *manifest.yml)
    if printf '%s' "$contenu" | grep -Eiq '(token|api[_-]?key|secret|password)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?[^[:space:]<$"'"'"']'; then
      refuser "ce fichier est explicitement interdit aux secrets"
    fi
    ;;
esac

exit 0
