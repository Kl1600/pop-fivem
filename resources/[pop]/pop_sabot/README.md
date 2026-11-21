# pop_sabot

GTA 6-style wheel clamp. An agent (job from `Config.Jobs`, on duty) fits the clamp: the vehicle is frozen and the
engine is cut. The agent can remove it (the item is returned), or anyone can cut it off with an angle grinder
(slow, loud, on-duty police are alerted as soon as cutting starts).

- Frameworks: ESX (Legacy and older), QBCore, Qbox, standalone (auto-detected).
- Inventories: pop_inventory, ox_inventory, qs-inventory, qb-inventory, ps-inventory, or the framework's own.
- Interaction: ox_target, qb-target, otherwise a native [E] prompt.
- No dependency, no database. Server: no loop. Client: no loop unless a clamped vehicle is known.
- 10 languages (`Config.Locale`): en, fr, es, de, it, pt, nl, pl, tr, ar.

## Installation

1. Put `pop_sabot` in `resources/[pop]/`.
2. `server.cfg`: `ensure` your framework and inventory **before** `ensure [pop]`.
3. Register both items (names can be changed in `Config.Items`).

### Items

**ox_inventory** (`data/items.lua`):
```lua
['wheel_clamp']   = { label = 'Wheel clamp',   weight = 5000, stack = true, consume = 0 },
['angle_grinder'] = { label = 'Angle grinder', weight = 3000, stack = false },
```
`consume = 0` is required: the script removes the clamp itself, only once the clamp is actually fitted.
In standalone with ox_inventory, also add to `wheel_clamp`: `server = { export = 'pop_sabot.wheel_clamp' }`.

**QBCore** (`qb-core/shared/items.lua`):
```lua
wheel_clamp   = { name = 'wheel_clamp',   label = 'Wheel clamp',   weight = 5000, type = 'item', image = 'wheel_clamp.png',   unique = false, useable = true,  shouldClose = true, description = '' },
angle_grinder = { name = 'angle_grinder', label = 'Angle grinder', weight = 3000, type = 'item', image = 'angle_grinder.png', unique = true,  useable = false, shouldClose = true, description = '' },
```

**ESX** (`items` table):
```sql
INSERT INTO `items` (`name`, `label`, `weight`) VALUES ('wheel_clamp', 'Wheel clamp', 5), ('angle_grinder', 'Angle grinder', 3);
```

`wheel_clamp` must be usable (the script registers it itself); `angle_grinder` is only checked, never consumed.
`Config.Items.cutter = nil` disables cutting.

### Clamp prop

`Config.Prop.model = 'prop_clamp'` **is not in the base game**: stream a clamp model (not included) in a stream
resource, or play without a prop (the clamp stays active). The prop is visual only: the interaction is always on
the vehicle, near the clamped wheel (`Config.Prop.bone`).

## Server exports

```lua
exports.pop_sabot:IsClamped(netId)         -- bool
exports.pop_sabot:SetClamped(netId, state) -- bool: fit (true) / remove (false) without item or job; false if the vehicle is not found
```

Useful for an impound, an admin menu or another script. The state can also be read anywhere through the
`Entity(veh).state.popClamp` state bag (written by the server only; a client change is reverted).

## Limits

- A deleted vehicle (garage, impound, restart) loses its clamp: no persistence.
- Driving is blocked by the clients (no server native can prevent it). The server asks the vehicle's current owner
  to freeze it; the freeze is then maintained by the clients.
- In standalone there is no job: no agent can fit or remove a clamp (only `SetClamped` and cutting work).
- No built-in fine or impound.

## Security

The server checks everything: job and duty, item, distance to the vehicle (server position), player alive and on
foot, free driver seat, per-player lock, and the cutting time (no earlier than `Config.Durations.cut`, expired
10 s after it). `Config.Debug = true` logs every fit, removal and cut to the console (player, identifier, plate).
