# Méthode de travail : équipe d'agents pour scripts FiveM

Inspiration : 0Resmon (scripts optimisés ~0.00 ms). Notre identité : **sobre, simple, compatible tous serveurs, toutes langues.**

## Rôles des agents (consignes complètes dans `agents/`)
1. **Architecte** : écrit `SPEC.md` (le contrat commun : fichiers, events, callbacks, messages NUI, SQL, config, locales).
2. **Dev Serveur** : `server/`, `bridge/server.lua`, `sql/`.
3. **Dev Client** : `client/`, `bridge/client.lua`.
4. **Dev NUI** : `web/`.
5. **Auditeur** : relit tout sans avoir écrit le code (sécurité, perf, compatibilité, langues, simplicité).

Ordre : Architecte → (Serveur + Client + NUI en parallèle) → Auditeur → corrections → livraison (.zip).
Plusieurs scripts peuvent avancer en même temps : une équipe complète par script, un dossier par script.

## Standards communs
- **Style** : sobre et simple. Fond uni, une couleur d'accent, police système, pas de dégradés/glassmorphism, animation courte unique. Peu de fonctionnalités, parfaitement faites.
- **Compatibilité** : ESX, QBCore, Qbox, standalone (détection auto). Aucune dépendance obligatoire sauf oxmysql si stockage. ox_lib non requis (callbacks internes). ox_target/qb-target sinon prompt natif. ox/qb/qs-inventory sinon inventaire du framework.
- **Langues** : en (défaut + repli), fr, es, de, it, pt, nl, pl, tr, ar. Aucun texte en dur. Support RTL pour l'arabe.
- **Performance** : pas de `Wait(0)` permanent, boucles adaptatives, nettoyage à l'arrêt. Cible < 0.02 ms au repos.
- **Sécurité** : le serveur vérifie tout (argent, items, distance, job, cooldown). Jamais de montant venant du client.
- **Structure type** :
  ```
  nom_script/
    fxmanifest.lua
    config.lua
    bridge/ (client.lua, server.lua)
    shared/ (callback.lua, locale.lua)
    client/
    server/
    locales/ (en.lua, fr.lua, ...)
    web/ (index.html, style.css, script.js)
    sql/install.sql
    README.md
  ```
