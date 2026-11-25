# pop_ems : cahier des charges (SPEC)

Contrat commun des devs **Serveur**, **Client** et **NUI**. Les noms (events, callbacks, clés, messages) sont à reprendre **à l'identique**.
Références : `docs/standard-international.md`, `docs/gabarit-pop.md`, `templates/pop_base` (README = API Bridge/Callback/kit), `resources/[pop]/pop_death`, `pop_medexam`, `pop_inventory`, `pop_notify`.

Règles transverses :
- ~0,00 ms au repos. **Aucune boucle `Wait(0)` permanente.** Les threads ne tournent que si quelque chose est en cours (appel, saignement, transport, progression).
- **Le serveur est seul juge** : job, service, distance, objets, argent, durée des actions. Le client ne fait qu'afficher et demander.
- Aucun appel direct à ESX/QBCore/Qbox/ox_* hors `bridge/` et du bloc « framework direct » de `server/common.lua` (argent de société, service QB).
- Aucun texte en dur (Lua, HTML, JS) : `L('cle')` côté Lua, `data-locale="cle"` / `Pop.t('cle')` côté NUI.
- `bridge/` et `shared/` = copies exactes de `templates/pop_base` (jamais modifiés ici). `web/kit/` = copie exacte du kit.
- Dépendance obligatoire : **aucune** (pas de base de données). `pop_death`, `pop_medexam`, `pop_inventory`, `pop_notify` sont facultatifs (`GetResourceState(...) == 'started'`).

---

## 1. Description et fonctionnalités

Métier ambulancier court et sobre, inspiré GTA 6 dans le style (plusieurs petites étapes, le bon outil pour la bonne situation).

1. **Service et vestiaire** : zone vestiaire dans chaque hôpital. « Prendre le service » met la tenue EMS (composants de vêtements du `config.lua`), « Finir le service » remet la tenue civile mémorisée. Réservé au job `Config.Job.name` (ou ACE `pop.ems` en standalone).
2. **Garage** : zone garage (en service uniquement). Sortir un véhicule de `Config.Vehicles` (créé **par le serveur**), un seul véhicule par secouriste ; « Ranger le véhicule » le supprime.
3. **Appels** : `pop_death` déclenche `pop_death:emsCalled` (event serveur local). Si au moins un EMS est en service, un appel est créé et affiché à tous les EMS en service (petite carte NUI à droite + blip). Touche `Config.AcceptCallKey` (Y) = prendre le dernier appel en attente : GPS vers le blessé, statut « Pris par <nom> » visible par les autres, le blessé est prévenu. L'appel se ferme quand le secouriste arrive (< `Config.Calls.arrive` m), quand le blessé n'est plus à terre, se déconnecte, ou après `Config.Calls.expire` s.
4. **Soins sur un joueur** (cible joueur via `Bridge.Target.AddModel`, en service uniquement) : option « Soigner » qui ouvre un petit menu NUI :
   - **Diagnostic** : conscient/inconscient, santé en %, saignement, jambe touchée, et zones de `pop_medexam` si lancé.
   - **Bandage** (objet `bandage`) : rapide, arrête le saignement, rend `Config.BandageHealth` PV.
   - **Kit de soins** (objet `kitsoins`) : lent, soin complet (santé max, blessures effacées). Patient conscient seulement.
   - **Réanimer** (objet `defib`, non consommé) : patient inconscient et **ne saignant plus** (si blessures activées) → oblige l'étape bandage d'abord.
   - **Mettre dans l'ambulance** : patient inconscient, ambulance de service à moins de `Config.Distances.vehicle` m.
   Chaque action = `begin` serveur → barre de progression (`Bridge.Progress`) → `finish` serveur (durée contrôlée par le serveur).
