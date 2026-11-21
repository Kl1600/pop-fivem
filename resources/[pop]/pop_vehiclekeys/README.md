# pop_vehiclekeys

Vehicle keys as inventory items: remote lock with beep and lights, engine locked without the key, locksmith duplicates.
No mandatory dependency (no oxmysql, no ox_lib). ESX, QBCore, Qbox and standalone detected automatically.

## Installation

1. Put `pop_vehiclekeys` in `resources/[pop]/`.
2. Declare the key item in your inventory (see below).
3. `server.cfg`: start your framework and inventory **before** `[pop]`:
   ```
   ensure qb-core          # or es_extended / qbx_core
   ensure ox_inventory     # or qs-inventory / qb-inventory / pop_inventory
   ensure [pop]
   ```
4. Adjust `config.lua` (language, key item, lock range, locksmith locations and price).

A key is the item `Config.KeyItem` (default `vehicle_key`) with the metadata `{ plate = 'ABC123', description = 'Plate: ABC123' }`.
The inventory **must support item metadata** (ox, qs, qb, ps, pop inventory, or the QBCore/Qbox inventory).

## Item declaration

**ox_inventory** (`ox_inventory/data/items.lua`), with every framework:
```lua
['vehicle_key'] = {
    label = 'Vehicle key',
    weight = 10,
    stack = false,
    close = true,
    consume = 0, -- required: using the key must not remove it
},
```
Without `consume = 0`, ox_inventory removes the key each time it is used.
Standalone with ox_inventory only: also add `server = { export = 'pop_vehiclekeys.vehicle_key' }` so the item is usable,
and set `Config.Locksmith.price = 0` (no money in standalone).

**pop_inventory** (`pop_inventory/data/items.lua`):
```lua
['vehicle_key'] = { label = 'Vehicle key', weight = 10, stack = false, consume = 0 },
```

**qb-core / Qbox shared items** (`qb-core/shared/items.lua`):
```lua
vehicle_key = { name = 'vehicle_key', label = 'Vehicle key', weight = 10, type = 'item', image = 'vehicle_key.png', unique = true, useable = true, shouldClose = true, description = 'Vehicle key' },
```

**qs-inventory** (`qs-inventory/shared/items.lua`): same fields as QBCore (`unique = true`, `useable = true`).

## Usage

- Remote: key `U` by default (players can change it in Settings > Key Bindings > FiveM).
- Use a key from the inventory: locks / unlocks the vehicle with that plate if it is nearby.
- At a locksmith: use the key to copy from the inventory, wait for the progress bar, pay `Config.Locksmith.price`.
- Give a key: use the inventory's normal "give" feature.

## Exports (server)

```lua
exports.pop_vehiclekeys:GiveKey(source, GetVehicleNumberPlateText(vehicle)) -- bool
exports.pop_vehiclekeys:RemoveKey(source, plate, all)                       -- bool (all = true: every key of this plate)
exports.pop_vehiclekeys:HasKey(source, plate)                               -- bool
```
These exports are the only way for another script (dealership, garage, admin menu) to create a key.
No client event can create a key from a plate: duplicates require owning the key (checked server side).

## Limits

- ESX with its base inventory (no metadata): not supported. Use ox / qs / qb / pop inventory. The script prints a
  console warning and the engine lock is disabled (`GlobalState.pop_vehiclekeys_supported = false`).
- The engine lock is applied by the client (no reliable server native); key ownership is always checked server side.
- Scripts calling qb-vehiclekeys events are not supported (on purpose: those events allowed anyone to get any key).
  Use the `GiveKey` export instead.
- Lock state is not persistent (it lives on the vehicle in game).
- Vehicles nobody received a key for (NPC vehicles, job vehicles, garages or dealerships that do not call `GiveKey`)
  cannot be started. Your garage, dealership and job scripts must call
  `exports.pop_vehiclekeys:GiveKey(source, plate)` when they hand out a vehicle. Bicycles (`Config.NoKeyClasses`) are exempt.
- Standalone with ox_inventory: there is no money, so set `Config.Locksmith.price = 0`.
- The engine check asks the server again every 30 s while you drive with the key (a key taken away on the road is detected).
