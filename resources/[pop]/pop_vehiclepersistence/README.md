# pop_vehiclepersistence

Players' vehicles stay exactly where they were parked, across disconnects and server restarts: position, lock state,
damage (body, engine, tank, doors, windows, tyres), dirt, fuel, mods, colours and neons.
No menu, no command: everything is automatic and invisible.

- Vehicles only exist in the world when a player is within `Config.SpawnDistance`; hundreds of parked vehicles cost nothing.
- No duplicates: before creating a vehicle, the server looks for its plate in the world and adopts the existing one.
- A tracked vehicle that disappears (stored in a garage, impounded, `/dv`) or is wrecked stops being tracked.

## Requirements

- **OneSync is required** (`set onesync on`, enabled by default on recent servers): vehicles are created server-side.
  Without OneSync the resource cannot create or follow any vehicle.
- **oxmysql**.
- Optional: ESX (Legacy or old), QBCore, Qbox, `pop_vehiclekeys`, `pop_bennys`, `pop_paintgun`.

## Installation

1. Copy `pop_vehiclepersistence` into `resources/[pop]/`.
2. The table is created automatically on start (or run `sql/install.sql`).
3. In `server.cfg`, start oxmysql, your framework and `pop_vehiclekeys` (if used) **before** `[pop]`:
   ```
   ensure oxmysql
   ensure es_extended   # or qb-core / qbx_core
   ensure [pop]
   ```

## Configuration (`config.lua`)

| Key | Default | Description |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar |
| `Config.Debug` | `false` | console logs (creations, adoptions, removals with plate and reason) |
| `Config.Mode` | `'auto'` | which vehicles are kept (see below) |
| `Config.SpawnDistance` | `150.0` | a parked vehicle appears when a player is closer than this (metres) |
| `Config.MaxPerOwner` | `5` | parked vehicles per owner; beyond that the oldest is towed (deleted) |
| `Config.ExpireDays` | `14` | a vehicle not driven for this many days is deleted (`0` = never) |

### Modes

| Mode | Vehicle kept if | Owner |
|---|---|---|
| `framework` | its plate exists in `owned_vehicles` (ESX) / `player_vehicles` (QBCore, Qbox) | owner from that table |
| `keys` | the driver has a key (`exports.pop_vehiclekeys:HasKey`) | first driver |
| `all` | any vehicle driven by a player | first driver |

`auto`: `framework` with ESX / QBCore / Qbox (if the table exists), otherwise `keys` if `pop_vehiclekeys` is started,
otherwise `all`. The effective mode is printed in the console on start.

In `framework` mode, a vehicle marked as stored in the framework table (`stored = 1` ESX, `state ~= 0` QBCore/Qbox)
is never recreated.

## Temporary vehicles (POP contract)

Rental, job or company vehicles must never be kept. Any script can flag them, server-side:

```lua
Entity(vehicle).state:set('pop_temporary', true, true)
```

Trains are always ignored.

## Server API

```lua
exports.pop_vehiclepersistence:IsPersisted(plate)     -- bool
exports.pop_vehiclepersistence:RemoveVehicle(plate)   -- bool: stop tracking, delete the entity if empty
exports.pop_vehiclepersistence:GetVehicles(owner?)    -- { { plate, owner, model, x, y, z, spawned }, ... }
```

Garages may call `RemoveVehicle(plate)` before storing a vehicle (optional: a vanished vehicle is detected anyway).

Local server event emitted after each creation by this script (keys, fuel...):

```lua
AddEventHandler('pop_vehiclepersistence:spawned', function(plate, netId) end)
```

Local server events listened to: `pop_bennys:saved` (`src, plate, props, owned?`; health, dirt and fuel are ignored) and `pop_paintgun:painted`
(`src, netId, color, target, plate`).

## Security

- The client only sends a network id and visual properties. Position, heading, plate, model, type, lock state,
  health and owner are always read by the server.
- Properties are validated (known fields, types and bounds) and size-limited; per-player cooldown and rate limit.
- An update while on foot is only accepted for the vehicle that player was just driving, within 10 m.

## Limits

- OneSync is required.
- A tracked vehicle deleted by another script (garage, impound, `/dv`, cleanup script) is simply forgotten: it stops
  being tracked and is not recreated. Calling `RemoveVehicle(plate)` first is cleaner but optional.
- A tracked vehicle whose plate is changed by another script is released (no longer followed under its old plate).
- Fuel and mods come from the driver's last update: a cheater can alter the look of **their own** vehicle, with no
  money or item gain.
- A garage that spawns a "stored" vehicle without updating `stored` / `state` may create a short-lived duplicate:
  it is resolved on the next check (the empty copy created by this script is deleted).
- Temporary vehicle scripts must set `pop_temporary` (see above).
- Health and dirt are read server-side; a vehicle with no network owner keeps its last known values.

## Performance

- Client: one loop at 1000 / 1500 ms, no per-frame loop.
- Server: proximity check every 5 s, differential save every 60 s, expiry every hour. No entity while nobody is near.
