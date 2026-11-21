# pop_weed

Culture de cannabis en pot, simple et lisible : planter, arroser, engrais (facultatif), récolter.
La qualité dépend des soins. Props locaux uniquement, aucune boucle rapide côté serveur (~0.00 ms).

## Installation

1. Dépendance : **oxmysql** (obligatoire). Framework, inventaire et target sont détectés automatiquement.
2. Copier `pop_weed` dans `resources/[pop]/`.
3. `server.cfg` : lancer le framework, l'inventaire et le target **avant** :
   ```
   ensure oxmysql
   ensure es_extended   # ou qb-core / qbx_core
   ensure ox_inventory  # ou qb-inventory / qs-inventory
   ensure ox_target     # facultatif (ou qb-target) : sinon prompt « [E] » intégré
   ensure pop_weed
   ```
4. La table `pop_weed_plants` est créée au démarrage (`sql/install.sql` fourni pour référence).
5. Déclarer les items ci-dessous dans votre inventaire.

Sans inventaire (standalone pur), la plantation est impossible : un avertissement s'affiche en console.

## Items

Noms par défaut (modifiables dans `Config.Items`) : `weed_pot`, `weed_seed`, `water_bottle`, `weed_fertilizer`, `weed`.
`weed_pot` et `weed_seed` sont **utilisables** (ils lancent le placement). `weed` reçoit la métadonnée `{ quality = 0-100 }`.

### ox_inventory (`data/items.lua`)
```lua
-- consume = 0 : l'item n'est pas retiré à l'utilisation (pop_weed le retire à la plantation).
['weed_pot']        = { label = 'Pot', weight = 500, consume = 0 },
['weed_seed']       = { label = 'Cannabis seed', weight = 10, consume = 0 },
['weed_fertilizer'] = { label = 'Fertilizer', weight = 500 },
['weed']            = { label = 'Weed', weight = 50 },
```
ox_inventory fournit déjà `water` : mettre `Config.Items.water = 'water'`.
En standalone avec ox_inventory, ajouter `server = { export = 'pop_weed.weed_pot' }` (et `pop_weed.weed_seed`).

### QBCore / Qbox avec qb-inventory ou ps-inventory (`qb-core/shared/items.lua`)
```lua
weed_pot        = { name = 'weed_pot',        label = 'Pot',           weight = 500, type = 'item', image = 'weed_pot.png',        unique = false, useable = true,  shouldClose = true, description = '' },
weed_seed       = { name = 'weed_seed',       label = 'Cannabis seed', weight = 10,  type = 'item', image = 'weed_seed.png',       unique = false, useable = true,  shouldClose = true, description = '' },
weed_fertilizer = { name = 'weed_fertilizer', label = 'Fertilizer',    weight = 500, type = 'item', image = 'weed_fertilizer.png', unique = false, useable = false, shouldClose = true, description = '' },
weed            = { name = 'weed',            label = 'Weed',          weight = 50,  type = 'item', image = 'weed.png',            unique = false, useable = false, shouldClose = true, description = '' },
```
`water_bottle` : déjà présent dans QBCore, rien à ajouter.

### qs-inventory
qs-inventory a son propre fichier d'items (`qs-inventory/shared/items.lua`) : y déclarer les mêmes items,
au même format que ci-dessus, avec `useable = true` pour `weed_pot` et `weed_seed`.

### ESX (inventaire du framework)
Décommenter le bloc `INSERT IGNORE INTO items` de `sql/install.sql`. L'inventaire ESX ne gère pas les métadonnées :
la qualité influence alors seulement la quantité récoltée.

## Configuration (`config.lua`)

| Clé | Défaut | Rôle |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar |
| `Config.GrowTime` | `3600` | secondes jusqu'à la récolte |
| `Config.WaterDuration` | `1800` | secondes de 100 % à 0 % d'eau |
| `Config.RotTime` | `86400` | une plante mûre non récoltée disparaît après ce délai |
| `Config.MaxPlants` | `5` | plantes max par joueur |
| `Config.MinSpacing` | `1.5` | distance minimale entre deux plantes |
| `Config.OwnerOnly` | `false` | seul le planteur peut récolter |
| `Config.Quality` | `75 / 25 / 100` | base, bonus engrais, pénalité à sec |
| `Config.Harvest` | `2 - 6` | quantité selon la qualité |
| `Config.Police` | police, sheriff ; 25 % | jobs (en service) qui peuvent détruire, chance d'alerte, durée du blip |
| `Config.SpawnDistance` | `50.0` | distance d'affichage des plantes |

## Exports serveur

```lua
exports.pop_weed:GetPlants()              -- copies, avec owner
exports.pop_weed:GetPlayerPlantCount(src) -- number
exports.pop_weed:RemovePlant(id)          -- bool
```

Export client : `exports.pop_weed:IsPlacing()`.

## Langues

`locales/` : 10 langues. Ajouter une langue : copier `en.lua`, changer le code, traduire.
