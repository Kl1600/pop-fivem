# Audit complet de la base POP (21/11/2026)

Audit en lecture seule de tous les scripts de `resources/[pop]/`, sauf la police (`pop_police`, `pop_police80`), mise de côté par le client.
Chaque ligne indique la gravité, l'emplacement, le problème et la correction proposée.

**À savoir avant de corriger :**
- `ox_target` **est présent** sur le serveur (dans `resources/[pop]/`). Les remarques « ox_target absent » des auditeurs sont fausses et ne figurent pas ici.
- Ressources **absentes** du serveur : `MapZones`, `CircuitBreakerMinigame_lua`, `cr-3dnui`, `esx_notify`, `esx_ambulancejob`, `esx_identity`, `esx_policejob`, `ls_bolt_minigame`, `lb-phone`, `plt_*`, `uz_AutoShot`, `mt_printers`, `qb-*`, `ox_inventory`.
- Le cash est l'objet `cash` de `pop_inventory`, la banque est le compte ESX `bank`. Plus de pesos.

---

## Lot 1 — Chef 1 : admin, management, intérim, DUI, ox_target

**Haute**
- `pop_management/client.lua:1292-1315` — `LocalPlayer.state.laptopOpen=true` est posé avant des `return` anticipés et n'est jamais remis à false. **Cause probable du bug Échap.** → Poser l'état après les contrôles, ou le remettre à false à chaque sortie.
- `pop_admin/client/main.lua:59-93` + `players.lua:162,223,245` — la boucle qui bloque Échap reste active quand le Lua croit le menu ouvert alors que la NUI l'a caché (mode spec). → Ne bloquer que si le menu est réellement affiché.
- `pop_management/server.lua:857-858, 909, 652` — dépôt, retrait et prime utilisent le compte ESX `money` au lieu de l'objet `cash`. → Exports `pop_inventory`.
- `pop_management/server.lua:1026` — `UPDATE users SET bank = bank + ?` : cette colonne n'existe pas. La société est débitée, le joueur ne reçoit rien. → Mettre à jour le JSON `accounts`, ou refuser si le joueur est hors ligne.
- `pop_management/server.lua:1352-1389` — `vehicleProps` et `plate` viennent du client : n'importe quel modèle peut être enregistré. → Comparer au modèle commandé, plaque générée côté serveur.
- `pop_interim/server.lua:51` — `xPlayer.setJob2` n'existe pas dans ESX 1.16 : erreur à la validation de GoPostal. → `setJob`, ou test de la fonction.
- `pop_admin/server/main.lua` (`setgroup`) — aucune hiérarchie : un mod peut se mettre superadmin. → Interdire d'attribuer un groupe supérieur ou égal au sien.
- `ox_target/client/main.lua:489-495` — `mechNotify` appelle `exports['notification']` (absent) sans pcall, ce qui casse la checklist mécano. → `pop_notify`, dans un pcall.

**Moyenne**
- `pop_admin/server/main.lua` (test de sauvegarde ESX, 60 s après la connexion) — réécrit la ligne `users`. → Passer en lecture seule, ou retirer une fois le diagnostic terminé.
- `pop_admin/client/players.lua:200-210, 118` — `specTarget` et `NetworkSetInSpectatorMode` sont envoyés à chaque frame. → Seulement au changement.
- `pop_admin/server/main.lua` (`jobDelete`) + `pop_management` — requêtes sur `job2`, qui n'existe pas. → Retirer.
- `persistent_vehicles` est utilisée par `pop_admin` et `pop_management` : vérifier qu'elle est bien créée (`pop_vehiclepersistence`).
- `pop_management/server.lua:1228-1251, 2015-2156` — n'importe quel employé peut vider le compte société en achats. → Patron uniquement + délai.
- `pop_management/server.lua:2464-2470` — la clé `key_d8` est cherchée dans l'inventaire ESX au lieu de `pop_inventory`. → Export de recherche `pop_inventory`.
- `pop_management/client.lua:1966` — impression vers `mt_printers` (absent) sans message. → Tester et notifier.
- `pop_management/client.lua:303, 1648-1657` — chaque client crée les laptops en objets réseau, d'où des doublons. → Objets locaux.
- `pop_management/server.lua` (`cr-laptop:getSocietyData`) — `TriggerEvent` côté serveur sans `source`. → `TriggerClientEvent`.
- `pop_interim/client.lua:187-391` — `selectJob` et `close` restent possibles pendant la préparation de l'aperçu (peds orphelins, blocage). → Bloquer pendant la transition.
- `ox_target/client/main.lua:631, 718, 782` — événements `vg_engine:*` et `tab_hud:*` restés à l'ancien nom. → Vérifier qui les émet et renommer.

