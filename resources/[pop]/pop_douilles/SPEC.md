# pop_douilles : SPEC (contrat commun Serveur / Client / NUI)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `tab_inventory/douilles_*.lua`.

---

## 1. Description et fonctionnalités

Les tirs laissent des douilles. La police enquête en 3 étapes courtes, façon GTA 6 :
**fouiller** la zone → **ramasser** les douilles comme preuves → **lire** le rapport (utiliser l'item).

- **Tir** : le client détecte la baisse de munitions de l'arme en main (pas d'`IsPedShooting` à chaque frame) et le
  signale au serveur au plus 1 fois par seconde. Le serveur crée une douille (ou ajoute au tas proche de la même arme).
- **Douilles invisibles par défaut** : rien n'est envoyé aux joueurs. Seul un policier (`Config.PoliceJobs`, en
  service) qui **fouille** (touche `Config.SearchKey`, barre de 3 s) reçoit les douilles à ≤ `Config.SearchRadius` :
  petit prop local au sol + interaction « Ramasser » pendant `Config.RevealTime`.
- **Ramasser** : barre courte → item `Config.Item` avec métadonnées : calibre, signature balistique, heure, position,
  nombre de douilles.
- **Rapport** : un policier qui utilise l'item voit une petite carte (calibre, signature, date, rue, nombre).
  Deux douilles de même signature = même tireur, même arme.
- **Disparition** après `Config.Lifetime` ; plafond `Config.MaxCasings` (les plus anciennes sont supprimées).

**Performance** : aucune entité réseau ; aucune douille diffusée à tous ; props créés seulement après une fouille,
pour ce joueur, puis supprimés. Détection des tirs : 250 ms seulement arme à feu en main, sinon 1000 ms.
Serveur : une purge toutes les 60 s.

**Hors périmètre** : lampe UV, laboratoire, base de données, vision admin, nettoyage des douilles par les criminels.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_douilles/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR
  README.md               SERVEUR   (item par inventaire, limites)
  bridge/server.lua       SERVEUR   copie STRICTE du template
  bridge/client.lua       CLIENT    copie STRICTE
  shared/callback.lua     SERVEUR   copie STRICTE
  shared/locale.lua       SERVEUR   copie STRICTE
  common/casing.lua       SERVEUR   constantes partagées (chargé des deux côtés)
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    détection des tirs, fouille, props, ramassage, rapport
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/pop.css, pop.js NUI       copie STRICTE
```

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_douilles'
author 'POP'
version '1.0.0'
description 'POP Douilles - bullet casings as police evidence'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua', 'common/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

---

## 3. Données

### `common/casing.lua`
```lua
Casing = {}
Casing.REPORT_INTERVAL = 1000  -- ms : client, envoi groupé des tirs ; serveur : refus si plus rapide (marge 200 ms)
Casing.MAX_SHOTS       = 30    -- tirs max acceptés par signalement
Casing.REPORT_DISTANCE = 4.0   -- serveur : position signalée / position du joueur
Casing.MERGE_DISTANCE  = 2.0   -- même arme à moins de 2 m → même tas
Casing.MAX_COUNT       = 99    -- douilles max dans un tas
Casing.MAX_PER_SIGNATURE = 15  -- tas max par signature (même tireur, même arme), avant Config.MaxCasings
Casing.PICKUP_DISTANCE = 2.5   -- serveur
Casing.TARGET_DISTANCE = 1.5   -- client
Casing.SEARCH_COOLDOWN = 5     -- secondes entre deux fouilles (serveur)
Casing.REPORT_TIME     = 12000 -- ms d'affichage de la carte rapport
```

### Douille (serveur uniquement)
```lua
casings[id] = {
    id = 7,                 -- entier croissant
    x = 0.0, y = 0.0, z = 0.0, -- sol
    weapon = -1076751822,   -- hash (lu côté serveur)
    count = 3,
    createdAt = os.time(),
    signature = 'A1B2C3',   -- 6 hex : djb2(identifier .. ':' .. weapon) % 2^32, comme l'ancien script
}
```
L'identifiant du tireur n'est **jamais** stocké ni envoyé : seulement la signature (empreinte).

### Données envoyées au client après fouille : `{ id, x, y, z }` (rien d'autre).

### Métadonnée de l'item ramassé
```lua
{
    caliber = '9mm',            -- nil si arme non listée dans Config.Calibers
    signature = 'A1B2C3',
    shotAt = 1773695584,        -- os.time() du tir
    time = '21/11/2026 14:32',  -- os.date(L('time_format'), shotAt)
    x = 293.3, y = -648.1, z = 29.0, -- arrondis à 0,1
    count = 3,
    description = L('casing_description', caliberLabel, time),
}
```
Chaque item porte des métadonnées uniques : les preuves ne s'empilent pas (inventaires à métadonnées).

---

## 4. Events

| Event | Sens | Paramètres | Destinataire | Rôle |
|---|---|---|---|---|
| `pop_douilles:server:shot` | C → S | `coords` (`{ x, y, z }`, sol), `shots` (int), `previous` (bool : tirs de l'arme tenue avant un changement) | serveur | Signalement de tirs (sans réponse) |
| `pop_douilles:client:removed` | S → C | `id` (int) | `-1` | Douille ramassée ou expirée : supprimer prop/target si affichée |
| `pop_douilles:client:report` | S → C | `data` (section 6) | le joueur | Affiche la carte rapport |

`shot` est un net event (pas un callback) : fréquent, sans réponse. Throttle serveur obligatoire (section 12).

---

## 5. Callbacks

Convention : `ok, reason, arg`. Échec → le client notifie `L(reason or 'error', arg)`. Succès → serveur notifie.

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_douilles:search` | aucun | `ok, reason, list` (`list` = tableau séquentiel de `{ id, x, y, z }`) |
| `pop_douilles:pickup` | `id` (int) | `ok, reason, arg` |

