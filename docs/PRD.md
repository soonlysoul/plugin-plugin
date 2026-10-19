# PRD — plugin-agent

2026-10-19 · Soon

**Statut : APPROUVÉ** le 2026-10-19, par Soon (« oui »), après une modification
faite à sa demande : plugin-flutter sert seul de modèle, et la réécriture de
plugin-nixos devient un test de plugin-agent. Première approbation le même jour
(« je valide »), à l'issue du cadrage. Toute modification d'un document approuvé
le repasse en revue.

## Problème

Soon a publié deux plugins dans sa marketplace GitHub `soon` : plugin-flutter et
plugin-nixos. Le premier a demandé un parcours en sept phases : audit de la
documentation officielle, squelette, gardes testés, agents, skills, validation,
publication. Une bonne part de ce parcours ne tient à aucun domaine : vérifier
ce que la plateforme accepte réellement, poser un manifeste qui passe la
validation stricte, tester un hook sans ouvrir de session, augmenter la version
pour que les appareils se mettent à jour, référencer le plugin dans la
marketplace.

Ce savoir a été acquis à la main, parfois en corrigeant une hypothèse fausse :
la validation lancée à la racine d'un plugin ne contrôle que la marketplace. Il
vit aujourd'hui dans les documents d'un seul plugin. Le second a été construit
autrement ; plugin-flutter sert seul de modèle. Chaque nouveau
plugin repart donc de zéro, ou recopie un aîné et en diverge. Un nom choisi trop
vite coûte un renommage après publication, comme flutter-forge devenu
plugin-flutter. L'outil générique officiel ne connaît ni ces conventions ni
plusieurs faits récents de la plateforme, et ne date rien de ce qu'il sait.

Pourquoi maintenant : plugin-flutter a été clôturé le 2026-10-19 sur la version
de la plateforme encore installée. Ce qu'il a appris est exact aujourd'hui, et
commencera à dater à la prochaine mise à jour.

## Solution

plugin-agent permet à Soon de :

- **cadrer** un plugin : décrire le besoin, être interrogé une question à la
  fois, approuver le cadrage et l'architecture avant toute écriture ;
- **créer** un plugin dédié, nommé `plugin-<domaine>`, dans son propre dépôt,
  qui passe la validation stricte et sa propre suite de tests dès sa création ;
- **ajouter un composant** — skill, agent, hook, déclaration d'un serveur MCP
  existant — en voyant son test échouer avant qu'il passe ; pour un skill, ce
  test est un cas d'évaluation comparé à une exécution sans le plugin ;
- **faire évoluer ses plugins existants** qui suivent le modèle (plugin-flutter),
  sans toucher à leur contenu métier ;
- **publier** : créer le dépôt GitHub, ouvrir la PR qui ajoute le plugin à la
  marketplace `soon`, augmenter la version, tenir le journal des changements,
  poser l'étiquette de version — chaque geste après un accord explicite — et,
  au besoin, monter le plugin en sous-module dans un dépôt hôte ;
- **connaître le coût en contexte** de chaque composant avant de publier ;
- **ré-auditer** : savoir quels faits revérifier, et quels formats ont changé,
  depuis la dernière mise à jour de la plateforme ;
- **reprendre** un travail interrompu depuis ce qui est sur disque.

## Utilisateur cible

Soon, unique destinataire. Conçoit et publie ses propres plugins dans sa
marketplace GitHub publique `soon`, depuis un poste dont toute la configuration
est déclarée et où rien ne s'installe à la main. Travaille en français, dans
l'éditeur ou le terminal, avec plusieurs comptes d'abonnement. Exige la preuve
avant l'annonce : un test vu rouge puis vert, une sortie montrée, une décision
motivée et datée. Mène un plugin sur plusieurs sessions et plusieurs jours, avec
des interruptions. Délègue volontiers une décision (« tranche le mieux »), à
condition qu'elle soit motivée et révisable.

## User Stories

### Cadrage

- **US-1** — En tant que Soon, je veux décrire un besoin de plugin et être
  interrogé une question à la fois, avec une recommandation motivée, afin
  d'obtenir un cadrage sans trou.
- **US-2** — En tant que Soon, je veux pouvoir déléguer une décision et recevoir
  le choix retenu avec sa raison, afin d'avancer sans perdre la trace de ce qui a
  été tranché à ma place.