**Basse**
- Commandes de dev ouvertes : `pop_interim /devpreview`.
- `pop_management` : `SELECT *` toutes les 5 s (30 s suffisent), logo sur une URL Discord expirée, `getPlayersForSuggestion` sans contrôle de job, `coords.x` non numérique qui plante.
- `pop_duiengine` : un nouveau TXD à chaque ouverture, `AttachPanelToBone` sous une clé numérique.
- `pop_admin` : `qty` du give non borné, code mort (`specExit`, `minimized`).
- `clm_ProgressBar/fxmanifest.lua:11` — `example.lua` chargé (`/example_add` ouvert à tous). → Retirer.

---

## Lot 2 — Chef 2 : inventaire, tenue, création de perso, connexion

**Tenue en caleçon (bug signalé par le client) : causes probables**
1. `pop_charcreator/client/main.lua:357-391` + `pop_inventory/client.lua:1355-1370` — le skin sauvegardé est « nu » et ESX le recharge au spawn. L'inventaire ne réapplique la tenue qu'une fois, 4 s après. → Réappliquer `currentEquipment` sur `skinchanger:modelLoaded`, `esx:onPlayerSpawn` et `playerSpawned`.
2. `pop_inventory/server/sv_utils.lua:44` + `client.lua:1364-1381` — si ESX n'est pas encore chargé, l'inventaire se charge sous la `license:`, donc vide. → Pas de repli sur la license en ESX ; `playerReady` seulement après `esx:playerLoaded`.
3. `pop_inventory/client.lua:1132` — `drawable`/`texture` venant de `pop_clothes` peuvent être des chaînes. → `tonumber()`.
4. `pop_inventory/config.lua:2323` — t-shirt homme sur le composant 38 (inexistant), t-shirt femme qui met torse nu, composant 3 toujours écrasé (`client.lua:1213`).

