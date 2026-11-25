# POP FiveM — instructions pour Claude

Dépôt des scripts FiveM POP, vendus dans l'esprit 0Resmon (~0.00 ms). Identité : **sobre, simple, compatible tous serveurs, toutes langues, gameplay inspiré GTA 6.**

À lire avant de travailler :
- `docs/direction-artistique.md` : gameplay et visuel
- `docs/methode.md` : équipe d'agents et standards techniques
- `.claude/agents/` : consignes de chaque agent

## Règles du dépôt
- Chaque script vit dans `resources/[pop]/pop_<nom>/` (préfixe `pop_`, minuscules, underscore).
- Plus de déploiement automatique (quota gratuit GitHub) : on pousse sur `main`, puis le client déploie lui-même (Actions > Deploy to test server > Run workflow) et teste. Lint en local avant chaque push (`luacheck`, `luac5.4 -p`, `node --check`). Ne pousse sur `main` que du code qui démarre sans erreur.
- Scripts = base d'origine du client (anciens tab_*/vg_*/vanguard_*) renommée en pop_*, optimisée, couleurs d'origine conservées (pas de rose ajouté). Même fonctionnement et même style. Depuis le 25/11/2026 : 5 langues (fr, en, es, de, ar) et compatibles tous serveurs (ESX, QBCore, Qbox, standalone) : suivre `docs/standard-international.md`. utility_lib, checksystem, object_gizmo = dépendances tierces (utility_lib en CfxLua, exclu de luac). Lint : `luacheck templates` 0/0 et `luac5.4 -p` sur les scripts.
- Jamais de clé de licence, mot de passe ou identifiant dans le dépôt : ils vont dans les secrets GitHub.

## Méthode pour un nouveau script
1. Agent `fivem-architecte` → `SPEC.md` dans le dossier du script.
2. En parallèle : `fivem-dev-serveur`, `fivem-dev-client`, `fivem-dev-nui`.
3. `fivem-auditeur` → corrections → fusion dans `main`.
Plusieurs scripts peuvent avancer en même temps (une équipe et un dossier par script).
