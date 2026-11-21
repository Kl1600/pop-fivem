# pop_vehiclepersistence : SPEC (contrat commun Serveur / Client)

> Référence unique : noms (fichiers, callbacks, statebags, clés de config et de locale, champs) repris **à l'identique**.
> API commune : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).
> Modèle lu (pas copié) : `[system]/tab_vehiclepersistence/` (client.lua, config.lua, Server.cs). Le C# est remplacé
> par du Lua serveur ; les placeholders UtilityNet, le HUD `/showvehicles` et les commandes de test sont retirés.
> **OneSync obligatoire** (création de véhicules côté serveur).

---

## 1. Description et fonctionnalités

Les véhicules des joueurs restent là où ils ont été garés, après une déconnexion ou un redémarrage, dans l'état où
on les a laissés : position, verrouillage, dégâts (carrosserie, moteur, réservoir, portes, vitres, pneus), saleté,
carburant, mods, couleurs, néons. Aucun menu, aucune commande : tout est automatique et invisible.

- **Suivi** : un véhicule est suivi dès qu'un joueur éligible le conduit (section 3.3). Le client envoie ses
  propriétés quand le joueur prend le volant (après 3 s) et quand il le quitte.
- **Apparition par proximité** : le serveur ne crée l'entité que lorsqu'un joueur est à moins de
  `Config.SpawnDistance` ; il la retire (après sauvegarde) quand plus personne n'est proche et qu'elle est vide.
  Résultat : des centaines de véhicules garés sans coût réseau.
- **Sans doublon** : avant de créer une entité, le serveur cherche la plaque dans le monde et **adopte** le véhicule
  existant. Si un garage fait sortir une copie pendant que la nôtre existe, la nôtre (vide) est supprimée.
- **Fin de suivi automatique** : un véhicule suivi qui disparaît sans que le script l'ait retiré (rangé au garage,
  fourrière, `/dv`) ou qui est détruit (épave) n'est plus suivi (ligne SQL supprimée). Un véhicule rangé dans la table
  du framework (`stored` / `state`) n'est pas recréé.
- **Limite** : `Config.MaxPerOwner` véhicules par propriétaire ; au-delà, le plus ancien est remorqué (supprimé).
- **Nettoyage** : un véhicule non conduit depuis `Config.ExpireDays` jours est supprimé.
- **Intégrations (facultatives, détectées)** : table du framework en lecture (`owned_vehicles` ESX, `player_vehicles`
  QBCore / Qbox), `pop_vehiclekeys` (`HasKey`), `pop_bennys:saved`, `pop_paintgun:painted`.
- **Véhicules temporaires ignorés** : statebag d'entité `pop_temporary = true` (posé par pop_enterprisegarage,
  pop_bikerental ou tout autre script : **contrat commun POP**).

**Hors périmètre** : garage, fourrière, menu, marqueurs 3D, véhicules PNJ, remorques attachées, passagers.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_vehiclepersistence/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes pop_base + section 8)
  README.md               SERVEUR   (installation, OneSync, modes, contrat pop_temporary, limites)
  sql/install.sql         SERVEUR
  bridge/ shared/         copiés par l'intégrateur (ne pas modifier)
  common/props.lua        SERVEUR   API Props (section 3.1), chargée des deux côtés ; copiée telle quelle dans pop_bennys
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR   chargement, boucles, callbacks, exports, intégrations
  client/main.lua         CLIENT    détection volant / sortie, envoi des propriétés, application des propriétés
