# pop_vehiclekeys : SPEC (contrat commun Serveur / Client)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).
> Modèle lu (pas copié) : `tab_inventory/vehiclekeys_*.lua`.

---

## 0. Prérequis bloquant : extension de `templates/pop_base` (Dev Serveur de ce script)

Une clé est un item avec la métadonnée `plate`. Il faut donc **lire les métadonnées** et **retirer une pile précise**.
Le bridge actuel ne sait pas le faire : on l'étend **dans le template** (règle du dépôt), puis on le recopie.
Ces ajouts ne cassent rien : nouvelles fonctions et nouveau paramètre optionnel. Le Dev Serveur de pop_vehiclekeys
les écrit dans `templates/pop_base/bridge/server.lua` **et** documente les 3 lignes dans `templates/pop_base/README.md`
(tableau « Bridge serveur »), puis copie le fichier dans `pop_vehiclekeys/bridge/server.lua`.

| Ajout | Retour | Règle |
|---|---|---|
| `Bridge.SupportsMetadata` | bool | `false` si `Bridge.Inventory == 'none'`, ou si inventaire `framework` avec ESX ou standalone ; `true` sinon |
| `Bridge.GetItems(src, item)` | `{ { slot = int\|nil, count = int, metadata = table }, ... }` | toutes les piles de l'item ; `metadata` jamais nil (`{}`) ; liste vide si rien |
| `Bridge.RemoveItem(src, item, count, metadata, slot)` | bool | **nouveau 5e paramètre optionnel** `slot`. S'il est donné : vérifier via `GetItems` que ce slot contient l'item avec `count` suffisant, puis retirer **ce slot** |

Adaptateurs (champ `items` ajouté à chaque adaptateur, `remove` reçoit `slot` en 5e argument) :

| Inventaire | `items(src, item)` | `remove(..., slot)` |
|---|---|---|
| pop_inventory | `exports.pop_inventory:Search(src, 'slots', item)` (API ox, voir NOTE) | `RemoveItem(src, item, count, metadata, slot)` |
| ox_inventory | `exports.ox_inventory:Search(src, 'slots', item)` → `{ slot, count, metadata }` | `RemoveItem(src, item, count, metadata, slot)` |
| qs-inventory | `exports['qs-inventory']:GetInventory(src)` → filtrer `name == item` (`amount`, `info`, `slot`) | `RemoveItem(src, item, count, slot)` |
| qb-inventory, ps-inventory, QBCore / Qbox (framework) | `Player.PlayerData.items` → filtrer (`amount`, `info`, `slot`) | qb v2 : `exports['qb-inventory']:RemoveItem(src, item, count, slot, RES)` ; sinon `Player.Functions.RemoveItem(item, count, slot)` |
| ESX (framework) | une seule entrée `{ slot = nil, count = n, metadata = {} }` si n > 0 | slot ignoré |
| none / standalone | `{}` | false |

`-- NOTE:` à laisser dans le code : « pop_inventory doit exposer `Search(src, 'slots', item)` comme ox_inventory ».
Les autres scripts de la vague (pop_douilles, pop_sabot…) n'ont pas besoin de ces ajouts, mais recopient le bridge
du template avant leur audit (copie stricte = règle de l'auditeur).

---

## 1. Description et fonctionnalités

Clés de véhicule en **items**, façon GTA 6 : télécommande avec bip et feux, moteur bloqué sans clé.

- **Clé = item** `Config.KeyItem` avec la métadonnée `{ plate = 'ABC123', description = 'Plate: ABC123' }`.
- **Verrouiller / déverrouiller** : touche `Config.LockKey` (modifiable par le joueur dans les raccourcis FiveM).
  Cible : le véhicule où l'on est, sinon le plus proche à `Config.LockDistance`. Le serveur vérifie la clé.
  Effet : animation de télécommande (à pied), bip, feux qui clignotent (2 fois = fermé, 1 fois = ouvert).
- **Utiliser l'item clé** depuis l'inventaire : verrouille / déverrouille le véhicule de **cette** plaque s'il est
  à portée ; chez un serrurier, fabrique un double.
- **Moteur sans clé** (`Config.RequireKeyForEngine`) : au volant sans la clé, le moteur reste coupé.
  Classes exemptées : `Config.NoKeyClasses` (vélos par défaut).
- **Serrurier** (`Config.Locksmith`) : utiliser sa clé sur place → barre de progression → double payé.
- **Donner une clé** : avec la fonction « donner » de l'inventaire (transfert d'item normal). Aucun event du script.

