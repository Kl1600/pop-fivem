# pop_weed : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).

---

## 1. Description et fonctionnalités

Culture de cannabis en pot, simple et lisible, façon GTA 6 : des étapes courtes, et une récolte dont la qualité
dépend des soins donnés.

**Boucle de jeu**
1. **Planter** : utiliser l'item `pot` (ou `seed`) avec un pot **et** une graine dans l'inventaire. Un aperçu
   transparent de la plante apparaît devant le joueur : `[E] Planter`, `[X] Annuler`. Barre de progression, puis
   le serveur valide et retire 1 pot + 1 graine.
2. **Arroser** : il faut une bouteille d'eau (consommée). L'eau baisse avec le temps (100 % → 0 % en
   `Config.WaterDuration`). Une plante neuve démarre à **0 % d'eau** : arroser est la 2e étape.
3. **Engrais (facultatif)** : une seule fois par plante, avant maturité. Bonus de qualité.
4. **Récolter** : quand la croissance atteint 100 %. Quantité et qualité dépendent des soins. Item de récolte
   avec la métadonnée `{ quality = n }` (si l'inventaire gère les métadonnées).

**Règles**
- Croissance basée **uniquement sur le temps serveur** (`os.time()`), 3 stades visuels. Elle ne s'arrête pas.
- **Qualité** (0-100) : base + bonus engrais − pénalité selon le temps passé **à sec** (eau à 0 %) pendant la
  croissance. Formule unique dans `common/plant.lua` (section 11).
- Une plante mûre non récoltée **pourrit** après `Config.RotTime` et disparaît.
- **Police** (`Config.Police.jobs`, en service) : peut détruire n'importe quelle plante.
- **Odeur** : à chaque récolte, `Config.Police.alertChance` de chance d'alerter la police en service (notification
  + blip temporaire sur la position).
- Limite de plantes par joueur, espacement minimal entre plantes, pas dans l'eau ni en véhicule.
- Persistance en base (oxmysql, table `pop_weed_plants`), créée automatiquement au démarrage.

**HUD** (sobre, petit, côté droit, fondu 150 ms)
- Carte d'info quand le joueur est à ≤ `Plant.INFO_DISTANCE` de la plante la plus proche : stade, croissance %,
  eau %, qualité %, engrais oui/non, « Prête à récolter ».
- Panneau de placement pendant la pose : `[E] Planter  [X] Annuler`, ou la raison si l'emplacement est invalide.
- Prompts / progression / notifications : ceux du kit (`pop:prompt`, `pop:progress`) via le bridge.

**Performance**
- Props **locaux uniquement** (`CreateObject(..., false, false, false)`), aucune entité réseau.
- Streaming par distance dans **une seule boucle adaptative** (250 / 1000 / 2000 ms). `Wait(0)` seulement pendant
  le placement (temporaire, 30 s max) et dans `Bridge.Progress`.
- Serveur : aucune boucle rapide. Une seule boucle de nettoyage toutes les 5 min (plantes pourries).
- Les valeurs (stade, eau, qualité) sont **calculées** à partir d'horodatages : aucune synchro périodique.

