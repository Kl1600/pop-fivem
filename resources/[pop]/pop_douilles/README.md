# pop_douilles

Gunshots leave bullet casings. Police **search** the area (`K` by default), **bag** the casings as evidence, then
**read** the ballistic report by using the item. Two casings with the same signature = same shooter, same weapon.

- No hard dependency (ESX, QBCore, Qbox or standalone; ox_target / qb-target, otherwise a native prompt).
- No database: casings live in memory and are cleared on restart (by design).
- 10 languages (`Config.Locale`), Arabic in RTL.

## Installation

1. Put `pop_douilles` in `resources/[pop]/`.
2. `ensure` your framework and inventory **before** `[pop]`.
3. Register the `bullet_casing` item (or the value of `Config.Item`) in your inventory, see below.
4. Set `Config.PoliceJobs` (the player needs the job **and** must be on duty).

## Registering the item

The item must be **usable** and **not stackable**: every piece of evidence carries its own metadata.
Using it must **not** consume it (the report can be read again).

**ox_inventory** (`ox_inventory/data/items.lua`)
```lua
['bullet_casing'] = {
    label = 'Bullet casing',
    weight = 10,
    stack = false,
    close = true,
    consume = 0,
},
```
In **standalone** with ox_inventory, also add: `server = { export = 'pop_douilles.bullet_casing' },`.

**QBCore / qb-inventory / ps-inventory** (`qb-core/shared/items.lua`)
```lua
bullet_casing = { name = 'bullet_casing', label = 'Bullet casing', weight = 10, type = 'item',
    image = 'bullet_casing.png', unique = true, useable = true, shouldClose = true, description = '' },
```

**Qbox**: Qbox uses ox_inventory, see above.

**qs-inventory** (`qs-inventory/shared/items.lua`): same format as QBCore (`unique = true`, `useable = true`).

**ESX (default inventory)**
```sql
INSERT INTO `items` (`name`, `label`, `weight`) VALUES ('bullet_casing', 'Bullet casing', 1);
```

## Server exports

```lua
-- Creates a casing (crime scene, NPC). identifier is optional: the signature is based on 'npc' otherwise.
local id = exports.pop_douilles:AddCasing(vector3(x, y, z), `WEAPON_PISTOL`, 3, 'any-identifier')

-- Removes casings within a radius, returns how many were removed.
local removed = exports.pop_douilles:ClearArea(vector3(x, y, z), 15.0)
```

## Limits

- Shot detection is client-side: a cheater can choose not to report shots. They cannot fake the weapon (read by
  the server) or a distant position (checked by the server).
- Shots fired right before holstering or switching weapons are sent immediately; the server keeps the last weapon
  it saw for 1.5 s to attribute them.
- One shooter with one weapon can leave at most 15 casing spots; older ones disappear first. Server-wide cap:
  `Config.MaxCasings`.
- Inventory without metadata (default ESX): the item is given without information; no report is shown.
- In standalone there is no job: nobody can search.
- `Config.Prop` is visual only (the pickup zone is a small box around the casing). If your server streams a real
  casing model, put its name here.
- `Config.Debug = true` prints shots, searches, pickups and export calls to the console.