**Faille corrigée de l'ancien script** : `vehicle_keys:server:giveKey` donnait n'importe quelle clé à n'importe qui.
Ici **aucun event ni callback ne crée de clé à partir d'une plaque envoyée par le client**. Une clé n'apparaît que :
1. par l'export serveur `GiveKey` (concession, garage, admin…) ;
2. par un double chez le serrurier, **si le joueur possède déjà cette clé** (lue côté serveur dans son inventaire).
Pas de commande `/givekey`.

**Hors périmètre** : crochetage, câblage, alarme, clés partagées sans item, persistance du verrouillage.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_vehiclekeys/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes pop_base + section 8)
  README.md               SERVEUR   (installation, déclaration de l'item par inventaire, exports, limites)
  bridge/server.lua       SERVEUR   copie STRICTE du template APRÈS l'extension de la section 0
  bridge/client.lua       CLIENT    copie STRICTE de templates/pop_base/bridge/client.lua
  shared/callback.lua     SERVEUR   copie STRICTE
  shared/locale.lua       SERVEUR   copie STRICTE
  common/keys.lua         SERVEUR   constantes + Keys.Normalize (chargé des deux côtés)
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT
  web/index.html          CLIENT    minimal : kit seul (sans #app, sans script.js)
  web/kit/pop.css, pop.js CLIENT    copie STRICTE
```

**Pas de NUI propre au script** : `web/` ne sert qu'au HUD du kit (prompt, barre de progression). Aucun Dev NUI.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_vehiclekeys'
author 'POP'
version '1.0.0'
description 'POP Vehicle Keys - item keys, remote lock, engine lock'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua', 'common/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

---

## 3. Données

### `common/keys.lua`
```lua
Keys = {}
Keys.ACTION_DISTANCE = 3.0    -- serrurier (serveur : Bridge.IsNear)
Keys.LOCK_TOLERANCE  = 2.0    -- marge serveur ajoutée à Config.LockDistance
Keys.FX_RADIUS       = 30.0   -- joueurs qui reçoivent bip + feux
Keys.LOCK_COOLDOWN   = 1000   -- ms entre deux verrouillages d'un même joueur (serveur)
Keys.ENGINE_RECHECK  = 5000   -- ms : nouvelle demande au serveur tant qu'on est au volant sans clé
Keys.ENGINE_RECHECK_OWNED = 30000 -- ms : revérification même avec la clé (clé donnée / retirée en route)
Keys.ENGINE_RETRY    = 500    -- ms : nouvelle demande quand le serveur ne voit pas encore le joueur dans le véhicule

-- Plaque comparable : sans espaces, en majuscules, 8 caractères max. nil si vide ou invalide.
function Keys.Normalize(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('%s+', ''):upper()
    if plate == '' or #plate > 8 or plate:find('[^%w]') then return nil end
    return plate
end
```

### Métadonnée d'une clé
`{ plate = Keys.Normalize(plate), description = L('key_description', plate) }`. La comparaison se fait **toujours**
sur `Keys.Normalize(metadata.plate)`.

### Fonctions internes serveur (`server/main.lua`)
- `findKey(src, plate)` → `slot, metadata` ou nil : parcourt `Bridge.GetItems(src, Config.KeyItem)`.
- `hasKey(src, plate)` → bool.
- `giveKey(src, plate)` → bool : `Bridge.AddItem(src, Config.KeyItem, 1, meta)`.
- `toggleLock(src, veh)` → `ok, reason, locked` : logique commune au callback et à l'item (section 12).

---

## 4. Events

Aucun event client → serveur propre au script (tout passe par les callbacks).

| Event | Sens | Paramètres | Destinataire | Rôle |
|---|---|---|---|---|
| `pop_vehiclekeys:client:lockFx` | S → C | `netId` (int), `locked` (bool), `actor` (int, server id) | joueurs à ≤ `Keys.FX_RADIUS` du véhicule | Bip + feux ; `SetVehicleDoorsLocked` local ; si `actor` = soi et à pied : animation télécommande |
| `pop_vehiclekeys:client:startDuplicate` | S → C | `plate` (string), `price` (int) | le joueur | Lance la barre « double » chez le serrurier |

---

## 5. Callbacks

Convention : `ok (bool), reason (clé de locale) | nil, arg | nil`. Échec → le **client** notifie
`L(reason or 'error', arg)` en `error`. Succès → le **serveur** notifie. `nil` (timeout / anti-spam) = `error`.

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_vehiclekeys:toggleLock` | `netId` (int) | `ok, reason, locked` |
| `pop_vehiclekeys:hasKey` | `netId` (int) | `bool` (false si invalide) ; **`nil`** si le serveur ne voit pas encore le joueur dans ce véhicule |
| `pop_vehiclekeys:duplicate` | `plate` (string) | `ok, reason, arg` |

Raisons : `error`, `no_vehicle`, `too_far`, `no_key`, `cooldown` (arg = 1), `not_supported`,
`not_enough_money`, `inventory_full`, `busy`.

---

## 6. NUI

Pas de NUI propre. Seuls les messages du kit (`pop:prompt`, `pop:progress`) sont utilisés via le bridge.

---

## 7. Exports publics (serveur)

| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_vehiclekeys:GiveKey(src, plate)` | bool | ajoute une clé ; notifie `key_received` ; false si plaque invalide, inventaire plein ou `not SupportsMetadata` |
| `exports.pop_vehiclekeys:RemoveKey(src, plate, all)` | bool | retire une clé de cette plaque (toutes si `all == true`) ; notifie `key_removed` ; false si aucune |
| `exports.pop_vehiclekeys:HasKey(src, plate)` | bool | |

Ce sont les **seules** portes d'entrée pour créer une clé depuis un autre script. Exemple README :
`exports.pop_vehiclekeys:GiveKey(source, GetVehicleNumberPlateText(vehicle))`.

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_vehiclekeys ─────────────────────────────────────────

-- Item clé (à déclarer dans votre inventaire, voir README). Métadonnée : { plate = 'ABC123' }.
Config.KeyItem = 'vehicle_key'

-- Touche par défaut de la télécommande (chaque joueur peut la changer dans Paramètres > Raccourcis > FiveM).
Config.LockKey = 'U'

-- Portée de la télécommande (mètres).
Config.LockDistance = 10.0

-- Le moteur ne démarre pas sans la clé.
Config.RequireKeyForEngine = true

-- Classes de véhicules qui n'ont pas besoin de clé (13 = vélos).
Config.NoKeyClasses = { 13 }

-- Serrurier : utiliser sa clé sur place pour faire un double.
Config.Locksmith = {
    price    = 150,     -- prix d'un double (0 = gratuit ; en standalone, mettre 0)
    account  = 'cash',  -- 'cash' | 'bank'
    duration = 5000,    -- durée de fabrication (ms)
    blip     = true,
    locations = {
        vec3(170.0, -1799.4, 29.3), -- exemple, à ajuster
    },
}
```

---

## 9. Locales

10 fichiers (écrits par le Dev Serveur) : kit commun inchangé + clés ci-dessous sous `-- Textes propres au script :`.

| Clé | en | fr |
|---|---|---|
| `keymap_lock` | Vehicle: lock / unlock | Véhicule : verrouiller / déverrouiller |
| `locked` | Vehicle locked | Véhicule verrouillé |
| `unlocked` | Vehicle unlocked | Véhicule déverrouillé |
| `no_vehicle` | No vehicle nearby | Aucun véhicule à proximité |
| `no_key` | You don't have the keys to this vehicle | Vous n'avez pas les clés de ce véhicule |
| `no_key_engine` | No key: the engine won't start | Pas de clé : le moteur ne démarre pas |
| `key_description` | Plate: %s | Plaque : %s |
| `key_invalid` | This key isn't linked to a vehicle | Cette clé n'est liée à aucun véhicule |
| `key_received` | You received the key for %s | Vous avez reçu la clé de %s |
| `key_removed` | The key for %s was taken back | La clé de %s vous a été retirée |
| `vehicle_not_here` | Vehicle %s isn't nearby | Le véhicule %s n'est pas à proximité |
| `locksmith_blip` | Locksmith | Serrurier |
| `locksmith_target` | Duplicate a key | Faire un double |
| `locksmith_hint` | Use the key to copy from your inventory | Utilisez la clé à copier depuis votre inventaire |
| `duplicating` | Cutting a duplicate ($%s)... | Fabrication du double (%s $)... |
| `duplicated` | Duplicate made for %s | Double fabriqué pour %s |
| `not_supported` | Your inventory doesn't support vehicle keys | Votre inventaire ne gère pas les clés de véhicule |

Clés de base réutilisées : `too_far`, `not_enough_money`, `inventory_full`, `cooldown`, `busy`, `error`,
`progress_cancelled`. Logs console en anglais, sans `L()`.

---

## 10. Schéma SQL

Aucun. Les clés vivent dans l'inventaire ; le verrouillage n'est pas persistant (état du véhicule en jeu).

---

## 11. Comportement client (`client/main.lua`)

- **Télécommande** : `RegisterCommand('pop_vehiclekeys_lock', fn, false)` +
  `RegisterKeyMapping('pop_vehiclekeys_lock', L('keymap_lock'), 'keyboard', Config.LockKey)`.
  Au déclenchement (ignoré si `Bridge.IsBusy()` ou mort) : véhicule actuel, sinon le plus proche de
  `GetGamePool('CVehicle')` à ≤ `Config.LockDistance` (calcul **ponctuel**, pas de boucle). Aucun → `no_vehicle`.
  Véhicule non réseau (`NetworkGetEntityIsNetworked` faux) → `no_key`. Sinon
  `Callback.Await('pop_vehiclekeys:toggleLock', VehToNet(veh))` ; échec → notification.
- **`lockFx`** : `NetToVeh(netId)` ; s'il existe : `SetVehicleDoorsLocked(veh, locked and 2 or 1)`, son
  `PlaySoundFromEntity(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', veh, 'PI_Menu_Sounds', true, 0)`,
  feux : `SetVehicleLights(veh, 2)` / `0` toutes les 150 ms (2 cycles si fermé, 1 si ouvert), puis
  `SetVehicleLights(veh, 0)`. Si `actor == GetPlayerServerId(PlayerId())` et à pied : animation
  `anim@mp_player_intmenu@key_fob@` / `fob_click`, flag 48, 1000 ms (dict chargé avec timeout 1 s, puis `RemoveAnimDict`).
- **Moteur** (si `Config.RequireKeyForEngine` **et** `GlobalState.pop_vehiclekeys_supported ~= false`, attendu au plus 10 s
  au démarrage ; `false` = inventaire sans métadonnées → la boucle n'est pas lancée) : une boucle :
  - pas conducteur (`GetPedInVehicleSeat(veh, -1) ~= ped`) → `Wait(1000)`, oubli de l'état ;
  - conducteur d'un véhicule exempté (classe dans `Config.NoKeyClasses`) ou non réseau → `Wait(1000)` ;
  - nouveau véhicule, réponse encore inconnue, sans clé et dernier contrôle > `Keys.ENGINE_RECHECK`, ou **avec** clé
    et dernier contrôle > `Keys.ENGINE_RECHECK_OWNED` → `Callback.Await('pop_vehiclekeys:hasKey', netId)` ;
  - réponse `nil` (joueur pas encore vu dans le véhicule côté serveur, ou timeout) : état inchangé, **ni coupure
    moteur ni notification**, `Wait(Keys.ENGINE_RETRY)` puis nouvelle demande ;
  - sans clé : `SetVehicleEngineOn(veh, false, true, true)`, notification `no_key_engine` **une fois** par véhicule,
    `Wait(500)` ; avec clé : `Wait(1000)`.
- **Serrurier** : pour chaque `Config.Locksmith.locations[i]` : blip si `blip` (sprite 134, couleur 0, échelle 0.8,
  nom `L('locksmith_blip')`, `SetBlipAsShortRange`) et `Bridge.Target.AddBoxZone('pop_vehiclekeys_locksmith_' .. i,
  coords, vec3(2.0, 2.0, 2.0), 0.0, { { label = L('locksmith_target'), icon = 'fa-solid fa-key', distance = 2.0,
  onSelect = notifie L('locksmith_hint') } })`.
- **`startDuplicate(plate, price)`** : ignoré si `Bridge.IsBusy()`. `Bridge.Progress(L('duplicating', price),
  Config.Locksmith.duration, { anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 } })` ; si terminé →
  `Callback.Await('pop_vehiclekeys:duplicate', plate)` ; échec → notification.
- **Arrêt** : blips et zones supprimés (les targets sont aussi nettoyés par le bridge).

---

## 12. Comportement serveur et sécurité (`server/main.lua`)

Au démarrage : `GlobalState:set('pop_vehiclekeys_supported', Bridge.SupportsMetadata(), true)`. Si faux → avertissement console
(anglais) : clés impossibles avec cet inventaire ; toutes les actions répondent `not_supported` ; le client ne lance pas
la boucle moteur (et `hasKey` répond `true` par sécurité).

**Item utilisable** `Config.KeyItem` → `cb(src, item, metadata)` :
1. `plate = Keys.Normalize(metadata and metadata.plate)` ; nil → `Bridge.Notify(src, L('key_invalid'), 'error')`.
2. Près d'un serrurier (`Bridge.IsNear(src, loc, Keys.ACTION_DISTANCE)`) → `TriggerClientEvent('pop_vehiclekeys:client:startDuplicate', src, plate, Config.Locksmith.price)`.
3. Sinon : premier véhicule de `GetAllVehicles()` dont `Keys.Normalize(GetVehicleNumberPlateText(v)) == plate` et
   à ≤ `Config.LockDistance + Keys.LOCK_TOLERANCE` du joueur → `toggleLock(src, v)` ; aucun → `vehicle_not_here` (arg plate).
   (La possession est revérifiée dans `toggleLock` : la métadonnée reçue n'est pas une preuve suffisante.)

**`toggleLock(src, veh)`** (callback `toggleLock` : `veh = NetworkGetEntityFromNetworkId(netId)` après
`math.type(netId) == 'integer'`) :
1. `DoesEntityExist(veh)` et `GetEntityType(veh) == 2`, sinon `no_vehicle`.
2. Anti-spam : `now - lastLock[src] < Keys.LOCK_COOLDOWN` → `cooldown`, arg 1.
3. Distance : `Bridge.IsNear(src, GetEntityCoords(veh), Config.LockDistance + Keys.LOCK_TOLERANCE)`, sinon `too_far`.
4. **Plaque lue côté serveur** : `GetVehicleNumberPlateText(veh)` (jamais celle du client), normalisée.
5. `hasKey(src, plate)`, sinon `no_key`.
6. `locked = GetVehicleDoorLockStatus(veh) < 2` (nouvel état) → `SetVehicleDoorsLocked(veh, locked and 2 or 1)`.
7. `lockFx` à chaque joueur de `Bridge.GetPlayers()` à ≤ `Keys.FX_RADIUS` (`Bridge.IsNear`), notification
   `locked` / `unlocked` (succès) au joueur, retour `true, nil, locked`.

**`hasKey(netId)`** : netId entier et véhicule existant, sinon `false` ; joueur **dans** ce véhicule
(`GetVehiclePedIsIn(GetPlayerPed(src), false) == veh`), sinon **`nil`** (synchro réseau en retard : le client
redemande) ; puis `hasKey(src, plaque serveur)`.

**`duplicate(plate)`** :
1. `plate = Keys.Normalize(plate)`, sinon `error`. Verrou `busy[src]` (libéré dans tous les cas et à la
   déconnexion / unload) → `busy`.
2. Près d'un serrurier, sinon `too_far`.
3. `findKey(src, plate)` : le joueur **possède déjà** cette clé, sinon `no_key`.
4. `Bridge.CanCarry(src, Config.KeyItem, 1)`, sinon `inventory_full`.
5. Si `price > 0` : `Bridge.RemoveMoney(src, Config.Locksmith.account, price, 'pop_vehiclekeys')`, sinon `not_enough_money`.
6. `giveKey` ; échec → rembourser (`Bridge.AddMoney`) et `inventory_full`. Succès : notification `duplicated` (plate).

**Exports** : `plate` normalisé (sinon false), `src` = joueur valide (`Bridge.GetPlayer(src)`).
`RemoveKey` : boucle `findKey` → `Bridge.RemoveItem(src, Config.KeyItem, 1, metadata, slot)` (une fois, ou jusqu'à
épuisement si `all`).

**Règles générales**
- Aucune clé créée à partir d'une donnée client sans preuve de possession serveur (section 1).
- Plaque, distance, possession, argent : toujours lus côté serveur.
- Pas de `RegisterNetEvent` serveur ; l'anti-spam du template reste actif.
- `lastLock` et `busy` nettoyés dans `Bridge.OnPlayerDropped` et `Bridge.OnPlayerUnloaded`.
- `Config.Debug` : log des créations de clé (export ou double) avec src et plaque.

---

## 13. Limites (README)
- ESX avec l'inventaire de base (sans métadonnées) : non pris en charge → utiliser ox / qs / qb / pop inventory.
- Le blocage du moteur est appliqué par le client (aucune native serveur fiable) ; la clé reste vérifiée côté serveur.
- Les scripts qui appellent les events de qb-vehiclekeys ne sont pas pris en charge (volontaire : faille) → export `GiveKey`.
- Véhicules sans `GiveKey` (PNJ, véhicules de job, garages / concessions non adaptés) : moteur bloqué. Les garages,
  concessions et jobs doivent appeler `GiveKey` (exemple dans le README).
- Standalone + ox_inventory : pas d'argent → `Config.Locksmith.price = 0`.

## 14. Checklist auditeur
- Section 0 faite dans le template, README du template à jour, bridge recopié à l'identique.
- `luacheck resources templates` : 0 erreur. 10 locales complètes, aucun texte en dur.
- Aucun chemin client → création de clé sans possession. Aucun `Wait(0)` hors `Bridge.Progress`.
- Testé ESX / QBCore / Qbox ; ox / qb / qs ; ox_target, qb-target, prompt.
