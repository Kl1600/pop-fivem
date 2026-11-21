# pop_sabot : SPEC (contrat commun Serveur / Client)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `tab_inventory/sabot_*.lua`.

---

## 1. Description et fonctionnalités

Sabot de roue façon GTA 6 : un agent pose le sabot, le véhicule ne bouge plus. Pour l'enlever : l'agent le retire
vite, ou quelqu'un le **découpe** à la disqueuse (long, bruyant, la police est prévenue dès le début).

- **Poser** : un membre d'un job autorisé (`Config.Jobs`, en service) utilise l'item `Config.Items.clamp` près d'un
  véhicule vide → barre de progression → l'item est retiré, le véhicule est saboté.
- **Effet** : véhicule figé, moteur coupé, impossible à conduire. Prop de sabot fixé sur la roue avant gauche.
- **Retirer** (job autorisé) : interaction sur le sabot → barre → sabot retiré, l'item est rendu à l'agent.
- **Découper** (tout le monde, avec l'outil `Config.Items.cutter`) : barre longue → sabot détruit (aucun item rendu),
  alerte police au début si `Config.CutAlert`.
- **Synchro par statebag** du véhicule : `Entity(veh).state.popClamp = true` (écrit par le serveur, répliqué).

**Performance** : aucune boucle si le client ne connaît aucun véhicule saboté ; sinon une boucle à 250 ms à moins
de 10 m d'un véhicule saboté, 1000 ms au-delà.
Props **locaux**. Serveur : aucune boucle.

**Hors périmètre** : amende, fourrière, persistance après suppression du véhicule ou redémarrage.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_sabot/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR
  README.md               SERVEUR   (items, modèle du prop à streamer, exports)
  bridge/server.lua       SERVEUR   copie STRICTE du template
  bridge/client.lua       CLIENT    copie STRICTE
  shared/callback.lua     SERVEUR   copie STRICTE
  shared/locale.lua       SERVEUR   copie STRICTE
  common/clamp.lua        SERVEUR   constantes (chargé des deux côtés)
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT
  web/index.html          CLIENT    minimal : kit seul (sans #app, sans script.js)
  web/kit/pop.css, pop.js CLIENT    copie STRICTE
```

**Pas de NUI propre au script** (HUD du kit seulement). Aucun Dev NUI.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_sabot'
author 'POP'
version '1.0.0'
description 'POP Sabot - wheel clamp'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua', 'common/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

---

## 3. Données

### `common/clamp.lua`
```lua
Clamp = {}
Clamp.STATE           = 'popClamp' -- clé du statebag véhicule (true ou nil)
Clamp.PLACE_DISTANCE  = 3.0        -- client : recherche du véhicule à l'utilisation de l'item
Clamp.ACTION_DISTANCE = 4.0        -- serveur : Bridge.IsNear sur le véhicule
Clamp.TARGET_DISTANCE = 2.0        -- client : interaction sur le sabot
Clamp.PROP_DISTANCE   = 60.0       -- client : prop créé en deçà, supprimé au-delà de +20 m
```

### État
- Serveur : table de référence `clampedNet[netId] = true` (lue par les callbacks et `IsClamped`), copiée dans le
  statebag `Entity(veh).state:set(Clamp.STATE, true, true)` à la pose ; `nil` au retrait. Nettoyée sur
  `entityRemoved`. `cutStart[src] = { netId = int, t = GetGameTimer() }` (ms) pendant une découpe.
- Client : `clamped[veh] = { prop = handle|nil, target = id|nil, warned = bool }`.

---

## 4. Events

| Event | Sens | Paramètres | Destinataire | Rôle |
|---|---|---|---|---|
| `pop_sabot:client:startPlace` | S → C | aucun | le joueur | Après utilisation de l'item (job OK) : chercher le véhicule, lancer la pose |
| `pop_sabot:client:cutAlert` | S → C | `coords` (`{ x, y, z }`) | policiers en service (`Config.PoliceJobs`) | Notification + blip temporaire |

Aucun event client → serveur (callbacks uniquement).

---

## 5. Callbacks

Convention : `ok, reason, arg`. Échec → le client notifie `L(reason or 'error', arg)`. Succès → serveur notifie.

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_sabot:place` | `netId` (int) | `ok, reason, arg` |
| `pop_sabot:remove` | `netId` (int) | `ok, reason, arg` |
| `pop_sabot:cut` | `netId` (int), `phase` (`'start'` \| `'finish'`) | `ok, reason, arg` |

`cut` en deux temps : `'start'` **avant** la barre (contrôles + alerte police), `'finish'` **après** la barre
(applique). Le serveur refuse un `finish` trop tôt (section 12).

Raisons : `error`, `wrong_job`, `no_vehicle`, `too_far`, `already_clamped`, `not_clamped`, `vehicle_occupied`,
`missing_item` (arg = `L('item_clamp')` ou `L('item_cutter')`), `busy`.

---

## 6. NUI

Pas de NUI propre. Barres de progression et prompt via le kit (bridge).

---

## 7. Exports publics (serveur)

| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_sabot:IsClamped(netId)` | bool | |
| `exports.pop_sabot:SetClamped(netId, state)` | bool | pose / retire sans item ni job (fourrière, admin, autre script) ; false si véhicule introuvable |

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_sabot ───────────────────────────────────────────────

-- Items (à déclarer dans votre inventaire, voir README). cutter = nil : découpe impossible.
Config.Items = {
    clamp  = 'wheel_clamp',   -- poser (rendu quand un agent le retire)
    cutter = 'angle_grinder', -- découper (non consommé)
}

-- Jobs qui posent et retirent le sabot (format Bridge.HasJob, en service).
Config.Jobs = { 'police', 'mechanic' }

-- Durées (ms).
Config.Durations = { place = 5000, remove = 4000, cut = 20000 }

-- Alerte police quand quelqu'un commence à découper un sabot.
Config.CutAlert   = true
Config.PoliceJobs = { 'police', 'sheriff' }
Config.BlipTime   = 60 -- secondes

-- Prop du sabot (modèle à streamer, voir README). Modèle absent = sabot actif sans prop.
Config.Prop = {
    model    = 'prop_clamp',
    bone     = 'wheel_lf',
    offset   = vec3(-0.1, 0.15, -0.3),
    rotation = vec3(180.0, 200.0, 90.0),
}
```

---

## 9. Locales

10 fichiers (écrits par le Dev Serveur).

| Clé | en | fr |
|---|---|---|
| `item_clamp` | Wheel clamp | Sabot de roue |
| `item_cutter` | Angle grinder | Disqueuse |
| `no_vehicle` | No vehicle nearby | Aucun véhicule à proximité |
| `already_clamped` | This vehicle already has a clamp | Ce véhicule a déjà un sabot |
| `not_clamped` | This vehicle has no clamp | Ce véhicule n'a pas de sabot |
| `vehicle_occupied` | Someone is in the driver's seat | Quelqu'un est au volant |
| `vehicle_incompatible` | This vehicle can't be clamped | Ce véhicule ne peut pas recevoir de sabot |
| `placing` | Fitting the clamp... | Pose du sabot... |
| `removing` | Removing the clamp... | Retrait du sabot... |
| `cutting` | Cutting the clamp... | Découpe du sabot... |
| `placed` | Clamp fitted: vehicle immobilized | Sabot posé : véhicule immobilisé |
| `removed` | Clamp removed | Sabot retiré |
| `cut` | Clamp cut off | Sabot découpé |
| `clamped_driver` | This vehicle is clamped | Ce véhicule a un sabot |
| `target_remove` | Remove the clamp | Retirer le sabot |
| `target_cut` | Cut the clamp | Découper le sabot |
| `police_alert` | Someone is cutting a wheel clamp | Quelqu'un découpe un sabot de roue |
| `police_blip` | Clamp cutting | Découpe de sabot |

Clés de base réutilisées : `wrong_job`, `too_far`, `missing_item`, `busy`, `error`, `progress_cancelled`.

---

## 10. Schéma SQL

Aucun.

---

## 11. Comportement client (`client/main.lua`)

- **État job** : `isJob` = job local dans `Config.Jobs` (noms, ou clés si table à grades) **et** `onDuty`, mis à
  jour par `Bridge.OnPlayerLoaded` / `Bridge.OnJobUpdate`.
- **Suivi des sabots** :
  - `AddStateBagChangeHandler(Clamp.STATE, nil, fn(bagName, _, value))` : `GetEntityFromStateBagName(bagName)`
    (si 0, réessayer toutes les 100 ms pendant 2 s max) ; `value == true` → `clamped[veh] = {}` ; sinon `clear(veh)`.
  - Au chargement du joueur (`Bridge.OnPlayerLoaded`) : un seul passage sur `GetGamePool('CVehicle')` pour lire
    `Entity(veh).state[Clamp.STATE]` (véhicules déjà présents).
- **Boucle** (démarrée quand `clamped` devient non vide, s'arrête quand il est vide), `Wait(1000)` :
  - véhicule disparu → `clear(veh)` ;
  - `NetworkGetEntityOwner(veh) == PlayerId()` → `FreezeEntityPosition(veh, true)` + `SetVehicleUndriveable(veh,
    true)` (aussi **dès l'entrée en suivi**, sans attendre la boucle) ;
  - joueur au volant → `SetVehicleEngineOn(veh, false, true, true)`, `SetVehicleUndriveable(veh, true)`,
    notification `clamped_driver` une fois par entrée (`warned`) ;
  - distance ≤ `Clamp.PROP_DISTANCE` et pas de prop → créer ; > `Clamp.PROP_DISTANCE + 20` → supprimer prop + target ;
  - `Wait(250)` si un véhicule saboté est à moins de 10 m, sinon `Wait(1000)`.
  - NOTE à vérifier en jeu : un véhicule qui sort de portée puis revient doit être resuivi par le handler de
    statebag (réplication initiale) ; sinon ajouter un scan léger du pool.
- **Prop (visuel seulement)** : si `IsModelInCdimage(Config.Prop.model)` faux → pas de prop. Sinon
  `RequestModel` (timeout 3 s), `CreateObject(hash, x, y, z + 2.0, false, false, false)`, collisions coupées,
  `AttachEntityToEntity(prop, veh, GetEntityBoneIndexByName(veh, Config.Prop.bone), offset.x, offset.y, offset.z,
  rotation.x, rotation.y, rotation.z, false, false, false, false, 2, true)`, `SetModelAsNoLongerNeeded`.
  Puis **toujours** `target = Bridge.Target.AddLocalEntity(veh, options)` : le prop, sans collision, est invisible
  pour ox_target / qb-target.
- **Options de target** (`distance = Clamp.TARGET_DISTANCE`) :

  | label | icon | canInteract | Déroulé |
  |---|---|---|---|
  | `L('target_remove')` | `fa-solid fa-key` | `isJob` et près de la roue | barre `Config.Durations.remove`, `L('removing')` → `pop_sabot:remove(netId)` |
  | `L('target_cut')` | `fa-solid fa-screwdriver-wrench` | `not isJob`, `Config.Items.cutter ~= nil` et près de la roue | `pop_sabot:cut(netId, 'start')` ; si ok : son `PlaySoundFromEntity(soundId, 'Drill_Pin_Break', ped, 'DLC_HEIST_FLEECA_SOUNDSET', true, 0)` rejoué toutes les 3,5 s pendant la barre, barre `Config.Durations.cut`, `L('cutting')` → `pop_sabot:cut(netId, 'finish')` |

  Anim (pose, retrait, découpe) : `anim@amb@clubhouse@tutorial@bkr_tut_ig3@` / `machinic_loop_mechandplayer`, flag 1.
  Avant chaque barre : `Bridge.IsBusy()` → `busy` ; distance à la roue (`GetWorldPositionOfEntityBone` sur
  `Config.Prop.bone`, sinon centre du véhicule) ≤ `Clamp.TARGET_DISTANCE` → sinon `too_far` ;
  `IsVehicleSeatFree(veh, -1)` → sinon `vehicle_occupied`.
- **`startPlace`** : ignoré si `Bridge.IsBusy()` ou en véhicule. Véhicule le plus proche (`GetGamePool('CVehicle')`,
  ≤ `Clamp.PLACE_DISTANCE`) ; aucun → `no_vehicle` ; non réseau ou os `Config.Prop.bone` absent
  (`GetEntityBoneIndexByName == -1`) → `vehicle_incompatible` ; déjà saboté → `already_clamped`.
  Barre `Config.Durations.place`, `L('placing')` → `pop_sabot:place(netId)`.
- **`cutAlert`** : notification `police_alert` (`warning`) + blip (sprite 161, couleur 1, échelle 0.9, nom
  `L('police_blip')`) supprimé après `Config.BlipTime` secondes.
- **`clear(veh)`** : `Bridge.Target.Remove(target)`, supprime le prop ; si propriétaire →
  `FreezeEntityPosition(veh, false)`, `SetVehicleUndriveable(veh, false)` ; `clamped[veh] = nil`.
- **Arrêt** : `clear` de tous les véhicules connus, blips supprimés.

---

## 12. Sécurité serveur (`server/main.lua`)

**Item utilisable** `Config.Items.clamp` → job autorisé **et** en service, sinon notification `wrong_job` ; puis
`startPlace`. Rien n'est retiré ici.

**Commun aux 3 callbacks**
1. `math.type(netId) == 'integer'`, `veh = NetworkGetEntityFromNetworkId(netId)`, `DoesEntityExist(veh)` et
   `GetEntityType(veh) == 2`, sinon `no_vehicle`.
2. `Bridge.IsNear(src, GetEntityCoords(veh), Clamp.ACTION_DISTANCE)`, sinon `too_far`.
3. Verrou `busy[src]` pendant le traitement (libéré dans tous les cas).
4. Joueur vivant (`not Bridge.IsDead(src)`) et à pied (`GetVehiclePedIsIn(GetPlayerPed(src), false) == 0`), sinon `error`.

**`place`** : job autorisé en service (`wrong_job`) ; pas déjà saboté (`already_clamped`) ;
`GetPedInVehicleSeat(veh, -1) == 0` (`vehicle_occupied`) ; `Bridge.RemoveItem(src, Config.Items.clamp, 1)`
(sinon `missing_item` + `L('item_clamp')`) ; `clampedNet[netId] = true`, `state:set(Clamp.STATE, true, true)`,
`FreezeEntityPosition(veh, true)` (demandé au propriétaire actuel, maintenu par les clients), notification `placed`.

**`remove`** : job autorisé en service (`wrong_job`) ; saboté (`not_clamped`) ; `clampedNet[netId] = nil`,
`state:set(Clamp.STATE, nil, true)`,
`FreezeEntityPosition(veh, false)` ; `Bridge.AddItem(src, Config.Items.clamp, 1)` (si plein : rien rendu, jamais
de doublon) ; notification `removed`.

**`cut`**
- `phase` vaut `'start'` ou `'finish'`, sinon `error`. `Config.Items.cutter` non nil, sinon `error`.
- Saboté (`not_clamped`) ; `Bridge.HasItem(src, Config.Items.cutter)` (`missing_item` + `L('item_cutter')`).
- `start` : `cutStart[src] = { netId = netId, t = GetGameTimer() }` (ms) ; si `Config.CutAlert` → `cutAlert` (coords du
  véhicule) à chaque joueur de `Bridge.GetPlayers()` avec `Bridge.HasJob(p, Config.PoliceJobs)` et
  `Bridge.GetJob(p).onDuty`. Retour `true` sans notification.
- `finish` : `cutStart[src]` existe, même `netId`, `elapsed = GetGameTimer() - t` avec
  `elapsed >= Config.Durations.cut - 1000` **et** `elapsed <= Config.Durations.cut + 10000` (découpe expirée),
  sinon `error`. Puis `cutStart[src] = nil`, `clampedNet[netId] = nil`, `state:set(Clamp.STATE, nil, true)`, `FreezeEntityPosition(veh, false)`,
  **aucun item rendu**, notification `cut`.

**Exports** : mêmes contrôles d'entité (1) ; ni job ni item. `IsClamped` lit `clampedNet`. `SetClamped(netId,
false)` ne fait rien (pas de dégel) si le véhicule n'a pas de sabot.

**Règles générales** : la référence est `clampedNet` ; le statebag est écrit **uniquement** par le serveur
(réplication `true`). `AddStateBagChangeHandler(Clamp.STATE)` serveur : si la valeur diffère de `clampedNet[netId]`
(écriture d'un client propriétaire), la valeur de référence est rétablie. `clampedNet` nettoyé sur `entityRemoved`.
Journaux (`who(src)`, plaque) calculés seulement si `Config.Debug`. Aucun `RegisterNetEvent` serveur. `busy` et `cutStart` nettoyés dans
`Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded`.

---

## 13. Limites (README)
- Le modèle `prop_clamp` n'est pas dans le jeu de base : streamer un modèle de sabot (non fourni) ou jouer sans prop.
- Un véhicule supprimé (garage, fourrière, redémarrage) perd son sabot.
- Le blocage de conduite est appliqué par les clients (aucune native serveur ne l'interdit) ; le gel est demandé
  au propriétaire actuel par le serveur, puis maintenu par les clients.

## 14. Checklist auditeur
- Copies strictes ; 10 locales ; aucun texte en dur.
- Aucune boucle sans véhicule saboté connu ; props locaux uniquement ; aucun `Wait(0)` hors `Bridge.Progress`.
- La découpe ne peut pas se terminer avant la durée configurée ; le statebag n'est écrit que par le serveur.