- **US-3** — En tant que Soon, je veux approuver explicitement le cadrage et
  l'architecture avant que le moindre fichier du plugin soit écrit, afin que rien
  ne soit approuvé implicitement.
- **US-4** — En tant que Soon, je veux qu'un document approuvé repasse en revue
  dès qu'il est modifié, afin de savoir à tout moment ce qui est validé.

### Création

- **US-5** — En tant que Soon, je veux qu'un nom hors du format
  `plugin-<domaine>`, ou déjà pris dans la marketplace ou sur GitHub, soit refusé
  avec la raison, afin d'éviter un renommage après publication.
- **US-6** — En tant que Soon, je veux obtenir un plugin dédié qui passe la
  validation stricte et sa suite de tests dès sa création, afin de partir d'un
  état vert.
- **US-7** — En tant que Soon, je veux que la création refuse un dossier cible
  non vide plutôt que de l'écraser, afin de ne jamais perdre un travail existant.

### Composants

- **US-8** — En tant que Soon, je veux ajouter un skill, un agent, un hook ou la
  déclaration d'un serveur MCP en voyant son test échouer pour la bonne raison
  avant qu'il passe, afin de suivre mon cycle rouge/vert.
- **US-9** — En tant que Soon, je veux que le test d'un skill soit un cas
  d'évaluation comparé à une exécution sans le plugin, et qu'un cas déjà réussi
  sans le plugin soit refusé, afin de prouver que le skill apporte quelque chose.
- **US-10** — En tant que Soon, je veux que chaque suite d'évaluation contienne
  au moins un cas où le skill ne doit pas se déclencher, afin de détecter un
  skill qui se déclenche à tort.
- **US-11** — En tant que Soon, je veux connaître avant le lancement le coût
  estimé d'une évaluation, son plafond et le compte qui la paiera, afin de ne pas
  consommer de quota à mon insu.
- **US-12** — En tant que Soon, je veux qu'une évaluation qui ne peut pas lancer
  de commandes sur ce poste soit déclarée bloquée, avec la cause, plutôt que
  réussie, afin de ne pas prendre un contournement pour une preuve.
- **US-13** — En tant que Soon, je veux que chaque agent produit déclare
  explicitement ses outils, afin qu'aucun agent n'hérite de tous les outils à mon
  insu.
- **US-14** — En tant que Soon, je veux que chaque hook produit soit testé avec
  des entrées simulées, sans session, afin de le prouver sans consommer de quota.
- **US-15** — En tant que Soon, je veux être averti qu'un hook s'appliquera à
  toutes mes sessions une fois le plugin installé pour mon compte, afin de
  décider en connaissance de cause.
- **US-16** — En tant que Soon, je veux qu'une demande de composant hors
  périmètre soit refusée avec la raison et le déclencheur qui la rouvrirait, afin
  de ne pas grossir un plugin sans besoin.

### Plugins existants

- **US-17** — En tant que Soon, je veux ajouter un composant à plugin-flutter
  sans toucher à son contenu métier, afin de faire évoluer mes plugins publiés.
- **US-18** — En tant que Soon, je veux qu'un plugin hors modèle soit signalé
  avec la liste de ses écarts, sans aucune modification, afin de savoir pourquoi
  plugin-agent ne s'en charge pas.
- **US-19** — En tant que Soon, je veux reconstruire un plugin existant dans un
  dossier à part et y faire passer sa propre suite de tests, sans jamais modifier
  l'original, afin de confronter le modèle à mes plugins réels.

### Publication

- **US-20** — En tant que Soon, je veux que chaque geste vers GitHub — création
  de dépôt, push, PR — soit annoncé avec sa commande exacte et exécuté seulement
  après mon oui, afin de garder la main sur tout ce qui sort du poste.
- **US-21** — En tant que Soon, je veux que l'ajout d'un nouveau plugin à la
  marketplace passe par une PR que je fusionne moi-même, afin qu'une relecture
  ait réellement lieu.
- **US-22** — En tant que Soon, je veux qu'une sortie de version augmente la
  version selon la nature du changement, complète le journal des changements et
  pose l'étiquette de version, afin que mes appareils reçoivent la mise à jour.
- **US-23** — En tant que Soon, je veux qu'une publication soit refusée si les
  tests ou la validation stricte ne sont pas verts, ou si le dépôt a des
  changements non enregistrés, afin de ne jamais publier un état non prouvé.
