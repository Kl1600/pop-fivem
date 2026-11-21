# POP FiveM — instructions pour Claude

Dépôt des scripts FiveM POP, vendus dans l'esprit 0Resmon (~0.00 ms). Identité : **sobre, simple, compatible tous serveurs, toutes langues, gameplay inspiré GTA 6.**

À lire avant de travailler :
- `docs/direction-artistique.md` : gameplay et visuel
- `docs/methode.md` : équipe d'agents et standards techniques
- `.claude/agents/` : consignes de chaque agent

## Règles du dépôt
- Chaque script vit dans `resources/[pop]/pop_<nom>/` (préfixe `pop_`, minuscules, underscore).
- Un push sur `main` qui modifie `resources/[pop]/` est déployé automatiquement sur le serveur de test par SFTP (`.github/workflows/deploy.yml`). Ne pousse sur `main` que du code qui démarre sans erreur.
- Scripts = conversions des anciens scripts tab (voir docs/conversion.md) : même fonctionnement et même style, compatibles tous frameworks, 4 langues (fr, en, ar, de). Lint : `luacheck templates` 0/0 et `luac5.4 -p` sur les scripts.
- Jamais de clé de licence, mot de passe ou identifiant dans le dépôt : ils vont dans les secrets GitHub.

## Méthode pour un nouveau script
1. Agent `fivem-architecte` → `SPEC.md` dans le dossier du script.
2. En parallèle : `fivem-dev-serveur`, `fivem-dev-client`, `fivem-dev-nui`.
3. `fivem-auditeur` → corrections → fusion dans `main`.
Plusieurs scripts peuvent avancer en même temps (une équipe et un dossier par script).
