# pop_bennys : SPEC (contrat commun Serveur / Client / NUI)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`, `Pop.*`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `[system]/tab_bennys/` (client, config, server, html).
> Le paiement en items de l'ancien script (montants et items envoyés par le client) est remplacé par un **prix
> calculé par le serveur** et payé via `Bridge.RemoveMoney`.

---

## 1. Description et fonctionnalités

Atelier de personnalisation sobre : on entre dans l'atelier au volant, on règle, on voit le résultat en direct, on paie
ou on annule.

1. **Entrer** dans la zone d'un atelier (`Config.Shops`) au volant : `[E] Personnaliser` (prompt du kit).
   Atelier public, ou réservé à un job en service (`jobs`, format `Bridge.HasJob`) : le mécano conduit la voiture du
   client dans l'atelier et paie.
2. **Régler** dans un panneau latéral (6 catégories) : peinture (primaire, secondaire, nacré, jantes : palette),
   roues (type + jante), carrosserie (pièces disponibles sur ce modèle), performance (moteur, freins, transmission,
   suspension, blindage, turbo), éclairage (xénon + couleur, néons 4 côtés + couleur), vitres (teinte).
   **Aperçu en direct** sur le véhicule, caméra qui change de vue par catégorie, prix de chaque ligne et total.
3. **Payer** : le serveur recalcule le prix depuis la config, retire l'argent (`Config.Account`), construit les
   propriétés finales et les **sauvegarde** : event serveur local `pop_bennys:saved(src, plate, props)` (garages,
   pop_vehiclepersistence) + écriture facultative dans la table du framework (`owned_vehicles.vehicle` ESX,
   `player_vehicles.mods` QBCore / Qbox).
4. **Annuler** (bouton ou Échap) : le véhicule retrouve exactement son état d'origine.

Véhicule figé pendant la session ; radar masqué ; aucune boucle rapide hors zone.

**Hors périmètre** : couleurs RGB libres, plaque, extras, klaxons, intérieur, réparation, factures société.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_bennys/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes pop_base + section 8)
  README.md               SERVEUR   (installation, mode mécano, intégration garages : pop_bennys:saved, standalone)
  bridge/ shared/         copiés par l'intégrateur (ne pas modifier)
  common/props.lua        copié par l'intégrateur depuis pop_vehiclepersistence (API Props, voir 3.1 ; ne pas modifier)
  common/bennys.lua       SERVEUR   constantes, Bennys.Valid, Bennys.Price (section 3.2), chargé des deux côtés
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR   sessions, achat, sauvegarde framework
  client/main.lua         CLIENT    zones, blips, ouverture, aperçu, caméra, NUI
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/                copié par l'intégrateur (ne pas modifier)
```

Pas de SQL propre (seulement l'écriture facultative dans la table du framework) : `oxmysql` est utilisé **s'il est
démarré** (`GetResourceState('oxmysql') == 'started'`), sinon l'écriture framework est désactivée (avertissement console).

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_bennys'
author 'POP'
version '1.0.0'
description 'POP Bennys - vehicle customization workshop'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua', 'common/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```
`@oxmysql/lib/MySQL.lua` est chargé seulement si la ressource existe : le Dev Serveur vérifie
`GetResourceState('oxmysql')` avant tout appel `MySQL.*` (pas de `dependencies`).

---

## 3. Données

### 3.1 API `Props` (fichier `common/props.lua` de pop_vehiclepersistence, contrat commun)
Format des propriétés ESX / QBCore / ox_lib, couleurs palette. Fonctions : `Props.Get(veh)` (client),
`Props.Set(veh, p)` (client, applique seulement les champs présents), `Props.Sanitize(p)` (pure),
`Props.Merge(base, changes)` (pure), tables `Props.MODS` (index → clé) et `Props.TOGGLES`. Détail complet :
`resources/[pop]/pop_vehiclepersistence/SPEC.md` section 3.1.