- **US-24** — En tant que Soon, je veux répéter une publication sans rien
  envoyer, afin de voir chaque geste avant de le faire.
- **US-25** — En tant que Soon, je veux voir dans la PR et à chaque version le
  coût en contexte de chaque composant, et être alerté au-delà d'un seuil, afin
  de garder mes sessions légères.
- **US-26** — En tant que Soon, je veux pouvoir monter un plugin publié en
  sous-module dans un dépôt hôte, afin que ce dépôt s'appuie sur une version
  épinglée.
- **US-27** — En tant que Soon, je veux qu'une publication interrompue — coupure
  réseau, refus de GitHub — dise ce qui a été fait et ce qui reste, sans rien
  refaire en double, afin de reprendre sans dégât.
- **US-28** — En tant que Soon, je veux que l'état de la marketplace soit lu sur
  GitHub et non dans une copie locale, afin de ne pas décider sur un catalogue
  périmé.
- **US-29** — En tant que Soon, je veux recevoir à la fin la commande
  d'installation ou de mise à jour à lancer moi-même sur chaque appareil, afin
  que l'installation reste mon geste.
- **US-30** — En tant que Soon, je veux que plugin-agent publie lui-même sa
  version 0.1.1, chaque geste après mon accord, afin de prouver la chaîne de
  publication sur la vraie marketplace.

### Ré-audit

- **US-31** — En tant que Soon, je veux, après une mise à jour de la plateforme,
  la liste des faits mesurés sur une version antérieure, et une liste vide si la
  version n'a pas changé, afin de savoir quoi revérifier.
- **US-32** — En tant que Soon, je veux voir quels formats de composants ont
  changé entre deux versions de la plateforme, afin de corriger la base de faits
  avant qu'un plugin ne casse.
- **US-33** — En tant que Soon, je veux que la validation stricte l'emporte quand
  elle contredit un fait de la base, et que ce fait soit signalé à corriger, afin
  que la base reste juste.

### Reprise

- **US-34** — En tant que Soon, je veux reprendre un travail interrompu depuis ce
  qui est sur disque, avec un résumé avant toute action, afin de continuer après
  une limite d'usage ou une coupure de session.

## Critères de succès

1. Un plugin fraîchement créé passe la validation stricte et sa propre suite de
   tests : zéro échec, aucune retouche à la main.
2. Reconstruit dans un dossier à part, plugin-flutter passe 100 % de sa propre
   suite de tests et la validation stricte. Réécrit au modèle dans un dossier à
   part, plugin-nixos passe la validation stricte et sa suite portée au modèle,
   qui garde chacun de ses cas d'origine, et le contrôle de conformité n'y relève
   plus aucun écart. Les originaux ne portent aucun changement.
3. Le plugin témoin — un skill, un agent, un hook — se construit de bout en bout,
   du cadrage à la répétition de publication, sans autre intervention que les
   accords demandés.
4. Chaque composant ajouté laisse la sortie enregistrée de son test en échec,
   puis du même test qui passe.
5. La suite d'évaluation de chaque skill compte au moins un cas qui doit le
   déclencher et un qui ne le doit pas, trois exécutions par cas, et un écart
   positif avec l'exécution sans le plugin.
6. Aucune création de dépôt, aucun push, aucune PR sans un accord explicite
   enregistré ; la marketplace `soon` ne change que par une PR fusionnée par
   Soon.
7. plugin-agent publie lui-même sa version 0.1.1 : version et journal à jour,
   étiquette de version présente, et un appareil qui met à jour reçoit 0.1.1.
8. Après un changement de version de la plateforme, le ré-audit liste les faits
   mesurés sur une version antérieure et les formats changés ; à version
   inchangée, les deux listes sont vides.
9. Le coût en contexte permanent de plugin-agent lui-même reste sous le seuil
   d'alerte.

## Hors périmètre

- Le contenu métier des plugins (consignes Flutter, règles NixOS) : plugin-agent
  fournit la charpente et la méthode.
- Les plugins hors modèle — plugins de tiers, anciennes formes non dédiées — et
  leur mise en conformité. La réécriture de plugin-nixos au modèle est un test de
  plugin-agent, pas une fonction : elle se fait dans un dossier à part et n'est
  jamais publiée.
- Le plugin embarqué dans le dépôt qu'il sert, remplacé par le montage en
  sous-module.
- La configuration pour d'autres utilisateurs : compte, marketplace et langue
  des messages restent écrits en dur.
