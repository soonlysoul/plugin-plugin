# Guide d'utilisation — plugin-plugin

plugin-plugin construit des plugins Claude Code au modèle de plugin-flutter, du cadrage à la publication dans la marketplace `soon`. Les décisions sont les vôtres ; plugin-plugin les prépare, les trace et refuse d'avancer sans elles.

## Principes

- **Rien n'est approuvé implicitement.** Un document de cadrage, un lancement payant, un geste vers GitHub : chacun attend votre accord, et l'accord est consigné.
- **Une question à la fois**, posée en texte, avec une recommandation motivée en tête. Le skill s'arrête ensuite ; répondez dans la conversation.
- **Aucun résultat sans sa commande.** Chaque étape est réussie, échouée, bloquée ou non exécutée, avec la commande lancée et son code de sortie.
- **L'état vit sur le disque**, dans `.plugin-plugin/` du plugin cible et dans git. Une session coupée se reprend sans dépendre de sa mémoire.

## Le parcours d'un nouveau plugin

| Étape | Skill | Ce que vous faites |
| --- | --- | --- |
| 1. Cadrer | `/plugin-plugin:frame` | Décrire le besoin, répondre aux questions (ou déléguer une décision), approuver le PRD puis l'architecture |
| 2. Créer | `/plugin-plugin:create` | Rien : le nom est vérifié sur GitHub, la charpente posée, git initialisé, la suite du plugin lancée, verte |
| 3. Ajouter | `/plugin-plugin:add` | Demander un composant : skill, agent, hook, déclaration d'un serveur MCP |
| 4. Contrôler | `/plugin-plugin:check` | Lire les écarts au modèle, s'il y en a |
| 5. Publier | `/plugin-plugin:release` | Lire la répétition, puis dire « oui » à chaque étape de la publication |

`resume` et `reaudit` servent à tout moment.

## Cadrer — `frame`

« cadre un nouveau plugin ». Dans un dossier vide ou encore absent : une question par message — besoin, hors périmètre, nom, langue des identifiants, composants, critères —, chacune avec sa recommandation. « Choisis pour moi » délègue la décision, consignée avec sa raison dans `.plugin-plugin/decisions.md`. Le PRD puis l'architecture vous sont présentés ; seul un accord explicite les fait passer en APPROUVÉ, et il est cité mot pour mot dans `.plugin-plugin/approvals.log`. Un document approuvé puis modifié repasse en REVUE.

## Créer — `create`

« crée le plugin », une fois le cadrage approuvé. Le dossier ne doit contenir que ce cadrage : tout autre fichier fait refuser la création, sans rien toucher. Le plugin créé passe sa propre suite dès sa naissance.

## Ajouter un composant — `add`

« ajoute un agent à plugin-… ». Chaque composant arrive avec son test, vu en échec avant de passer :

- **Skill** : la suite d'évaluation est écrite à partir de vos demandes concrètes — celles qui doivent le déclencher, celles qui ne le doivent pas. Avant tout lancement s'affichent le nombre de sessions, le coût estimé, le plafond et le compte qui paie ; rien ne part sans votre « oui ».
- **Hook** : vous êtes averti qu'un hook d'un plugin installé pour le compte s'applique à toutes les sessions, puis il est testé sur des entrées simulées, sans session.
- **Agent** : ses outils sont déclarés un par un, jamais `Agent` ; un garde de portée le tient à ses dossiers d'écriture et à sa liste de commandes.
- **Serveur MCP** : un serveur existant est déclaré, sans rien installer ni écrire de secret ; vos valeurs s'écrivent `${VAR}`.

Un composant hors périmètre — code d'un serveur MCP, channel, serveur de langage, style de sortie, commande classique, option de plugin, dépendance entre plugins — est refusé, avec sa raison et ce qui le rouvrirait.

`add` travaille aussi sur plugin-flutter, qu'il n'a pas créé : il n'y écrit que le composant et son câblage.

## Contrôler — `check`

« plugin-nixos suit-il le modèle ? ». La liste des écarts, un par ligne, sans rien modifier. `add` refuse un plugin qui en a.

## Publier — `release`

Ne se lance que sur votre demande explicite, `/plugin-plugin:release <dossier>`.

1. **La répétition** n'envoie rien. Elle refuse un arbre non enregistré, une validation ou une suite rouge, une autre branche que `main`. Elle propose la version (correctif, mineure, majeure selon le changement), rédige l'entrée du CHANGELOG, éprouve l'étiquette, mesure le coût en contexte par composant et liste chaque geste avec sa commande exacte.
2. **La publication**, à votre demande, avance étape par étape. Chaque étape est annoncée avec ses commandes ; tapez **« oui »**, littéralement, pour la lancer. Toute autre réponse la retire, et une annonce sans réponse pendant trente minutes aussi.
3. Un nouveau plugin entre dans la marketplace `soon` par une PR. **La fusion est à vous.**
4. À la fin : la commande d'installation ou de mise à jour.

Une publication coupée se reprend sans rien refaire : ce qui est fait se lit dans les dépôts.

## Reprendre — `resume`

« reprends où on s'est arrêté ». Dix lignes au plus : ce qui est fait, ce qui reste, l'étape suivante proposée, les incohérences entre le point de reprise et git. Rien n'est modifié avant votre accord.

## Ré-auditer — `reaudit`

Sur demande explicite, `/plugin-plugin:reaudit`, après une mise à jour de Claude Code : les faits de la base à revérifier, les formats de composants qui ont changé, les faits que la validation stricte contredit.