5. **Transport à l'hôpital** : patient allongé à l'arrière de l'ambulance (attaché au véhicule). Option sur l'ambulance « Sortir le patient ». Zone « Admettre le patient » à l'entrée de chaque hôpital : si l'ambulance du secouriste avec son patient est à moins de `Config.Distances.admit` m, le patient est réanimé, soigné et placé au lit (`bed`) de l'hôpital.
6. **Blessures légères** (optionnel, `Config.Injuries.enabled`) : au-delà de `Config.Injuries.bleedDamage` dégâts d'un coup → saignement (perte de `bleedLoss` PV toutes les `interval` s) ; coup à une jambe → démarche blessée (clipset). Effacées par le kit, la réanimation, l'admission, ou quand la santé revient au max (réapparition pop_death, autre script).
7. **Facture** : chaque soin réussi a un prix (`Config.Prices`, 0 = gratuit). Débit du patient en banque, sinon en liquide (`Bridge.RemoveMoney`). Crédit à la société `Config.Job.name` si un système de société est trouvé, sinon sur le compte banque du secouriste. Pas de facture en standalone.
8. **Sans EMS en service** : aucun appel créé, le blessé reçoit `no_medic_available` ; **pop_death reste inchangé** (réapparition à l'hôpital au bout du délai). pop_ems ne modifie jamais pop_death.

Hors périmètre (volontairement) : brancard/civière physique (déjà géré par l'objet `brancard` de pop_inventory), menus de boss, salaires, base de données, soins de PNJ.

---

## 2. Arborescence exacte

```
resources/[pop]/pop_ems/
  fxmanifest.lua
  config.lua
  README.md                 en + fr (installation en 3 étapes, config, exports, events)
  SPEC.md
  bridge/client.lua         copie exacte templates/pop_base
  bridge/server.lua         copie exacte
  shared/locale.lua         copie exacte
  shared/callback.lua       copie exacte
  locales/en.lua            langue de secours (toutes les clés)
  locales/fr.lua
  locales/es.lua
  locales/de.lua
  locales/ar.lua            Locales.ar._rtl = true
  client/main.lua           état local (onDuty), vestiaire/tenue, garage, blips hôpitaux, exports client, nettoyage
  client/calls.lua          réception de la liste d'appels, blips d'appel, GPS, touche d'acceptation, NUI 'calls'
  client/care.lua           target joueur, menu NUI, enchaînement begin → Progress → finish, réception treated/revived, carte diagnostic
  client/transport.lua      target ambulance (sortir le patient), zone d'admission, attach/detach/admitted côté patient
  client/injuries.lua       blessures légères (saignement, boiterie), statebag popEmsInjury
  server/common.lua         table Ems = {}, état partagé, helpers (isMedic, onDuty, isDead, cooldown, bill, société « framework direct »)
  server/duty.lua           callbacks setDuty, spawnVehicle, returnVehicle ; nettoyage au départ
  server/calls.lua          handler pop_death:emsCalled, acceptCall, diffusion, boucle de fermeture
  server/care.lua           callbacks begin / finish (diagnose, bandage, kit, revive, load)
  server/transport.lua      unloadPatient, admit, suivi des patients transportés
  web/index.html
  web/style.css
  web/script.js
  web/kit/pop.css           copie exacte du kit
  web/kit/pop.js            copie exacte du kit
  install/items_ox.lua      bandage, kitsoins, defib pour ox_inventory
  install/items_qb.lua      idem pour qb-core/shared/items.lua
  install/items_esx.sql     INSERT INTO items (bandage, kitsoins, defib)
  install/items_pop.lua     déclaration de `bandage` à coller dans pop_inventory/config/items_2.lua (kitsoins existe dans items_2.lua, defib dans items_1.lua)
  install/images/bandage.webp, kitsoins.webp, defib.webp
```

Pas de `install/sql.sql` : le script ne stocke rien.

### fxmanifest.lua
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'pop_ems'
author 'KL'
description 'POP EMS - ambulance job: duty, calls, care, transport'
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/script.js', 'web/kit/*.css', 'web/kit/*.js' }
shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/main.lua', 'client/injuries.lua', 'client/calls.lua', 'client/care.lua', 'client/transport.lua' }
server_scripts { 'bridge/server.lua', 'server/common.lua', 'server/duty.lua', 'server/calls.lua', 'server/care.lua', 'server/transport.lua' }
escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
version '1.0.0'
```
Pas de `dependencies`. Pas de `@oxmysql`.

---

## 3. Events

Toutes les actions client → serveur passent par des **callbacks** (section 4) : **aucun `RegisterNetEvent` serveur** dans pop_ems (rien à usurper).

### 3.1 Serveur → client (`TriggerClientEvent`, `RegisterNetEvent` côté client)

| Event | Destinataire | Paramètres | Effet client |
|---|---|---|---|
| `pop_ems:client:calls` | chaque EMS en service | `list` (table), `newId` (int\|nil) | Remplace la liste locale, met à jour blips + NUI `calls`. Si `newId` : `Bridge.Notify(L('call_new', rue), 'info')` + son court natif. |
| `pop_ems:client:dutyOff` | un EMS | aucun | Fin de service forcée (job perdu) : tenue civile, retire targets/blips/NUI. |
| `pop_ems:client:treated` | patient | `kind` : `'bandage'` \| `'kit'` | bandage : saignement à false, +`Config.BandageHealth` PV (si vivant). kit : santé max, blessures effacées. |
| `pop_ems:client:revived` | patient | `health` (int) | Détache si attaché, `NetworkResurrectLocalPlayer` sur place (heading actuel), `SetEntityHealth(health)`, `ClearPedBloodDamage`, blessures effacées. L'écran pop_death se ferme seul (sa boucle 500 ms détecte le retour à la vie). |
| `pop_ems:client:attach` | patient | `vehicleNetId` (int) | Attend l'entité (timeout 3 s), `AttachEntityToEntity(ped, veh, 0, Config.PatientOffset, 0, 0, 180.0, ...)`. |
| `pop_ems:client:detach` | patient | aucun | `DetachEntity`, place le ped à `GetOffsetFromEntityInWorldCoords(veh, 0.0, -4.0, 0.0)` si le véhicule existe. |
| `pop_ems:client:admitted` | patient | `bed` (vector4) | Fondu noir, détache, `NetworkResurrectLocalPlayer(bed)`, santé max, blessures effacées, fondu retour. |

Format d'un élément de `list` (`pop_ems:client:calls`), personnalisé par destinataire :
```lua
{ id = 12, coords = vector3(x, y, z), time = 1764000000, status = 'pending' | 'taken', medic = 'Nom Prénom' | nil, mine = true | false }
```
Liste triée du plus récent au plus ancien. Liste vide = plus d'appel.

### 3.2 Events serveur locaux (`AddEventHandler`, jamais `RegisterNetEvent`)

| Event | Sens | Paramètres | Rôle |
|---|---|---|---|
| `pop_death:emsCalled` | pop_death → pop_ems | `src` (int), `coords` (vector3) | Création d'un appel (voir 5.3). **AddEventHandler uniquement** : un client ne peut pas le déclencher. |
| `pop_ems:revived` | pop_ems → autres scripts | `patient`, `medic` | Émis après une réanimation réussie (logs). |
| `pop_ems:admitted` | pop_ems → autres scripts | `patient`, `medic`, `stationIndex` | Émis après une admission. |

Events des bridges déjà fournis (ne pas redéclarer) : `pop_ems:bridge:notify`, `pop_ems:cb:*`, `pop_ems:playerLoaded|playerUnloaded|playerDropped`.

---

## 4. Callbacks (`shared/callback.lua`)

Tous enregistrés côté serveur (`Callback.Register`), appelés côté client par `Callback.Await` dans un thread.
**Retour uniforme : `ok` (boolean), `data`.** Si `ok == false`, `data` = clé de locale de l'erreur (le client fait `Bridge.Notify(L(data), 'error')`).

| Nom | Paramètres | Retour si ok | Vérifications serveur |
|---|---|---|---|
| `pop_ems:setDuty` | `stationIndex` (int), `state` (bool) | `true, state` | isMedic ; station existe ; `Bridge.IsNear(src, station.locker, Config.Distances.zone + 1.0)`. À `false` : supprime son véhicule. Pose `Player(src).state.popEmsDuty` (répliqué). QBCore/Qbox : `SetJobDuty` (framework direct). |
| `pop_ems:spawnVehicle` | `stationIndex`, `vehicleIndex` (int) | `true, netId` | isMedic + en service ; près de `station.garage` ; véhicule existe dans `Config.Vehicles` ; aucun véhicule à moins de 3 m de `station.spawn` (sinon `spawn_blocked`). Supprime l'ancien véhicule du joueur, `CreateVehicleServerSetter(joaat(model), 'automobile', spawn)`, attend l'existence (timeout 3 s), `SetVehicleDoorsLocked(veh, 1)`, mémorise `Ems.vehicles[src] = netId`. |
| `pop_ems:returnVehicle` | aucun | `true` | En service ; véhicule mémorisé existe et à moins de 10 m du joueur (sinon `no_vehicle`) ; refuse si un patient y est attaché (`patient_busy`). Supprime. |
| `pop_ems:acceptCall` | `callId` (int) | `true, callId` | En service ; appel existe ; statut `pending` (sinon `call_already_taken`). Un seul appel pris par EMS (l'ancien repasse `pending`). Notifie le patient `call_accepted_patient`, rediffuse la liste. |
| `pop_ems:begin` | `targetId` (int), `action` (string), `vehicleNetId` (int\|nil, seulement pour `load`) | `true, durationMs` | voir 10. Mémorise `Ems.actions[src] = { target, action, started = GetGameTimer(), vehicle }`. |
| `pop_ems:finish` | `targetId` (int), `action` (string) | `true, result` | Action mémorisée identique ; `elapsed >= Config.Durations[action] - 500` et `<= durée + 30000` ; re-vérifie tout (distance, état, objet). Applique, facture, efface `Ems.actions[src]`. `result` = table diagnostic pour `diagnose`, sinon `nil`. |
| `pop_ems:unloadPatient` | `vehicleNetId` (int) | `true` | En service ; véhicule à moins de `Config.Distances.vehicle` m ; un patient y est attaché. Détache. |
| `pop_ems:admit` | `stationIndex` (int) | `true` | En service ; près de `station.dropoff` (`zone + 1.0`) ; patient transporté par ce secouriste (`Ems.transported[p].medic == src`) ; véhicule à moins de `Config.Distances.admit` m de `dropoff` (sinon `no_patient`). |

Valeurs de `action` : `'diagnose'`, `'bandage'`, `'kit'`, `'revive'`, `'load'`. Toute autre valeur → `false, 'error'`.

Table `result` du diagnostic :
```lua
{ dead = bool, health = 0..100, bleeding = bool, limp = bool,
  parts = { head = 0..100, torso = .., leftArm = .., rightArm = .., leftLeg = .., rightLeg = .. } | nil } -- parts : statebag medInjuries de pop_medexam s'il est lancé
```
`health` = `(GetEntityHealth(ped) - 100) / (GetEntityMaxHealth(ped) - 100) * 100` borné 0..100 (lu côté serveur), 0 si mort.

---

## 5. Logique serveur (résumé pour le dev serveur)

### 5.1 État (`server/common.lua`, table `Ems`)
```lua
Ems.duty        = {}  -- [src] = stationIndex
Ems.vehicles    = {}  -- [src] = netId
Ems.calls       = {}  -- [id] = { id, patient, coords, time, status, medic }
Ems.actions     = {}  -- [src] = { target, action, started, vehicle }
Ems.transported = {}  -- [patient] = { vehicle = netId, medic = src }
Ems.lastAction  = {}  -- [src] = GetGameTimer() du dernier finish réussi
```
Helpers : `Ems.isMedic(src)` (= `Bridge.HasJob(src, { [Config.Job.name] = Config.Job.minGrade })` ou `IsPlayerAceAllowed(src, 'pop.ems')`), `Ems.isOnDuty(src)` (isMedic **et** `Ems.duty[src]`, sinon met fin au service et envoie `pop_ems:client:dutyOff`), `Ems.isDead(src)` (`exports.pop_death:isDead(src)` si pop_death lancé, **ou** `Bridge.IsDead(src)`), `Ems.dutyCount()`, `Ems.bill(patient, medic, kind)`, `Ems.addSocietyMoney(amount)`, `Ems.broadcastCalls(newId)`.

### 5.2 Facture `Ems.bill(patient, medic, kind)`
- `price = Config.Prices[kind]` ; rien si `price <= 0` ou `Bridge.Framework == 'standalone'`.
- `Bridge.RemoveMoney(patient, 'bank', price, 'pop_ems')`, sinon `'cash'`. Échec → `Bridge.Notify(medic, L('bill_unpaid'), 'warning')`.
- Succès → `Ems.addSocietyMoney(price)` ; si false → `Bridge.AddMoney(medic, 'bank', price, 'pop_ems')`. Notifie patient `billed_you` et secouriste `bill_paid` (%s = montant).
- `Ems.addSocietyMoney` (framework direct, chaque appel sous `pcall`) : ESX `esx_addonaccount:getSharedAccount('society_' .. Config.Job.name)` ; QBCore `qb-banking:AddMoney` puis `qb-management:AddMoney` ; Qbox `Renewed-Banking:addAccountMoney` puis `qb-banking`. Renvoie true si crédité.

### 5.3 Appels
- `AddEventHandler('pop_death:emsCalled', function(src, coords))` : `src` valide, `coords` vector3 sinon `Bridge.GetCoords(src)`. Si `Ems.dutyCount() == 0` → `Bridge.Notify(src, L('no_medic_available'), 'warning')`, fin. Un appel ouvert par patient maximum (on met à jour coords/time). Sinon nouvel id incrémental, `status = 'pending'`, `Ems.broadcastCalls(id)`.
- Boucle de fermeture : un seul thread, `Wait(10000)`, ne tourne que si `Ems.calls` ou `Ems.transported` non vides. Ferme un appel si : patient déconnecté, `not Ems.isDead(patient)`, `os.time() - time > Config.Calls.expire`, ou EMS preneur à moins de `Config.Calls.arrive` m. Libère un transport si le véhicule n'existe plus (`pop_ems:client:detach` au patient). Rediffuse si changement.
- Départ d'un joueur (`Bridge.OnPlayerDropped` et `OnPlayerUnloaded`) : patient → ferme son appel et son transport ; EMS → fin de service, supprime son véhicule (détache son patient), ses appels pris repassent `pending`.

### 5.4 Application des actions (`finish`)
| action | Effet |
|---|---|
| `diagnose` | renvoie `result` (aucune facture) |
| `bandage` | `Bridge.RemoveItem(src, Config.Items.bandage, 1)` → `pop_ems:client:treated(target, 'bandage')`, facture `bandage` |
| `kit` | `RemoveItem(Config.Items.kit, 1)` → `treated('kit')` ; si pop_medexam lancé : `TriggerClientEvent('pop_medexam:treated', target)` ; facture `kit` |
| `revive` | `HasItem(Config.Items.defib)` (non consommé) → `pop_ems:client:revived(target, Config.ReviveHealth)`, ferme l'appel du patient, `TriggerEvent('pop_ems:revived', target, src)`, facture `revive` |
| `load` | `Ems.transported[target] = { vehicle, medic = src }`, `Entity(veh).state:set('popEmsPatient', target, true)`, `Player(target).state:set('popEmsTransport', vehicle, true)`, `pop_ems:client:attach(target, vehicle)` |

`Config.Items.<x> = false` : aucun objet exigé ni retiré (utile en standalone sans inventaire).

Admission : détache, `Ems.transported[p] = nil`, statebags remis à nil, `pop_ems:client:admitted(p, station.bed)`, ferme l'appel, facture `admit`, `TriggerEvent('pop_ems:admitted', p, src, stationIndex)`, notifie secouriste `patient_admitted` et patient `admitted_you` (%s = `station.label`).

---

## 6. Logique client (résumé pour le dev client)

- **Au chargement** (`Bridge.OnPlayerLoaded`) : blips hôpitaux (`Config.Blips.station`, nom = `station.label`), zones vestiaire et garage via `Bridge.Target.AddBoxZone` (ids `pop_ems_locker_<i>`, `pop_ems_garage_<i>`, size `vec3(2.0, 2.0, 2.0)`). `canInteract` : job local = `Config.Job.name` (affichage seulement, le serveur revérifie).
  - Vestiaire : options `duty_on_label` (si hors service) / `duty_off_label` (si en service).
  - Garage : une option par véhicule `L('garage_take', v.label)` + `garage_return` (en service).
- **Prise de service** (réponse ok) : mémorise les composants civils (`GetPedDrawableVariation/TextureVariation` des composants présents dans la tenue), applique `Config.Outfits.male|female` selon le modèle (`mp_f_freemode_01` = female), ajoute : target joueurs `Bridge.Target.AddModel(Config.PlayerModels, …)` option `target_care` (`canInteract` : `IsPedAPlayer(e) and e ~= PlayerPedId()`), target véhicules `Bridge.Target.AddModel(models de Config.Vehicles, …)` option `target_unload` (`canInteract` : `Entity(veh).state.popEmsPatient ~= nil`), zones admission `pop_ems_admit_<i>` option `target_admit`. **Fin de service** : tout est retiré (`Bridge.Target.Remove`), tenue civile, NUI `calls` vidée, blips d'appel supprimés. Hors service = aucun target sur les joueurs (aucun scan).
- **Garage** : après `spawnVehicle` ok, attend `NetworkDoesEntityExistWithNetworkId` (timeout 3 s), `TaskWarpPedIntoVehicle(ped, veh, -1)`.
- **Appels** (`client/calls.lua`) : blip par appel (`Config.Blips.call`, nom `L('call_blip')`), rue calculée une fois (`GetStreetNameAtCoord` + `GetStreetNameFromHashKey`). Thread d'affichage seulement s'il y a des appels : `Wait(1000)`, recalcule distances/âges, envoie NUI `calls`. Touche : `RegisterCommand('pop_ems_accept')` + `RegisterKeyMapping('pop_ems_accept', L('keymap_accept'), 'keyboard', Config.AcceptCallKey)` → prend le plus récent `pending` ; si ok : `SetNewWaypoint`, `Bridge.Notify(L('call_taken_you', id), 'success')`.
- **Menu de soins** : `onSelect(entity)` → `targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))`, état local du ped (`IsPedDeadOrDying`), ambulance de service proche, puis NUI `menu` + `SetNuiFocus(true, true)`. Disponibilité affichée (le serveur décide) : `diagnose` toujours ; `bandage` toujours ; `kit` si conscient ; `revive` si inconscient ; `load` si inconscient et ambulance (`Config.Vehicles`) à moins de `Config.Distances.vehicle` m.
- **Enchaînement d'une action** : `begin` → `Bridge.Progress(L('progress_' .. action), durationMs, { anim = ANIMS[action] })` → si annulée, rien ; sinon `finish`. Pour `diagnose` : NUI `diagnosis` (affichée 10 s, sans focus). Pour `load` : `vehicleNetId` = `NetworkGetNetworkIdFromEntity` de l'ambulance la plus proche. Animations (dans `client/care.lua`, pas dans la config) : `diagnose` / `bandage` / `kit` = `amb@medic@standing@tendtodead@idle_a` `idle_a` flag 1 ; `revive` = `mini@cpr@char_a@cpr_str` `cpr_pumpchest` flag 1 ; `load` = `anim@heists@box_carry@` `idle` flag 49.
- **Blessures** (`client/injuries.lua`, seulement si `Config.Injuries.enabled`) : `AddEventHandler('gameEventTriggered')` sur `CEventNetworkEntityDamage` (victime = mon ped), dégâts = différence de santé ; `GetPedLastDamageBone` → jambe si os dans la liste des jambes (mêmes bone ids que `pop_medexam/config.lua`, en dur dans le fichier). Statebag client `LocalPlayer.state:set('popEmsInjury', { bleeding = bool, limp = bool }, true)`. Un seul thread, actif seulement si une blessure existe, `Wait(Config.Injuries.interval * 1000)` : vivant et saignement → `-bleedLoss` PV ; santé = max → tout effacer et arrêter. Boiterie : `RequestAnimSet` + `SetPedMovementClipset(ped, Config.Injuries.limpClipset, 0.2)`, retirée par `ResetPedMovementClipset`. Notifications `injury_bleeding` / `injury_limp` une fois à l'apparition.
- **Arrêt de la ressource** : tenue civile si en service, détache le patient, focus NUI rendu (le bridge nettoie targets/progression).

---

## 7. Messages NUI

Kit `web/kit/` : `Pop.on`, `Pop.post`, `Pop.t`, `Pop.translate`, `Pop.show`. Les messages `pop:prompt`, `pop:progress`, `pop:notify` sont envoyés par le bridge et **gérés par le kit** (rien à coder). Textes : `data-locale="cle"`, remplis au chargement via `pop:ready` (bridge : `{ locale, accent }`). Si `locale._rtl` : `dir="rtl"` sur `<html>` (fait par le kit), la mise en page doit rester correcte.

### 7.1 Lua → JS (`SendNUIMessage`)

```json
{ "action": "calls", "data": {
    "acceptKey": "Y",
    "calls": [ { "id": 12, "street": "Strawberry Ave", "distance": 840, "age": 2,
                 "status": "pending", "medic": null, "mine": false } ] } }
```
Max `Config.Calls.maxShown` cartes (les plus récentes). `calls` vide → panneau caché (fondu 150 ms). `age` en minutes (0 → `call_age_now`, sinon `call_age` %d) ; `distance` en mètres (`call_distance` %d). Statut : `call_status_pending` ou `call_status_taken` (%s = medic), `mine` → `call_status_mine`. Pied de panneau : `[Y] call_accept_key` seulement s'il existe un appel `pending`.

```json
{ "action": "menu", "data": { "show": true,
    "actions": [ { "id": "diagnose", "enabled": true }, { "id": "bandage", "enabled": true },
                 { "id": "kit", "enabled": false }, { "id": "revive", "enabled": true },
                 { "id": "load", "enabled": false } ] } }
{ "action": "menu", "data": { "show": false } }
```
Libellé = `menu_<id>`, sous-titre = `menu_hint_<id>`, titre = `menu_title`, bouton fermer = `close`. Bouton désactivé grisé, non cliquable.

```json
{ "action": "diagnosis", "data": { "dead": true, "health": 0, "bleeding": true, "limp": false,
    "parts": { "head": 100, "torso": 40, "leftArm": 100, "rightArm": 100, "leftLeg": 70, "rightLeg": 100 } } }
```
Titre `diag_title` ; lignes : `diag_unconscious`/`diag_conscious`, `diag_health` (%d), `diag_bleeding`/`diag_no_bleeding`, `diag_limp` si true ; si `parts` : une ligne par zone `diag_part` (%s = `part_<zone>`, %d = valeur), en accent si < 50. Disparaît après 10 s ou au message suivant.

### 7.2 JS → Lua (`RegisterNUICallback`)

| Nom | Corps JSON | Réponse | Rôle |
|---|---|---|---|
| `pop:ready` | `{}` | `{ locale, accent }` | fourni par le bridge |
| `close` | `{}` | `'ok'` | fourni par le bridge (Échap ou bouton fermer) ; pop_ems s'y abonne via `Bridge.OnUiClose` pour cacher le menu |
| `menuAction` | `{ "id": "bandage" }` | `'ok'` | client : `SetNuiFocus(false, false)`, cache le menu, lance l'action (id inconnu ignoré) |

### 7.3 Style (DA POP, identique à pop_notify)
- Police `'TT Firs Neue', 'Segoe UI', Tahoma, sans-serif` (même `@import` que pop_notify).
- Panneaux : `background: rgba(10,10,12,.4)`, `backdrop-filter: blur(12px)`, `border: 1px solid rgba(255,255,255,.1)`, `border-radius: 4px`, texte blanc, secondaire `rgba(255,255,255,.5)`.
- Icône d'en-tête : rond blanc 18 px, pictogramme `#0a0a0c`. Accent unique `#5d90ec` (barre fine en bas d'une carte d'appel pris par moi, valeurs critiques). **Pas de rose, pas de dégradé.**
- Appels : colonne à droite, en haut, largeur 273 px, cartes empilées (gap 10 px). Menu : panneau à droite, centré verticalement, ~260 px, boutons pleine largeur. Diagnostic : petite carte sous le menu. Fondu 150 ms, jamais de grande fenêtre centrale.
- Touches affichées avec `pop-key` : « [Y] Prendre l'appel ».

---

## 8. Exports

| Côté | Export | Paramètres | Retour |
|---|---|---|---|
| serveur | `isOnDuty` | `src` | bool |
| serveur | `getOnDutyCount` | — | int |
| serveur | `createCall` | `src`, `coords` (vector3\|nil) | `callId` \| nil (même logique que `pop_death:emsCalled`, pour un téléphone ou un autre script) |
| serveur | `revive` | `src` | bool (réanimation forcée sans contrôle de job : réservé aux scripts serveur, ex. admin) |
| client | `isOnDuty` | — | bool |
| client | `getInjuries` | — | `{ bleeding = bool, limp = bool }` |

---

## 9. Schéma SQL

Aucun. Rien n'est stocké (service, appels et transports sont en mémoire et repartent à zéro au redémarrage). Pas d'oxmysql.
Objets à déclarer pour les inventaires hors pop_inventory : `install/items_*` (`bandage`, `kitsoins`, `defib`).
Dans pop_inventory : `kitsoins` et `defib` existent déjà (`config/items_2.lua`) ; `bandage` n'y figure pas → `install/items_pop.lua` :
```lua
bandage = { label = 'Bandage', weight = 0.1, maxStack = 10, icon = 'img/bandage.webp', tags = { 'ems', 'medical' }, gradientColor = 'rgba(50, 230, 50, 0.4)' },
```
(non utilisable seul : il s'emploie via le menu de soins.)

---

## 10. `config.lua` (contenu exact, commentaires en anglais)

```lua
Config = {}

------------------------------------------------------------------------
-- Common POP settings (do not remove)
------------------------------------------------------------------------
Config.Locale = 'fr'          -- fr, en, es, de, ar (missing key falls back to 'en')
Config.Debug = false
Config.Framework = 'auto'     -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto'     -- 'pop_inventory' | 'ox_inventory' | 'qs-inventory' | 'qb-inventory' | 'ps-inventory' | 'framework' | 'none'
Config.Target    = 'auto'     -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto'     -- 'framework' | 'ox_lib' | 'pop' | 'native'
Config.AccentColor = '#5d90ec'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_ems
------------------------------------------------------------------------

-- Job (standalone: ACE 'pop.ems' instead)
Config.Job = { name = 'ambulance', minGrade = 0 }

-- Key to take the latest pending call (players can change it in FiveM key bindings)
Config.AcceptCallKey = 'Y'

-- Items used (false = no item required)
Config.Items = { bandage = 'bandage', kit = 'kitsoins', defib = 'defib' }

-- Action durations (ms)
Config.Durations = { diagnose = 3000, bandage = 4000, kit = 8000, revive = 10000, load = 3000 }

-- Prices billed to the patient (0 = free)
Config.Prices = { bandage = 50, kit = 150, revive = 500, admit = 800 }

-- Health given back (GTA health: 100 = dead, 200 = full)
Config.ReviveHealth = 150
Config.BandageHealth = 20

-- Distances (m)
Config.Distances = { interact = 3.0, vehicle = 6.0, admit = 15.0, zone = 2.0 }

-- Seconds between two finished actions for the same medic (anti-spam)
Config.ActionCooldown = 3

-- Calls: expire (s), arrival distance that closes the call (m), cards shown
Config.Calls = { expire = 600, arrive = 20.0, maxShown = 3 }

-- Light injuries (bleeding, limp)
Config.Injuries = {
    enabled = true,
    bleedDamage = 15,   -- damage in one hit that starts bleeding
    bleedLoss = 2,      -- health lost per tick while bleeding
    interval = 10,      -- seconds between ticks
    limpClipset = 'move_m@injured',
}

-- Player ped models that can be treated (add your addon peds)
Config.PlayerModels = { 'mp_m_freemode_01', 'mp_f_freemode_01' }

-- Service vehicles (label can be renamed)
Config.Vehicles = {
    { model = 'ambulance', label = 'Ambulance' },
}

-- Patient position in the back of the ambulance (offset from the vehicle)
Config.PatientOffset = vec3(0.0, -2.2, 0.6)

-- EMS outfit: [component id] = { drawable, texture }
Config.Outfits = {
    male   = { [3] = { 85, 0 }, [4] = { 96, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 250, 0 } },
    female = { [3] = { 109, 0 }, [4] = { 99, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 258, 0 } },
}

-- Blips: sprite, colour, scale
Config.Blips = {
    station = { sprite = 61, color = 2, scale = 0.8 },
    call    = { sprite = 153, color = 1, scale = 0.9 },
}

-- Hospitals (same as pop_death). Coordinates to check in game.
Config.Stations = {
    {
        label = 'Pillbox Hill',
        locker  = vec3(301.6, -599.3, 43.3),
        garage  = vec3(294.5, -600.8, 43.3),
        spawn   = vec4(290.8, -610.6, 43.4, 70.0),
        dropoff = vec3(294.0, -574.5, 43.2),
        bed     = vec4(298.6, -584.5, 43.3, 70.0),
    },
    {
        label = 'Sandy Shores',
        locker  = vec3(1834.2, 3688.4, 34.3),
        garage  = vec3(1828.3, 3693.2, 34.2),
        spawn   = vec4(1820.6, 3692.1, 34.2, 300.0),
        dropoff = vec3(1836.5, 3669.6, 34.3),
        bed     = vec4(1839.4, 3672.9, 34.3, 210.0),
    },
    {
        label = 'Paleto Bay',
        locker  = vec3(-254.2, 6324.6, 32.4),
        garage  = vec3(-259.5, 6334.9, 32.4),
        spawn   = vec4(-270.6, 6337.6, 32.4, 225.0),
        dropoff = vec3(-243.5, 6326.2, 32.4),
        bed     = vec4(-247.8, 6331.2, 32.4, 225.0),
    },
}
```
Les noms de lieux, de véhicules et d'objets restent dans la config (jamais dans les locales). Les coordonnées autres que `bed` sont indicatives : le client les ajuste en jeu (`Config.Debug = true` affiche les zones ox_target/qb-target).

---

## 11. Clés de traduction

Fichiers : `locales/en.lua` (référence, toutes les clés), `fr`, `es`, `de`, `ar` (`_rtl = true`). Mêmes clés partout, mêmes `%s`/`%d` dans le même ordre. Tutoiement en fr. Ajouter une langue = copier `en.lua`. Contrôle : `lua5.4 tools/check-locales.lua "resources/[pop]/pop_ems"` → OK.

Clés communes du gabarit (copiées de pop_base) : `cancel`, `confirm`, `close`, `interact`, `progress_cancelled`, `no_permission`, `wrong_job`, `too_far`, `not_enough_money`, `missing_item` (%s), `inventory_full`, `cooldown` (%s), `busy`, `error`.

Clés pop_ems (texte fr de référence) :

| Clé | fr |
|---|---|
| `duty_on_label` | Prendre le service |
| `duty_off_label` | Finir le service |
| `duty_on` | Tu es en service. |
| `duty_off` | Tu n'es plus en service. |
| `not_on_duty` | Tu dois être en service. |
| `garage_take` | Sortir : %s |
| `garage_return` | Ranger le véhicule |
| `vehicle_out` | Véhicule sorti. |
| `vehicle_returned` | Véhicule rangé. |
| `spawn_blocked` | La place est occupée. |
| `no_vehicle` | Aucun véhicule de service à proximité. |
| `call_title` | Appel d'urgence |
| `call_new` | Nouvel appel : %s |
| `call_blip` | Appel EMS |
| `call_accept_key` | Prendre l'appel |
| `call_status_pending` | En attente |
| `call_status_taken` | Pris par %s |
| `call_status_mine` | En route |
| `call_distance` | %d m |
| `call_age` | il y a %d min |
| `call_age_now` | à l'instant |
| `call_taken_you` | Appel #%d pris, GPS activé. |
| `call_already_taken` | Appel déjà pris. |
| `call_none` | Aucun appel en attente. |
| `call_accepted_patient` | Un secouriste arrive. |
| `no_medic_available` | Aucun secouriste en service. |
| `keymap_accept` | EMS : prendre le dernier appel |
| `target_care` | Soigner |
| `target_unload` | Sortir le patient |
| `target_admit` | Admettre le patient |
| `menu_title` | Soins |
| `menu_diagnose` | Diagnostic |
| `menu_bandage` | Bandage |
| `menu_kit` | Kit de soins |
| `menu_revive` | Réanimer |
| `menu_load` | Mettre dans l'ambulance |
| `menu_hint_diagnose` | État du patient |
| `menu_hint_bandage` | Rapide, arrête le saignement |
| `menu_hint_kit` | Lent, soin complet |
| `menu_hint_revive` | Défibrillateur |
| `menu_hint_load` | Pour le transport |
| `progress_diagnose` | Examen en cours |
| `progress_bandage` | Pose du bandage |
| `progress_kit` | Soins en cours |
| `progress_revive` | Réanimation |
| `progress_load` | Installation du patient |
| `diag_title` | Diagnostic |
| `diag_conscious` | Conscient |
| `diag_unconscious` | Inconscient |
| `diag_health` | Santé : %d %% |
| `diag_bleeding` | Saigne |
| `diag_no_bleeding` | Pas de saignement |
| `diag_limp` | Jambe touchée |
| `diag_part` | %s : %d %% |
| `part_head` | Tête |
| `part_torso` | Torse |
| `part_leftArm` | Bras gauche |
| `part_rightArm` | Bras droit |
| `part_leftLeg` | Jambe gauche |
| `part_rightLeg` | Jambe droite |
| `patient_dead` | Le patient est inconscient : réanime-le d'abord. |
| `patient_not_dead` | Le patient est conscient. |
| `patient_bleeding` | Arrête d'abord le saignement. |
| `patient_busy` | Le patient est déjà pris en charge. |
| `patient_self` | Tu ne peux pas te soigner toi-même ici. |
| `no_patient` | Aucun patient à admettre. |
| `patient_loaded` | Patient installé. |
| `patient_unloaded` | Patient sorti. |
| `patient_admitted` | Patient admis à %s. |
| `admitted_you` | Tu as été pris en charge à %s. |
| `revived_you` | Tu as été réanimé. |
| `treated_bandage_you` | Ton saignement est arrêté. |
| `treated_kit_you` | Tu as été soigné. |
| `done_diagnose` | Examen terminé. |
| `done_bandage` | Bandage posé. |
| `done_kit` | Soins terminés. |
| `done_revive` | Patient réanimé. |
| `billed_you` | Facture des soins : %s $ |
| `bill_paid` | Soins facturés : %s $ |
| `bill_unpaid` | Le patient n'a pas pu payer. |
| `injury_bleeding` | Tu saignes. Trouve des soins. |
| `injury_limp` | Ta jambe est touchée. |

`missing_item` reçoit le **nom de l'objet** tel que configuré (`Config.Items.x`) ; le dev client peut afficher le label de l'inventaire s'il est disponible, sinon le nom.

---

## 12. Sécurité : vérifications serveur obligatoires

Chaque callback commence par `local src = source` (fourni par `Callback.Register`) et valide **tous** les paramètres (`math.type(x) == 'integer'`, `type(action) == 'string'`, index dans les bornes de `Config.Stations` / `Config.Vehicles`, `GetPlayerName(targetId) ~= nil`).

1. **Job + service** : `Ems.isOnDuty(src)` revérifie le job à chaque appel (`Bridge.HasJob` avec `minGrade`, ou ACE `pop.ems`). Perte du job → fin de service forcée. `setDuty` exige seulement isMedic.
2. **Distance** (positions serveur, `Bridge.IsNear` / `Bridge.GetCoords`) : patient à `Config.Distances.interact` m au `begin` **et** au `finish` ; zones à `Config.Distances.zone + 1.0` m ; véhicule à `Config.Distances.vehicle` m ; admission à `Config.Distances.admit` m du `dropoff`.
3. **Durée** : `finish` refusé sans `begin` correspondant (même cible, même action) ou si `elapsed < Config.Durations[action] - 500 ms`. Une seule action en cours par secouriste ; une cible ne peut être traitée que par un secouriste à la fois (`patient_busy`).
4. **Cooldown** : `Config.ActionCooldown` s entre deux `finish` réussis (`cooldown`), en plus de `Config.CallbackRateLimit`.
5. **État du patient** : `targetId ~= src` (`patient_self`) ; `kit` seulement si vivant (`patient_dead`) ; `revive` et `load` seulement si `Ems.isDead(target)` (`patient_not_dead`) ; `revive` refusé si `Config.Injuries.enabled` et `Player(target).state.popEmsInjury.bleeding` (`patient_bleeding`) ; `load` refusé si déjà transporté.
6. **Objets** : `Bridge.HasItem` au `begin`, `Bridge.RemoveItem` au `finish` (l'action échoue si le retrait échoue, `missing_item`). Défibrillateur : présence seulement.
7. **Véhicules** : créés uniquement par le serveur ; `NetworkGetEntityFromNetworkId` + `DoesEntityExist` + modèle dans `Config.Vehicles` pour `load`/`unload`/`admit` ; `load` exige un véhicule de service (n'importe quel EMS) ; `admit` exige le patient de **ce** secouriste. Un véhicule par secouriste.
8. **Argent** : prix lus uniquement dans `Config.Prices`, jamais envoyés par le client ; `Bridge.RemoveMoney` vérifie le solde ; crédit seulement après débit réussi.
9. **Appels** : `pop_death:emsCalled` écouté par `AddEventHandler` uniquement (jamais `RegisterNetEvent`) ; un appel ouvert par patient ; seul un EMS en service peut prendre un appel `pending`.
10. **Statebags** : `popEmsDuty`, `popEmsPatient`, `popEmsTransport` posés **par le serveur uniquement**. `popEmsInjury` est posé par le client du patient : il ne sert qu'au diagnostic et au blocage de la réanimation (un tricheur ne peut que se gêner lui-même) ; il n'ouvre aucun droit.
11. **Nettoyage** : drop/unload d'un joueur → actions, transports, appels, véhicules et service libérés (pas de fuite mémoire, pas de véhicule fantôme).
12. **Logs** : `if Config.Debug then print(...) end` uniquement.

---

## 13. Vérification avant push
- `luacheck "resources/[pop]/pop_ems"` 0/0, `luac5.4 -p` sur chaque `.lua`, `node --check web/script.js`.
- `lua5.4 tools/check-locales.lua "resources/[pop]/pop_ems"` → OK.
- resmon au repos (hors service, aucun appel) : 0,00 ms. En service sans appel : 0,00–0,01 ms.
- Captures NUI en fr et en ar (RTL). Test en jeu sur ESX : avec pop_death (appel → prise → GPS → bandage → réanimation → ambulance → admission → facture) et sans EMS en service (réapparition pop_death inchangée).