- Toute marketplace autre que `soon`, y compris la marketplace officielle.
- Écrire le code d'un serveur MCP ; les channels ; les styles de sortie ; les
  commandes classiques ; les modifications d'interface ; les options de plugin ;
  les dépendances entre plugins.
- La déclaration d'un serveur de langage, prévue en v0.2.
- La dépendance à l'outil générique officiel ou à tout autre plugin tiers.
- Installer ou mettre à jour un plugin sur un appareil.
- Fusionner la PR de la marketplace.
- Les gestes destructifs sur GitHub : supprimer un dépôt, forcer un push,
  réécrire un historique publié, retirer un plugin de la marketplace.
- L'intégration continue sur GitHub.
- Modifier la configuration du poste : plugin-agent signale une dépendance
  machine manquante, il ne la déclare pas.
- Publier un rapport d'évaluation hors du poste.

## Décisions d'implémentation

- **Langue** : messages et documents en français. La langue des identifiants
  (noms des skills et des agents) se choisit au cadrage, plugin par plugin ;
  l'anglais est proposé par défaut.
- **Nom** : toujours `plugin-<domaine>`, en minuscules et tirets. Un refus nomme
  la règle enfreinte, ou l'endroit où le nom est déjà pris.
- **Versions** : correctif pour une consigne corrigée, mineure pour un composant
  ajouté, majeure pour un changement qui casse l'existant.
- **Accord** : chaque geste vers GitHub s'affiche avec sa commande exacte ; seul
  un « oui » explicite vaut accord, toute autre réponse ou l'absence de réponse
  vaut refus.
- **Résultat de chaque étape** : réussi, échoué, bloqué ou non exécuté, avec la
  commande lancée et son code de sortie. Rien n'est annoncé terminé sans la
  sortie des tests.
- **Statut des documents** : brouillon, revue, approuvé ; toute modification d'un
  document approuvé le repasse en revue.
- **Évaluations** : avant chaque lancement s'affichent le nombre de sessions, le
  coût estimé, le plafond et le compte qui paie. Plafond par défaut : 3 USD par
  passage, modifiable avant chaque lancement. Le rapport reste sur le poste.
- **Coût en contexte** : affiché par composant ; alerte au-delà de 1 000 tokens
  permanents par plugin.
- **Plugin hors modèle** : liste de ses écarts au modèle, aucune modification.
- **Ré-audit sans changement** : « rien à revérifier depuis la version X ».
- **Reprise** : un résumé de dix lignes au plus, puis attente de l'accord avant
  toute action.
- **Échec d'un geste GitHub** : il nomme le geste échoué, ce qui est déjà fait,
  et la commande qui reprend.

## Notes complémentaires

- **Dépendance machine** : le bac à sable des évaluations exige un outil
  d'isolation et un relais réseau, absents du poste le 2026-10-19 ; déclarés le
  même jour dans la configuration du poste, construction vérifiée, application
  en attente — elle fait monter le système d'une version majeure. D'ici là, les
  évaluations ne lancent aucune commande.
- **Fonction expérimentale** : les évaluations reposent sur une fonction de la
  plateforme marquée expérimentale, surveillée par le ré-audit.
- **Coût mesuré** le 2026-10-19 : de 0,13 à 0,23 USD par session évaluée, sur un
  cas exécuté avec et sans le plugin. Une suite valide, soit 12 sessions, est
  estimée entre 2 et 3 USD par skill — une estimation, pas une mesure.
- **Portée des hooks**, mesurée le 2026-10-19 : un hook d'un plugin installé pour
  le compte s'applique à toutes les sessions.
- **Catalogue local**, mesuré le 2026-10-19 : la copie locale de la marketplace
  retardait de plusieurs heures sur GitHub.
- **Amorçage** : la version 0.1.0 se construit à la main ; plugin-agent ne se
  publie lui-même qu'à partir de 0.1.1. La base de faits initiale reprend les
  mesures de la phase A de plugin-flutter.
- **Hypothèse** : l'exécution sans le plugin d'une évaluation charge peut-être
  les autres plugins installés, dont l'ancien flutter-forge, qui porte un skill
  du même nom. À vérifier en conservant les traces.
- **À venir** : déclaration d'un serveur de langage en v0.2 ; code d'un serveur
  MCP et channels rouverts au premier plugin qui a besoin d'un système sans
  ligne de commande, ou d'un channel.