### 3.2 `common/bennys.lua` : table globale `Bennys`
```lua
Bennys = {}
Bennys.ZONE_TOLERANCE  = 3.0   -- serveur : marge ajoutée au rayon de l'atelier
Bennys.SESSION_TIMEOUT = 900   -- secondes
Bennys.MAX_CHANGES     = 64
Bennys.BODY = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 48 }   -- index de mods de carrosserie proposés
Bennys.PERF = { modEngine = 'engine', modBrakes = 'brakes', modTransmission = 'transmission',
                modSuspension = 'suspension', modArmor = 'armor' }  -- clé Props -> clé de Config.Prices
Bennys.TYPES = { automobile = true, bike = true, quadbike = true }   -- GetVehicleType autorisés
Bennys.CATEGORIES = { 'paint', 'wheels', 'body', 'performance', 'lights', 'windows' }
```

**Clés modifiables** (toute autre clé est refusée) :
| Clé | Catégorie | Valeur valide (`Bennys.Valid(key, value)`) | Prix (`Bennys.Price(key, value)`) |
|---|---|---|---|
| `color1`, `color2`, `pearlescentColor`, `wheelColor` | paint | entier, `id` présent dans `Config.Colors` | `Config.Prices.paint` |
| `wheels` | wheels | entier 0..12 | 0 |
| `modFrontWheels` | wheels | entier -1..255 | `Config.Prices.wheels` |
| `Props.MODS[i]` pour `i` dans `Bennys.BODY` | body | entier -1..255 | `Config.Prices.body` |
| clés de `Bennys.PERF` | performance | entier -1..`#Config.Prices[perf] - 1` | -1 → 0, sinon `Config.Prices[perf][value + 1]` |
| `modTurbo` | performance | boolean | `true` → `Config.Prices.turbo`, `false` → 0 |
| `modXenon` | lights | boolean | `true` → `Config.Prices.xenon`, `false` → 0 |
| `xenonColor` | lights | entier -1..12 | `Config.Prices.xenon` |
| `neonEnabled` | lights | liste de 4 booleans | `Config.Prices.neon` |
| `neonColor` | lights | liste `{ r, g, b }` égale à une entrée de `Config.NeonColors` | `Config.Prices.neon` |
| `windowTint` | windows | entier 0..6 | `Config.Prices.tint` |

Une ligne n'est facturée que si sa valeur **diffère** de l'origine (comparaison profonde pour les listes).
`Bennys.Valid` et `Bennys.Price` sont **pures** (aucune native) : utilisées par le serveur (autorité) et le client.

### 3.3 Session serveur
```lua
Sessions[src] = { netId, veh, plate, rawPlate, shop = index, original = Props, raw = table|nil, owned = bool, t = os.time() }
SessionByVeh[veh] = src
```
`original` : propriétés de référence pour le calcul du prix :
- véhicule **possédé** (table du framework lisible, ligne trouvée) → JSON de la table (`vehicle` ESX / `mods` QB),
  décodé (`raw`), puis `Props.Sanitize(raw)` : un client ne peut pas prétendre avoir déjà un mod ;
- sinon → `Props.Sanitize(current)` envoyé par le client à l'ouverture (référence de prix seulement : jamais
  transmise dans `pop_bennys:saved`, qui ne contient alors que les lignes payées, `owned = false`).

`Plate.Normalize(plate)` (en tête de `server/main.lua`, même règle que pop_vehiclekeys).

---

## 4. Events

Aucun event réseau propre au script (tout passe par les callbacks).

