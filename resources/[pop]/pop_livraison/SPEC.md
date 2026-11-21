# pop_livraison : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).

---

## 1. Description et fonctionnalités

Petit job de livraison de colis au départ d'un dépôt. Une **tournée** = `Config.Packages` adresses tirées au hasard ;
chaque colis livré est payé par le serveur selon la distance parcourue.

**Boucle de jeu**
1. **Dépôt** : parler au chef de quai (PNJ). Deux choix (esprit GTA 6) :
   - **Avec la camionnette** (`Config.Vehicle`) : caution payée, camionnette temporaire fournie ; à chaque adresse il
     faut **sortir le colis de l'arrière** de la camionnette puis le porter à la porte. Caution rendue au retour du
     véhicule au dépôt.
   - **Avec son propre véhicule / à pied** : pas de caution, pas d'étape de chargement.
2. **Rouler** : blip + itinéraire GPS vers l'adresse ; petit HUD à droite : `Livraison 2/3`, temps restant, consigne.
3. **Livrer** : à la porte, `[E] Livrer le colis` → courte barre de progression → paie immédiate.
4. **Fin** : après le dernier colis, la tournée se termine (mode à pied) ou il faut **ramener la camionnette** au
   dépôt (mode camionnette) pour récupérer la caution. Abandon possible au dépôt (caution perdue).