**Haute**
- `pop_inventory/server/sv_sync.lua:9-17` — `playerReady` recharge l'inventaire depuis la base à volonté, d'où une duplication possible. → Ignorer si l'inventaire est déjà chargé.
- `pop_inventory/server/sv_sync.lua:239-283` + `sv_player_items.lua:36` — deux joueurs dans le même coffre se réécrivent mutuellement (duplication ou perte). → Un seul ouvreur par coffre.
- `pop_inventory/server/sv_remote_containers.lua:828-873` — `openStaticChest` accepte des id hors config, sans distance (pillage à distance). → Liste blanche + distance.
- `pop_inventory/items_server.lua:597-627` — brancard : aucune vérification (on peut y forcer n'importe qui). → Distance + état mort/menotté.
- `pop_inventory/server/sv_exports.lua:165-173` — rien n'est sauvegardé à l'arrêt de la ressource (jusqu'à 60 s perdues). → `saveStore` de tous les inventaires.
- `pop_inventory/remote_container.lua:321` — `startMovingBox` est utilisé avant sa déclaration (déplacer un carton plante). → Le déclarer avant.
- `pop_charcreator` / `pop_idcard` / `pop_passport` — `esx:showNotification` passe par `esx_notify` (absent) : aucune notification. → `pop_notify`, ou faire fournir `esx_notify` par `pop_notify`.
- `pop_charcreator/client/main.lua:456-461` — le créateur ne s'ouvre qu'à la toute première connexion : un joueur qui quitte pendant la création n'a plus jamais de créateur. → Décision serveur (`firstname` vide).
- `pop_loading/client.lua:58-99` — le clic « Accéder au plateau » pendant la transition casse la caméra du créateur et retire la pose et l'invincibilité. → Déclencher à la fin de la transition, ou sauter si le créateur est ouvert.
- `pop_clothes/fxmanifest.lua:22` — export `openAdmin` déclaré mais jamais défini (`pop_inventory/client.lua:576` plante). → Le définir ou le retirer.

**Moyenne**
- `pop_inventory/server/sv_utils.lua:25-51` — 4 `print` à chaque `getIdentifier` (console inondée).
- `pop_inventory/server/sv_inventory_state.lua:967-970` — `pickupToSlot` sur une case occupée perd l'objet.
- `pop_inventory/server/sv_remote_containers.lua:810` — stockage perso de 30 cases ouvrable de partout.
- `pop_inventory/server/sv_actions.lua:274-289` — `rename` sans contrôle (HTML injecté).
- `pop_inventory/server/sv_player_items.lua:940-1066` — `shopBuy` sans distance au magasin, argent perdu si l'inventaire est plein.
- `pop_inventory/lib_shim.lua:64` — `alertDialog` ne renvoie rien : paiement TPE toujours refusé.
- `pop_inventory/server/sv_admin.lua:502` — requête `job2` (colonne inexistante).
- `pop_inventory/server/sv_database.lua:188-212` — un grade 0 et un grade 4 ajoutés à tous les jobs à chaque démarrage.
- `pop_inventory` — trois threads de sauvegarde et `requestState` toutes les secondes inventaire ouvert. → Un seul thread, sur les inventaires modifiés.
- `checksystem/server/main.lua:54-66` — réessai infini si la base est en erreur.
- `pop_inventory/config.lua:20-27` — licences admin écrites dans le dépôt. → ACE.
- `pop_charcreator/server/main.lua:155-162` + `pop_clothes/server.lua:28` — instance privée et mode créateur accessibles à tous (tatouages gratuits).
- `pop_clothes/server.lua:79-135` — achat sans distance, valeurs non typées, Decals à 0 $, tatouages hors liste.
- `pop_clothes/client.lua:415-474` — le barbier perd la coupe payée (natives au lieu de `skinchanger:change`).
- `pop_clothes/index.html:408` — vignettes chargées depuis `uz_AutoShot` (absent) : des centaines de 404.
- `pop_clothes/server.lua:43-53` — taxe via `esx_addonaccount` sans repli.
- `pop_charcreator/client/main.lua:103-134` — les commandes de caméra ne marchent plus après être passé par les vêtements.

**Basse**
- `pop_inventory` : `/testshop` actif (`Debug.Commands`), restes de pesos, ped iFruit dupliqué à chaque restart, recette « safe » qui compte mal, double `playerDropped`, exports en double.
- `pop_clothes/config.lua:30, 39` — deux magasins aux coordonnées fausses.
- `pop_charcreator` : `imports.lua` chargé deux fois, modèle de ped non contrôlé côté serveur, taille du skin non limitée.
- `pop_idcard` / `pop_passport` — boucle Échap inutile, photo du lecteur au lieu du titulaire, commandes console qui plantent.

---

## Lot 3 — Chef 3 : illégal et mission vol de voitures

**Aujourd'hui, personne ne peut terminer la mission `pop_grandtheftauto`.**

**Haute**
- `pma_voice_challenge/client.lua:85` + `pop_voice_ui/client.lua:19` — `MumbleIsPlayerTalking(...) == 1` est toujours faux, donc le test de persuasion de Thornton échoue toujours. → Retirer `== 1`.
- `pop_grandtheftauto/client/crack.lua:433,455` — `CircuitBreakerMinigame_lua` (absent) : l'étape PCB est impossible. → `ultra-voltlab`, ou un repli.
- `pop_grandtheftauto/client/interact.lua:101` — parler à Svetlana ne lance pas le casse (seul `/startheist`, réservé aux admins, le fait). → Svetlana déclenche le départ.
- `pop_grandtheftauto/server/alert.lua:247-265` — les emplacements de livraison ne sont jamais libérés : plus de camion dès la 3e partie.
- `pop_grandtheftauto/server/alert.lua:125-135,167` — mission jamais réinitialisée (2e casse impossible), et `heistStart` est envoyé à tout le serveur.
- `pop_grandtheftauto/server/alert.lua:145-150` + `client/client.lua:129-133` — le relais « event » déclenche n'importe quel événement chez tout le monde. → Liste blanche + contrôle du propriétaire.
- `pop_grandtheftauto/client/client.lua:9,18` — `/nightv` (touche N) saute l'étape Thornton.
- `pop_grandtheftauto/client/utils.lua:82` — `SafeCreateLaser` s'appelle lui-même (erreur introduite au renommage) : les lasers ne sont jamais créés. → Appeler `exports['kq_lasers']:CreateLaser`.

**Moyenne**
- `pop_grandtheftauto` :
  - modèles douteux : `turismoo` (→ `turismo3`), `schweizer2`, `ig_valentina` et le dictionnaire d'anim `amnilka@…` (boucles de chargement infinies) ;
  - marqueur des clés en `Wait(0)` partout sur la carte ;
  - PCB retiré avant la réussite ;
  - suppression de n'importe quel véhicule derrière le camion ;
  - aucune récompense ;
  - timer de 30 s affiché « 04:00 » ;
  - commandes `blc`, `removeblc` et `e mechanic4` inexistantes ;
  - alertes police spammables.
- `pop_territories` — `MapZones` absent : le système est inerte. → Zones internes (centre/rayon). Prise de contrôle trop rapide (+10 % par vente, sans cooldown).
- `pop_weed/server.lua:192` — l'eau ne compte pas, `HarvestAmount` est ignoré.
- `pop_dealing/server.lua:86,186,335` — PNJ créés chez tous les joueurs sur toute la carte, alerte envoyée aux civils au lieu de la police.
- `pop_crew/server.lua:163-164` — tag et label non filtrés (HTML injecté).
- `pop_bikerental/config.lua:30` — point de spawn occupé par le véhicule exposé (« Zone bloquée » en permanence).
- `pma_voice_challenge` + `pop_voice_ui` — `/voice-ui` enregistré deux fois, focus sans sortie. `pop_voice_ui/thornton.lua` : modèle inexistant.

**Basse**
- `ultra-voltlab` — état non réinitialisé entre deux parties.
- Commandes de dev ouvertes : `/jouer`, `/dv100`, `/previewlivraison`, `/voltlab`.
- `pop_livraison` — modèles douteux, chargements sans délai maximum.
- `pop_weed` — pas de limite de plantes par joueur, toutes affichées partout.

---

## Lot 4 — Chef 4 : véhicules, banque et divers

**Haute**
- `pop_bennys/client.lua:284-288` + `server.lua:24-26` — coût calculé par la NUI : modifications gratuites. → Recalculer côté serveur.
- `pop_bennys/client.lua:388` — `/bennys` ouvert à tous. → Réserver aux admins.
- `pop_bennys/client.lua:357-362` — plaque modifiable librement (copie de la plaque d'un autre). → Retirer ou valider côté serveur.
- `pop_enterprisegarage/server.lua:155-179` — rangement de n'importe quelle plaque sans contrôle : duplication. → Vérifier `state='out'` et la présence du véhicule.
- `pop_enterprisegarage/server.lua:176` — le véhicule rangé réapparaît (la copie en mémoire de `pop_vehiclepersistence` n'est pas oubliée). → Export `Forget(plate)`.
- `pop_vehiclepersistence/server.lua:72-82, 393-435` — `sanitize` accepte le modèle et les mods du client. → Comparer à l'entité côté serveur.
- `pop_emotes/client/core/utils.lua:248,254,353,359` — objet réseau créé à chaque emote et jamais supprimé (fuite). → Supprimer ces lignes.
- `pop_emotes/fxmanifest.lua:41-50` — aucun des 10 `stream/*.ytyp` n'est à ce chemin (props custom invisibles). → Corriger les chemins.
- `pop_boards/server/main.lua:27-114, 117` — sauvegarde sans droits, sans distance ni limite, et `requestData` spammable. → Droits, distance, quota, cooldown.

**Moyenne**
- `pop_vehiclepersistence` :
  - la connexion compte comme une interaction (`touch=true`) ;
  - tous les véhicules du joueur apparaissent partout ;
  - doublon possible à la déconnexion ;
  - `vehicleSpawned`/`despawnFailed` sans contrôle ;
  - décor `fFuel` lu sans être déclaré.
- `pop_enterprisegarage` — véhicule détruit bloqué en `out` pour toujours, clés jamais reprises au rangement.
- `pop_bank/server/main.lua:153-189` — un chèque est encaissé en `cash` dans un coffre au lieu du compte `bank`. → À valider avec le client.
- `pop_kilometrage/server.lua:72-73` — première valeur acceptée sans vérification en base.
- `pop_v3dui/client.lua:170-192` — `SendNUIMessage` presque à chaque frame. → Environ 30 ms.
- `pop_boards` / `pop_affiche` :
  - panneaux DUI jamais détruits en s'éloignant (mémoire GPU) ;
  - champs client rediffusés tels quels ;
  - `data.pos` nil qui tue le thread.
- `pop_emotes/server/main.lua:41-57` — emote partagée relayée telle quelle (props arbitraires). → Ne transmettre que le nom.
- `pop_medexam/client.lua:147` — `SendNUIMessage` à chaque frame pendant l'examen.
- `pop_hud/html/script.js:72` — le HUD réapparaît quand il devrait être masqué (sous l'écran de connexion). `esx:loadingScreenOff` n'est écouté par personne.
- `pop_notify/html/script.js:78-131` — `innerHTML` sans échappement.

**Basse**
- `pop_hud` — vie mal calculée pour un ped femme, config pma-voice relancée toutes les 5 s, callback `closeChecklist` inexistant.
- `pop_doorlock` — `getItemCount` sans pcall, `esx_notify` si l'option est activée.
- `pop_emotes` — le deuxième prop utilise les paramètres du premier ; n'importe qui peut arrêter l'emote d'un autre.
- `pop_chat` — pas de cooldown sur /me, nom Steam au lieu du nom RP.
- `pop_medexam/config.lua:8` — job `youtool` suspect.
- `pop_kilometrage` — `requestMileage` sans limite.
- `pop_enterprisegarage` — collisions de plaques, notifications non harmonisées.
- `pop_bennys` / `pop_v3dui` / `pop_speedometer` — manifests sans `lua54` ou en `adamant`.
- `ox_target/server` — pas de contrôle de distance (comportement d'origine).