**Hors périmètre (volontairement)** : séchage/transformation, vente, lampes, gizmo de placement, menus.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_weed/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + clés de la section 8, à l'identique)
  README.md               SERVEUR   (installation, items par inventaire, config)
  sql/install.sql         SERVEUR
  bridge/server.lua       SERVEUR   copie STRICTE de templates/pop_base/bridge/server.lua
  bridge/client.lua       CLIENT    copie STRICTE de templates/pop_base/bridge/client.lua
  shared/callback.lua     SERVEUR   copie STRICTE de templates/pop_base/shared/callback.lua
  shared/locale.lua       SERVEUR   copie STRICTE de templates/pop_base/shared/locale.lua
  common/plant.lua        SERVEUR   logique partagée (formules), chargée des deux côtés (section 11)
  locales/en.lua          SERVEUR   clés de base (pop_base) + clés de la section 9
  locales/fr.lua  es.lua  de.lua  it.lua  pt.lua  nl.lua  pl.lua  tr.lua  ar.lua   SERVEUR (idem, ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    synchro, streaming des props, targets, carte d'info, alerte police
  client/placement.lua    CLIENT    mode placement (aperçu, validation locale, envoi)
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/pop.css         NUI       copie STRICTE de templates/pop_base/web/kit/pop.css
  web/kit/pop.js          NUI       copie STRICTE de templates/pop_base/web/kit/pop.js
```

**Copies depuis `templates/pop_base`** (jamais modifiées dans le script ; un manque se corrige dans le template) :
- Dev Serveur : `bridge/server.lua`, `shared/callback.lua`, `shared/locale.lua`.
- Dev Client : `bridge/client.lua`.
- Dev NUI : `web/kit/` (pop.css, pop.js).
- Dev Serveur : écrit les **10** fichiers `locales/` en **fusionnant** les clés de base de pop_base (bloc
  « Kit commun », inchangé) et les clés de la section 9 (sous `-- Textes propres au script :`).

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_weed'
author 'POP'
version '1.0.0'
description 'POP Weed - cannabis growing'

dependencies { 'oxmysql' }

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
    'common/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
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

---

## 3. Données d'une plante

### `PlantData` (envoyée aux clients) : **jamais** de propriétaire
```lua
{
    id         = 12,        -- integer (id SQL)
    x          = 293.26,    -- number
    y          = -648.12,
    z          = 113.07,    -- z du sol (l'offset du modèle est ajouté côté client)
    heading    = 276.0,     -- number 0-360
    plantedAt  = 1773695584,-- os.time() serveur à la plantation
    water      = 100.0,     -- niveau d'eau (0-100) au moment waterAt
    waterAt    = 1773695600,-- os.time() serveur où `water` a été fixé
    dry        = 0,         -- secondes cumulées à sec, arrêtées à waterAt
    fertilized = false,     -- boolean
}
```
Côté serveur, l'entrée en mémoire a en plus `owner` (identifiant `Bridge.GetIdentifier`). Le serveur envoie
toujours une copie **sans** `owner` (fonction locale `toClient(p)`).

### Heure serveur côté client
Le client n'a pas `os.time()`. À chaque réception d'un `now` serveur :
`syncNow, syncTimer = now, GetGameTimer()` puis `ServerNow() = syncNow + (GetGameTimer() - syncTimer) / 1000`.
Toutes les fonctions `Plant.*` reçoivent `now` en paramètre (serveur : `os.time()`, client : `ServerNow()`).

---

## 4. Events

Les actions client → serveur passent **toutes par des callbacks** (section 5). Il n'y a **aucun**
`RegisterNetEvent` serveur propre au script.

### Serveur → Client (`RegisterNetEvent` côté client)

| Event | Paramètres | Destinataire | Rôle |
|---|---|---|---|
| `pop_weed:client:startPlacement` | aucun | le joueur | Lance le mode placement (après les pré-contrôles de l'item utilisable) |
| `pop_weed:client:plantAdded` | `plant` (PlantData), `now` (int) | `-1` | Nouvelle plante |
| `pop_weed:client:plantUpdated` | `plant` (PlantData), `now` (int) | `-1` | Eau ou engrais modifié (remplace l'entrée entière) |
| `pop_weed:client:plantRemoved` | `id` (int) | `-1` | Plante récoltée, détruite, pourrie ou retirée par export |
| `pop_weed:client:policeAlert` | `coords` (`{ x, y, z }`) | chaque policier en service | Notification + blip temporaire |

Le client ignore `plantAdded` si l'id existe déjà, et `plantUpdated` / `plantRemoved` si l'id est inconnu.

### Évènements du bridge utilisés (pas d'event réseau supplémentaire)
- Serveur : `Bridge.OnPlayerDropped(src)` → libère les verrous `busy[src]`.
- Client : `Bridge.OnPlayerLoaded` → charge les plantes ; `Bridge.OnJobUpdate` → met à jour `isPolice`.

---

## 5. Callbacks (`shared/callback.lua`)

Convention de retour des actions : `ok (bool), reason (string, clé de locale) | nil, arg | nil`.
En cas d'échec, le **client** affiche `Bridge.Notify(L(reason or 'error', arg), 'error')`.
En cas de succès, c'est le **serveur** qui notifie (`Bridge.Notify(src, ..., 'success')`).
`nil` (timeout 10 s ou anti-spam) = traiter comme `reason = 'error'`.

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_weed:getPlants` | aucun | `plants` (tableau **séquentiel** de PlantData), `now` (int) |
| `pop_weed:plant` | `coords` (`{ x, y, z }`, z = sol), `heading` (number) | `ok, reason, arg` |
| `pop_weed:water` | `id` (int) | `ok, reason, arg` |
| `pop_weed:fertilize` | `id` (int) | `ok, reason, arg` |
| `pop_weed:harvest` | `id` (int) | `ok, reason, arg` |
| `pop_weed:destroy` | `id` (int) | `ok, reason, arg` |

`pop_weed:getPlants` attend la fin du chargement SQL (`while not loaded do Wait(200) end`, dans le handler).

**Raisons possibles** (toutes sont des clés de locale existantes) :
`error`, `busy`, `too_far`, `missing_item` (arg = libellé traduit, ex. `L('item_seed')`), `inventory_full`,
`wrong_job`, `in_vehicle`, `cannot_plant_here`, `too_close_plant`, `max_plants` (arg = `Config.MaxPlants`),
`plant_not_found`, `not_ready`, `plant_not_thirsty`, `already_fertilized`, `already_ready`, `not_owner`.

Aucun callback serveur → client.

---

## 6. Messages NUI

L'interface **ne prend jamais le focus** (`SetNuiFocus` jamais appelé par le script). Pas de callback JS → Lua
propre au script : seuls ceux du kit existent (`pop:ready`, `close`, gérés par le bridge).

### Lua → JS (`SendNUIMessage`)

**`pop_weed:info`** : carte d'info de la plante la plus proche. Envoyé seulement si une valeur affichée change.
```json
{ "action": "pop_weed:info", "show": true,
  "stage": 2, "stages": 3, "growth": 57, "water": 42, "quality": 88,
  "fertilized": true, "ready": false }
```
```json
{ "action": "pop_weed:info", "show": false }
```
Tous les nombres sont des **entiers** (arrondis côté Lua). `growth`, `water`, `quality` : 0-100.

**`pop_weed:placement`** : panneau du mode placement. Envoyé à l'ouverture, à chaque changement de validité et à
la fermeture.
```json
{ "action": "pop_weed:placement", "show": true, "valid": true, "reason": null,
  "confirmKey": "E", "cancelKey": "X" }
```
```json
{ "action": "pop_weed:placement", "show": true, "valid": false, "reason": "too_close_plant",
  "confirmKey": "E", "cancelKey": "X" }
```
```json
{ "action": "pop_weed:placement", "show": false }
```
`confirmKey` = `Config.Keys.Interact.label`, `cancelKey` = `Config.Keys.Cancel.label`.
`reason` est une clé de locale (`cannot_plant_here`, `too_close_plant`, `in_vehicle`), traduite côté JS par `Pop.t`.

### Interface (Dev NUI)
- `web/index.html` : base de pop_base, `<link rel="stylesheet" href="style.css">` après `kit/pop.css`.
  Remplacer `#app` par deux blocs, masqués par défaut (`pop-panel pop-fade`) :
  - `#weed-info` (carte) : en-tête `data-locale="info_title"` + stade (`#weed-stage`) ; 3 lignes libellé + valeur
    `NN%` + barre fine (4 px) : `info_growth`, `info_water`, `info_quality` ; ligne `#weed-fert` (petite).
  - `#weed-place` : `[E] place_confirm   [X] cancel` (classes `pop-key`), ou la raison seule.
- `web/script.js` : `Pop.on('pop_weed:info', ...)`, `Pop.on('pop_weed:placement', ...)`, `Pop.show(el, visible)`.
  - Stade : `Pop.t('info_stage', stage, stages)` ; si `ready` : `Pop.t('info_ready')` en couleur d'accent.
  - Engrais : `Pop.t('info_fertilized')` ou `Pop.t('info_not_fertilized')`.
  - Barres : `transform: scaleX(valeur / 100)` ; eau < 25 → couleur `--pop-danger`.
  - Placement invalide : afficher `Pop.t(reason)` en `--pop-danger`, masquer la touche de confirmation.
  - Tous les libellés via `data-locale` / `Pop.t` : **aucun texte en dur**.
- `web/style.css` : carte de 220 px, `position: fixed; right: 24px; top: 28%` (au-dessus du HUD du kit centré à
  50 %), `#weed-place` en `bottom: 12%; right: 24px`. Fond `--pop-bg`, texte `--pop-size-sm`, accent
  `--pop-accent`, aucun dégradé, aucune ombre lourde, transition = celle de `.pop-fade` uniquement.
  RTL : `[dir="rtl"]` → `right: auto; left: 24px`, barres `transform-origin: right`.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_weed:GetPlants()` | tableau de PlantData **avec** `owner` | lecture (MDT, admin…) ; copies, pas les références internes |
| `exports.pop_weed:GetPlayerPlantCount(src)` | number | plantes du joueur (par identifiant) |
| `exports.pop_weed:RemovePlant(id)` | bool | supprime (mémoire + SQL) et diffuse `plantRemoved` |

Client :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_weed:IsPlacing()` | bool | mode placement actif |

---

## 8. config.lua (contenu exact)

Le fichier reprend **à l'identique** le `config.lua` de `templates/pop_base` (Locale, Debug, Framework, Inventory,
Target, Notify, AccentColor, Keys, CallbackRateLimit), puis ajoute à la suite :

```lua
-- ─── pop_weed ───────────────────────────────────────────────

-- Noms des items (à déclarer dans votre inventaire, voir README).
Config.Items = {
    pot        = 'weed_pot',
    seed       = 'weed_seed',
    water      = 'water_bottle',     -- ox_inventory : 'water'
    fertilizer = 'weed_fertilizer',
    harvest    = 'weed',             -- reçoit la métadonnée { quality = 0-100 }
}

Config.GrowTime      = 3600   -- secondes de la plantation à la récolte
Config.WaterDuration = 1800   -- secondes pour passer de 100 % à 0 % d'eau
Config.RotTime       = 86400  -- une plante mûre non récoltée disparaît après ce délai (secondes)

Config.MaxPlants  = 5         -- plantes max par joueur
Config.MinSpacing = 1.5       -- distance minimale entre deux plantes (mètres)
Config.OwnerOnly  = false     -- true : seul le planteur peut récolter

-- Qualité finale = base + engrais - (temps à sec / GrowTime) * dryPenalty, bornée 0-100.
Config.Quality = { base = 75, fertilizer = 25, dryPenalty = 100 }

-- Quantité récoltée = min + (max - min) * qualité / 100 (arrondi inférieur).
Config.Harvest = { min = 2, max = 6 }

-- Durée des actions (ms).
Config.Durations = { plant = 4000, water = 3000, fertilize = 3000, harvest = 6000, destroy = 5000 }

Config.Police = {
    jobs        = { 'police', 'sheriff' }, -- format Bridge.HasJob ; doivent être en service
    alertChance = 0.25,                    -- chance d'alerte à chaque récolte (0 = jamais)
    blipTime    = 60,                      -- durée du blip d'alerte (secondes)
}

-- Distance d'apparition des plantes (mètres).
Config.SpawnDistance = 50.0

-- Stades visuels, répartis à parts égales sur GrowTime. offset = décalage vertical du modèle.
Config.Stages = {
    { model = 'bkr_prop_weed_01_small_01b', offset = 0.0 },
    { model = 'bkr_prop_weed_med_01b',      offset = -2.5 },
    { model = 'bkr_prop_weed_lrg_01b',      offset = -2.5 },
}
```

Aucune autre clé. Les distances fixes sont des constantes de `common/plant.lua` (section 11).

---

## 9. Locales

10 fichiers : `en` (défaut + repli), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (`_rtl = true`).
Chaque fichier = bloc « Kit commun » de pop_base inchangé + les clés ci-dessous sous `-- Textes propres au script :`.
Les formats `%s` sont conservés dans toutes les langues (même nombre, même ordre). `%%` = signe pourcent
(utilisé avec `string.format` côté Lua ; la clé `harvested` n'est jamais passée par `Pop.t`).

| Clé | en | fr |
|---|---|---|
| `item_pot` | Pot | Pot |
| `item_seed` | Cannabis seed | Graine de cannabis |
| `item_water` | Water bottle | Bouteille d'eau |
| `item_fertilizer` | Fertilizer | Engrais |
| `place_confirm` | Plant | Planter |
| `cannot_plant_here` | You can't plant here | Impossible de planter ici |
| `too_close_plant` | Too close to another plant | Trop près d'une autre plante |
| `in_vehicle` | Get out of the vehicle first | Sortez d'abord du véhicule |
| `max_plants` | You can't have more than %s plants | Vous ne pouvez pas avoir plus de %s plantes |
| `planting` | Planting... | Plantation... |
| `watering` | Watering... | Arrosage... |
| `fertilizing` | Adding fertilizer... | Ajout d'engrais... |
| `harvesting` | Harvesting... | Récolte... |
| `destroying` | Destroying the plant... | Destruction de la plante... |
| `planted` | Plant potted. Water it now | Plante mise en pot. Arrosez-la |
| `watered` | Plant watered | Plante arrosée |
| `fertilized` | Fertilizer added | Engrais ajouté |
| `harvested` | Harvested x%s (quality %s%%) | Récolte : x%s (qualité %s %%) |
| `destroyed` | Plant destroyed | Plante détruite |
| `plant_not_found` | This plant no longer exists | Cette plante n'existe plus |
| `not_ready` | This plant isn't ready yet | Cette plante n'est pas encore prête |
| `already_ready` | This plant is already fully grown | Cette plante a fini de pousser |
| `plant_not_thirsty` | This plant doesn't need water | Cette plante n'a pas besoin d'eau |
| `already_fertilized` | This plant already has fertilizer | Cette plante a déjà de l'engrais |
| `not_owner` | This isn't your plant | Ce n'est pas votre plante |
| `target_water` | Water | Arroser |
| `target_fertilize` | Fertilize | Mettre de l'engrais |
| `target_harvest` | Harvest | Récolter |
| `target_destroy` | Destroy | Détruire |
| `info_title` | Cannabis | Cannabis |
| `info_stage` | Stage %s/%s | Stade %s/%s |
| `info_ready` | Ready to harvest | Prête à récolter |
| `info_growth` | Growth | Croissance |
| `info_water` | Water | Eau |
| `info_quality` | Quality | Qualité |
| `info_fertilized` | Fertilized | Engrais : oui |
| `info_not_fertilized` | No fertilizer | Engrais : non |
| `police_alert` | Strong cannabis smell reported nearby | Forte odeur de cannabis signalée |
| `police_blip` | Cannabis smell | Odeur de cannabis |

Clés de base réutilisées : `cancel`, `too_far`, `missing_item`, `inventory_full`, `wrong_job`, `busy`, `error`,
`progress_cancelled`. Les messages console (logs) restent en anglais et ne passent pas par `L()`.

---

## 10. Schéma SQL

`sql/install.sql` (le serveur exécute aussi ce `CREATE TABLE IF NOT EXISTS` au démarrage : aucune action manuelle
requise) :

```sql
CREATE TABLE IF NOT EXISTS `pop_weed_plants` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner`      VARCHAR(64)  NOT NULL,
    `x`          FLOAT        NOT NULL,
    `y`          FLOAT        NOT NULL,
    `z`          FLOAT        NOT NULL,
    `heading`    FLOAT        NOT NULL DEFAULT 0,
    `planted_at` INT UNSIGNED NOT NULL,
    `water`      FLOAT        NOT NULL DEFAULT 0,
    `water_at`   INT UNSIGNED NOT NULL,
    `dry`        INT UNSIGNED NOT NULL DEFAULT 0,
    `fertilized` TINYINT(1)   NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`owner`)
);

