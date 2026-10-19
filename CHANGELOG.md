# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne corrigée, mineure pour un composant ajouté, majeure pour un changement qui casse l'existant.

## [0.1.0] — en cours

Version d'amorçage, construite à la main et jamais publiée : elle reçoit une étiquette locale à la clôture. La 0.1.1 sera la première publication.

### Ajouté

- Manifeste `plugin.json` et marketplace locale `.claude-plugin/marketplace.json`, au modèle de plugin-flutter.
- Suite déterministe `tests/run-all.sh` : manifestes, validation stricte par cible, coût en contexte permanent plafonné à 1 000 tokens ; sorties 0, 1 et 2.