Event **serveur local** émis (`TriggerEvent`, non réseau) :
| Event | Paramètres | Quand |
|---|---|---|
| `pop_bennys:saved` | `src` (int), `plate` (string normalisée), `props` (Props, clés de l'atelier uniquement), `owned` (bool) | après chaque achat réussi |

`owned = true` : `props` = référence du framework + lignes payées, limitée aux clés modifiables (couleurs, `wheels`,
mods de `Bennys.BODY` et `Bennys.PERF`, `modFrontWheels`/`modBackWheels`, `modTurbo`, `modXenon`, `xenonColor`, `neon*`,
`windowTint`). `owned = false` : `props` **partiel**, seulement les lignes payées (à fusionner avec l'état connu).

---

## 5. Callbacks

Convention : `ok, reason (clé de locale) | nil, arg | nil`. Échec → le client notifie `L(reason or 'error', arg)` en
`error` ; succès → le serveur notifie. `nil` (timeout / anti-spam) = `error`.

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_bennys:open` | `netId` (int), `shop` (int, index `Config.Shops`), `current` (Props du client) | `ok, reason` |
| `pop_bennys:buy` | `netId` (int), `changes` (liste `{ key, value }`) | `ok, reason, arg` (succès : `arg` = total payé) |
| `pop_bennys:close` | `netId` (int) | `true` |

Raisons : `error`, `busy`, `too_far`, `wrong_job`, `not_driver`, `vehicle_not_allowed`, `vehicle_in_use`,
`invalid_change`, `no_changes`, `not_enough_money`.

---

## 6. Messages NUI

### Lua → JS
**`pop_bennys:open`** (le Lua construit tout depuis les natives du véhicule) :
```json
{ "action": "pop_bennys:open",
  "colors": [ { "id": 0, "hex": "#0a0a0a" }, { "id": 27, "hex": "#c01618" } ],
  "neonColors": [ [255, 46, 136], [34, 211, 238] ],
  "prices": { "color1": 500, "modFrontWheels": 800, "modSpoilers": 600,
              "modEngine": [2500, 5000, 7500, 10000], "modTurbo": 7500, "neonEnabled": 1500, "windowTint": 400 },
  "categories": [
    { "id": "paint", "items": [
        { "key": "color1", "type": "color", "value": 27 },
        { "key": "color2", "type": "color", "value": 0 },
        { "key": "pearlescentColor", "type": "color", "value": 0 },
        { "key": "wheelColor", "type": "color", "value": 156 } ] },
    { "id": "wheels", "items": [
        { "key": "wheels", "type": "list", "value": 0, "min": 0, "max": 12 },
        { "key": "modFrontWheels", "type": "list", "value": -1, "min": -1, "max": 49 } ] },
    { "id": "body", "items": [ { "key": "modSpoilers", "type": "list", "value": -1, "min": -1, "max": 3 } ] },
    { "id": "performance", "items": [
        { "key": "modEngine", "type": "list", "value": -1, "min": -1, "max": 3 },
        { "key": "modTurbo", "type": "toggle", "value": false } ] },
    { "id": "lights", "items": [
        { "key": "modXenon", "type": "toggle", "value": false },
        { "key": "xenonColor", "type": "list", "value": -1, "min": -1, "max": 12 },
        { "key": "neonEnabled", "type": "neon", "value": [false, false, false, false] },
        { "key": "neonColor", "type": "neoncolor", "value": [255, 0, 255] } ] },
    { "id": "windows", "items": [ { "key": "windowTint", "type": "list", "value": 0, "min": 0, "max": 6 } ] }
  ] }
```
Règles de construction (Lua) :
- `prices` : une entrée par clé présente (nombre ou liste pour `Bennys.PERF`), lue dans `Config.Prices` selon la table 3.2.
- `body` : seulement les index de `Bennys.BODY` avec `GetNumVehicleMods(veh, i) > 0` ; `max = count - 1`.
- `performance` : `max = min(GetNumVehicleMods(veh, i), #Config.Prices[perf]) - 1` ; ligne omise si `max < 0`.
- `wheels` : `max` de `modFrontWheels` = `GetNumVehicleMods(veh, 23) - 1`. Moto (`GetVehicleClass == 8`) : `wheels`
  fixé à 6 (`min = max = 6`).
- Catégorie sans ligne → omise.

**`pop_bennys:close`** : `{ "action": "pop_bennys:close" }` (fermeture forcée par le Lua).

### JS → Lua (`RegisterNUICallback`)
| Nom | Corps | Réponse | Effet Lua |
|---|---|---|---|
| `pop_bennys:preview` | `{ "key": "modEngine", "value": 2 }` | `{ "ok": true, "updates": [] }` | `Bennys.Valid` sinon `{ ok = false }` ; applique `Props.Set(veh, { [key] = value })` (`modFrontWheels` sur moto : aussi `modBackWheels`). Après `wheels` : jante remise à -1 et `updates = [ { "key": "modFrontWheels", "max": n, "value": -1 } ]` |
| `pop_bennys:camera` | `{ "category": "paint" }` | `{ "ok": true }` | change la vue (section 11) |
| `pop_bennys:confirm` | `{ "changes": [ { "key": "modEngine", "value": 2 } ] }` | `{ "ok": true }` ou `{ "ok": false, "error": "<clé>" }` | `pop_bennys:buy` ; succès → fermeture sans restauration ; échec → notification, le menu reste ouvert |
| `close` (kit) | `{}` | bridge | `Bridge.OnUiClose` → annulation : restauration + `pop_bennys:close` |

### Interface (Dev NUI)
- `index.html` : base pop_base + `style.css`. `#app` → `#bennys` (`pop-panel pop-fade`, masqué) :
  - en-tête `data-locale="title"` ;
  - `#bennys-tabs` : un bouton `pop-button pop-small` par catégorie reçue (`Pop.t('cat_' + id)`), actif = bordure
    accent ; changement d'onglet → `Pop.post('pop_bennys:camera', { category })` ;
  - `#bennys-items` : lignes de la catégorie active : libellé `Pop.t('label_' + key)` + contrôle + prix de la ligne
    (`Pop.t('price', n)`, en accent seulement si modifiée, sinon vide) :
    - `list` : `‹` valeur `›` (boutons, bornes `min` / `max`, pas de bouclage) ; valeur affichée :
      -1 → `Pop.t('stock')` ; `wheels` → `Pop.t('wheel_type_' + v)` ; `windowTint` → `Pop.t('tint_' + v)` ;
      performance → `Pop.t('level', v + 1)` ; autres → `Pop.t('option', v + 1, max + 1)` ;
    - `toggle` : bouton `Pop.t('on')` / `Pop.t('off')` ;
    - `color` : grille de pastilles 24 px (6 par ligne) depuis `colors`, sélection = contour accent ;
    - `neon` : 4 boutons `Pop.t('neon_0')` … `Pop.t('neon_3')` (activé = accent) ;
    - `neoncolor` : pastilles depuis `neonColors` (`rgb(r, g, b)`).
    Chaque changement → `Pop.post('pop_bennys:preview', { key, value })` puis applique `updates`.
  - pied : `#bennys-total` = `Pop.t('total', somme)` ; boutons `data-locale="confirm"` (désactivé si aucune ligne
    modifiée) et `data-locale="cancel"`.
- `script.js` : garde `original` (valeurs reçues) et `current`. Prix d'une ligne (même règle que `Bennys.Price`) :
  liste de prix → `value >= 0 ? prices[key][value] : 0` ; toggle → `value ? prix : 0` ; sinon le nombre ;
  0 si `current` égale `original` (comparaison profonde). Confirmer → `Pop.post('pop_bennys:confirm', { changes })`
  (seulement les lignes modifiées, `wheels` inclus si modifié) ; réponse `ok` → masque ; sinon reste ouvert.
  Annuler / Échap → `Pop.post('close')` puis masque. `Pop.on('pop_bennys:close')` → masque. DOM construit sans
  `innerHTML` pour les données. Aucun texte en dur.
- `style.css` : panneau 320 px, `position: fixed; right: 24px; top: 50%; transform: translateY(-50%);
  max-height: 80vh`, défilement de `#bennys-items` ; fond `--pop-bg`, une seule couleur d'accent, aucun dégradé ni
  ombre lourde, transition = `.pop-fade`. RTL : à gauche.

---

## 7. Exports publics

Client : `exports.pop_bennys:IsOpen()` → bool. Serveur : aucun (intégration = event `pop_bennys:saved`).

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_bennys ──────────────────────────────────────────────

-- Compte débité : 'cash' | 'bank'. En standalone (aucun argent), mettre tous les prix à 0.
Config.Account = 'bank'

-- Écrit les propriétés achetées dans la table du framework (owned_vehicles / player_vehicles) si le véhicule y est.
Config.SaveToFramework = true

-- Ateliers. jobs = false : public ; sinon format Bridge.HasJob, en service (ex. { mechanic = 0 }).
Config.Shops = {
    { coords = vec3(-211.94, -1324.53, 30.45), radius = 4.0, jobs = false, blip = true },
}

-- Prix. Performance : prix du niveau 1, 2, 3... (le nombre d'entrées limite les niveaux proposés).
Config.Prices = {
    paint = 500,        -- par couleur changée
    wheels = 800,       -- jante
    body = 600,         -- par pièce
    engine = { 2500, 5000, 7500, 10000 },
    brakes = { 1500, 3000, 4500 },
    transmission = { 2000, 4000, 6000 },
    suspension = { 1000, 2000, 3000, 4000 },
    armor = { 2500, 5000, 7500, 10000, 12500 },
    turbo = 7500,
    xenon = 1000,       -- activation ou couleur
    neon = 1500,        -- disposition ou couleur
    tint = 400,
}

-- Palette de peinture : id = couleur native GTA, hex = aperçu.
Config.Colors = {
    { id = 0,   hex = '#0a0a0a' }, { id = 1,   hex = '#1c1d21' }, { id = 4,   hex = '#999da0' },
    { id = 111, hex = '#ffffff' }, { id = 27,  hex = '#c01618' }, { id = 28,  hex = '#8c1b1d' },
    { id = 38,  hex = '#f6901a' }, { id = 88,  hex = '#ffc400' }, { id = 92,  hex = '#9acc40' },
    { id = 54,  hex = '#2f592a' }, { id = 64,  hex = '#59667c' }, { id = 70,  hex = '#355e9c' },
    { id = 74,  hex = '#6ea9c4' }, { id = 135, hex = '#f21896' }, { id = 145, hex = '#622699' },
    { id = 45,  hex = '#584635' }, { id = 49,  hex = '#bfad8f' }, { id = 156, hex = '#a3a3a3' },
}

-- Couleurs de néons proposées (r, g, b).
Config.NeonColors = {
    { 255, 46, 136 }, { 34, 211, 238 }, { 255, 255, 255 }, { 255, 0, 0 },
    { 0, 255, 0 }, { 0, 80, 255 }, { 255, 200, 0 }, { 150, 0, 255 },
}
```

---

## 9. Locales

10 fichiers (Dev Serveur) : kit commun inchangé + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `title` | Benny's | Benny's |
| `blip` | Benny's workshop | Atelier Benny's |
| `open_hint` | Customize | Personnaliser |
| `cat_paint` | Paint | Peinture |
| `cat_wheels` | Wheels | Roues |
| `cat_body` | Body | Carrosserie |
| `cat_performance` | Performance | Performance |
| `cat_lights` | Lights | Éclairage |
| `cat_windows` | Windows | Vitres |
| `label_color1` | Primary | Primaire |
| `label_color2` | Secondary | Secondaire |
| `label_pearlescentColor` | Pearlescent | Nacré |
| `label_wheelColor` | Rim color | Couleur des jantes |
| `label_wheels` | Wheel type | Type de roues |
| `label_modFrontWheels` | Rims | Jantes |
| `label_modSpoilers` | Spoiler | Aileron |
| `label_modFrontBumper` | Front bumper | Pare-chocs avant |
| `label_modRearBumper` | Rear bumper | Pare-chocs arrière |
| `label_modSideSkirt` | Side skirts | Bas de caisse |
| `label_modExhaust` | Exhaust | Échappement |
| `label_modFrame` | Roll cage | Arceau |
| `label_modGrille` | Grille | Calandre |
| `label_modHood` | Hood | Capot |
| `label_modFender` | Left fender | Aile gauche |
| `label_modRightFender` | Right fender | Aile droite |
| `label_modRoof` | Roof | Toit |
| `label_modLivery` | Livery | Livrée |
| `label_modEngine` | Engine | Moteur |
| `label_modBrakes` | Brakes | Freins |
| `label_modTransmission` | Transmission | Transmission |
| `label_modSuspension` | Suspension | Suspension |
| `label_modArmor` | Armor | Blindage |
| `label_modTurbo` | Turbo | Turbo |
| `label_modXenon` | Xenon lights | Phares xénon |
| `label_xenonColor` | Xenon color | Couleur xénon |
| `label_neonEnabled` | Neons | Néons |
| `label_neonColor` | Neon color | Couleur des néons |
| `label_windowTint` | Window tint | Teinte des vitres |
| `neon_0` | Left | Gauche |
| `neon_1` | Right | Droite |
| `neon_2` | Front | Avant |
| `neon_3` | Back | Arrière |
| `wheel_type_0` … `wheel_type_12` | Sport, Muscle, Lowrider, SUV, Offroad, Tuner, Bike, High end, Benny's Original, Benny's Bespoke, Open wheel, Street, Track | Sport, Muscle, Lowrider, SUV, Tout-terrain, Tuner, Moto, Haut de gamme, Benny's Original, Benny's Bespoke, Monoplace, Rue, Piste |
| `tint_0` … `tint_6` | None, Pure black, Dark smoke, Light smoke, Stock, Limo, Green | Aucune, Noir pur, Fumé foncé, Fumé clair, D'origine, Limousine, Verte |
| `stock` | Stock | D'origine |
| `option` | %s / %s | %s / %s |
| `level` | Level %s | Niveau %s |
| `on` | On | Oui |
| `off` | Off | Non |
| `price` | $%s | %s $ |
| `total` | Total: $%s | Total : %s $ |
| `not_driver` | You must be driving the vehicle | Vous devez être au volant |
| `vehicle_not_allowed` | This vehicle can't be customized here | Ce véhicule ne peut pas être modifié ici |
| `vehicle_in_use` | This vehicle is already being customized | Ce véhicule est déjà en cours de modification |
| `invalid_change` | Invalid modification | Modification invalide |
| `no_changes` | No changes to pay for | Aucune modification à payer |
| `paid` | Modifications installed ($%s) | Modifications installées (%s $) |

(`wheel_type_n` et `tint_n` : une clé par valeur, dans l'ordre indiqué.) Clés de base réutilisées : `confirm`,
`cancel`, `too_far`, `wrong_job`, `not_enough_money`, `busy`, `error`.

---

## 10. Schéma SQL

Aucune table. Écriture facultative (section 12) dans `owned_vehicles` (ESX) / `player_vehicles` (QBCore, Qbox).

---

## 11. Comportement client (`client/main.lua`)

- **Blips** : pour chaque atelier avec `blip` : sprite 72, couleur 0, échelle 0.8, `SetBlipAsShortRange`, nom `L('blip')`.
- **Boucle de zone** (une seule) : distance au plus proche atelier : > 50 m → `Wait(1500)` ; ≤ 50 m → `Wait(500)` ;
  **dans le rayon, conducteur**, menu fermé et non occupé → `Wait(0)` (seulement là) :
  `DisableControlAction(0, 86, true)` (klaxon) ; prompt du kit
  `SendNUIMessage({ action = 'pop:prompt', show = true, key = Config.Keys.Interact.label, label = L('open_hint') })`
  envoyé une fois à l'entrée, `show = false` à la sortie ; `IsDisabledControlJustReleased(0, 86)` ou
  `IsControlJustReleased(0, Config.Keys.Interact.control)` → `open(index)`.
- **`open(index)`** : véhicule actuel ; `current = Props.Get(veh)` ;
  `Callback.Await('pop_bennys:open', VehToNet(veh), index, current)` ; échec → notification. Succès :
  `snapshot = current`, `SetVehicleModKit(veh, 0)`, `FreezeEntityPosition(veh, true)`, `DisplayRadar(false)`,
  caméra `paint`, message `pop_bennys:open`, `SetNuiFocus(true, true)`, prompt masqué.
- **Caméra** : vues constantes `CAMERAS = { paint = { pos = { 4.4, 0.0, 1.0 }, look = { 0.0, 0.0, 0.5 } },
  wheels = { pos = { 3.0, 1.6, 0.2 }, look = { 0.0, 1.6, 0.1 } }, body = { pos = { 3.2, -3.2, 1.4 }, look = { 0.0, 0.0, 0.6 } },
  performance = { pos = { 0.0, 4.4, 1.3 }, look = { 0.0, 1.6, 0.6 } }, lights = { pos = { 3.2, 2.2, 0.1 }, look = { 0.0, 0.0, -0.3 } },
  windows = { pos = { 2.6, 0.4, 1.3 }, look = { 0.0, 0.2, 1.0 } } }` (décalages locaux du véhicule) ;
  `CreateCamWithParams`, `PointCamAtCoord`, transition `SetCamActiveWithInterp` 500 ms depuis la vue précédente.
- **Surveillance** pendant le menu : boucle 500 ms : véhicule disparu, joueur mort ou plus conducteur → annulation.
- **Ouverture refusée** : classes 13, 14, 15, 16, 21, ou vitesse ≥ 2.0. Moto = `IsThisModelABike` (vélos exclus).
- **Fermeture** : après achat, ou réponse `nil` de `buy` → aucune restauration ; annulation → restauration des seules clés
  touchées par l'aperçu (`touched`, + `modFrontWheels`/`modBackWheels` après `wheels`), peinture RGB personnalisée et
  variation de jante (mods 23/24) d'origine réappliquées, puis `Callback.Trigger('pop_bennys:close', netId)`. Dans les
  deux cas : `RenderScriptCams(false, …)` puis caméras détruites, `FreezeEntityPosition(veh, false)`, radar remis dans
  son état d'origine (`IsRadarHidden`), `SetNuiFocus(false, false)`, message `pop_bennys:close`.
- **Arrêt de la ressource** : menu ouvert → restauration du snapshot, caméra, gel, radar, focus, prompt, blips.

---

## 12. Comportement serveur et sécurité (`server/main.lua`)

**`pop_bennys:open(netId, shop, current)`**
1. Joueur valide ; pas de session pour `src` (sinon `busy`) ; verrou de traitement `busy[src]`.
2. `math.type(shop) == 'integer'` et `Config.Shops[shop]` existe ; `Bridge.IsNear(src, s.coords, s.radius + Bennys.ZONE_TOLERANCE)`, sinon `too_far`.
3. `s.jobs` → `Bridge.HasJob(src, s.jobs)` **et** `Bridge.GetJob(src).onDuty`, sinon `wrong_job`.
4. Véhicule : netId entier, entité existante, `GetEntityType == 2` ; `GetPedInVehicleSeat(veh, -1) == GetPlayerPed(src)`,
   sinon `not_driver` ; `Bennys.TYPES[GetVehicleType(veh)]`, sinon `vehicle_not_allowed` ; `SessionByVeh[veh]`, sinon
   `vehicle_in_use`. Plaque serveur normalisée, sinon `error`.
5. `original` selon la section 3.3 (lecture framework seulement si oxmysql démarré et framework ≠ standalone ;
   ESX `SELECT vehicle FROM owned_vehicles WHERE plate = ? OR REPLACE(plate, ' ', '') = ? LIMIT 1`, QB / Qbox
   `SELECT mods FROM player_vehicles WHERE plate = ? OR REPLACE(plate, ' ', '') = ? LIMIT 1`, paramètres plaque brute
   (sans espaces de bord) puis normalisée ; JSON invalide → non possédé). Joueur revalidé après la lecture.
6. Session créée, `true`.

**`pop_bennys:buy(netId, changes)`**
1. Session de `src` existante, même `netId` et même entité, âge ≤ `Bennys.SESSION_TIMEOUT`, sinon `error` (session supprimée si expirée).
2. Revérifier : atelier proche, job, conducteur (mêmes raisons que l'ouverture).
3. `changes` : table séquentielle de 1 à `Bennys.MAX_CHANGES` entrées `{ key = string, value }`, clés uniques,
   chaque entrée `Bennys.Valid(key, value)`, moto (`GetVehicleType == 'bike'`) : `wheels` = 6 uniquement, sinon
   `invalid_change` (tout ou rien ; `s.t` rafraîchi, comme pour `not_enough_money`).
4. Lignes réellement modifiées (différentes de `original`) ; aucune → `no_changes`.
   `total = Σ Bennys.Price(key, value)` (entier ≥ 0, lu dans la config serveur).
5. `total > 0` → `Bridge.RemoveMoney(src, Config.Account, total, 'pop_bennys')`, sinon `not_enough_money`.
6. `lignes.wheels` sans `modFrontWheels` → `modFrontWheels` = valeur envoyée, sinon `-1` (non facturé) ; moto :
   `modBackWheels = modFrontWheels`. `final = Props.Merge(owned and original or nil, lignes)` limité aux clés modifiables (section 4).
7. Si `Config.SaveToFramework` et `owned` : `MySQL.update` de la colonne JSON avec `Props.Merge(raw, lignes)` (garde les
   clés inconnues du garage, `plate` et `model` d'origine) ; `color1` / `color2` achetée → `customPrimaryColor` /
   `customSecondaryColor` retirée (data et final) ; erreur SQL → log console, l'achat reste valide.
8. `TriggerEvent('pop_bennys:saved', src, plate, final, owned)`, notification `L('paid', total)` (`success`), session supprimée.
   Retour `true, nil, total`.

**`pop_bennys:close(netId)`** : supprime la session de `src` (si `netId` correspond). Toujours `true`.

**Règles générales**
- Prix, palette, niveaux et compte : **uniquement** depuis la config serveur ; le client n'envoie que des clés et des
  valeurs, validées une à une.
- Référence de prix fiable pour les véhicules possédés (table du framework), jamais l'état envoyé par le client.
- Une session par joueur et par véhicule ; sessions et verrous nettoyés dans `Bridge.OnPlayerDropped` /
  `Bridge.OnPlayerUnloaded`, et à l'achat / l'annulation / l'expiration.
- Aucun `RegisterNetEvent` serveur ; anti-spam du template actif. `Config.Debug` : log des achats (src, plaque, total).

---

## 13. Performance
- Hors atelier : boucle à 1500 / 500 ms. `Wait(0)` seulement dans la zone d'un atelier, au volant, menu fermé.
- Menu ouvert : aucune boucle par frame (caméra fixe, véhicule figé), surveillance à 500 ms.

## 14. Limites (README)
- L'aperçu est appliqué par le client ; un tricheur pourrait modifier son véhicule sans payer, mais la sauvegarde
  (event et table du framework) ne contient que ce qui a été payé.
- Couleurs RGB personnalisées non proposées (palette) ; une couleur d'origine RGB est restaurée à l'annulation.
- Véhicule non possédé : `pop_bennys:saved` reçoit des props partielles (`owned = false`).
- Standalone : pas d'argent → prix à 0.

## 15. Checklist auditeur
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`. Copies strictes (bridge, shared, kit, props).
- Annuler / Échap / arrêt de la ressource restaurent toujours le véhicule et rendent le focus.
- Aucun montant ni prix venant du client ; achat refusé hors zone, sans job, sans être conducteur.
