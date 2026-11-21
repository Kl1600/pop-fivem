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

## Fondation : `templates/pop_base`
Chaque script part d'une copie de `templates/pop_base/` (hors de `resources/`, jamais déployé) :
`cp -r templates/pop_base "resources/[pop]/pop_<nom>"`, puis renommer dans `fxmanifest.lua` (voir `templates/pop_base/README.md`).
- `bridge/`, `shared/`, `web/kit/` et les clés communes de `locales/` sont copiés **tels quels** : on ne les modifie pas dans un script.
  Un bug ou un manque se corrige dans `templates/pop_base`, puis on recopie le dossier dans les scripts concernés.
- Le script n'ajoute que son code : `client/`, `server/`, `web/script.js` (+ `style.css`), ses clés de config et ses textes.
- API à utiliser partout : `Bridge.*` (framework, argent, items, job, target, notifications, progression), `Callback.*` (sans ox_lib), `L()` (traductions), `Pop.*` côté NUI.
- Vérification : `luacheck templates resources` (config `.luacheckrc`) et `node --check` sur les .js.

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
    web/ (index.html, script.js, style.css, kit/ pop.css + pop.js)
    sql/install.sql
    README.md
  ```