```

**Pas de NUI** : aucun dossier `web/`, pas de `ui_page`. Aucun Dev NUI.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_vehiclepersistence'
author 'POP'
version '1.0.0'
description 'POP Vehicle Persistence - parked vehicles stay where they were left'

dependencies { 'oxmysql' }

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua', 'common/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'bridge/server.lua', 'server/*.lua' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

Constantes (en tête de `server/main.lua`) : `TICK = 5000` (ms, boucle de proximité), `SAVE_TICK = 60000` (ms),
`EXPIRE_TICK = 3600000` (ms), `DESPAWN_MARGIN = 50.0` (m), `SPAWN_BUDGET = 5` (créations max par tick),
`EXIT_DISTANCE = 10.0` (m, joueur qui vient de sortir), `UPDATE_COOLDOWN = 2000` (ms par joueur),
`OWNED_CACHE = 300` (s), `PROPS_MAX_LENGTH = 8192` (caractères JSON), `SPAWN_TIMEOUT = 3000` (ms).
Constantes client : `ENTER_DELAY = 3000` (ms), `APPLY_WAIT = 3000` (ms).

---

## 3. Données

### 3.1 `common/props.lua` : table globale `Props` (contrat partagé avec pop_bennys)

Format des propriétés = noms d'ESX / QBCore / ox_lib, pour que les garages du framework les relisent tels quels.
Couleurs **palette uniquement** (entiers), pas de RGB personnalisé.

```lua
Props = {}