**Règles**
- Temps limite par tournée (`Config.TimeLimit`) : dépassé → tournée terminée, camionnette supprimée, caution perdue.
- Délai entre deux tournées (`Config.Cooldown`).
- Paie serveur par colis : `Config.Pay.base + floor(distance_km × Config.Pay.perKm)` (distance à vol d'oiseau entre
  le point précédent et l'adresse).
- Validation serveur : proximité de l'adresse, **temps minimal** de trajet (anti-téléportation), camionnette proche
  en mode camionnette.
- Job facultatif (`Config.Job = false` : tout le monde).
- Camionnette créée **côté serveur** avec le statebag `pop_temporary = true` (les autres scripts POP — garages,
  fourrière, persistance — l'ignorent), supprimée à la fin, à l'abandon, à la déconnexion et à l'arrêt.

**HUD** : carte discrète à droite, visible seulement pendant une tournée. Fondu 150 ms. Pas de focus NUI.

**Performance** : client : PNJ par distance (1000/2500 ms) ; pendant une tournée, une boucle à 1000 ms (HUD, zone de
porte à ≤ 60 m). `Wait(0)` seulement **pendant le port du colis** (désactive sprint/saut/entrer dans un véhicule) et
dans `Bridge.Progress`. Serveur : un `SetTimeout` toutes les 30 s, seulement s'il existe des tournées.

**Hors périmètre** : choix des colis, signature, colis fragiles, classement, livraisons en équipe.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_livraison/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + section 8)
  README.md               SERVEUR   (en ANGLAIS : installation, adresses, clés de véhicule, statebag)
  locales/en.lua … ar.lua SERVEUR   10 fichiers, ar : _rtl = true
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    dépôt, PNJ, tournée, blips, port du colis, HUD
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
```
`bridge/`, `shared/callback.lua`, `shared/locale.lua`, `web/kit/` : **copiés par l'intégrateur**.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_livraison'
author 'POP'
version '1.0.0'
description 'POP Delivery - parcel delivery job'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/*.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
```
Pas d'oxmysql.

---

## 3. Données

### `RunData` (serveur → client)
```lua
{
    destinations = { { x = -14.1, y = -1441.0, z = 31.1, w = 180.0 }, ... }, -- adresses de la tournée, dans l'ordre
    index    = 1,      -- int : prochaine adresse (total + 1 = toutes livrées)
    total    = 3,      -- int
    timeLeft = 1200,   -- int : secondes restantes
    netId    = 1234,   -- int | nil : camionnette (mode camionnette)
}
```

### Entrée serveur `runs[src]`
`{ identifier, dests = { index de Config.Destinations }, index, startedAt, lastAt, lastPos (vector3), expiresAt,
vehicle = handle | nil, deposit = int, paid = int }`.

---

## 4. Events

### Serveur → Client
| Event | Paramètres | Destinataire | Rôle |
|---|---|---|---|
| `pop_livraison:client:runEnded` | `reason` (clé de locale : `run_expired`) | le joueur | Le serveur a clos la tournée (temps écoulé) : le client nettoie tout et notifie |

Aucun `RegisterNetEvent` serveur propre au script. Bridge : `Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded` →
supprime la camionnette et la tournée (caution perdue), libère `busy[src]`.

---

## 5. Callbacks (`shared/callback.lua`)

Convention : `ok, reason, arg, ...`. Échec → le client notifie `L(reason or 'error', arg)` en `error`. Succès → le
serveur notifie. `nil` = `error`.

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_livraison:start` | `withVehicle` (bool) | `ok, reason, arg, run` (RunData) |
| `pop_livraison:deliver` | aucun | `ok, reason, arg, index` (int : nouvelle valeur de `index`) |
| `pop_livraison:finish` | aucun | `ok, reason, arg` |
| `pop_livraison:cancel` | aucun | `ok, reason, arg` |

Raisons : `error`, `busy`, `too_far`, `wrong_job`, `cooldown` (arg = secondes), `already_on_run`, `no_run`,
`not_enough_money`, `spawn_blocked`, `vehicle_missing`, `vehicle_too_far`, `too_fast`, `run_not_done`.

---

## 6. Messages NUI

L'interface **ne prend jamais le focus**. Pas de callback JS → Lua propre au script.

### Lua → JS
**`pop_livraison:hud`** : envoyé au début, à chaque changement d'étape et chaque seconde (décompte) pendant une tournée.
```json
{ "action": "pop_livraison:hud", "show": true, "index": 2, "total": 3, "timeLeft": 845, "step": "take" }
```
```json
{ "action": "pop_livraison:hud", "show": false }
```
`step` ∈ `drive` (rouler vers l'adresse), `take` (sortir le colis de la camionnette), `deliver` (porter à la porte),
`return` (ramener la camionnette au dépôt). Libellé : `Pop.t('hud_' + step)`.

### Interface (Dev NUI)
- `web/index.html` : `style.css` après `kit/pop.css`. `#delivery` (`pop-panel pop-fade`, masqué) :
  titre `Pop.t('hud_title', index, total)` (si `step == 'return'` : `Pop.t('hud_title_done')`), temps `mm:ss`
  à droite (`--pop-danger` sous 60 s), consigne `Pop.t('hud_' + step)` en `pop-small`.
- `web/style.css` : 220 px, `position: fixed; right: 24px; top: 28%;` RTL : `right: auto; left: 24px`.
- Aucun texte en dur.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_livraison:IsOnRun(src)` | bool | tournée en cours |
| `exports.pop_livraison:GetRun(src)` | `{ index, total, timeLeft, paid }` \| nil | lecture (copie) |

Client :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_livraison:IsOnRun()` | bool | tournée en cours |

---

## 8. config.lua (contenu exact)

Reprend **à l'identique** le `config.lua` de `templates/pop_base`, puis ajoute :

```lua
-- ─── pop_livraison ──────────────────────────────────────────

-- Job requis (format Bridge.HasJob), false = tout le monde.
Config.Job = false

-- Dépôt : PNJ chef de quai.
Config.Depot = { coords = vector4(1175.53, -3309.27, 5.92, 71.0), ped = 's_m_m_postal_01', blip = true }

Config.Blip = { sprite = 478, color = 5, scale = 0.8 }

-- Camionnette fournie (false : pas de camionnette, uniquement le mode à pied / véhicule perso).
Config.Vehicle = { model = 'boxville2', spawn = vector4(1178.56, -3307.38, 5.95, 89.27), deposit = 500 }

Config.Account   = 'bank'  -- compte de la paie et de la caution : 'cash' | 'bank'
Config.Packages  = 3       -- colis par tournée
Config.Pay       = { base = 150, perKm = 100 } -- paie par colis
Config.TimeLimit = 1200    -- secondes par tournée
Config.Cooldown  = 60      -- secondes entre deux tournées

Config.Durations = { take = 2000, deliver = 3000 } -- ms

-- Adresses de livraison (porte : x, y, z, heading). Au moins Config.Packages entrées.
Config.Destinations = {
    vector4(-14.13, -1441.00, 31.10, 180.0),
    vector4(126.40, -1929.50, 21.38, 210.0),
    vector4(250.20, -1730.90, 29.67, 50.0),
    vector4(-1150.70, -1520.70, 10.63, 35.0),
    vector4(-815.90, 178.60, 72.15, 110.0),
    vector4(7.90, 538.40, 176.03, 150.0),
    vector4(1393.00, 1141.80, 114.33, 90.0),
    vector4(1973.00, 3815.50, 33.43, 30.0),
    vector4(1661.30, 4776.20, 42.00, 280.0),
    vector4(-347.60, 6225.60, 31.88, 225.0),
}
```
NOTE : positions approximatives (portes connues de la carte), à vérifier en jeu par l'intégrateur.

Constantes (code) : `ACTION_DISTANCE = 6.0` (serveur : joueur ↔ porte / PNJ), `VEHICLE_DISTANCE = 40.0` (serveur :
camionnette ↔ porte), `RETURN_DISTANCE = 20.0` (serveur : camionnette ↔ `Config.Vehicle.spawn`),
`MAX_SPEED = 70.0` m/s (serveur, anti-téléportation), `TARGET_DISTANCE = 2.0`, `PED_DISTANCE = 40.0`,
`DOOR_ZONE_DISTANCE = 60.0` (client : création de la zone de porte), `BOX_PROP = 'hei_prop_heist_box'`.

---

## 9. Locales

10 fichiers (en, fr, es, de, it, pt, nl, pl, tr, ar `_rtl = true`). Bloc « Kit commun » + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `blip_name` | Delivery depot | Dépôt de livraison |
| `blip_destination` | Delivery | Livraison |
| `target_start_vehicle` | Start a delivery run (van, $%s deposit) | Commencer une tournée (camionnette, caution %s $) |
| `target_start_foot` | Start a delivery run (own vehicle) | Commencer une tournée (véhicule perso) |
| `target_finish` | Return the van | Rendre la camionnette |
| `target_cancel` | Abandon the run | Abandonner la tournée |
| `target_take` | Take a parcel | Prendre un colis |
| `target_deliver` | Deliver the parcel | Livrer le colis |
| `taking` | Taking the parcel... | Prise du colis... |
| `delivering` | Delivering... | Livraison... |
| `run_started` | Run started: %s parcels to deliver | Tournée commencée : %s colis à livrer |
| `delivered` | Parcel delivered (+$%s) | Colis livré (+%s $) |
| `run_completed` | Run completed: $%s earned | Tournée terminée : %s $ gagnés |
| `return_van` | All parcels delivered: return the van to the depot | Tous les colis sont livrés : ramenez la camionnette au dépôt |
| `deposit_returned` | Deposit returned (+$%s) | Caution rendue (+%s $) |
| `run_cancelled` | Run abandoned | Tournée abandonnée |
| `run_expired` | Out of time: run over | Temps écoulé : tournée terminée |
| `already_on_run` | You are already on a run | Vous avez déjà une tournée en cours |
| `no_run` | You don't have a run | Vous n'avez pas de tournée |
| `spawn_blocked` | The van spot is blocked | La place de la camionnette est occupée |
| `vehicle_missing` | Your van is gone | Votre camionnette a disparu |
| `vehicle_too_far` | Bring the van closer | Rapprochez la camionnette |
| `too_fast` | That was suspiciously fast | C'était étrangement rapide |
| `run_not_done` | Deliver all the parcels first | Livrez d'abord tous les colis |
| `hud_title` | Delivery %s/%s | Livraison %s/%s |
| `hud_title_done` | Deliveries done | Livraisons terminées |
| `hud_drive` | Drive to the address | Rendez-vous à l'adresse |
| `hud_take` | Take a parcel from the van | Prenez un colis dans la camionnette |
| `hud_deliver` | Bring the parcel to the door | Portez le colis à la porte |
| `hud_return` | Return the van to the depot | Ramenez la camionnette au dépôt |

Clés de base réutilisées : `too_far`, `wrong_job`, `cooldown`, `not_enough_money`, `busy`, `error`,
`progress_cancelled`.

---

## 10. Schéma SQL

Aucun.

---

## 11. Comportement attendu

### Serveur
- **start** : tire `Config.Packages` index **distincts** de `Config.Destinations` (mélange de Fisher-Yates).
  Mode camionnette : contrôle de la place (aucun véhicule de `GetAllVehicles()` à < 3 m de `Config.Vehicle.spawn`,
  sinon `spawn_blocked`), caution `Bridge.RemoveMoney(src, Config.Account, deposit, 'pop_livraison')`, puis
  `CreateVehicleServerSetter(joaat(model), 'automobile', x, y, z, w)` ; attente `DoesEntityExist` (≤ 2 s, sinon
  caution rendue et `error`) ; `SetVehicleNumberPlateText(veh, ('POPL%04d'):format(math.random(0, 9999)))` ;
  `Entity(veh).state:set('pop_temporary', true, true)` ; `Entity(veh).state:set('fuel', 100.0, true)` (ox_fuel).
  Clés : si `GetResourceState('qbx_vehiclekeys') == 'started'` → `pcall(exports.qbx_vehiclekeys.GiveKeys, …, src, veh)`
  (NOTE: export à confirmer selon la version). `run.startedAt = run.lastAt = os.time()`, `lastPos` = position du
  dépôt, `expiresAt = os.time() + Config.TimeLimit`. Notification `run_started`.
- **deliver** succès : `pay = Config.Pay.base + floor(#(dest - lastPos) / 1000 * Config.Pay.perKm)` ;
  `Bridge.AddMoney(src, Config.Account, pay, 'pop_livraison')` ; `run.paid += pay` ; `lastPos = dest`,
  `lastAt = os.time()`, `index += 1`. Notification `delivered`. Si c'était le dernier colis : mode à pied → tournée
  close, délai posé, notification `run_completed` (arg = `run.paid`) ; mode camionnette → notification `return_van`.
- **finish** (mode camionnette, tous livrés) : camionnette à ≤ `RETURN_DISTANCE` du point de spawn → caution rendue
  (`deposit_returned`) ; suppression du véhicule ; tournée close, délai posé, `run_completed`.
- **cancel** : véhicule supprimé, caution perdue, délai posé, `run_cancelled`.
- **Expiration** : `SetTimeout(30000)` en chaîne tant que `next(runs)` ; tournée expirée → véhicule supprimé,
  délai posé, `pop_livraison:client:runEnded(src, 'run_expired')`.
- **Arrêt** (`onResourceStop`) : supprime toutes les camionnettes.
- Suppression d'un véhicule : `DoesEntityExist(veh)` puis `DeleteEntity(veh)`.

### Client
- Blip du dépôt (`Config.Blip`, `L('blip_name')`). PNJ du dépôt par distance (boucle 1000/2500 ms, scénario
  `WORLD_HUMAN_CLIPBOARD`), `Bridge.Target.AddLocalEntity` ; sans PNJ : `AddBoxZone('pop_livraison_depot', …)`.
- Options du dépôt (distance `TARGET_DISTANCE`), `canInteract` sur l'état local :
  | label | canInteract | action |
  |---|---|---|
  | `L('target_start_vehicle', Config.Vehicle.deposit)` | `Config.Vehicle` et pas de tournée | `start(true)` |
  | `L('target_start_foot')` | pas de tournée | `start(false)` |
  | `L('target_finish')` | tournée camionnette et `index > total` | `pop_livraison:finish` |
  | `L('target_cancel')` | tournée en cours | `pop_livraison:cancel` |
  Icônes : `fa-solid fa-truck`, `fa-solid fa-box`, `fa-solid fa-flag-checkered`, `fa-solid fa-xmark`.
- `start` : `Callback.Await('pop_livraison:start', withVehicle)` → RunData. Camionnette : attendre
  `NetworkDoesNetworkIdExist(netId)` (≤ 5 s), `NetToVeh`, `TaskWarpPedIntoVehicle(ped, veh, -1)` ; clés QBCore :
  si `qb-vehiclekeys` est lancé → `TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))`
  (NOTE). Option sur la camionnette (`Bridge.Target.AddLocalEntity`) : `L('target_take')`, `fa-solid fa-box-open`,
  canInteract = pas de colis porté et adresse courante à ≤ `DOOR_ZONE_DISTANCE` du joueur.
- Adresse courante : blip (sprite 478, couleur 5, `SetBlipRoute(true)`, nom `L('blip_destination')`). Boucle tournée
  à 1000 ms : HUD (`timeLeft` décompté localement depuis la valeur serveur) ; à ≤ `DOOR_ZONE_DISTANCE` de la porte →
  `AddBoxZone('pop_livraison_door', xyz, vec3(1.5, 1.5, 2.5), w, { { label = L('target_deliver'),
  icon = 'fa-solid fa-box', distance = TARGET_DISTANCE, canInteract = (pas de camionnette) ou colis porté } })`,
  retirée au-delà ou au changement d'adresse.
- `step` : `return` si `index > total` ; sinon `deliver` si colis porté ou mode à pied et porte à ≤ 60 m ; `take` si
  mode camionnette et porte à ≤ 60 m ; sinon `drive`.
- **Prendre un colis** : `Bridge.Progress(L('taking'), Config.Durations.take, { anim = { dict = 'anim@heists@box_carry@',
  clip = 'idle', flag = 49 } })` → prop `BOX_PROP` local attaché (os 60309, offsets `0.025, 0.08, 0.255, -145.0,
  290.0, 0.0`), anim `anim@heists@box_carry@` / `idle` flag 49. Boucle `Wait(0)` **seulement pendant le port** :
  désactive les contrôles 21, 22, 23, 24, 25 ; `Config.Keys.Cancel.control` → reposer le colis (prop supprimé).
- **Livrer** : `Bridge.Progress(L('delivering'), Config.Durations.deliver, { anim = { dict = 'pickup_object',
  clip = 'putdown_low', flag = 0 } })` → `pop_livraison:deliver` ; succès → prop supprimé, adresse suivante (ou fin).
- Fin de tournée (succès, abandon, `runEnded`) : blips, zones, target camionnette, prop, HUD (`show = false`) nettoyés.
- Arrêt de la ressource : idem + PNJ.

---

## 12. Règles de sécurité (serveur, obligatoires)

Le client n'envoie que `withVehicle`. Adresses, paie, temps, caution : serveur uniquement.

**Commun** : verrou `busy[src]` → `busy` (libéré dans tous les cas) ; `Bridge.GetIdentifier` non nil ; joueur mort →
`error` ; anti-spam du template actif. Une tournée est liée au personnage, à son instance et à sa date d'expiration.
Quand un métier est configuré, le métier et le service sont revérifiés à chaque action.

**`start`**
1. Pas de tournée en cours → sinon `already_on_run`. 2. `Config.Job` faux ou `Bridge.HasJob(src, Config.Job)` avec le service actif, sinon
`wrong_job`. 3. Délai par identifiant → `cooldown`. 4. `Bridge.IsNear(src, Config.Depot.coords, ACTION_DISTANCE)`,
sinon `too_far`. 5. `withVehicle == true` seulement si `Config.Vehicle` ; caution retirée avant toute création ;
toute erreur après retrait → caution rendue.

**`deliver`**
1. Tournée en cours et `index <= total`, sinon `no_run`.
2. `Bridge.IsNear(src, adresse courante, ACTION_DISTANCE)`, sinon `too_far`.
3. `os.time() - lastAt >= #(adresse - lastPos) / MAX_SPEED`, sinon `too_fast` (rien n'est payé ; l'adresse reste à
   livrer).
4. Mode camionnette : véhicule existant (sinon `vehicle_missing`) et à ≤ `VEHICLE_DISTANCE` de l'adresse
   (`GetEntityCoords(veh)` serveur), sinon `vehicle_too_far`.
5. `index` incrémenté **avant** `Bridge.AddMoney` (pas de double paie) puis restauré si le versement échoue.

**`finish`** : tournée camionnette en cours, sinon `no_run` ; `index > total`, sinon `run_not_done` ; caution rendue
si le véhicule est intact à ≤ `RETURN_DISTANCE` du spawn. Véhicule intact mais trop éloigné → `vehicle_too_far` ;
camionnette détruite ou absente → pas de caution ; joueur à
≤ `ACTION_DISTANCE` du PNJ, sinon `too_far`.

**`cancel`** : tournée en cours, sinon `no_run` ; joueur près du dépôt, sinon `too_far`.

**Véhicule** : jamais créé par le client ; seul le serveur le supprime ; un joueur n'a qu'une camionnette ; le
statebag `pop_temporary` est posé côté serveur (réplication `true`), jamais lu comme preuve de propriété.

---

## 13. Checklist de livraison (auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques à `templates/pop_base`.
- 10 locales complètes ; aucun texte en dur.
- `Wait(0)` seulement pendant le port du colis et `Bridge.Progress` ; < 0.02 ms hors tournée.
- Camionnette supprimée à la fin, à l'abandon, à l'expiration, au drop/unload, à l'arrêt.
- ESX, QBCore, Qbox ; ox_target, qb-target, prompt natif ; standalone : paie impossible (`AddMoney` false) → README.
