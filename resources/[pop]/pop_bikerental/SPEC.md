# pop_bikerental : SPEC (contrat commun Serveur / Client / NUI)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`, `Pop.*`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `[illegal]/vanguard_bikerental/` (client, server).
> Failles de l'ancien script corrigées : position de sortie et modèle envoyés par le client, prix codé en dur,
> clé donnée par un event client. **OneSync obligatoire** (création de véhicules côté serveur).

---

## 1. Description et fonctionnalités

Location de vélos et de scooters à des points fixes, payée à la prise, avec une caution rendue au retour.

1. **Louer** : au comptoir d'un point (`Config.Locations`), options de target / prompt « Louer BMX (50 $) » une par
   véhicule de `Config.Vehicles`. Le serveur encaisse **prix + caution** (`Config.Account`), crée le véhicule sur la
   place du point et remet la clé via `pop_vehiclekeys` s'il est démarré.
2. **Rouler** : un petit minuteur discret s'affiche quand on est sur le véhicule loué (et toujours dans les
   2 dernières minutes). Avertissement à 2 minutes.
3. **Rendre** : à **n'importe quel** point, véhicule garé à côté du comptoir : option « Rendre le véhicule ».
   Le véhicule est supprimé, la caution est rendue s'il n'est pas abîmé.
4. **Expiration** (`Config.Duration` minutes) : le véhicule est supprimé, la caution est perdue. Idem s'il est détruit
   ou supprimé, ou si le loueur se déconnecte.

Une location à la fois par joueur. Les véhicules portent le statebag `pop_temporary = true` (contrat POP).

**Hors périmètre** : prolongation, location à plusieurs, véhicules d'exposition, paiement à la minute.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_bikerental/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes pop_base + section 8)
  README.md               SERVEUR   (installation, OneSync, points, standalone : prix et caution à 0)
  bridge/ shared/         copiés par l'intégrateur (ne pas modifier)
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    blips, targets, minuteur
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/                copié par l'intégrateur (ne pas modifier)
```

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_bikerental'
author 'POP'
version '1.0.0'
description 'POP Bike Rental - rent bikes and scooters'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

Constantes :
| Constante | Valeur | Fichier |
|---|---|---|
| `ACTION_DISTANCE` | 2.0 m (+ 1.0 de tolérance serveur) | client (target), serveur |
| `RETURN_DISTANCE` | 10.0 m (véhicule ↔ comptoir) | serveur |
| `SPAWN_CLEAR` | 2.5 m | serveur |
| `SPAWN_TIMEOUT` | 3000 ms | serveur |
| `WARN_BEFORE` | 120 s | serveur (avertissement), client (minuteur toujours visible) |
| `MIN_HEALTH` | 300.0 (moteur **et** carrosserie au-dessus → caution rendue) | serveur |
| `TICK` | 15000 ms (active seulement s'il y a des locations) | serveur |

---

## 3. Données

Serveur :
```lua
Rentals[src] = { plate = 'RENT1234', entity = 1234, expires = os.time() + Config.Duration * 60,
                 deposit = 100, warned = false }
```
Plaque : `'RENT'` + 4 chiffres aléatoires, unique (absente de `Rentals` et de `GetAllVehicles()`, 10 essais max sinon `error`).
Statebags d'entité posés à la création (serveur, répliqués) : `pop_temporary = true`, `fuel = 100.0`.

Client : `rental = { netId, expiresAt = GetGameTimer() + seconds * 1000 } | nil`.

---

## 4. Events

| Event | Sens | Paramètres | Rôle |
|---|---|---|---|
| `pop_bikerental:client:ended` | S → C (le loueur) | aucun | Location terminée (rendue, expirée, perdue) : `rental = nil`, minuteur masqué |

Aucun event client → serveur.

---

## 5. Callbacks

Convention : `ok, reason | nil, ...`. Échec → le client notifie `L(reason or 'error', arg)` ; succès → le serveur
notifie. `nil` = `error`.

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_bikerental:rent` | `location` (int), `index` (int, dans `Config.Vehicles`) | `ok, reason, netId, seconds` |
| `pop_bikerental:giveBack` | `location` (int) | `ok, reason` |

