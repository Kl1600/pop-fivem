# pop_weed

Grow cannabis in pots. Plant, water, optionally fertilize, and harvest. Care determines quality. Plants use local props, and the server avoids fast polling loops, targeting ~0.00 ms at idle.

## Installation

1. Install **oxmysql**. The resource detects your framework, inventory, and target system automatically.
2. Copy `pop_weed` into `resources/[pop]/`.
3. Start the framework, inventory, and target system before the resource in `server.cfg`:

   ```
   ensure oxmysql
   ensure es_extended   # or qb-core / qbx_core
   ensure ox_inventory  # or qb-inventory / qs-inventory
   ensure ox_target     # optional (or qb-target), with a built-in [E] prompt as fallback
   ensure pop_weed
   ```

4. The resource creates the `pop_weed_plants` table on startup. See `sql/install.sql` for reference.
5. Register the items below with your inventory.

Planting requires an inventory. Pure standalone servers without one receive a console warning.

## Items

The defaults in `Config.Items` are `weed_pot`, `weed_seed`, `water_bottle`, `weed_fertilizer`, and `weed`. Using `weed_pot` or `weed_seed` starts placement. The `weed` item receives `{ quality = 0-100 }` metadata.

### ox_inventory (`data/items.lua`)

```lua
-- consume = 0 keeps the item on use. pop_weed removes it when planting succeeds.
['weed_pot']        = { label = 'Pot', weight = 500, consume = 0 },
['weed_seed']       = { label = 'Cannabis seed', weight = 10, consume = 0 },
['weed_fertilizer'] = { label = 'Fertilizer', weight = 500 },
['weed']            = { label = 'Weed', weight = 50 },
```

ox_inventory already provides `water`. Set `Config.Items.water = 'water'`.
In standalone mode with ox_inventory, add `server = { export = 'pop_weed.weed_pot' }` to the pot and use `pop_weed.weed_seed` for the seed.

### QBCore or Qbox with qb-inventory or ps-inventory (`qb-core/shared/items.lua`)

```lua
weed_pot        = { name = 'weed_pot',        label = 'Pot',           weight = 500, type = 'item', image = 'weed_pot.png',        unique = false, useable = true,  shouldClose = true, description = '' },
weed_seed       = { name = 'weed_seed',       label = 'Cannabis seed', weight = 10,  type = 'item', image = 'weed_seed.png',       unique = false, useable = true,  shouldClose = true, description = '' },
weed_fertilizer = { name = 'weed_fertilizer', label = 'Fertilizer',    weight = 500, type = 'item', image = 'weed_fertilizer.png', unique = false, useable = false, shouldClose = true, description = '' },
weed            = { name = 'weed',            label = 'Weed',          weight = 50,  type = 'item', image = 'weed.png',            unique = false, useable = false, shouldClose = true, description = '' },
```

QBCore already provides `water_bottle`.

### qs-inventory

Register the same items in `qs-inventory/shared/items.lua`, using the format above with `useable = true` for `weed_pot` and `weed_seed`.

### ESX framework inventory

Uncomment the `INSERT IGNORE INTO items` block in `sql/install.sql`. The built-in ESX inventory has no metadata support, so quality affects only the harvest quantity.

## Configuration (`config.lua`)

| Key | Default | Purpose |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar |
| `Config.GrowTime` | `3600` | Seconds until harvest |
| `Config.WaterDuration` | `1800` | Seconds for water to drop from 100% to 0% |
| `Config.RotTime` | `86400` | Seconds before an unharvested mature plant disappears |
| `Config.MaxPlants` | `5` | Maximum plants per player |
| `Config.MinSpacing` | `1.5` | Minimum spacing between plants |
| `Config.OwnerOnly` | `false` | When enabled, only the planter can harvest |
| `Config.Quality` | `75 / 25 / 100` | Base quality, fertilizer bonus, and dry penalty |
| `Config.Harvest` | `2 - 6` | Quantity by quality |
| `Config.Police` | police, sheriff, 25% chance | On-duty jobs that can destroy plants, alert chance, and blip duration |
| `Config.SpawnDistance` | `50.0` | Plant display distance |

## Server exports

```lua
exports.pop_weed:GetPlants()              -- copies including owner
exports.pop_weed:GetPlayerPlantCount(src) -- number
exports.pop_weed:RemovePlant(id)          -- bool
```

Client export: `exports.pop_weed:IsPlacing()`.

## Languages

`locales/` contains ten languages. To add one, copy `en.lua`, change the language code, and translate the values.