-- Index de mod GTA -> clé (valeur : entier -1..255, -1 = d'origine).
Props.MODS = {
    [0] = 'modSpoilers', [1] = 'modFrontBumper', [2] = 'modRearBumper', [3] = 'modSideSkirt', [4] = 'modExhaust',
    [5] = 'modFrame', [6] = 'modGrille', [7] = 'modHood', [8] = 'modFender', [9] = 'modRightFender', [10] = 'modRoof',
    [11] = 'modEngine', [12] = 'modBrakes', [13] = 'modTransmission', [14] = 'modHorns', [15] = 'modSuspension',
    [16] = 'modArmor', [23] = 'modFrontWheels', [24] = 'modBackWheels', [25] = 'modPlateHolder',
    [26] = 'modVanityPlate', [27] = 'modTrimA', [28] = 'modOrnaments', [29] = 'modDashboard', [30] = 'modDial',
    [31] = 'modDoorSpeaker', [32] = 'modSeats', [33] = 'modSteeringWheel', [34] = 'modShifterLeavers',
    [35] = 'modAPlate', [36] = 'modSpeakers', [37] = 'modTrunk', [38] = 'modHydrolic', [39] = 'modEngineBlock',
    [40] = 'modAirFilter', [41] = 'modStruts', [42] = 'modArchCover', [43] = 'modAerials', [44] = 'modTrimB',
    [45] = 'modTank', [46] = 'modWindows', [48] = 'modLivery',
}

-- Mods à bascule -> clé (valeur : boolean).
Props.TOGGLES = { [18] = 'modTurbo', [20] = 'modSmokeEnabled', [22] = 'modXenon' }
```

| Champ | Type / bornes | Lecture (`Get`) | Application (`Set`) |
|---|---|---|---|
| `plateIndex` | int 0..5 | `GetVehicleNumberPlateTextIndex` | `SetVehicleNumberPlateTextIndex` |
| `bodyHealth`, `engineHealth`, `tankHealth` | number -4000..1000 | `GetVehicleBodyHealth` / `GetVehicleEngineHealth` / `GetVehiclePetrolTankHealth` | `SetVehicle…Health(v + 0.0)` |
| `fuelLevel` | number 0..100 | `Entity(veh).state.fuel` si nombre, sinon `GetVehicleFuelLevel` | `SetVehicleFuelLevel` + `Entity(veh).state:set('fuel', v, true)` (ox_fuel) + `DecorSetFloat(veh, '_FUEL_LEVEL', v)` si `DecorIsRegisteredAsType('_FUEL_LEVEL', 1)` |
| `dirtLevel` | number 0..15 | `GetVehicleDirtLevel` | `SetVehicleDirtLevel` |
| `color1`, `color2` | int 0..255 | `GetVehicleColours` | `ClearVehicleCustomPrimaryColour` / `Secondary` puis `SetVehicleColours` (couleur absente = couleur actuelle) |
| `pearlescentColor`, `wheelColor` | int 0..255 | `GetVehicleExtraColours` | `SetVehicleExtraColours` (idem) |
| `wheels` | int -1..12 | `GetVehicleWheelType` | `SetVehicleWheelType` (**avant** les mods de roues) |
| `windowTint` | int -1..6 | `GetVehicleWindowTint` | `SetVehicleWindowTint` |
| `xenonColor` | int -1..255 | `GetVehicleXenonLightsColor` | `SetVehicleXenonLightsColor` |
| `livery` | int -1..255 | `GetVehicleLivery` | `SetVehicleLivery` si ≥ 0 |
| `neonEnabled` | 4 booleans (liste) | `IsVehicleNeonLightEnabled(veh, 0..3)` | `SetVehicleNeonLightEnabled` |
| `neonColor`, `tyreSmokeColor` | 3 int 0..255 (liste) | `GetVehicleNeonLightsColour` / `GetVehicleTyreSmokeColor` | `SetVehicleNeonLightsColour` / `SetVehicleTyreSmokeColor` |
| `extras` | table `["0".."20"] = boolean` | `DoesExtraExist` + `IsVehicleExtraTurnedOn` | `SetVehicleExtra(veh, id, on and 0 or 1)` |
| `mod…` (`Props.MODS`) | int -1..255 | `GetVehicleMod` | `SetVehicleMod(veh, index, v, false)` |
| `modTurbo`, `modSmokeEnabled`, `modXenon` | boolean | `IsToggleModOn` | `ToggleVehicleMod` |
| `doorsBroken` | table `["0".."5"] = true` | `IsVehicleDoorDamaged` | `SetVehicleDoorBroken(veh, i, true)` |
| `windowsBroken` | table `["0".."7"] = true` | `not IsVehicleWindowIntact` | `SmashVehicleWindow` |
| `tyreBurst` | table `["0".."7"] = true` | `IsVehicleTyreBurst(veh, i, false)` | `SetVehicleTyreBurst(veh, i, false, 1000.0)` |

Clés des tables `extras`, `doorsBroken`, `windowsBroken`, `tyreBurst` : **chaînes** (sûr en JSON). Pas de `plate` ni de
`model` dans `Props.Get` (gérés par le serveur ; ajoutés par le serveur au moment d'écrire dans la table du framework).

| Fonction | Côté | Rôle |
|---|---|---|
| `Props.Get(veh)` | client | table complète ci-dessus ; `nil` si l'entité n'existe pas |
| `Props.Set(veh, p)` | client | applique les champs présents ; ordre : `SetVehicleModKit(veh, 0)`, `wheels`, couleurs, mods, bascules, néons, fumée, teinte, xénon, livrée, extras, plaque (index), santé, carburant, saleté, **dégâts en dernier** |
| `Props.Sanitize(p)` | les deux (pure) | nouvelle table ne gardant que les champs connus, du bon type et dans les bornes (les autres sont **ignorés**, pas d'erreur) ; `nil` si `p` n'est pas une table. Nombres : finis (`n == n`, pas `±math.huge`) ; entiers : `math.type == 'integer'` après `math.floor` des valeurs JSON entières |
| `Props.Merge(base, changes)` | les deux (pure) | copie de `base` (ou `{}`) dont les champs sont remplacés par ceux de `changes` (copie profonde des sous-tables) |

### 3.2 Enregistrement serveur (`Vehicles[plate]`, en mémoire)
```lua
{
    plate   = 'ABC123',      -- Plate.Normalize (ci-dessous)
    owner   = 'char1:abc',   -- identifiant du propriétaire (section 3.3)
    model   = -1216765807,   -- GetEntityModel (serveur)
    vtype   = 'automobile',  -- GetVehicleType (serveur), requis par CreateVehicleServerSetter
    x = 0.0, y = 0.0, z = 0.0, heading = 0.0,
    locked  = true,          -- GetVehicleDoorLockStatus(veh) >= 2
    props   = { ... } | nil, -- Props (dernier envoi valide du client, + intégrations)
    seen    = 1773695584,    -- os.time() de la dernière conduite (sert à l'expiration)
    entity  = 1234 | nil,    -- entité serveur actuelle, nil si non présente dans le monde
}
```
`Plate.Normalize(plate)` (en tête de `server/main.lua`, même règle que pop_vehiclekeys) : chaîne, espaces retirés,
majuscules, 1 à 8 caractères alphanumériques, sinon `nil`.

### 3.3 Éligibilité et propriétaire (`Config.Mode`)
| Mode | Véhicule suivi si | `owner` |
|---|---|---|
| `'framework'` | la plaque existe dans `owned_vehicles` (ESX) / `player_vehicles` (QBCore, Qbox) | colonne `owner` (ESX) / `citizenid` (QB) |
| `'keys'` | `exports.pop_vehiclekeys:HasKey(src, plate)` | `Bridge.GetIdentifier(src)` au premier suivi |
| `'all'` | tout véhicule conduit par un joueur | `Bridge.GetIdentifier(src)` au premier suivi |

`'auto'` (défaut) : `framework` si `Bridge.Framework ~= 'standalone'` **et** que la table répond, sinon `keys` si
`pop_vehiclekeys` est démarré, sinon `all`. Mode effectif affiché en console au démarrage (anglais).
Toujours ignorés : `Entity(veh).state.pop_temporary == true`, plaque invalide, types `train`.

Requêtes framework (paramétrées, cache par plaque `OWNED_CACHE` s, erreur SQL = non éligible, non mise en cache) :
- ESX : `SELECT owner, stored FROM owned_vehicles WHERE REPLACE(plate, ' ', '') = ? LIMIT 1`
- QB / Qbox : `SELECT citizenid, state FROM player_vehicles WHERE REPLACE(plate, ' ', '') = ? LIMIT 1`
- « Rangé » (ne pas recréer, supprimer l'enregistrement) : ESX `stored == 1` ; QB `state ~= 0`.

---

## 4. Events

Aucun event réseau propre au script. Communication serveur → clients par **statebag d'entité** :

| Statebag (entité) | Posé par | Valeur | Rôle |
|---|---|---|---|
| `pop_vehiclepersistence_props` | serveur, répliqué | Props | Propriétés à appliquer par le **propriétaire réseau** juste après la création |
| `pop_temporary` | autres scripts (serveur) | `true` | Contrat POP : véhicule temporaire, jamais suivi |

Events **locaux serveur** écoutés (intégrations, `AddEventHandler`) :
| Event | Paramètres | Effet |
|---|---|---|
| `pop_bennys:saved` | `src`, `plate`, `props` | si suivi : `rec.props = Props.Merge(rec.props, Props.Sanitize(props))`, sauvegarde |
| `pop_paintgun:painted` | `src`, `netId`, `color`, `target`, `plate` | si suivi : `color1` / `color2` / les deux = `color` dans `rec.props`, sauvegarde |

Event **local serveur émis** : `pop_vehiclepersistence:spawned` (`plate`, `netId`) après chaque création par le script
(pour d'autres scripts : clés, carburant…).

---

## 5. Callbacks

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_vehiclepersistence:update` | `netId` (int), `props` (table) | `bool` (suivi accepté) ; le client n'affiche rien |
| `pop_vehiclepersistence:applied` | `netId` (int) | `bool` ; le serveur efface le statebag |

Aucun callback serveur → client.

---

## 6. NUI

Aucune.

---

## 7. Exports publics (serveur)

| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_vehiclepersistence:IsPersisted(plate)` | bool | plaque suivie |
| `exports.pop_vehiclepersistence:RemoveVehicle(plate)` | bool | arrête le suivi (mémoire + SQL) et supprime l'entité si elle existe et est vide ; à appeler par un garage **avant** de supprimer lui-même le véhicule (facultatif : la disparition est détectée de toute façon) |
| `exports.pop_vehiclepersistence:GetVehicles(owner?)` | liste `{ plate, owner, model, x, y, z, spawned }` | copie ; filtrée par `owner` si donné |

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_vehiclepersistence ──────────────────────────────────

-- Véhicules gardés : 'auto' | 'framework' (table owned_vehicles / player_vehicles)
-- | 'keys' (le conducteur a la clé pop_vehiclekeys) | 'all' (tout véhicule conduit par un joueur).
-- 'auto' : framework si ESX / QBCore / Qbox, sinon keys si pop_vehiclekeys est lancé, sinon all.
Config.Mode = 'auto'

-- Un véhicule garé apparaît quand un joueur est à moins de cette distance (mètres).
Config.SpawnDistance = 150.0

-- Véhicules garés max par propriétaire : au-delà, le plus ancien est remorqué.
Config.MaxPerOwner = 5

-- Un véhicule non conduit depuis ce nombre de jours est supprimé (0 = jamais).
Config.ExpireDays = 14
```

---

## 9. Locales

10 fichiers (Dev Serveur) : kit commun inchangé + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `limit_towed` | Your vehicle %s was towed (max %s parked vehicles) | Votre véhicule %s a été remorqué (%s véhicules garés max) |

Logs console en anglais, sans `L()`.

---

## 10. Schéma SQL

`sql/install.sql` (aussi exécuté au démarrage, `CREATE TABLE IF NOT EXISTS`) :
```sql
CREATE TABLE IF NOT EXISTS `pop_vehiclepersistence` (
    `plate`   VARCHAR(8)   NOT NULL,
    `owner`   VARCHAR(64)  NOT NULL,
    `model`   BIGINT       NOT NULL,
    `vtype`   VARCHAR(16)  NOT NULL DEFAULT 'automobile',
    `x`       FLOAT        NOT NULL,
    `y`       FLOAT        NOT NULL,
    `z`       FLOAT        NOT NULL,
    `heading` FLOAT        NOT NULL DEFAULT 0,
    `locked`  TINYINT(1)   NOT NULL DEFAULT 1,
    `props`   LONGTEXT     NULL,
    `seen`    INT UNSIGNED NOT NULL,
    PRIMARY KEY (`plate`),
    KEY `idx_owner` (`owner`)
);
```
Écriture : `INSERT ... ON DUPLICATE KEY UPDATE` (toutes les colonnes sauf `plate`) ; suppression : `DELETE ... WHERE plate = ?`.
Requêtes **paramétrées**. `props` = `json.encode(rec.props)` ou `NULL`.

---

## 11. Comportement client (`client/main.lua`)

- **Une seule boucle** : à pied `Wait(1500)` ; en véhicule `Wait(1000)`.
  - Le joueur devient **conducteur** d'un véhicule réseau (`GetPedInVehicleSeat(veh, -1) == ped`,
    `NetworkGetEntityIsNetworked`) → mémorise `veh` et l'heure ; `ENTER_DELAY` ms plus tard, s'il est toujours au volant :
    `Callback.Trigger('pop_vehiclepersistence:update', VehToNet(veh), Props.Get(veh))`.
  - Il **quitte** le siège conducteur (sortie, changement de place, mort) → si `veh` existe encore :
    `Callback.Trigger('pop_vehiclepersistence:update', VehToNet(veh), Props.Get(veh))`, puis oubli.
  - Aucun envoi pour un véhicule dont `Entity(veh).state.pop_temporary` est vrai.
- **Application** : `AddStateBagChangeHandler('pop_vehiclepersistence_props', nil, fn)` : si `value` est une table,
  thread → `GetEntityFromStateBagName(bagName)` (attente jusqu'à `APPLY_WAIT` ms que l'entité existe) ; seulement si
  `NetworkGetEntityOwner(veh) == PlayerId()` : `Props.Set(veh, value)` puis
  `Callback.Trigger('pop_vehiclepersistence:applied', VehToNet(veh))`. Sinon rien (le propriétaire s'en charge).
- Aucune notification, aucun texte, aucun `Wait(0)`.

---

## 12. Comportement serveur et sécurité (`server/main.lua`)

### Démarrage
`CREATE TABLE IF NOT EXISTS`, détection du mode (section 3.3 ; test de la table framework par `SELECT 1 ... LIMIT 1`
dans un `pcall`), `SELECT *` → `Vehicles` (entity = nil), suppression immédiate des expirés, `loaded = true`.
Les boucles ne démarrent qu'après `loaded`.

### Création d'un véhicule (`spawn(rec)`)
1. Plaque déjà présente dans le monde (carte `plaque normalisée → entité` construite au tick depuis `GetAllVehicles()`) →
   **adopter** : `rec.entity = cette entité`, rien n'est créé.
2. Mode framework : ligne absente ou « rangée » → supprimer l'enregistrement (mémoire + SQL), ne rien créer.
3. `veh = CreateVehicleServerSetter(rec.model, rec.vtype, rec.x, rec.y, rec.z, rec.heading)` ; attendre
   `DoesEntityExist` (`SPAWN_TIMEOUT`, pas de 50 ms), sinon log et abandon (nouvel essai au tick suivant).
4. `SetEntityOrphanMode(veh, 2)`, `SetVehicleNumberPlateText(veh, rec.plate)`,
   `SetVehicleDoorsLocked(veh, rec.locked and 2 or 1)`.
5. Si `rec.props` : statebag `pop_vehiclepersistence_props` = `Props.Merge(rec.props, {})` (répliqué).
6. `rec.entity = veh`, `TriggerEvent('pop_vehiclepersistence:spawned', rec.plate, NetworkGetNetworkIdFromEntity(veh))`.

### Boucle de proximité (`TICK`)
Positions des joueurs (`Bridge.GetPlayers()` + `GetEntityCoords(GetPlayerPed(src))`), carte des plaques du monde, puis
pour chaque enregistrement :
- **Entité présente** :
  - `not DoesEntityExist` → **disparue sans nous** : suppression de l'enregistrement (rangé, fourrière, `/dv`).
  - `GetEntityHealth(entity) <= 0` ou `GetVehicleEngineHealth(entity) <= -4000` → épave : suppression de
    l'enregistrement, `SetEntityOrphanMode(entity, 0)` (le jeu la nettoiera).
  - Une **autre** entité porte la même plaque → si la nôtre est vide : `DeleteEntity` (la nôtre) puis adopter l'autre ;
    sinon adopter rien (log debug).
  - Vide (aucun siège -1..`GetVehicleMaxNumberOfPassengers` occupé, `GetPedInVehicleSeat`) et aucun joueur à moins de
    `Config.SpawnDistance + DESPAWN_MARGIN` → `capture(rec)` (ci-dessous), sauvegarde, `rec.entity = nil` **puis**
    `DeleteEntity`.
- **Entité absente** : un joueur à moins de `Config.SpawnDistance` et budget `SPAWN_BUDGET` non épuisé → `spawn(rec)`.

`capture(rec)` (lecture **serveur**) : `x, y, z`, `heading`, `locked`, et dans `rec.props` : `bodyHealth`,
`engineHealth`, `tankHealth`, `dirtLevel` (natives serveur `GetVehicleBodyHealth`, `GetVehicleEngineHealth`,
`GetVehiclePetrolTankHealth`, `GetVehicleDirtLevel`).

### Sauvegarde (`SAVE_TICK`) et expiration (`EXPIRE_TICK`)
- Toutes les 60 s : `capture` de chaque enregistrement avec entité ; écriture seulement si position (> 1 m), cap,
  verrouillage ou santé ont changé. Couvre les crashs et les déconnexions au volant.
- `rec.seen = os.time()` à chaque `update` accepté pendant la conduite (le joueur est au volant).
- Toutes les heures (si `Config.ExpireDays > 0`) : enregistrements avec `seen < os.time() - ExpireDays * 86400` et
  entité absente ou vide → suppression (entité comprise).
- Arrêt (`onResourceStop` de cette ressource, `txAdmin:events:serverShuttingDown`) : `capture` + sauvegarde de tout,
  puis `DeleteEntity` des entités **vides** créées ou adoptées (les occupées restent : elles seront adoptées au
  redémarrage par leur plaque).

### `pop_vehiclepersistence:update(netId, props)` : règles
1. Joueur valide (`Bridge.GetPlayer(src)`), `UPDATE_COOLDOWN` par joueur, sinon `false`.
2. `math.type(netId) == 'integer'`, entité existante, `GetEntityType == 2`, sinon `false`.
3. `Entity(veh).state.pop_temporary` → `false`. Plaque **lue côté serveur** et normalisée, sinon `false`.
4. Le joueur est au volant (`GetPedInVehicleSeat(veh, -1) == GetPlayerPed(src)`) **ou** à moins de `EXIT_DISTANCE`
   du véhicule (sortie), sinon `false`.
5. Éligibilité selon le mode (section 3.3), sinon `false`.
6. `props` : `Props.Sanitize(props)` ; si le JSON dépasse `PROPS_MAX_LENGTH` → ignoré (l'enregistrement est quand même
   mis à jour avec les valeurs serveur). Les champs de santé et de saleté sont **toujours** remplacés par `capture`.
7. Enregistrement existant attaché à une autre entité encore existante → règle « autre entité » ci-dessus.
8. Nouvel enregistrement : si le propriétaire a déjà `Config.MaxPerOwner` véhicules, retirer le plus ancien
   (`seen` le plus petit) dont l'entité est absente ou vide ; notifier `src`
   `L('limit_towed', plaque, Config.MaxPerOwner)` (`warning`). Aucun retirable → le nouveau n'est pas suivi (`false`).
9. `rec.entity = veh`, `rec.model = GetEntityModel(veh)`, `rec.vtype = GetVehicleType(veh)`, `capture(rec)`,
   sauvegarde immédiate (regroupée : une écriture max par plaque toutes les 2 s). Retour `true`.

### `pop_vehiclepersistence:applied(netId)`
Entité existante dont la plaque est suivie avec `rec.entity == veh` → `Entity(veh).state:set('pop_vehiclepersistence_props', nil, true)`, `true` ; sinon `false`.

### Règles générales
- Le client n'envoie qu'un `netId` et des propriétés visuelles : position, cap, plaque, modèle, type, verrouillage,
  santé et propriétaire sont **toujours** lus côté serveur.
- **Anti-duplication** : une plaque = un enregistrement = au plus une entité ; recherche par plaque avant toute
  création ; `rec.entity = nil` avant tout `DeleteEntity` du script ; budget de création par tick.
- Pas de `RegisterNetEvent` serveur ; l'anti-spam du template reste actif ; `cooldown` nettoyé dans
  `Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded`.
- `Config.Debug` : log des créations, adoptions, suppressions (plaque, raison).

---

## 13. Performance
- Client : une boucle à 1000 / 1500 ms, aucun `Wait(0)`, aucune entité créée par le client.
- Serveur : boucle de 5 s (O(joueurs × véhicules) en distances simples), sauvegarde différentielle toutes les 60 s,
  expiration toutes les heures. Aucune entité tant que personne n'est proche.

## 14. Limites (README)
- OneSync requis. Le carburant et les mods viennent du dernier envoi du conducteur (un tricheur peut maquiller **son**
  véhicule, sans gain d'argent ni d'objet).
- Un garage qui fait sortir un véhicule « rangé » sans mettre à jour `stored` / `state` peut créer un doublon
  momentané : il est résolu au tick suivant (la copie vide du script est supprimée).
- Les scripts de véhicules temporaires doivent poser `Entity(veh).state:set('pop_temporary', true, true)`.

## 15. Checklist auditeur
- `luacheck resources templates` : 0 erreur. 10 locales. Aucun texte en dur.
- Aucun chemin client → choix de position, de plaque, de modèle ou de propriétaire.
- Redémarrage serveur, redémarrage de la ressource avec un joueur au volant, `/dv`, rangement au garage : jamais de doublon.