Raisons : `error`, `wrong_job`, `cooldown` (arg secondes), `too_far`, `casing_not_found`, `inventory_full`, `busy`.
`search` sans résultat : `true, nil, {}` → le client notifie `L('nothing_found')`.

---

## 6. Messages NUI

L'interface **ne prend jamais le focus**. Pas de callback JS → Lua propre au script.

**`pop_douilles:report`** (Lua → JS)
```json
{ "action": "pop_douilles:report", "show": true,
  "caliber": "9mm", "signature": "A1B2C3", "time": "21/11/2026 14:32",
  "street": "Strawberry Ave", "count": 3 }
```
```json
{ "action": "pop_douilles:report", "show": false }
```
`caliber` peut être `null` → afficher `Pop.t('caliber_unknown')`. `street` est calculée par le client
(`GetStreetNameAtCoord` + `GetStreetNameFromHashKey` sur x, y, z) ; vide → `Pop.t('street_unknown')`.
Le client envoie `show = false` après `Casing.REPORT_TIME` ms (un nouveau rapport relance le minuteur).

**Interface (Dev NUI)**
- `index.html` : base pop_base + `style.css` après `kit/pop.css`. `#app` remplacé par `#casing-report`
  (`pop-panel pop-fade`, masqué) : titre `data-locale="report_title"` ; 5 lignes libellé / valeur :
  `report_caliber` (`#cr-caliber`), `report_signature` (`#cr-signature`, police monospace, couleur d'accent),
  `report_time` (`#cr-time`), `report_street` (`#cr-street`), `report_count` (`#cr-count`).
- `script.js` : `Pop.on('pop_douilles:report', ...)`, `Pop.show(el, data.show)`. Valeurs en `textContent` (jamais
  `innerHTML`). Aucun texte en dur.
- `style.css` : carte 240 px, `position: fixed; right: 24px; top: 30%`, fond `--pop-bg`, texte `--pop-size-sm`,
  aucun dégradé. RTL : `[dir="rtl"]` → `right: auto; left: 24px`.

---

## 7. Exports publics (serveur)

| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_douilles:AddCasing(coords, weaponHash, count, identifier)` | id \| nil | crée une douille (autre script : scène de crime, PNJ) ; `identifier` optionnel (signature sur `'npc'` sinon) |
| `exports.pop_douilles:ClearArea(coords, radius)` | int | supprime les douilles dans le rayon, renvoie le nombre |

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_douilles ────────────────────────────────────────────

-- Item reçu en ramassant (à déclarer dans votre inventaire, voir README).
Config.Item = 'bullet_casing'

-- Jobs qui peuvent fouiller, ramasser et lire le rapport (format Bridge.HasJob, en service).
Config.PoliceJobs = { 'police', 'sheriff' }

-- Touche par défaut pour fouiller (modifiable par le joueur dans les raccourcis FiveM).
Config.SearchKey = 'K'

Config.SearchRadius   = 10.0  -- mètres
Config.SearchDuration = 3000  -- ms
Config.PickupDuration = 2000  -- ms
Config.RevealTime     = 120   -- secondes d'affichage des douilles trouvées
Config.Lifetime       = 1200  -- secondes avant disparition d'une douille
Config.MaxCasings     = 150   -- douilles max sur le serveur

-- Modèle du prop au sol (petit objet du jeu de base). Invalide = interaction sans prop.
Config.Prop = 'w_pi_flaregun_shell'

-- Armes qui ne laissent pas de douille.
Config.IgnoredWeapons = {
    'WEAPON_STUNGUN', 'WEAPON_STUNGUN_MP', 'WEAPON_FLAREGUN', 'WEAPON_RAYPISTOL', 'WEAPON_RAYCARBINE',
    'WEAPON_PETROLCAN', 'WEAPON_HAZARDCAN', 'WEAPON_FIREEXTINGUISHER', 'WEAPON_RPG', 'WEAPON_HOMINGLAUNCHER',
    'WEAPON_GRENADELAUNCHER', 'WEAPON_GRENADELAUNCHER_SMOKE', 'WEAPON_COMPACTLAUNCHER', 'WEAPON_FIREWORK',
    'WEAPON_SNOWLAUNCHER',
}

-- Calibre par arme. Arme non listée = calibre inconnu.
Config.Calibers = {
    ['9mm']     = { 'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_SNSPISTOL', 'WEAPON_SNSPISTOL_MK2',
                    'WEAPON_APPISTOL', 'WEAPON_CERAMICPISTOL', 'WEAPON_MACHINEPISTOL', 'WEAPON_MICROSMG', 'WEAPON_SMG',
                    'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW', 'WEAPON_MINISMG' },
    ['.45 ACP'] = { 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL', 'WEAPON_GUSENBERG' },
    ['.50 AE']  = { 'WEAPON_PISTOL50' },
    ['.357']    = { 'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION', 'WEAPON_NAVYREVOLVER' },
    ['5.56mm']  = { 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE',
                    'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE', 'WEAPON_BULLPUPRIFLE_MK2', 'WEAPON_MILITARYRIFLE' },
    ['7.62mm']  = { 'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_COMPACTRIFLE', 'WEAPON_HEAVYRIFLE',
                    'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_MARKSMANRIFLE', 'WEAPON_MARKSMANRIFLE_MK2' },
    ['12 ga']   = { 'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_BULLPUPSHOTGUN',
                    'WEAPON_ASSAULTSHOTGUN', 'WEAPON_HEAVYSHOTGUN', 'WEAPON_COMBATSHOTGUN', 'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN' },
    ['.50 BMG'] = { 'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2' },
}
```
Les deux côtés construisent au démarrage des tables par hash (`joaat(name)`) : `ignored[hash]`, `caliberOf[hash]`.

---

## 9. Locales

10 fichiers (écrits par le Dev Serveur). `time_format` est un format `os.date` propre à chaque langue.

| Clé | en | fr |
|---|---|---|
| `keymap_search` | Search the ground for casings | Fouiller le sol (douilles) |
| `searching` | Searching the area... | Fouille de la zone... |
| `found_casings` | %s casing spot(s) found | %s emplacement(s) de douilles trouvé(s) |
| `nothing_found` | Nothing found here | Rien trouvé ici |
| `target_pickup` | Bag the casing | Ramasser la douille |
| `picking_up` | Bagging evidence... | Mise sous scellé... |
| `picked_up` | Casing bagged as evidence | Douille placée sous scellé |
| `casing_not_found` | This casing is gone | Cette douille a disparu |
| `casing_description` | %s casing - %s | Douille %s - %s |
| `caliber_unknown` | Unknown caliber | Calibre inconnu |
| `street_unknown` | Unknown location | Lieu inconnu |
| `time_format` | %m/%d/%Y %H:%M | %d/%m/%Y %H:%M |
| `report_title` | Ballistic report | Rapport balistique |
| `report_caliber` | Caliber | Calibre |
| `report_signature` | Signature | Signature |
| `report_time` | Fired | Tir |
| `report_street` | Location | Lieu |
| `report_count` | Casings | Douilles |

Clés de base réutilisées : `wrong_job`, `cooldown`, `too_far`, `inventory_full`, `busy`, `error`, `progress_cancelled`.
`casing_description` : 1er `%s` = calibre (ou `L('caliber_unknown')`), 2e = `time`.

---

## 10. Schéma SQL

Aucun. Douilles en mémoire (perdues au redémarrage, voulu). Les items ramassés sont gardés par l'inventaire.

---

## 11. Comportement client (`client/main.lua`)

- **Détection des tirs** (une boucle) :
  - `weapon = GetSelectedPedWeapon(ped)` ; si `not IsPedArmed(ped, 4)` ou `ignored[weapon]` → baseline à nil,
    `Wait(1000)`.
  - Sinon `ammo = GetAmmoInPedWeapon(ped, weapon)` ; si même arme que la baseline et `ammo < baseline` →
    `pending = pending + (baseline - ammo)` ; baseline = ammo ; `Wait(250)`.
  - Hash d'arme normalisé en entier signé 32 bits (`normHash`), comme côté serveur.
  - Arme changée ou rangée avec `pending > 0` → `previous = true` ; tant que `pending > 0`, la boucle tourne à
    250 ms pour envoyer **dès que** l'intervalle le permet.
  - Si `pending > 0` et `GetGameTimer() - lastSent ≥ Casing.REPORT_INTERVAL` : sol sous le joueur
    (`GetGroundZFor_3dCoord(x, y, z + 1.0)`, sinon `z - 0.95`), `TriggerServerEvent('pop_douilles:server:shot',
    { x, y, z }, math.min(pending, Casing.MAX_SHOTS), previous)`, `pending = 0`, `previous = false`.
  - Tous les joueurs exécutent cette boucle (le tireur peut être n'importe qui).
- **Fouille** : `RegisterCommand('pop_douilles_search', fn, false)` + `RegisterKeyMapping('pop_douilles_search',
  L('keymap_search'), 'keyboard', Config.SearchKey)`. Si pas policier en service (état local via `Bridge.GetJob` /
  `Bridge.OnJobUpdate`) → ne rien faire (pas de message : la touche reste libre pour les autres). Si mort, en
  véhicule ou `Bridge.IsBusy()` → rien (revérifié après la barre). `Bridge.Progress(L('searching'),
  Config.SearchDuration, { anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 } })` →
  chargement du modèle (`RequestModel` timeout 2 s) **avant** `Callback.Await('pop_douilles:search')` →
  notification `found_casings` (#list) ou `nothing_found` → affichage. L'affichage ne cède jamais la main
  (aucun `Wait`) : un `removed` reçu pendant la fouille ne peut pas laisser de douille fantôme.
- **Affichage** (par douille reçue, si pas déjà affichée) : **toujours** `Bridge.Target.AddBoxZone(
  'pop_douilles_' .. id, coords, vec3(0.6, 0.6, 0.6), 0.0, options)` ; le prop local (`CreateObject(hash, x, y, z,
  false, false, false)`, `PlaceObjectOnGroundProperly`, `FreezeEntityPosition`, sans collision) n'est **que
  visuel** : sans collision, ox_target / qb-target ne le détectent pas. Modèle invalide → zone seule.
  Option : `L('target_pickup')`,
  `fa-solid fa-magnifying-glass`, `distance = Casing.TARGET_DISTANCE`. Retrait automatique après
  `Config.RevealTime` (un `SetTimeout` par fouille), à `removed`, et à l'arrêt de la ressource.
- **Ramasser** : refusé si mort ou en véhicule (aussi dans `canInteract`). `Bridge.Progress(L('picking_up'), Config.PickupDuration, { anim = { dict = 'pickup_object',
  clip = 'pickup_low', flag = 0 } })` → `Callback.Await('pop_douilles:pickup', id)`.
- **Rapport** : `report(data)` → calcule `street`, `SendNUIMessage` (section 6), minuteur de fermeture.

---

## 12. Sécurité serveur (`server/main.lua`)

**`pop_douilles:server:shot(coords, shots)`**
1. Throttle : `now - lastShot[src] < Casing.REPORT_INTERVAL - 200` → ignorer silencieusement.
2. `coords` table ; x, y, z nombres finis ; `shots` entier ≥ 1, borné à `Casing.MAX_SHOTS`.
3. `Bridge.IsNear(src, coords, Casing.REPORT_DISTANCE)`, sinon ignorer.
4. **Arme lue côté serveur** : `GetSelectedPedWeapon(GetPlayerPed(src))`. Le client n'envoie jamais l'arme.
   Arme valide (ni `WEAPON_UNARMED` ni dans `ignored`) → `lastWeapon[src] = { hash, t = GetGameTimer() }`.
   Si l'arme actuelle est invalide, ou différente avec `previous == true`, et que `lastWeapon[src]` date de
   < 1500 ms → utiliser `lastWeapon[src].hash` (tirs envoyés juste après avoir rangé / changé d'arme). Sinon ignorer.
5. Tas existant de la même arme et de la même signature à ≤ `Casing.MERGE_DISTANCE` → `count = min(count + shots,
   Casing.MAX_COUNT)`. Sinon nouvelle douille (`signature` depuis `Bridge.GetIdentifier(src)` ou `'src:' .. src`) :
   d'abord, tant que cette signature a ≥ `Casing.MAX_PER_SIGNATURE` tas → supprimer son plus ancien (+ `removed`) ;
   puis si le total dépasse `Config.MaxCasings` → supprimer la plus ancienne (+ `removed`).

**`pop_douilles:search`** : `Bridge.HasJob(src, Config.PoliceJobs)` **et** `Bridge.GetJob(src).onDuty`, sinon
`wrong_job` ; mort ou en véhicule (`GetEntityHealth`, `GetVehiclePedIsIn`) → `error` ; cooldown `Casing.SEARCH_COOLDOWN` par joueur → `cooldown` ; centre = **position serveur**
(`Bridge.GetCoords(src)`), jamais une position client ; renvoie seulement `{ id, x, y, z }`.

**`pop_douilles:pickup(id)`** : `math.type(id) == 'integer'` et existe (sinon `casing_not_found`) ; même contrôle de
job ; mort ou en véhicule → `error` ; verrou `busy[src]` ; `Bridge.IsNear(src, casing, Casing.PICKUP_DISTANCE)`, sinon `too_far` ;
`Bridge.CanCarry(src, Config.Item, 1)`, sinon `inventory_full` ; **retirer la douille de la mémoire avant**
`Bridge.AddItem(src, Config.Item, 1, metadata)` ; échec → la remettre et `inventory_full`. Succès : `removed` à `-1`,
notification `picked_up`.

**Item utilisable** `Config.Item` → `cb(src, item, metadata)` : policier en service, sinon `wrong_job` ;
`metadata.signature` présente, sinon rien. Envoie `report` avec uniquement les champs relus depuis la métadonnée : `caliber`,
`signature`, `time`, `count` (section 6) **plus `x, y, z`** (nombres finis), envoyés au client seulement pour qu'il
calcule la rue ; ils ne vont pas dans la NUI. Chaînes tronquées (caliber 16, signature 6, time 32), count entier
1-99 (sinon `nil` → la NUI affiche `—`). La métadonnée n'est jamais renvoyée telle quelle.

**Purge** : toutes les 60 s, supprime les douilles plus vieilles que `Config.Lifetime` (+ `removed`).
**Nettoyage** : `lastShot`, `lastWeapon`, `busy`, cooldowns par src dans `Bridge.OnPlayerDropped` / `OnPlayerUnloaded`.

---

## 13. Limites (README)
- Un tricheur peut ne pas signaler ses tirs (détection côté client par nature) ; il ne peut pas inventer une arme
  ni une position éloignée.
- Inventaire sans métadonnées (ESX de base) : l'item est donné sans informations ; le rapport est vide.
- `Config.Prop` : si votre serveur stream un vrai modèle de douille, mettez son nom ici.

## 14. Checklist auditeur
- Copies strictes ; 10 locales complètes ; aucun texte en dur (Lua, HTML, JS).
- Aucune donnée de douille envoyée hors fouille ; aucun identifiant envoyé.
- Aucun `Wait(0)` hors `Bridge.Progress` ; aucune entité réseau ; < 0.02 ms au repos.
