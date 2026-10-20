# Dépannage — plugin-plugin

Premier réflexe :

```bash
claude plugin details plugin-plugin   # chargé, avec ses composants ?
bash tests/run-all.sh                 # depuis un clone : ses fichiers sont-ils intacts ?
```

| Symptôme | Cause probable | Que faire |
| --- | --- | --- |
| Le plugin n'apparaît pas | Session lancée sans `--plugin-dir`, ou plugin non installé | `claude --plugin-dir .` depuis la racine du clone ; `claude plugin list` |
| `bash tests/run-all.sh` sort en 2 | `jq` ou `claude` absent du `PATH` | Installer l'outil manquant par la configuration du poste |
| Une étape dit « bloqué » | `gh` absent ou non authentifié, GitHub illisible, `jq` absent | `gh auth status` ; l'étape n'est jamais comptée réussie |
| `gesture-guard` refuse un `git push` ou une commande `gh` | Le geste n'est pas l'étape annoncée, ou l'accord manque | Relancer l'étape par `pp.sh publish`, puis répondre « oui » au message suivant, rien d'autre |
| « oui » tapé, le geste refusé quand même | L'annonce a expiré (trente minutes) ou un autre message l'a retirée | Relancer `pp.sh publish` : l'étape est annoncée de nouveau |
| « hook error … blocking because onFailure is "block" » | Le script de `gesture-guard` n'a pas pu s'exécuter : fichier absent, `bash` introuvable, délai dépassé | `bash tests/run-all.sh` signale un script manquant (`test_paths`) ; vérifier que `bash` est sur le `PATH` |
| Un document approuvé est repassé en REVUE | Il a été modifié après son approbation | Le relire, puis l'approuver de nouveau par `frame` |
| `create` refuse le dossier | Il contient autre chose que le cadrage approuvé, ou le cadrage n'est pas approuvé | `pp.sh status docs/PRD.md` et `docs/ARCHITECTURE.md` ; vider le dossier de ce qui n'est pas le cadrage |
| `add` refuse le plugin | Le plugin a des écarts au modèle | `/plugin-plugin:check` les liste ; les corriger d'abord |
| La répétition refuse de publier | Arbre non enregistré, validation ou suite rouge, autre branche que `main`, `origin` étranger, rien depuis la dernière étiquette et des descriptions alignées | La raison est dans le message ; corriger, puis relancer |
| « le README ne nomme pas : … » ou « pas de ligne Version » | Un composant ajouté sans le décrire, ou un README sans `Version **X.Y.Z**` | Le décrire dans le README, commiter, relancer la répétition |
| « la branche align-… est déjà sur GitHub » | La PR d'un alignement précédent attend sa fusion, ou une branche est restée | Fusionner la PR nommée ; sans PR ouverte, retirer la branche soi-même |
| Une évaluation est « bloquée » | Un cas a besoin de Bash et le bac à sable n'est pas appliqué | Appliquer bwrap par la configuration du poste ; le cas n'est jamais compté réussi |
| Le point de reprise est rappelé en fin de tour | Il est plus ancien que le dernier commit ou qu'un fichier modifié | Le mettre à jour par l'étape en cours ; le rappel ne revient pas tant que rien ne change |
