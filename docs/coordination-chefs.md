# Coordination des 4 sessions « Chef »

Quatre sessions Claude travaillent en même temps sur le dépôt `Kl1600/pop-fivem`.
Chaque session est un **Chef** qui répartit son travail entre ses sous-agents.
Ce document est la référence commune : à lire en entier avant de commencer.

## 1. Le projet

- Serveur FiveM **POP**, ESX Legacy 1.16.3, en **français**.
- Scripts = base d'origine du client (anciens `tab_*`, `vg_*`, `vanguard_*`), renommés `pop_*` et optimisés.
  - **Le fonctionnement et le style d'origine sont conservés.** On corrige, on optimise, on ne réécrit pas.
  - **Pas de rose ajouté**, nulle part : on garde les couleurs d'origine.
  - Pas de multi-framework ni de traductions pour l'instant.
- Auteur dans chaque `fxmanifest.lua` : `author 'KL'`. Pas de mention tab, Tabernac ou Vanguard dans les noms, descriptions ou commandes.
- Dépendances tierces dans `resources/[pop]/` (noms d'origine, ne pas renommer) :
  `utility_lib`, `checksystem`, `object_gizmo`, `ox_target` (version Vanguard), `chHyperSound`, `clm_ProgressBar`, `interact-sound`, `kq_lasers` (escrow), `pma_voice_challenge`, `ultra-voltlab`.

## 2. Serveur de test et déploiement

- Un push sur `main` qui touche `resources/[pop]/` déploie automatiquement par SFTP (`.github/workflows/deploy.yml`), en 1 à 2 minutes. Seuls les fichiers modifiés partent.
- Le client relance lui-même dans txAdmin (`restart <ressource>` ou Restart). On ne peut pas redémarrer le serveur nous-mêmes.
- `resources/[pop]/pop.cfg` (exécuté par `server.cfg`) contient les ACE et un `ensure [pop]`. **Seul le Chef 1 le modifie.**
- Outil `.github/workflows/server-tools.yml` (lancé par workflow_dispatch) :
  - `list` : arborescence des ressources ;
  - `logs` : diagnostic `pop_admin/diag_save.log` ;
  - `disable_esx` : range les `esx_*` inutiles.

  Les logs txAdmin ne sont pas accessibles : on demande au client de coller la console.
- ESX gardé : `es_extended`, `esx_lib`, `esx_skin`, `skinchanger`, `cron`, `esx_addonaccount`, `esx_addoninventory`, `esx_basicneeds`, `esx_datastore`, `esx_society`, `esx_status`. Les autres `esx_*` sont rangés hors du dossier `resources/`.
- Base de données MariaDB : les tables `tab_*` gardent leur nom (données existantes). **Ne pas les renommer.**

## 3. Règles de travail entre Chefs (anti-conflit)

1. **Les tâches viennent du client, au moment voulu**, transmises par le Chef 1 (sous forme de prompt) ou données directement. Sans tâche, un Chef attend. Le Chef 1 garde les fichiers communs.
2. **Avant de toucher un script**, lire `docs/en-cours.md`. Si un autre Chef y travaille déjà, ne pas y toucher : prévenir le client.
   Sinon, ajouter une ligne `pop_xxx : Chef N (tâche)` dans ce fichier, la pousser tout de suite, et la retirer à la fin.
3. Travailler sur sa branche (`chefN/...`), puis publier ainsi :
   ```
   git fetch origin && git rebase origin/main && git push origin HEAD:main
   ```
   Si le push est refusé, refaire `fetch` + `rebase`. Jamais de `push -f` sur `main`.
4. Avant chaque push sur `main` :
   - `luac5.4 -p` sur les `.lua` modifiés (sauf `utility_lib` et `ox_target`, écrits en CfxLua) ;
   - `node --check` sur les `.js` ;
   - pas de hash entre backticks dans le code, utiliser `GetHashKey('…')`.
5. Fichiers communs (`pop.cfg`, `.github/`, `CLAUDE.md`, ce document) : ne les modifier que si le client le demande, et prévenir les autres via `docs/en-cours.md`.
6. Commit en français. Terminer chaque message de commit par les lignes d'attribution de sa propre session.
7. Chaque Chef tient ses notes dans `docs/chef<N>.md` : ce qui est fait, ce qui reste, les bugs connus.

## 4. Sécurité (non négociable)

- **Backdoors trouvées dans la base d'origine du client** : du JS chiffré (XOR + eval, signature « miaus ») et des lignes cachées dans les `fxmanifest`.
  - Elles ont été retirées des scripts POP.
  - Avant d'ajouter un script venant de `Téléchargements/tab-main`, le scanner (`fromCharCode(a[i]^k)`, `eval(`, `new Function`, longues lignes dans le manifest, fichiers `.gitkeep.js` ou `._*.js`).
  - Scripts infectés à ne jamais reprendre tels quels : `lb-phoneprop`, `ventoso`, `colbss_keypad`, `utility_kitchen_*`, `ShopRobberies`.
- Jamais de mot de passe, de clé ou de token dans le dépôt ni dans le chat (les secrets sont dans GitHub et OuiPanel).
- Côté serveur, ne jamais faire confiance au client pour l'argent, les items, les prix ou le job : vérifier la source, la distance et les droits.

## 5. Leçons déjà apprises

- **Raccourcis FiveM** : une touche liée à une commande reste mémorisée sur le PC du joueur. Changer une touche ou renommer une commande peut laisser l'ancien raccourci actif.
  - Touches déjà prises : F3 laptop, F5 emotes, F6 admin, F7 noclip, F10 police, TAB inventaire (appui) et roue façon GTA (maintenu), I inventaire, P radio, X mains levées, 1 à 4 armes.
- La roue native de GTA est désactivée : `pop_inventory/html/wheel.js` la remplace (armes équipées + objets utilisables).
- Le client a refusé : un ped dans l'inventaire (toutes les variantes testées), le rose, une DA « GTA 6 » qui change les couleurs.
- **Cash** = objet `cash` de `pop_inventory`, pas le compte ESX `money`. **Banque** = compte ESX `bank`. Les boutiques doivent accepter le cash puis la banque.
- **Plus de pesos** sur le serveur.
- **Chèques** : un chèque encaissé arrive sur le compte bancaire (`bank`), pas en cash (décision du client).
- Le client aime : réponses courtes en français, pas de jargon, aperçus visuels avant le jeu (capture Playwright de la NUI).
- Le client teste vite : prévenir quand un déploiement est fini et quelle ressource relancer.

## 6. Bugs connus (à attribuer par le client)

- Les vêtements équipés dans l'inventaire ne s'appliquent pas sur le perso, qui reste torse nu en caleçon. Côté `pop_clothes`, `pop_charcreator`, `skinchanger` et `pop_inventory`.
- Flux de connexion : écran « Accéder au plateau de jeu », puis création de perso. À vérifier en jeu.
- Blocage ESX « Cleaning stale player entry » (diagnostic dans `pop_admin`), et touche Échap qui ne marche pas chez le client.
- `MapZones` et `vehicle_keys` absents : ce sont des dépendances de `pop_territories` et `pop_bikerental`.
- Mission `pop_grandtheftauto` à valider en jeu.

## Gabarit POP (restructuration)
- Mode d'emploi : `docs/gabarit-pop.md`. Exemple : `pop_bank`.
- `bridge/` et `shared/` sont des copies exactes de `templates/pop_base` : ne jamais les modifier dans un script. Un bug dedans → le noter dans `docs/en-cours.md` pour le Chef 1, qui corrige le modèle et recopie partout.
- Avec pop_inventory, `Bridge.GetMoney/AddMoney/RemoveMoney(src, 'cash')` utilise l'objet `cash` ; `'bank'` reste le compte ESX.

## Fichiers écrits par le serveur
Un script qui écrit un fichier sur le serveur (SaveResourceFile, io.open) doit l'ajouter aux `--exclude-glob` de `.github/workflows/deploy.yml` (demander au Chef 1), sinon chaque déploiement l'écrase ou le supprime. Protégés aujourd'hui : bans.json, staff_characters.json, disconnect_logs.json, diag_save.log (pop_admin), plants.json (pop_weed), overrides.json, doors.json (pop_doorlock).

## ESX et inventaire externe (22/11)
ESX est réglé avec `Config.CustomInventory = true` (pop_inventory). ESX 1.16 ne gère ce mode qu'avec ox_inventory : sa sauvegarde plantait sur `getInventory(true)` (inventory.lua:112), donc banque, job et position n'étaient plus enregistrés et le joueur restait bloqué (« stale player entry »). Corrigé sur le serveur par l'action `fix_esx_save` de Server tools (copie de l'original : `inventory.lua.pop-backup`). **À refaire après chaque mise à jour d'ESX.** Ne jamais appeler `xPlayer.getInventory` / `addInventoryItem` d'ESX : passer par pop_inventory ou le bridge.
