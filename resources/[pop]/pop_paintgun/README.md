# pop_paintgun

Paint gun to repaint a vehicle: pick the area (primary, secondary, both) and a colour.
ESX, QBCore, Qbox or standalone; ox/qb/qs/ps-inventory or the framework inventory. No required dependency, no SQL.

## Installation

1. Copy `pop_paintgun` into `resources/[pop]/`.
2. `server.cfg`: `ensure pop_paintgun` **after** the framework and the inventory.
3. Add the `spray_gun` (not consumed) and `paint_can` (1 consumed per paint job) items to your inventory.
4. Settings in `config.lua`: `Config.Item`, `Config.PaintItem` (`nil` = nothing consumed), `Config.Jobs`,
   `Config.Duration`, `Config.Colors`, `Config.Locale`.

### Items

ox_inventory (`data/items.lua`):
```lua
['spray_gun'] = { label = 'Paint gun', weight = 1000, stack = false },
['paint_can'] = { label = 'Paint can', weight = 500 },
```
Standalone with ox_inventory: add `server = { export = 'pop_paintgun.spray_gun' }` to `spray_gun`.

QBCore (`qb-core/shared/items.lua`):
```lua
spray_gun = { name = 'spray_gun', label = 'Paint gun', weight = 1000, type = 'item', image = 'spray_gun.png', unique = true, useable = true, shouldClose = true, description = '' },
paint_can = { name = 'paint_can', label = 'Paint can', weight = 500, type = 'item', image = 'paint_can.png', unique = false, useable = false, shouldClose = false, description = '' },
```

ESX: insert both items into the `items` table of your database (`name`, `label`, `weight`).

## Garages: `pop_paintgun:painted` event

**Local** server event (not networked), fired after a validated paint job:

```lua
AddEventHandler('pop_paintgun:painted', function(src, netId, color, target, plate)
    -- target: 'primary' | 'secondary' | 'both' ; color: native GTA colour ; plate: vehicle plate text
end)
```
Use `AddEventHandler` (not `RegisterNetEvent`): a client then cannot trigger it.

## Limits

- The colour is applied, on the server's order, by the vehicle's network owner (the game syncs it). A cheater could
  paint without the script, but gains no item and no money: the server protects the items.
- The progress bar runs client-side and can be skipped by a cheater; the server still enforces the minimum duration
  and the paint can is consumed anyway.
- To keep the colour after storing the vehicle in a garage, the garage must save the vehicle properties
  (most do) or listen to `pop_paintgun:painted`.
