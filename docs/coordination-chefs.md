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

1. **Chacun ne modifie que ses propres dossiers** (voir la répartition, section 6). Si un autre dossier doit changer, on demande au Chef concerné, en passant par le client.
2. Travailler sur sa branche (`chef1/...`, `chef2/...`, `chef3/...`, `chef4/...`), puis publier ainsi :
   ```
   git fetch origin && git rebase origin/main && git push origin HEAD:main
   ```
   Si le push est refusé, refaire `fetch` + `rebase`. Jamais de `push -f` sur `main`.
3. Avant chaque push sur `main` :
   - `luac5.4 -p` sur les `.lua` modifiés (sauf `utility_lib` et `ox_target`, écrits en CfxLua) ;
   - `node --check` sur les `.js` ;
   - pas de hash entre backticks dans le code, utiliser `GetHashKey('…')`.
4. Fichiers partagés, modifiés **uniquement par le Chef 1** :
   - `pop.cfg`, `.github/`, `CLAUDE.md`, `docs/` (sauf les notes de chaque Chef) ;
   - `pop_inventory`, `pop_admin`, `pop_notify`.

   Les autres Chefs utilisent les exports existants (`pop_inventory:GiveItem/removeItem/getItemCount`, `pop_notify:ShowNotify`, `pop_admin:IsAdmin`).
5. Commit en français. Terminer chaque message de commit par les lignes d'attribution de sa propre session.
6. Chaque Chef tient ses notes dans `docs/chef<N>.md` : ce qui est fait, ce qui reste, les bugs connus.

## 4. Sécurité (non négociable)

- **Backdoors trouvées dans la base d'origine du client** : du JS chiffré (XOR + eval, signature « miaus ») et des lignes cachées dans les `fxmanifest`.
  - Elles ont été retirées des scripts POP.
  - Avant d'ajouter un script venant de `Téléchargements/tab-main`, le scanner (`fromCharCode(a[i]^k)`, `eval(`, `new Function`, longues lignes dans le manifest, fichiers `.gitkeep.js` ou `._*.js`).
  - Scripts infectés à ne jamais reprendre tels quels : `lb-phoneprop`, `ventoso`, `colbss_keypad`, `utility_kitchen_*`, `ShopRobberies`.
- Jamais de mot de passe, de clé ou de token dans le dépôt ni dans le chat (les secrets sont dans GitHub et OuiPanel).
- Côté serveur, ne jamais faire confiance au client pour l'argent, les items, les prix ou le job : vérifier la source, la distance et les droits.

## 5. Leçons déjà apprises

- **Raccourcis FiveM** : une touche liée à une commande reste mémorisée sur le PC du joueur. Changer une touche ou renommer une commande peut laisser l'ancien raccourci actif.
  - Touches déjà prises : F3 laptop, F5 emotes, F6 admin, F7 noclip, F10 police, TAB inventaire et roue, I inventaire, P radio, X mains levées, 1 à 4 armes.
- **Cash** = objet `cash` de `pop_inventory`, pas le compte ESX `money`. **Banque** = compte ESX `bank`. Les boutiques doivent accepter le cash puis la banque.
- **Plus de pesos** sur le serveur.
- Le client aime : réponses courtes en français, pas de jargon, aperçus visuels avant le jeu (capture Playwright de la NUI).
- Le client teste vite : prévenir quand un déploiement est fini et quelle ressource relancer.

## 6. Répartition

| Chef | Domaine | Dossiers (seuls à modifier) |
|---|---|---|
| **Chef 1** (session d'origine) | Coordination, inventaire, admin, serveur | `pop_inventory`, `pop_admin`, `pop_notify`, `pop.cfg`, `.github/`, `docs/`, `CLAUDE.md`, dépendances tierces |
| **Chef 2** | Illégal | `pop_dealing`, `pop_weed`, `pop_crew`, `pop_territories`, `pop_grandtheftauto`, `pop_doorlock`, `pop_bikerental`, `pop_livraison` |
| **Chef 3** | Métiers et entreprises | `pop_police`, `pop_police80`, `pop_management`, `pop_interim`, `pop_enterprisegarage`, `pop_bank`, `pop_bennys`, `pop_medexam`, `pop_computer`, `pop_duiengine`, `pop_boards`, `pop_affiche` |
| **Chef 4** | Perso, interface et véhicules | `pop_charcreator`, `pop_clothes`, `pop_hud`, `pop_speedometer`, `pop_loading`, `pop_chat`, `pop_emotes`, `pop_idcard`, `pop_passport`, `pop_voice_ui`, `pop_v3dui`, `pop_kilometrage`, `pop_vehiclepersistence` |

### Bugs connus à traiter

- **Chef 4** : les vêtements équipés dans l'inventaire ne s'appliquent pas sur le perso, qui reste torse nu en caleçon. Corriger côté `pop_clothes`, `pop_charcreator` et `skinchanger`. Si `pop_inventory` doit changer, demander au Chef 1.
- **Chef 4** : flux de connexion (écran « Accéder au plateau de jeu », puis création de perso) à vérifier en jeu.
- **Chef 1** : blocage ESX « Cleaning stale player entry » (diagnostic en place dans `pop_admin`) et touche Échap du client.
- **Chef 2** : `pop_dealing` (modes test coupés), `MapZones` et `vehicle_keys` absents (dépendances de territoires et de location de vélos), mission `pop_grandtheftauto` à valider en jeu.
- **Chef 3** : `pop_management` (tables, salaires), dispatch police (accès job police), banque.