-- ESX uniquement (inventaire du framework), à décommenter si besoin :
-- INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
--   ('weed_pot', 'Pot', 1), ('weed_seed', 'Cannabis seed', 1), ('water_bottle', 'Water bottle', 1),
--   ('weed_fertilizer', 'Fertilizer', 1), ('weed', 'Weed', 1);
```

Correspondance colonnes → PlantData : `planted_at` → `plantedAt`, `water_at` → `waterAt`,
`fertilized` (0/1) → boolean. Écritures : `MySQL.insert.await` (plantation, pour obtenir l'id), `MySQL.update`
(eau, engrais : `water`, `water_at`, `dry`, `fertilized`), `MySQL.query` (`DELETE`). Requêtes **toujours
paramétrées** (`?`). Pas de sauvegarde périodique : chaque changement est écrit tout de suite.

---

## 11. Logique partagée : `common/plant.lua` (Dev Serveur, utilisée par le Client)

Table globale `Plant`. Fonctions **pures** (aucune native, aucun effet de bord sauf `Settle`).
`p` = PlantData (ou entrée serveur), `now` = secondes serveur.

```lua
Plant = {}

Plant.ACTION_DISTANCE = 3.0   -- serveur : Bridge.IsNear pour planter / arroser / engrais / récolter / détruire
Plant.TARGET_DISTANCE = 1.8   -- client : distance des options de target
Plant.INFO_DISTANCE   = 2.0   -- client : affichage de la carte d'info
Plant.PLACE_FORWARD   = 1.0   -- client : distance de l'aperçu devant le joueur
Plant.THIRSTY_BELOW   = 90    -- arrosage possible seulement si eau < 90 %
```

| Fonction | Retour | Définition |
|---|---|---|
| `Plant.Progress(p, now)` | 0.0-1.0 | `clamp((now - p.plantedAt) / Config.GrowTime, 0, 1)` |
| `Plant.IsReady(p, now)` | bool | `Plant.Progress(p, now) >= 1.0` |
| `Plant.Stage(p, now)` | 1..#Config.Stages | `math.min(#Config.Stages, math.floor(Plant.Progress(p, now) * #Config.Stages) + 1)` |
| `Plant.Water(p, now)` | 0.0-100.0 | `max(0, p.water - (now - p.waterAt) * 100 / Config.WaterDuration)` |
| `Plant.DrySeconds(p, now)` | number | voir ci-dessous |
| `Plant.Quality(p, now)` | int 0-100 | `clamp(floor(Q.base + (p.fertilized and Q.fertilizer or 0) - Plant.DrySeconds(p, now) / Config.GrowTime * Q.dryPenalty + 0.5), 0, 100)` avec `Q = Config.Quality` |
| `Plant.HarvestAmount(quality)` | int | `Config.Harvest.min + floor((Config.Harvest.max - Config.Harvest.min) * quality / 100)` |
| `Plant.Settle(p, now)` | p | **serveur** : `p.dry = floor(Plant.DrySeconds(p, now))`, `p.water = Plant.Water(p, now)`, `p.waterAt = now` |

```lua
-- Temps passé à sec : seulement pendant la croissance (jusqu'à plantedAt + GrowTime).
function Plant.DrySeconds(p, now)
    local emptyAt = p.waterAt + p.water * Config.WaterDuration / 100
    local endAt = math.min(now, p.plantedAt + Config.GrowTime)
    return p.dry + math.max(0, endAt - math.max(emptyAt, p.waterAt))
end
```

Exemples (config par défaut) : arrosée à temps sans engrais → 75 ; avec engrais → 100 ; jamais arrosée → 0
(quantité 2) ; qualité 100 → quantité 6.

---

## 12. Comportement attendu

### Serveur (`server/main.lua`)
- **Démarrage** : thread → `CREATE TABLE IF NOT EXISTS` (section 10), `SELECT *`, remplit `plants[id]`, supprime
  d'abord les plantes pourries (`now > plantedAt + GrowTime + RotTime`), puis `loaded = true`.
  Avertissement console (anglais) si `Bridge.Inventory == 'none'` ou (`Bridge.Framework == 'standalone'` et
  `Bridge.Inventory == 'framework'`) : la plantation est impossible sans inventaire.
- **Items utilisables** : `Bridge.RegisterUsableItem(Config.Items.pot, onUse)` et idem pour `Config.Items.seed`.
  `onUse(src)` : pré-contrôles (pot ET graine présents, limite, pas en véhicule) → sinon `Bridge.Notify(src, L(...),
  'error')` ; si OK → `TriggerClientEvent('pop_weed:client:startPlacement', src)`. Rien n'est retiré ici.
- **Nettoyage** : `SetTimeout`/thread toutes les **300000 ms** : supprime les plantes pourries (mémoire, SQL,
  `plantRemoved`).
- **Récolte** : succès → `Bridge.Notify(src, L('harvested', amount, quality), 'success')` ; puis, si
  `math.random() < Config.Police.alertChance`, envoie `pop_weed:client:policeAlert` avec `{ x, y, z }` de la plante
  à chaque `src` de `Bridge.GetPlayers()` tel que `Bridge.HasJob(src, Config.Police.jobs)` et
  `Bridge.GetJob(src).onDuty`.
- **Arrosage / engrais** : `Plant.Settle(p, now)` **avant** de modifier ; arrosage → `p.water = 100` ; engrais →
  `p.fertilized = true` ; `MySQL.update`, puis `plantUpdated` à `-1` avec `os.time()`.

### Client (`client/main.lua`)
- **Chargement** : `Bridge.OnPlayerLoaded` → `Callback.Await('pop_weed:getPlants')` → remplit `WeedPlants[id]`
  (table globale côté client, lue par `placement.lua`) et l'heure serveur. `isPolice` = `Bridge.GetJob()` dans
  `Config.Police.jobs` (liste de noms ou clés si table à grades) **et** `onDuty`, mis à jour par
  `Bridge.OnJobUpdate`.
- **Boucle unique** (adaptative) :
  - aucune plante → `Wait(2000)` ;
  - pour chaque plante : `d ≤ Config.SpawnDistance` et non créée → créer ; créée et `d > Config.SpawnDistance + 10`
    → supprimer ; créée et `Plant.Stage` différent du stade affiché → recréer (prop + target) ;
  - plante créée la plus proche à `≤ Plant.INFO_DISTANCE` → `pop_weed:info` (si une valeur a changé), sinon
    `show = false` (une seule fois) ;
  - `Wait(nearest ≤ Plant.INFO_DISTANCE and 250 or nearest ≤ Config.SpawnDistance and 1000 or 2000)`.
- **Création d'un prop** : `RequestModel` (timeout 3 s), `CreateObject(hash, x, y, z + stage.offset, false, false,
  false)`, `SetEntityHeading`, `FreezeEntityPosition(true)`, collisions **actives** (raycast des targets),
  `SetModelAsNoLongerNeeded`. Puis `Bridge.Target.AddLocalEntity(entity, options)` ; à la suppression :
  `Bridge.Target.Remove(targetId)` puis `DeleteEntity`.
- **Options de target** (toutes `distance = Plant.TARGET_DISTANCE`), `canInteract` lit l'état local :

  | label | canInteract | Progression (`Config.Durations.*`, label) | Callback |
  |---|---|---|---|
  | `L('target_water')` | pas prête et `Plant.Water < Plant.THIRSTY_BELOW` | `water`, `L('watering')` | `pop_weed:water` |
  | `L('target_fertilize')` | pas prête et pas `fertilized` | `fertilize`, `L('fertilizing')` | `pop_weed:fertilize` |
  | `L('target_harvest')` | `Plant.IsReady` | `harvest`, `L('harvesting')` | `pop_weed:harvest` |
  | `L('target_destroy')` | `isPolice` | `destroy`, `L('destroying')` | `pop_weed:destroy` |

  Avant chaque action : si `Bridge.IsBusy()` → `Bridge.Notify(L('busy'), 'error')` ; `TaskTurnPedToFaceEntity`
  (500 ms), puis `Bridge.Progress(label, duration, { anim = ANIM })` ; si `true` → callback. Aucune vérification
  d'item côté client (le serveur répond `missing_item`).
  Animations : planter / engrais / récolter / détruire `amb@world_human_gardener_plant@male@base` / `base`
  (flag 1) ; arroser `weapon@w_sp_jerrycan` / `fire` (flag 1). Icônes (ox_target) : `fa-solid fa-droplet`,
  `fa-solid fa-flask`, `fa-solid fa-scissors`, `fa-solid fa-trash`.
- **Alerte police** : `Bridge.Notify(L('police_alert'), 'warning')` + blip `AddBlipForCoord` (sprite 140,
  couleur 1, échelle 0.9, nom `L('police_blip')`) supprimé après `Config.Police.blipTime` secondes.
- **Arrêt** (`onResourceStop`) : supprime props, targets, blips, aperçu de placement ; envoie `pop_weed:info` et
  `pop_weed:placement` avec `show = false`.

### Client (`client/placement.lua`)
- `pop_weed:client:startPlacement` : ignoré si déjà en placement ou `Bridge.IsBusy()`.
- Aperçu local : modèle `Config.Stages[1]`, `SetEntityAlpha(150)`, sans collision, figé. Chaque frame (**seulement
  pendant le placement**, 30 s max puis annulation) : position = joueur + avant × `Plant.PLACE_FORWARD`, z du sol
  via `GetGroundZFor_3dCoord`, heading = celui du joueur.
- Validité locale (raison) : en véhicule → `in_vehicle` ; pas de sol, écart sol/joueur > 1.5 m, joueur dans l'eau
  ou qui nage, ou eau au-dessus du sol (`GetWaterHeight`) → `cannot_plant_here` ; une plante de `WeedPlants` à
  moins de `Config.MinSpacing` → `too_close_plant`. Invalide → `SetEntityAlpha(60)`.
- Touches : `DisableControlAction` sur `Config.Keys.Interact.control` et `Config.Keys.Cancel.control` chaque frame
  (évite le double déclenchement avec le prompt du bridge), lecture par `IsDisabledControlJustReleased`.
  Confirmer (si valide) → supprime l'aperçu, `Bridge.Progress(L('planting'), Config.Durations.plant, { anim })`,
  puis `Callback.Await('pop_weed:plant', { x, y, z }, heading)`. Annuler / mort / timeout → fermeture.
  Le panneau NUI `pop_weed:placement` suit l'état.

---

## 13. Règles de sécurité (serveur, toutes obligatoires)

Le client n'est jamais cru : il n'envoie que `coords`/`heading` (placement) ou un `id`. Quantités, qualité, items,
temps : tout vient du serveur et de la config.

**Commun à toutes les actions**
1. `id` : `math.type(id) == 'integer'` et `plants[id]` existe, sinon `plant_not_found`.
2. Verrou par joueur `busy[src]` pendant le traitement (attentes SQL) → `busy` si déjà occupé ; libéré dans tous les
   cas (y compris erreur) et à la déconnexion.
3. `Bridge.IsNear(src, plante, Plant.ACTION_DISTANCE)`, sinon `too_far`.
4. `Bridge.GetIdentifier(src)` non nil, sinon `error`.
5. L'anti-spam du template (`Config.CallbackRateLimit`) reste actif.

**`pop_weed:plant`**
1. `coords` est une table ; `x`, `y`, `z` et `heading` sont des nombres finis (`n == n`, pas `±math.huge`) ;
   `|x|, |y| ≤ 10000`, `-200 ≤ z ≤ 2000` ; heading ramené dans `[0, 360)`.
2. `Bridge.IsNear(src, coords, Plant.ACTION_DISTANCE)`, sinon `too_far`.
3. `GetVehiclePedIsIn(GetPlayerPed(src), false) == 0`, sinon `in_vehicle`.
4. Aucune plante existante à moins de `Config.MinSpacing` (distance 3D sur toutes les plantes en mémoire), sinon
   `too_close_plant`.
5. Nombre de plantes de l'identifiant `< Config.MaxPlants`, sinon `max_plants`, arg `Config.MaxPlants`.
6. `Bridge.HasItem` pot puis graine, sinon `missing_item` + `L('item_pot')` / `L('item_seed')`.
7. Retrait : `Bridge.RemoveItem(pot)` puis `Bridge.RemoveItem(seed)` ; si le 2e échoue → rendre le pot
   (`Bridge.AddItem`) et `error`.
8. `MySQL.insert.await` ; si échec (pas d'id) → rendre pot + graine et `error`.
9. Plante créée avec `water = 0`, `waterAt = now`, `dry = 0`, `fertilized = false`, `owner = identifiant`.
   Diffusion `plantAdded`, notification `planted`.
   (Le contrôle « pas dans l'eau » est fait côté client : aucune native serveur fiable ; l'écart de hauteur est
   déjà borné par `IsNear`.)

**`pop_weed:water`** : pas prête (sinon `already_ready`) ; `Plant.Water < Plant.THIRSTY_BELOW` (sinon
`plant_not_thirsty`) ; `Bridge.RemoveItem(Config.Items.water)` réussi (sinon `missing_item` + `L('item_water')`).

**`pop_weed:fertilize`** : pas prête (sinon `already_ready`) ; pas déjà `fertilized` (sinon `already_fertilized`) ;
`Bridge.RemoveItem(Config.Items.fertilizer)` réussi (sinon `missing_item` + `L('item_fertilizer')`).

**`pop_weed:harvest`**
1. `Plant.IsReady(p, os.time())`, sinon `not_ready`.
2. Si `Config.OwnerOnly` et `p.owner ~= identifiant` → `not_owner`.
3. `quality = Plant.Quality(p, now)`, `amount = Plant.HarvestAmount(quality)`.
4. `Bridge.CanCarry(src, Config.Items.harvest, amount)`, sinon `inventory_full`.
5. **Retirer la plante de la mémoire avant** `Bridge.AddItem(src, Config.Items.harvest, amount, { quality = quality })`
   (empêche la double récolte) ; si `AddItem` échoue → remettre la plante et `inventory_full`.
6. `DELETE` SQL, diffusion `plantRemoved`, notification, alerte police éventuelle.

**`pop_weed:destroy`** : `Bridge.HasJob(src, Config.Police.jobs)` **et** `Bridge.GetJob(src).onDuty`, sinon
`wrong_job`. Puis suppression (mémoire, SQL, `plantRemoved`), notification `destroyed`. Aucune récompense.

**Items utilisables** : les pré-contrôles servent seulement au confort ; tout est revérifié dans `pop_weed:plant`.

**Données diffusées** : jamais d'`owner` ni d'identifiant envoyé aux clients.

---

## 14. Checklist de livraison (pour l'auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques octet pour octet à `templates/pop_base`.
- 10 locales présentes avec **toutes** les clés (base + section 9) ; aucun texte en dur (Lua et HTML/JS).
- Aucune entité réseau ; aucun `Wait(0)` hors placement / `Bridge.Progress` ; < 0.02 ms au repos.
- Fonctionne avec ESX (Legacy et ancien), QBCore, Qbox ; ox_target, qb-target et prompt natif ;
  ox / qb / qs-inventory et inventaire du framework.