Raisons : `error`, `busy`, `too_far`, `already_renting`, `spawn_blocked`, `not_enough_money`, `no_rental`,
`vehicle_not_here`, `vehicle_occupied`.

---

## 6. Messages NUI

L'interface ne prend **jamais** le focus. Aucun callback JS → Lua propre.

### Lua → JS
**`pop_bikerental:timer`** : envoyé seulement quand l'affichage change (le JS décompte seul, aucune synchro par seconde).
```json
{ "action": "pop_bikerental:timer", "show": true, "seconds": 1712 }
```
```json
{ "action": "pop_bikerental:timer", "show": false }
```

### Interface (Dev NUI)
- `index.html` : base pop_base + `style.css`. `#app` → `<div id="rent" class="pop-panel pop-fade"><span class="pop-small" data-locale="timer_label"></span> <span id="rent-time"></span></div>`.
- `script.js` : `Pop.on('pop_bikerental:timer')` : `show` → mémorise la fin (`Date.now() + seconds * 1000`), affiche,
  `setInterval` 1 s qui écrit `MM:SS` dans `#rent-time` (≤ 120 s restantes → couleur `--pop-danger`) ; à 0 ou
  `show = false` → arrêt de l'intervalle et masque. Aucun texte en dur.
- `style.css` : `#rent { position: fixed; right: 24px; bottom: 72px; font-variant-numeric: tabular-nums; }`
  (au-dessus d'un éventuel compteur pop_kilometrage en `bottom: 24px`), fond `--pop-bg`, une couleur d'accent, aucun
  dégradé, transition `.pop-fade`. RTL : `right: auto; left: 24px`.

---

## 7. Exports publics (serveur)

| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_bikerental:GetRental(src)` | `{ plate, expires }` \| `nil` | location en cours |
| `exports.pop_bikerental:IsRental(plate)` | bool | plaque louée par ce script |

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_bikerental ──────────────────────────────────────────

-- Compte débité / crédité : 'cash' | 'bank'. En standalone (aucun argent), mettre prix et caution à 0.
Config.Account = 'cash'

-- Durée d'une location (minutes) et caution rendue au retour (véhicule non abîmé).
Config.Duration = 30
Config.Deposit  = 100

-- Véhicules proposés partout. type : GetVehicleType ('bike' pour vélos et scooters).
Config.Vehicles = {
    { model = 'bmx',     price = 50,  type = 'bike' },
    { model = 'cruiser', price = 50,  type = 'bike' },
    { model = 'faggio',  price = 150, type = 'bike' },
}

-- Points de location. coords : comptoir. spawn : place de sortie (x, y, z, cap).
Config.Locations = {
    { coords = vec3(-512.29, -251.18, 35.77), spawn = vec4(-509.6, -253.9, 35.1, 202.75), blip = true },
    { coords = vec3(1882.68, 3696.54, 33.61), spawn = vec4(1885.4, 3699.0, 32.9, 218.75), blip = true },
}
```

---

## 9. Locales

10 fichiers (Dev Serveur) : kit commun inchangé + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `blip` | Bike rental | Location de vélos |
| `rent_target` | Rent %s ($%s) | Louer %s (%s $) |
| `return_target` | Return the vehicle | Rendre le véhicule |
| `rented` | Rented for %s min. Deposit of $%s refunded on return | Loué pour %s min. Caution de %s $ rendue au retour |
| `rented_plain` | Rented for %s min | Loué pour %s min |
| `returned` | Vehicle returned, deposit of $%s refunded | Véhicule rendu, caution de %s $ rendue |
| `returned_plain` | Vehicle returned | Véhicule rendu |
| `returned_damaged` | Vehicle returned damaged: deposit kept | Véhicule rendu abîmé : caution gardée |
| `expiring` | Your rental ends in 2 minutes | Votre location se termine dans 2 minutes |
| `expired` | Rental over: vehicle taken back, deposit kept | Location terminée : véhicule repris, caution gardée |
| `lost` | Rental vehicle lost: deposit kept | Véhicule de location perdu : caution gardée |
| `already_renting` | You already have a rental | Vous avez déjà une location |
| `no_rental` | You have no rental | Vous n'avez aucune location |
| `vehicle_not_here` | Bring the vehicle next to the counter | Ramenez le véhicule près du comptoir |
| `vehicle_occupied` | Get off the vehicle first | Descendez d'abord du véhicule |
| `spawn_blocked` | The spot is blocked | La place est occupée |
| `timer_label` | Rental | Location |

`rented_plain` / `returned_plain` : utilisées quand la caution vaut 0.

Clés de base réutilisées : `too_far`, `not_enough_money`, `busy`, `error`.

---

## 10. Schéma SQL

Aucun (les locations ne survivent pas à un redémarrage : véhicules supprimés à l'arrêt de la ressource).

---

## 11. Comportement client (`client/main.lua`)

- **Blips** : un par point avec `blip` (sprite 226, couleur 0, échelle 0.7, `SetBlipAsShortRange`, nom `L('blip')`).
- **Comptoirs** : `Bridge.Target.AddBoxZone('pop_bikerental_' .. i, loc.coords, vec3(1.5, 1.5, 2.0), 0.0, options)` ;
  options (toutes `distance = ACTION_DISTANCE`) :
  - une par véhicule `v` (index `j`) : `label = L('rent_target', nom, math.floor(v.price) + math.floor(Config.Deposit))` (entiers ≥ 0, même règle que le serveur) avec
    `nom = GetLabelText(GetDisplayNameFromVehicleModel(joaat(v.model)))` (le modèle si `NULL`), icône
    `fa-solid fa-bicycle`, `canInteract = rental == nil`, `onSelect` → `Callback.Await('pop_bikerental:rent', i, j)` ;
    succès → `rental = { netId, expiresAt }` ; échec → notification ;
  - `label = L('return_target')`, icône `fa-solid fa-rotate-left`, `canInteract = true` (toujours visible, le serveur répond `no_rental`), `onSelect` →
    `Callback.Await('pop_bikerental:giveBack', i)` ; échec → notification.
- **Minuteur** : une boucle seulement quand `rental` existe (démarrée à la location, finie à `ended`) : `Wait(1000)` ;
  `visible = (NetToVeh(rental.netId) == GetVehiclePedIsIn(ped, false) and ~= 0) or restant <= WARN_BEFORE` ;
  envoie `pop_bikerental:timer` (`seconds` = restant arrondi) seulement si `visible` change.
- **`pop_bikerental:client:ended`** : `rental = nil`, `show = false`.
- **Arrêt** : minuteur masqué, blips supprimés.

---

## 12. Comportement serveur et sécurité (`server/main.lua`)

**`pop_bikerental:rent(location, index)`**
1. Verrou `busy[src]` (libéré dans tous les cas) ; joueur valide ; `math.type` entier et `Config.Locations[location]`,
   `Config.Vehicles[index]` existent, sinon `error`.
2. `Bridge.IsNear(src, loc.coords, ACTION_DISTANCE + 1.0)`, sinon `too_far`.
3. `Rentals[src]` absent, sinon `already_renting`.
4. Aucun véhicule à moins de `SPAWN_CLEAR` de `loc.spawn` (`GetAllVehicles()`), sinon `spawn_blocked`.
5. `total = v.price + Config.Deposit` (entiers ≥ 0 lus dans la config) ; `total > 0` →
   `Bridge.RemoveMoney(src, Config.Account, total, 'pop_bikerental')`, sinon `not_enough_money`.
6. Plaque générée ; `veh = CreateVehicleServerSetter(joaat(v.model), v.type or 'bike', x, y, z, w)` ; attente
   `DoesEntityExist` (`SPAWN_TIMEOUT`) ; échec → entité supprimée si elle apparaît plus tard, puis remboursement
   intégral (`Bridge.AddMoney`) et `error`. Joueur déconnecté pendant l'attente → véhicule supprimé, remboursement
   si `Bridge.GetPlayer(src)` existe encore (sinon impossible, documenté dans le README), `error`.
   `SetEntityOrphanMode(veh, 2)`, `SetVehicleNumberPlateText(veh, plate)`, `SetVehicleDoorsLocked(veh, 1)`, statebags.
7. `Rentals[src] = { plate, entity = veh, expires, deposit = Config.Deposit, warned = false }` ; démarre la boucle `TICK`
   si elle ne tourne pas.
8. `pop_vehiclekeys` démarré → `exports.pop_vehiclekeys:GiveKey(src, plate)` (`pcall`).
9. Notification `L('rented', Config.Duration, Config.Deposit)` (`L('rented_plain', Config.Duration)` si caution 0), retour `true, nil, netId, Config.Duration * 60`.

**`pop_bikerental:giveBack(location)`**
1. Verrou ; location valide ; `Rentals[src]`, sinon `no_rental` ; près du comptoir, sinon `too_far`.
2. Entité existante et non épave (`GetVehicleEngineHealth <= -3999` ou `GetVehicleBodyHealth <= 0`), sinon fin
   `lost` (ci-dessous) et `no_rental`.
3. `#(GetEntityCoords(veh) - loc.coords) <= RETURN_DISTANCE`, sinon `vehicle_not_here`.
4. Aucun joueur à bord (parcours de `GetPlayers()` : `GetVehiclePedIsIn(GetPlayerPed(id), false) == veh`), sinon
   `vehicle_occupied`.
5. `ok = GetVehicleEngineHealth(veh) > MIN_HEALTH and GetVehicleBodyHealth(veh) > MIN_HEALTH`.
6. `finish(src)` (ci-dessous) ; `deposit == 0` → notification `returned_plain` ; sinon `ok` →
   `Bridge.AddMoney(src, Config.Account, deposit, 'pop_bikerental')`, notification `L('returned', deposit)` ; sinon
   `returned_damaged`. Retour `true`.

**`finish(src)`** : `r = Rentals[src]`, `Rentals[src] = nil` **avant** `DeleteEntity(r.entity)` (s'il existe) ; clé
reprise (`exports.pop_vehiclekeys:RemoveKey(src, r.plate, true)` si démarré, `pcall`, **même joueur déconnecté**) ;
`TriggerClientEvent('pop_bikerental:client:ended', src)` et notification seulement si en ligne.

**Boucle `TICK`** (s'arrête quand `Rentals` est vide) : pour chaque location :
- entité disparue ou épave → `finish` + notification `lost` ;
- `expires - now <= WARN_BEFORE` et pas `warned` → notification `expiring` (`warning`), `warned = true` ;
- `now >= expires` → `finish` (véhicule supprimé même occupé) + notification `expired`.

`Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded` : `finish(src)` (caution perdue), `busy[src]` nettoyé.
**Arrêt de la ressource** : toutes les entités louées supprimées et clés reprises (`RemoveKey` en `pcall`), aucun
remboursement.

**Règles générales**
- Le client n'envoie que deux index : modèle, type, prix, caution, place et plaque viennent de la config et du serveur.
- **Anti-duplication** : verrou par joueur, une location par joueur, place vérifiée libre, `Rentals[src] = nil` avant
  suppression et avant remboursement (pas de double caution), plaque unique.
- Aucun `RegisterNetEvent` serveur ; anti-spam du template actif. `Config.Debug` : log des locations / retours.

---

## 13. Performance
- Client : aucune boucle sans location ; minuteur à 1000 ms pendant une location ; comptoirs via le bridge.
- Serveur : aucune boucle sans location ; 15 s sinon.

## 14. Checklist auditeur
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`. 10 locales, aucun texte en dur.
- Impossible de louer deux fois, de choisir le prix, le modèle ou la position, d'encaisser deux fois la caution.
- Expiration, déconnexion et destruction suppriment toujours le véhicule.
